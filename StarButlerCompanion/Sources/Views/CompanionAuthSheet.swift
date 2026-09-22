import SwiftUI

public struct CompanionAuthSheet: View {
    @ObservedObject var auth = CompanionAuthManager.shared
    @ObservedObject var client = CompanionClient.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var relayUrl = ""
    @State private var isRegisterMode = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                if auth.isLoggedIn {
                    loggedInSection
                } else {
                    authFormSection
                }
                
                Section(header: Text("广域网云中继服务器")) {
                    HStack {
                        Text("地址")
                            .frame(width: 50, alignment: .leading)
                            .font(.system(size: 14))
                        TextField("http://192.168.49.168:8765", text: $relayUrl)
                            .font(.system(size: 13))
                            #if canImport(UIKit)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            #endif
                        
                        Button("保存") {
                            auth.saveRelayUrl(relayUrl)
                        }
                        .font(.system(size: 13, weight: .semibold))
                    }
                    Text("提示: 本地测试使用当前 Mac 的局域网 IP，外网使用配置您的公网域名或服务器中继。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(auth.isLoggedIn ? "账号与云控" : "注册 / 登录")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                relayUrl = auth.relayServerUrl
                if auth.isLoggedIn {
                    auth.fetchDeviceStatus()
                }
            }
        }
    }
    
    // MARK: - Logged In View
    
    private var loggedInSection: some View {
        Group {
            Section(header: Text("已登录账号")) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(auth.userEmail)
                            .font(.system(size: 16, weight: .bold))
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(client.isCloudConnected ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                            Text(client.isCloudConnected ? "云端长连正常" : "云端连接中...")
                                .font(.system(size: 12))
                                .foregroundColor(client.isCloudConnected ? .green : .orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("绑定的 Mac 主机")) {
                HStack {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 24))
                        .foregroundColor(auth.isHostOnline ? .green : .secondary)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(auth.hostMachineName ?? "未命名的 Mac")
                            .font(.system(size: 15, weight: .semibold))
                        
                        Text(auth.isHostOnline ? "Mac 正在运行且在线" : "Mac 离线或未启动 StarButler")
                            .font(.system(size: 12))
                            .foregroundColor(auth.isHostOnline ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    if auth.isHostOnline {
                        Text("\(auth.agentCount) 个智能体")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                Button(action: {
                    auth.fetchDeviceStatus()
                    client.reconnectCloud()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新主机状态与云连接")
                    }
                    .font(.system(size: 14))
                }
            }
            
            Section {
                Button(role: .destructive, action: {
                    auth.logout()
                }) {
                    HStack {
                        Spacer()
                        Text("退出登录")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Auth Form
    
    private var authFormSection: some View {
        Group {
            Section {
                VStack(alignment: .center, spacing: 10) {
                    Image(systemName: "cloud.badge.waveform.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                    
                    Text("StarButler 广域网远程控制")
                        .font(.system(size: 17, weight: .bold))
                    
                    Text("打破局域网限制。在 Mac 与 iPhone 上登录同一账号，外出使用 4G/5G 随时随地掌控 AI 智能体任务。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            
            Section(header: Text("账号信息")) {
                Picker("", selection: $isRegisterMode) {
                    Text("登录").tag(false)
                    Text("注册").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.vertical, 4)
                
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    TextField("电子邮箱", text: $email)
                        #if canImport(UIKit)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                }
                
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    SecureField("密码 (至少 6 位)", text: $password)
                }
            }
            
            if let err = auth.errorMessage {
                Section {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
            }
            
            if let succ = auth.successMessage {
                Section {
                    Text(succ)
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                }
            }
            
            Section {
                Button(action: {
                    auth.saveRelayUrl(relayUrl)
                    if isRegisterMode {
                        auth.register(email: email, password: password) { ok in
                            if ok { dismiss() }
                        }
                    } else {
                        auth.login(email: email, password: password) { ok in
                            if ok { dismiss() }
                        }
                    }
                }) {
                    HStack {
                        Spacer()
                        if auth.isAuthenticating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 6)
                        }
                        Text(isRegisterMode ? "立即注册并登录" : "登录")
                            .font(.system(size: 16, weight: .bold))
                        Spacer()
                    }
                    .frame(height: 32)
                }
                .disabled(email.isEmpty || password.count < 6 || auth.isAuthenticating)
            }
        }
    }
}
