import Foundation
import Network
import Combine

public struct DiscoveredMacHost: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let endpoint: NWEndpoint
    
    public init(name: String, endpoint: NWEndpoint) {
        self.id = "\(name)_\(endpoint)"
        self.name = name
        self.endpoint = endpoint
    }
}

public final class CompanionClient: ObservableObject {
    public static let shared = CompanionClient()
    
    @Published public var isConnected = false
    @Published public var connectedHostName: String?
    @Published public var agents: [CompanionAgent] = []
    @Published public var discoveredHosts: [DiscoveredMacHost] = []
    @Published public var isBrowsing = false
    @Published public var lastRefreshedAt: Date = Date()
    @Published public var totalTodayTokens: Int = 0
    @Published public var totalHistoryTokens: Int = 0
    @Published public var totalTokensPerSec: Int = 0
    
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.starbutler.companion.client", qos: .userInitiated)
    
    public var runningAgents: [CompanionAgent] {
        agents.filter { $0.isRunning }
    }
    
    public var stoppedAgents: [CompanionAgent] {
        agents.filter { !$0.isRunning }
    }
    
    public init() {
        startBrowsing()
    }
    
    // MARK: - Bonjour Browser (Zero-Config Mac Discovery)
    
    public func startBrowsing() {
        stopBrowsing()
        
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_starbutler._tcp", domain: nil), using: params)
        
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }
            var hosts: [DiscoveredMacHost] = []
            for result in results {
                if case let .service(name, _, _, _) = result.endpoint {
                    hosts.append(DiscoveredMacHost(name: name, endpoint: result.endpoint))
                }
            }
            
            DispatchQueue.main.async {
                self.discoveredHosts = hosts
                // Auto-connect if only one host is discovered and not connected
                if !self.isConnected, let first = hosts.first {
                    self.connect(to: first)
                }
            }
        }
        
        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isBrowsing = true
                case .failed, .cancelled:
                    self?.isBrowsing = false
                default:
                    break
                }
            }
        }
        
        browser.start(queue: queue)
        self.browser = browser
    }
    
    public func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isBrowsing = false
    }
    
    // MARK: - Connection Management
    
    public func connect(to host: DiscoveredMacHost) {
        disconnect()
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.includePeerToPeer = true
        
        let conn = NWConnection(to: host.endpoint, using: params)
        setupConnection(conn, hostName: host.name)
    }
    
    public func connect(host: String, port: UInt16) {
        disconnect()
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.includePeerToPeer = true
        
        let nwEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? 58240)
        let conn = NWConnection(to: nwEndpoint, using: params)
        setupConnection(conn, hostName: "\(host):\(port)")
    }
    
    private func setupConnection(_ conn: NWConnection, hostName: String) {
        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self.isConnected = true
                    self.connectedHostName = hostName
                    self.receiveLoop()
                case .failed, .cancelled:
                    self.isConnected = false
                    self.connectedHostName = nil
                default:
                    break
                }
            }
        }
        
        conn.start(queue: queue)
        self.connection = conn
    }
    
    public func disconnect() {
        connection?.cancel()
        connection = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectedHostName = nil
        }
    }
    
    // MARK: - Data Streaming
    
    private func receiveLoop() {
        guard let conn = connection else { return }
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = data, !data.isEmpty {
                let chunks = data.split(separator: 0x0A)
                for chunk in chunks {
                    if let msg = try? JSONDecoder().decode(CompanionMessagePayload.self, from: chunk),
                       let newAgents = msg.agents {
                        DispatchQueue.main.async {
                            self.agents = newAgents
                            self.lastRefreshedAt = Date()
                            self.updateAggregates()
                        }
                    }
                }
            }
            
            if isComplete || error != nil {
                self.disconnect()
            } else {
                self.receiveLoop()
            }
        }
    }
    
    private func updateAggregates() {
        var today = 0
        var history = 0
        var tps = 0
        for a in agents {
            today += a.todayTokens
            history += a.historyTokens
            if a.isRunning { tps += a.tokensPerSec }
        }
        self.totalTodayTokens = today
        self.totalHistoryTokens = history
        self.totalTokensPerSec = tps
    }
    
    // MARK: - Remote Actions
    
    public func terminateAgent(_ agent: CompanionAgent) {
        sendAction(action: "terminate", targetId: agent.bundleId)
    }
    
    public func terminateAllRunning() {
        sendAction(action: "terminateAll")
    }
    
    public func requestRefresh() {
        sendAction(action: "refresh")
    }
    
    private func sendAction(action: String, targetId: String? = nil) {
        guard let conn = connection, isConnected else { return }
        let msg = CompanionMessagePayload(type: "action", action: action, targetId: targetId)
        if let data = try? JSONEncoder().encode(msg) {
            var packet = data
            packet.append(0x0A)
            conn.send(content: packet, completion: .idempotent)
        }
    }
}
