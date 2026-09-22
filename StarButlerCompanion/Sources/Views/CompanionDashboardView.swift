import SwiftUI

public struct CompanionDashboardView: View {
    @ObservedObject var client = CompanionClient.shared
    
    @State private var showConnectionSheet = false
    @State private var showTerminateAllAlert = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Top Overview Banner
                    overviewBanner
                    
                    // Running Agents Section
                    if !client.runningAgents.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("运行中智能体 (\(client.runningAgents.count))")
                                    .font(.system(size: 16, weight: .bold))
                                Spacer()
                                
                                Button(action: { showTerminateAllAlert = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "stop.circle.fill")
                                            .font(.system(size: 12))
                                        Text("全部关闭")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.red.opacity(0.12)))
                                }
                            }
                            .padding(.horizontal, 4)
                            
                            ForEach(client.runningAgents) { agent in
                                CompanionAgentCard(agent: agent) {
                                    client.terminateAgent(agent)
                                }
                            }
                        }
                    }
                    
                    // Stopped Agents Section
                    if !client.stoppedAgents.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("已停止智能体 (\(client.stoppedAgents.count))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                            
                            ForEach(client.stoppedAgents) { agent in
                                CompanionAgentCard(agent: agent) {}
                            }
                        }
                    }
                    
                    if client.agents.isEmpty {
                        emptyPlaceholder
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .refreshable {
                client.requestRefresh()
            }
            #if canImport(UIKit)
            .background(Color(uiColor: .systemGroupedBackground))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
            .navigationTitle("StarButler")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    connectionBadgeButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
                #else
                ToolbarItem(placement: .navigation) {
                    connectionBadgeButton
                }
                ToolbarItem(placement: .primaryAction) {
                    refreshButton
                }
                #endif
            }
            .sheet(isPresented: $showConnectionSheet) {
                CompanionConnectionSheet()
            }
            .alert("确定全部关闭运行中的 AI 软件吗？", isPresented: $showTerminateAllAlert) {
                Button("全部关闭", role: .destructive) {
                    client.terminateAllRunning()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将向连接的 Mac 发送指令，立刻终止所有运行中的 AI 进程以释放系统资源。")
            }
        }
    }
    
    private var connectionBadgeButton: some View {
        Button(action: { showConnectionSheet = true }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(client.isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(client.isConnected ? "已连接" : "未连接")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(Color.gray.opacity(0.12)))
        }
    }
    
    private var refreshButton: some View {
        Button(action: { client.requestRefresh() }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
        }
    }
    
    // MARK: - Overview Banner
    
    private var overviewBanner: some View {
        HStack(spacing: 12) {
            BannerMetric(
                title: "今日 Token 消耗",
                value: formatTokens(client.totalTodayTokens),
                unit: "Tokens",
                icon: "chart.bar.fill",
                color: .blue
            )
            
            BannerMetric(
                title: "实时生成吞吐",
                value: "\(client.totalTokensPerSec)",
                unit: "T/s",
                icon: "bolt.fill",
                color: .orange
            )
            
            BannerMetric(
                title: "活跃智能体",
                value: "\(client.runningAgents.count)",
                unit: "个运行中",
                icon: "sparkles",
                color: .green
            )
        }
    }
    
    private var emptyPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: client.isConnected ? "tray" : "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(client.isConnected ? "暂无 AI 智能体数据" : "尚未连接到 Mac 主机")
                .font(.system(size: 16, weight: .semibold))
            
            Text(client.isConnected ? "下拉可重新向 Mac 发送探测请求" : "点击左上角状态按钮搜索并连接同一局域网下的 Mac")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !client.isConnected {
                Button("搜索局域网主机") {
                    showConnectionSheet = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                #if canImport(UIKit)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                #else
                .fill(Color(nsColor: .controlBackgroundColor))
                #endif
        )
        .padding(.top, 20)
    }
    
    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.2fM", Double(n) / 1_000_000.0)
        } else if n >= 1_000 {
            return String(format: "%.1fk", Double(n) / 1_000.0)
        } else {
            return "\(n)"
        }
    }
}

private struct BannerMetric: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                #if canImport(UIKit)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                #else
                .fill(Color(nsColor: .controlBackgroundColor))
                #endif
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
        )
    }
}
