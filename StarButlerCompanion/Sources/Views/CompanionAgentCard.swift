import SwiftUI

public struct CompanionAgentCard: View {
    public let agent: CompanionAgent
    public let onTerminate: () -> Void
    public let onActivate: () -> Void
    public let onLaunch: () -> Void
    
    @State private var showConfirm = false
    
    public init(
        agent: CompanionAgent,
        onTerminate: @escaping () -> Void,
        onActivate: @escaping () -> Void = {},
        onLaunch: @escaping () -> Void = {}
    ) {
        self.agent = agent
        self.onTerminate = onTerminate
        self.onActivate = onActivate
        self.onLaunch = onLaunch
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Real App Icon, Name, Model, State Badge
            HStack(spacing: 12) {
                appIconView
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(agent.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if let model = agent.modelName, !model.isEmpty {
                            Text(model)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.purple.opacity(0.12)))
                        }
                    }
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(agent.agentState.color)
                            .frame(width: 6, height: 6)
                        Text(agent.agentState.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(agent.agentState.color)
                        
                        if agent.isRunning, let pid = agent.pid {
                            Text("· PID \(pid)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        if agent.isRunning, agent.tokensPerSec > 0 {
                            Text("· \(agent.tokensPerSec) T/s")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Current Task Bubble (if running and task available)
            if agent.isRunning, let task = agent.currentTask, !task.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                    
                    Text(task)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.08)))
            }
            
            // Token Metrics Grid
            HStack(spacing: 0) {
                MetricItem(title: "今日消耗", value: "\(agent.formattedTodayTokens) T", highlight: agent.todayTokens > 0)
                Divider().frame(height: 22)
                MetricItem(title: "输入 (Prompt)", value: "\(agent.formattedInputTokens) T")
                Divider().frame(height: 22)
                MetricItem(title: "输出 (Gen)", value: "\(agent.formattedOutputTokens) T")
                Divider().frame(height: 22)
                MetricItem(title: "历史累计", value: "\(agent.formattedHistoryTokens) T")
            }
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
            
            // Bottom Action Bar: 大面性按钮
            if agent.isRunning {
                HStack(spacing: 10) {
                    Button(action: onActivate) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.forward.app.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("置顶前台")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.blue.opacity(0.12))
                        )
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: { showConfirm = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "power")
                                .font(.system(size: 13, weight: .bold))
                            Text("关闭进程")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.red)
                        )
                    }
                    .buttonStyle(.borderless)
                    .confirmationDialog("确定要关闭 \(agent.displayName) 吗？", isPresented: $showConfirm) {
                        Button("关闭应用进程", role: .destructive) {
                            onTerminate()
                        }
                        Button("取消", role: .cancel) {}
                    } message: {
                        Text("将向连接的 Mac 发送指令，结束该 AI 进程以释放算力与内存。")
                    }
                }
            } else {
                Button(action: onLaunch) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("启动应用")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                    )
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                #if canImport(UIKit)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                #else
                .fill(Color(nsColor: .controlBackgroundColor))
                #endif
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }
    
    // MARK: - App Icon View (Real native Mac App Icon or fallback)
    
    @ViewBuilder
    private var appIconView: some View {
        if let b64 = agent.iconBase64,
           let data = Data(base64Encoded: b64) {
            #if canImport(UIKit)
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
            } else {
                fallbackIcon
            }
            #elseif canImport(AppKit)
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
            } else {
                fallbackIcon
            }
            #else
            fallbackIcon
            #endif
        } else {
            fallbackIcon
        }
    }
    
    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(agent.isRunning ? Color.blue.opacity(0.15) : Color.gray.opacity(0.12))
                .frame(width: 44, height: 44)
            
            Image(systemName: agent.agentState.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(agent.agentState.color)
        }
    }
}

private struct MetricItem: View {
    let title: String
    let value: String
    var highlight: Bool = false
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: highlight ? .bold : .medium))
                .foregroundColor(highlight ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
