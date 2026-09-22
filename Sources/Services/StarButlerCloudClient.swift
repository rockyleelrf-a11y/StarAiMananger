import Foundation
import AppKit

public final class StarButlerCloudClient: ObservableObject {
    public static let shared = StarButlerCloudClient()
    
    @Published public var isLoggedIn: Bool = false
    @Published public var userEmail: String = ""
    @Published public var token: String = ""
    @Published public var relayServerUrl: String = "http://192.168.49.168:8765"
    @Published public var isWebSocketConnected: Bool = false
    @Published public var statusMessage: String = "未登录"
    @Published public var isConnecting: Bool = false
    
    public var onActionReceived: ((_ action: String, _ targetId: String?) -> Void)?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectWorkItem: DispatchWorkItem?
    private let userDefaults = UserDefaults.standard
    private let kEmailKey = "starbutler_cloud_email"
    private let kTokenKey = "starbutler_cloud_token"
    private let kRelayUrlKey = "starbutler_cloud_relay_url"
    
    private init() {
        loadPersistedCredentials()
        if isLoggedIn {
            connectWebSocket()
        }
    }
    
    // MARK: - Persistence
    
    private func loadPersistedCredentials() {
        if let savedRelay = userDefaults.string(forKey: kRelayUrlKey), !savedRelay.isEmpty {
            self.relayServerUrl = savedRelay
        }
        if let savedEmail = userDefaults.string(forKey: kEmailKey),
           let savedToken = userDefaults.string(forKey: kTokenKey),
           !savedEmail.isEmpty && !savedToken.isEmpty {
            self.userEmail = savedEmail
            self.token = savedToken
            self.isLoggedIn = true
            self.statusMessage = "已登录: \(savedEmail)"
        }
    }
    
    public func saveRelayUrl(_ url: String) {
        var cleanUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanUrl.hasPrefix("http://") && !cleanUrl.hasPrefix("https://") {
            cleanUrl = "http://" + cleanUrl
        }
        self.relayServerUrl = cleanUrl
        userDefaults.set(cleanUrl, forKey: kRelayUrlKey)
        if isLoggedIn {
            reconnectWebSocket()
        }
    }
    
    // MARK: - Auth API
    
    public func register(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let url = URL(string: "\(relayServerUrl)/api/auth/register") else {
            completion(.failure(NSError(domain: "StarButlerCloud", code: -1, userInfo: [NSLocalizedDescriptionKey: "服务器地址无效"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["email": cleanEmail, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        isConnecting = true
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isConnecting = false
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(NSError(domain: "StarButlerCloud", code: -2, userInfo: [NSLocalizedDescriptionKey: "服务器响应格式错误"])))
                    return
                }
                
                if let err = json["error"] as? String {
                    completion(.failure(NSError(domain: "StarButlerCloud", code: -3, userInfo: [NSLocalizedDescriptionKey: err])))
                    return
                }
                
                if let token = json["token"] as? String {
                    self.userEmail = cleanEmail
                    self.token = token
                    self.isLoggedIn = true
                    self.userDefaults.set(cleanEmail, forKey: self.kEmailKey)
                    self.userDefaults.set(token, forKey: self.kTokenKey)
                    self.statusMessage = "注册成功并已登录: \(cleanEmail)"
                    self.connectWebSocket()
                    completion(.success(cleanEmail))
                } else {
                    completion(.failure(NSError(domain: "StarButlerCloud", code: -4, userInfo: [NSLocalizedDescriptionKey: "未获取到有效 Token"])))
                }
            }
        }.resume()
    }
    
    public func login(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let url = URL(string: "\(relayServerUrl)/api/auth/login") else {
            completion(.failure(NSError(domain: "StarButlerCloud", code: -1, userInfo: [NSLocalizedDescriptionKey: "服务器地址无效"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["email": cleanEmail, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        isConnecting = true
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isConnecting = false
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(NSError(domain: "StarButlerCloud", code: -2, userInfo: [NSLocalizedDescriptionKey: "服务器响应格式错误"])))
                    return
                }
                
                if let err = json["error"] as? String {
                    completion(.failure(NSError(domain: "StarButlerCloud", code: -3, userInfo: [NSLocalizedDescriptionKey: err])))
                    return
                }
                
                if let token = json["token"] as? String {
                    self.userEmail = cleanEmail
                    self.token = token
                    self.isLoggedIn = true
                    self.userDefaults.set(cleanEmail, forKey: self.kEmailKey)
                    self.userDefaults.set(token, forKey: self.kTokenKey)
                    self.statusMessage = "已登录: \(cleanEmail)"
                    self.connectWebSocket()
                    completion(.success(cleanEmail))
                } else {
                    completion(.failure(NSError(domain: "StarButlerCloud", code: -4, userInfo: [NSLocalizedDescriptionKey: "未获取到有效 Token"])))
                }
            }
        }.resume()
    }
    
    public func logout() {
        disconnectWebSocket()
        userDefaults.removeObject(forKey: kEmailKey)
        userDefaults.removeObject(forKey: kTokenKey)
        self.isLoggedIn = false
        self.userEmail = ""
        self.token = ""
        self.statusMessage = "未登录"
    }
    
    // MARK: - WebSocket Long Connection (Host Mode)
    
    public func reconnectWebSocket() {
        disconnectWebSocket()
        connectWebSocket()
    }
    
    public func connectWebSocket() {
        guard isLoggedIn, !token.isEmpty else { return }
        disconnectWebSocket()
        
        let wsScheme = relayServerUrl.lowercased().hasPrefix("https") ? "wss" : "ws"
        let hostPart = relayServerUrl
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        
        let hostName = (Host.current().localizedName ?? "Mac").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Mac"
        let wsUrlString = "\(wsScheme)://\(hostPart)/relay?token=\(token)&role=host&name=\(hostName)"
        
        guard let url = URL(string: wsUrlString) else {
            self.statusMessage = "WebSocket 地址格式错误"
            return
        }
        
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        
        self.statusMessage = "正在连接云中继..."
        listenWebSocket()
    }
    
    public func disconnectWebSocket() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isWebSocketConnected = false
            if self.isLoggedIn {
                self.statusMessage = "云端连接已断开"
            }
        }
    }
    
    private func listenWebSocket() {
        guard let task = webSocketTask else { return }
        task.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    if !self.isWebSocketConnected {
                        self.isWebSocketConnected = true
                        self.statusMessage = "云端中继已连通 (远程控制就绪)"
                    }
                }
                
                switch message {
                case .string(let text):
                    self.handleIncomingString(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleIncomingString(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue listening
                self.listenWebSocket()
                
            case .failure(let error):
                print("[StarButlerCloudClient] WebSocket error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isWebSocketConnected = false
                    self.statusMessage = "连接异常，5秒后自动重连..."
                    self.scheduleReconnect()
                }
            }
        }
    }
    
    private func scheduleReconnect() {
        reconnectWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.isLoggedIn else { return }
            self.connectWebSocket()
        }
        reconnectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: item)
    }
    
    private func handleIncomingString(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // Check for action
        if let action = json["action"] as? String {
            let targetId = json["targetId"] as? String
            DispatchQueue.main.async {
                self.onActionReceived?(action, targetId)
            }
        }
    }
    
    // MARK: - Send Snapshot to Cloud Relay
    
    public func sendSnapshot(agents: [AIAgentApp]) {
        guard isLoggedIn, isWebSocketConnected, let task = webSocketTask else { return }
        let payloads = agents.map { CompanionAgentPayload(from: $0) }
        let msg = CompanionMessage(type: "snapshot", agents: payloads)
        guard let data = try? JSONEncoder().encode(msg),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        
        task.send(.string(jsonString)) { error in
            if let error = error {
                print("[StarButlerCloudClient] Send snapshot error: \(error.localizedDescription)")
            }
        }
    }
}
