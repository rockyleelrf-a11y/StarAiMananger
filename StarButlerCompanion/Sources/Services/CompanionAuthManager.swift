import Foundation
import Combine

public final class CompanionAuthManager: ObservableObject {
    public static let shared = CompanionAuthManager()
    
    @Published public var isLoggedIn: Bool = false
    @Published public var userEmail: String = ""
    @Published public var token: String = ""
    @Published public var relayServerUrl: String = "http://192.168.49.168:8765"
    @Published public var isHostOnline: Bool = false
    @Published public var hostMachineName: String? = nil
    @Published public var lastSeen: Double? = nil
    @Published public var agentCount: Int = 0
    @Published public var isAuthenticating: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil
    
    private let userDefaults = UserDefaults.standard
    private let kEmailKey = "companion_auth_email"
    private let kTokenKey = "companion_auth_token"
    private let kRelayUrlKey = "companion_auth_relay_url"
    
    private init() {
        loadCredentials()
    }
    
    public func loadCredentials() {
        if let savedRelay = userDefaults.string(forKey: kRelayUrlKey), !savedRelay.isEmpty {
            self.relayServerUrl = savedRelay
        }
        if let savedEmail = userDefaults.string(forKey: kEmailKey),
           let savedToken = userDefaults.string(forKey: kTokenKey),
           !savedEmail.isEmpty && !savedToken.isEmpty {
            self.userEmail = savedEmail
            self.token = savedToken
            self.isLoggedIn = true
            fetchDeviceStatus()
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
            fetchDeviceStatus()
            CompanionClient.shared.reconnectCloud()
        }
    }
    
    public func register(email: String, password: String, completion: ((Bool) -> Void)? = nil) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let url = URL(string: "\(relayServerUrl)/api/auth/register") else {
            self.errorMessage = "云中继服务器地址格式不正确"
            completion?(false)
            return
        }
        
        isAuthenticating = true
        errorMessage = nil
        successMessage = nil
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": cleanEmail, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAuthenticating = false
                if let error = error {
                    self.errorMessage = "连接失败: \(error.localizedDescription)"
                    completion?(false)
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.errorMessage = "服务器返回格式无效"
                    completion?(false)
                    return
                }
                
                if let err = json["error"] as? String {
                    self.errorMessage = err
                    completion?(false)
                    return
                }
                
                if let token = json["token"] as? String {
                    self.userEmail = cleanEmail
                    self.token = token
                    self.isLoggedIn = true
                    self.userDefaults.set(cleanEmail, forKey: self.kEmailKey)
                    self.userDefaults.set(token, forKey: self.kTokenKey)
                    self.successMessage = "注册成功并已登录"
                    self.fetchDeviceStatus()
                    CompanionClient.shared.connectCloud()
                    completion?(true)
                } else {
                    self.errorMessage = "未能获取访问授权"
                    completion?(false)
                }
            }
        }.resume()
    }
    
    public func login(email: String, password: String, completion: ((Bool) -> Void)? = nil) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let url = URL(string: "\(relayServerUrl)/api/auth/login") else {
            self.errorMessage = "云中继服务器地址格式不正确"
            completion?(false)
            return
        }
        
        isAuthenticating = true
        errorMessage = nil
        successMessage = nil
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": cleanEmail, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAuthenticating = false
                if let error = error {
                    self.errorMessage = "连接失败: \(error.localizedDescription)"
                    completion?(false)
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.errorMessage = "服务器返回格式无效"
                    completion?(false)
                    return
                }
                
                if let err = json["error"] as? String {
                    self.errorMessage = err
                    completion?(false)
                    return
                }
                
                if let token = json["token"] as? String {
                    self.userEmail = cleanEmail
                    self.token = token
                    self.isLoggedIn = true
                    self.userDefaults.set(cleanEmail, forKey: self.kEmailKey)
                    self.userDefaults.set(token, forKey: self.kTokenKey)
                    self.successMessage = "登录成功"
                    if let online = json["hostOnline"] as? Bool {
                        self.isHostOnline = online
                    }
                    if let hostName = json["hostName"] as? String {
                        self.hostMachineName = hostName
                    }
                    self.fetchDeviceStatus()
                    CompanionClient.shared.connectCloud()
                    completion?(true)
                } else {
                    self.errorMessage = "未能获取访问授权"
                    completion?(false)
                }
            }
        }.resume()
    }
    
    public func logout() {
        CompanionClient.shared.disconnectCloud()
        userDefaults.removeObject(forKey: kEmailKey)
        userDefaults.removeObject(forKey: kTokenKey)
        self.isLoggedIn = false
        self.userEmail = ""
        self.token = ""
        self.isHostOnline = false
        self.hostMachineName = nil
        self.errorMessage = nil
        self.successMessage = nil
    }
    
    public func fetchDeviceStatus() {
        guard isLoggedIn, !token.isEmpty else { return }
        guard let url = URL(string: "\(relayServerUrl)/api/device/status?token=\(token)") else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            
            DispatchQueue.main.async {
                if let online = json["hostOnline"] as? Bool {
                    self.isHostOnline = online
                }
                if let name = json["machineName"] as? String {
                    self.hostMachineName = name
                }
                if let count = json["agentCount"] as? Int {
                    self.agentCount = count
                }
                if let seen = json["lastSeen"] as? Double {
                    self.lastSeen = seen
                }
            }
        }.resume()
    }
}
