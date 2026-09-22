import Foundation
import Network

public struct CompanionAgentPayload: Codable, Identifiable {
    public let id: String
    public let name: String
    public let displayName: String
    public let bundleId: String
    public let isRunning: Bool
    public let pid: Int?
    public let state: String
    public let currentTask: String?
    public let modelName: String?
    public let inputTokens: Int
    public let outputTokens: Int
    public let todayTokens: Int
    public let historyTokens: Int
    public let tokensPerSec: Int
    
    public init(from agent: AIAgentApp) {
        self.id = agent.id
        self.name = agent.name
        self.displayName = agent.displayName
        self.bundleId = agent.bundleId
        self.isRunning = agent.isRunning
        self.pid = agent.pid.map { Int($0) }
        self.state = agent.state.rawValue
        self.currentTask = agent.currentTask
        self.modelName = agent.modelName
        self.inputTokens = agent.inputTokens
        self.outputTokens = agent.outputTokens
        self.todayTokens = agent.todayTokens
        self.historyTokens = agent.historyTokens
        self.tokensPerSec = agent.tokensPerSec
    }
}

public struct CompanionMessage: Codable {
    public let type: String  // "snapshot", "update", "action"
    public let timestamp: Double
    public let agents: [CompanionAgentPayload]?
    public let action: String?       // "terminate", "terminateAll", "refresh"
    public let targetId: String?     // bundleId
    
    public init(type: String, agents: [CompanionAgentPayload]? = nil, action: String? = nil, targetId: String? = nil) {
        self.type = type
        self.timestamp = Date().timeIntervalSince1970
        self.agents = agents
        self.action = action
        self.targetId = targetId
    }
}

public final class StarButlerCompanionServer: ObservableObject {
    public static let shared = StarButlerCompanionServer()
    
    @Published public var isRunning = false
    @Published public var connectedClientsCount = 0
    @Published public var port: UInt16 = 0
    
    public var onActionReceived: ((_ action: String, _ targetId: String?) -> Void)?
    
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.starbutler.companion.server", qos: .userInitiated)
    private var lastPayload: [CompanionAgentPayload] = []
    
    public init() {}
    
    public func start(preferredPort: UInt16 = 58240) {
        stop()
        do {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 5
            
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.includePeerToPeer = true
            
            // Configure Bonjour Service
            let hostName = Host.current().localizedName ?? "Mac"
            params.serviceClass = .responsiveData
            
            let nwPort = NWEndpoint.Port(rawValue: preferredPort) ?? .any
            let listener = try NWListener(using: params, on: nwPort)
            listener.service = NWListener.Service(name: "StarButler - \(hostName)", type: "_starbutler._tcp")
            
            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        if let actualPort = listener.port?.rawValue {
                            self?.port = actualPort
                        }
                    case .failed, .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            print("[StarButler Host] Failed to start NWListener: \(error)")
        }
    }
    
    public func stop() {
        queue.async {
            for c in self.connections {
                c.cancel()
            }
            self.connections.removeAll()
            self.listener?.cancel()
            self.listener = nil
            DispatchQueue.main.async {
                self.isRunning = false
                self.connectedClientsCount = 0
            }
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        queue.async {
            self.connections.append(connection)
            DispatchQueue.main.async {
                self.connectedClientsCount = self.connections.count
            }
            
            connection.stateUpdateHandler = { [weak self, weak connection] state in
                guard let self = self, let connection = connection else { return }
                switch state {
                case .ready:
                    // Send initial snapshot
                    self.sendSnapshot(to: connection)
                    self.receiveLoop(on: connection)
                case .failed, .cancelled:
                    self.removeConnection(connection)
                default:
                    break
                }
            }
            
            connection.start(queue: self.queue)
        }
    }
    
    private func removeConnection(_ connection: NWConnection) {
        queue.async {
            self.connections.removeAll(where: { $0 === connection })
            DispatchQueue.main.async {
                self.connectedClientsCount = self.connections.count
            }
        }
    }
    
    public func broadcast(agents: [AIAgentApp]) {
        let payload = agents.map { CompanionAgentPayload(from: $0) }
        queue.async {
            self.lastPayload = payload
            guard !self.connections.isEmpty else { return }
            
            let message = CompanionMessage(type: "update", agents: payload)
            guard let data = try? JSONEncoder().encode(message) else { return }
            
            // Delimit with newline
            var packet = data
            packet.append(0x0A) // '\n'
            
            for conn in self.connections {
                conn.send(content: packet, completion: .idempotent)
            }
        }
    }
    
    private func sendSnapshot(to connection: NWConnection) {
        let message = CompanionMessage(type: "snapshot", agents: self.lastPayload)
        if let data = try? JSONEncoder().encode(message) {
            var packet = data
            packet.append(0x0A)
            connection.send(content: packet, completion: .idempotent)
        }
    }
    
    private func receiveLoop(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self, weak connection] data, _, isComplete, error in
            guard let self = self, let connection = connection else { return }
            
            if let data = data, !data.isEmpty {
                // Split by newline
                let chunks = data.split(separator: 0x0A)
                for chunk in chunks {
                    if let msg = try? JSONDecoder().decode(CompanionMessage.self, from: chunk) {
                        if let action = msg.action {
                            DispatchQueue.main.async {
                                self.onActionReceived?(action, msg.targetId)
                            }
                        }
                    }
                }
            }
            
            if isComplete || error != nil {
                self.removeConnection(connection)
            } else {
                self.receiveLoop(on: connection)
            }
        }
    }
}
