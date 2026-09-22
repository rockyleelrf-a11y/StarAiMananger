import Foundation
import Network
import Combine

public enum CompanionConnectionMode: String {
    case lanBonjour = "局域网直连"
    case cloudRelay = "云端远程"
    case disconnected = "未连接"
}

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
    
    @Published public var isLanConnected = false
    @Published public var isCloudConnected = false
    @Published public var connectedHostName: String?
    @Published public var agents: [CompanionAgent] = []
    @Published public var discoveredHosts: [DiscoveredMacHost] = []
    @Published public var isBrowsing = false
    @Published public var lastRefreshedAt: Date = Date()
    @Published public var totalTodayTokens: Int = 0
    @Published public var totalHistoryTokens: Int = 0
    @Published public var totalTokensPerSec: Int = 0
    
    public var isConnected: Bool {
        isLanConnected || isCloudConnected
    }
    
    public var connectionMode: CompanionConnectionMode {
        if isLanConnected { return .lanBonjour }
        if isCloudConnected { return .cloudRelay }
        return .disconnected
    }
    
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var lanReceiveBuffer = Data()
    private let queue = DispatchQueue(label: "com.starbutler.companion.client", qos: .userInitiated)
    
    // Cloud WebSocket Task
    private var webSocketTask: URLSessionWebSocketTask?
    private var cloudReconnectItem: DispatchWorkItem?
    
    public var runningAgents: [CompanionAgent] {
        agents.filter { $0.isRunning }
    }
    
    public var stoppedAgents: [CompanionAgent] {
        agents.filter { !$0.isRunning }
    }
    
    public init() {
        startBrowsing()
        // Try connecting to cloud if logged in
        if CompanionAuthManager.shared.isLoggedIn {
            connectCloud()
        }
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
                // Auto-connect if only one host is discovered and not currently LAN-connected
                if !self.isLanConnected, let first = hosts.first {
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
    
    // MARK: - LAN Connection Management
    
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
        lanReceiveBuffer.removeAll()
        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self.isLanConnected = true
                    self.connectedHostName = hostName
                    self.receiveLoop()
                case .failed, .cancelled:
                    self.isLanConnected = false
                    if !self.isCloudConnected {
                        self.connectedHostName = nil
                    }
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
        lanReceiveBuffer.removeAll()
        DispatchQueue.main.async {
            self.isLanConnected = false
            if !self.isCloudConnected {
                self.connectedHostName = nil
            }
        }
    }
    
    // MARK: - LAN Data Streaming (Buffered)
    
    private func receiveLoop() {
        guard let conn = connection else { return }
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = data, !data.isEmpty {
                self.lanReceiveBuffer.append(data)
                
                // Parse full newline-terminated JSON payloads
                while let idx = self.lanReceiveBuffer.firstIndex(of: 0x0A) {
                    let packet = self.lanReceiveBuffer.subdata(in: 0..<idx)
                    self.lanReceiveBuffer.removeSubrange(0...idx)
                    
                    if let msg = try? JSONDecoder().decode(CompanionMessagePayload.self, from: packet),
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
    
    // MARK: - Cloud Relay WebSocket Management
    
    public func reconnectCloud() {
        disconnectCloud()
        connectCloud()
    }
    
    public func connectCloud() {
        let auth = CompanionAuthManager.shared
        guard auth.isLoggedIn, !auth.token.isEmpty else { return }
        disconnectCloud()
        
        let wsScheme = auth.relayServerUrl.lowercased().hasPrefix("https") ? "wss" : "ws"
        let hostPart = auth.relayServerUrl
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        
        let wsUrlString = "\(wsScheme)://\(hostPart)/relay?token=\(auth.token)&role=client"
        guard let url = URL(string: wsUrlString) else { return }
        
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        
        listenCloudWebSocket()
    }
    
    public func disconnectCloud() {
        cloudReconnectItem?.cancel()
        cloudReconnectItem = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isCloudConnected = false
            if !self.isLanConnected {
                self.connectedHostName = nil
            }
        }
    }
    
    private func listenCloudWebSocket() {
        guard let task = webSocketTask else { return }
        task.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    if !self.isCloudConnected {
                        self.isCloudConnected = true
                        if self.connectedHostName == nil {
                            self.connectedHostName = CompanionAuthManager.shared.hostMachineName ?? "Mac (云端)"
                        }
                    }
                }
                
                switch message {
                case .string(let text):
                    self.handleCloudMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleCloudMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue listening
                self.listenCloudWebSocket()
                
            case .failure(let error):
                print("[CompanionClient] Cloud WS error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isCloudConnected = false
                    self.scheduleCloudReconnect()
                }
            }
        }
    }
    
    private func scheduleCloudReconnect() {
        cloudReconnectItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, CompanionAuthManager.shared.isLoggedIn else { return }
            self.connectCloud()
        }
        cloudReconnectItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: item)
    }
    
    private func handleCloudMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        // 1. Check if it's host status update
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String, type == "hostStatus" {
            DispatchQueue.main.async {
                let online = json["online"] as? Bool ?? false
                let machineName = json["machineName"] as? String
                CompanionAuthManager.shared.isHostOnline = online
                if let name = machineName {
                    CompanionAuthManager.shared.hostMachineName = name
                    if !self.isLanConnected {
                        self.connectedHostName = "\(name) (云端)"
                    }
                }
            }
            return
        }
        
        // 2. Check if it's snapshot or update message
        if let msg = try? JSONDecoder().decode(CompanionMessagePayload.self, from: data),
           let newAgents = msg.agents {
            DispatchQueue.main.async {
                // If LAN is active, prefer LAN updates for lowest latency, but Cloud provides complete WAN fallback
                if !self.isLanConnected || self.agents.isEmpty {
                    self.agents = newAgents
                    self.lastRefreshedAt = Date()
                    self.updateAggregates()
                    CompanionAuthManager.shared.agentCount = newAgents.count
                    CompanionAuthManager.shared.isHostOnline = true
                }
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
    
    // MARK: - Unified Remote Actions (LAN + Cloud)
    
    public func terminateAgent(_ agent: CompanionAgent) {
        sendAction(action: "terminate", targetId: agent.bundleId)
    }
    
    public func activateAgent(_ agent: CompanionAgent) {
        sendAction(action: "activate", targetId: agent.bundleId)
    }
    
    public func launchAgent(_ agent: CompanionAgent) {
        sendAction(action: "launch", targetId: agent.bundleId)
    }
    
    public func terminateAllRunning() {
        sendAction(action: "terminateAll")
    }
    
    public func requestRefresh() {
        sendAction(action: "refresh")
    }
    
    private func sendAction(action: String, targetId: String? = nil) {
        let msg = CompanionMessagePayload(type: "action", action: action, targetId: targetId)
        
        // 1. Send via LAN connection if available
        if let conn = connection, isLanConnected {
            if let data = try? JSONEncoder().encode(msg) {
                var packet = data
                packet.append(0x0A)
                conn.send(content: packet, completion: .idempotent)
            }
        }
        
        // 2. Also send via Cloud Relay WebSocket if active
        if let task = webSocketTask, isCloudConnected {
            let dict: [String: Any?] = [
                "type": "action",
                "action": action,
                "targetId": targetId,
                "timestamp": Date().timeIntervalSince1970
            ]
            let cleanDict = dict.compactMapValues { $0 }
            if let jsonData = try? JSONSerialization.data(withJSONObject: cleanDict),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                task.send(.string(jsonString)) { _ in }
            }
        }
    }
}
