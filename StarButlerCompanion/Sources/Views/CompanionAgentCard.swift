import SwiftUI

public struct CompanionAgentCard: View {
    public let agent: CompanionAgent
    public let onTerminate: () -> Void
    
    @State private var showConfirm = false
    
    public init(agent: CompanionAgent, onTerminate: @escaping () -> Void) {
        self.agent = agent
        self.onTerminate = onTerminate
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row: Icon, Name, Model, State Badge & Close Button
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(agent.isRunning ? Color.blue.opacity(0.15) : Color.gray.opacity(0.12))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: agent.agentState.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(agent.agentState.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(agent.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if let model = agent.modelName, !model.isEmpty {
                            Text(model)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.purple.opacity(0.12)))
                        }
                    }
                    
                    HStack(spacing: 4) {
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
                
                if agent.isRunning {
                    Button(action: { showConfirm = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                            Text("关闭")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(Color.red.opacity(0.12)))
                    }
                    .buttonStyle(.borderless)
                    .confirmationDialog("确定要关闭 \(agent.displayName) 吗？", isPresented: $showConfirm) {
                        Button("关闭应用", role: .destructive) {
                            onTerminate()
                        }
                        Button("取消", role: .cancel) {}
                    }
                }
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
