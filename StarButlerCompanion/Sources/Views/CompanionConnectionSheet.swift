import SwiftUI

public struct CompanionConnectionSheet: View {
    @ObservedObject var client = CompanionClient.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var manualHost = ""
    @State private var manualPort = "58240"
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("当前连接状态")) {
                    HStack {
                        Image(systemName: client.isConnected ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(client.isConnected ? .green : .orange)
                            .font(.system(size: 20))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.isConnected ? "已连接到 Mac" : "未连接")
                                .font(.system(size: 15, weight: .semibold))
                            if let host = client.connectedHostName {
                                Text(host)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if client.isConnected {
                            Button("断开") {
                                client.disconnect()
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("广域网云端远程控制 (4G / 5G / 外网)")) {
                    NavigationLink(destination: CompanionAuthSheet()) {
                        HStack(spacing: 12) {
                            Image(systemName: "cloud.badge.waveform.fill")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 22))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(CompanionAuthManager.shared.isLoggedIn ? "云端远程控制已绑定" : "注册 / 登录云控账号")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(CompanionAuthManager.shared.isLoggedIn ? "账号: \(CompanionAuthManager.shared.userEmail) (\(client.isCloudConnected ? "已连通" : "正在连接"))" : "外出无需同一 Wi-Fi，跨互联网实时管理 Mac 智能体")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: HStack {
                    Text("局域网发现 (Bonjour)")
                    Spacer()
                    if client.isBrowsing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }) {
                    if client.discoveredHosts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("正在搜索局域网内的 StarButler...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text("请确保 Mac 与此设备连接在同一 Wi-Fi 下")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(client.discoveredHosts) { host in
                            HStack {
                                Image(systemName: "desktopcomputer")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(host.name)
                                        .font(.system(size: 15, weight: .medium))
                                    Text("局域网点对点服务")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    client.connect(to: host)
                                    dismiss()
                                }) {
                                    Text(client.connectedHostName == host.name ? "已连接" : "连接")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(client.connectedHostName == host.name ? .secondary : .blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section(header: Text("手动 IP 连接 (备用)")) {
                    HStack {
                        Text("IP 地址")
                            .frame(width: 70, alignment: .leading)
                        TextField("例如 192.168.1.10", text: $manualHost)
                            #if canImport(UIKit)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                    HStack {
                        Text("端口")
                            .frame(width: 70, alignment: .leading)
                        TextField("58240", text: $manualPort)
                            #if canImport(UIKit)
                            .keyboardType(.numberPad)
                            #endif
                    }
                    
                    Button("连接到指定主机") {
                        if !manualHost.isEmpty, let p = UInt16(manualPort) {
                            client.connect(host: manualHost, port: p)
                            dismiss()
                        }
                    }
                    .disabled(manualHost.isEmpty)
                }
            }
            .navigationTitle("伴侣配对管理")
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
        }
    }
}
