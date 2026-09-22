import SwiftUI
import AppKit

public struct PopoverContentView: View {
    @ObservedObject var manager: AIAgentManager
    
    public init(manager: AIAgentManager) {
        self.manager = manager
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().opacity(0.3)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 10) {
                    ForEach(manager.agents) { agent in
                        AIAgentCardView(agent: agent, manager: manager)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: manager.agents.map { "\($0.id)_\($0.isRunning)" })
            }
            .frame(maxHeight: 560)
            Divider().opacity(0.3)
            footerView
        }
        .frame(width: 720)
        .background(ZStack {
            VisualEffectBackground()
            Color(NSColor.windowBackgroundColor).opacity(0.92)
        })
    }
    
    private var headerView: some View {
        HStack(alignment: .center, spacing: 10) {
            if let logoUrl = Bundle.main.url(forResource: "logo", withExtension: "png"),
               let img = NSImage(contentsOf: logoUrl) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
            } else {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("StarButler")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(manager.runningCount) 个运行中")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(manager.runningCount > 0 ? .green : .secondary)
                        .padding(.horizontal, 7).padding(.vertical, 2.5)
                        .background(Capsule().fill(manager.runningCount > 0 ? Color.green.opacity(0.12) : Color.gray.opacity(0.12)))
                    
                    if manager.companionServer.connectedClientsCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "ipad.and.iphone")
                            Text("\(manager.companionServer.connectedClientsCount) 伴侣在线")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6).padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.blue.opacity(0.12)))
                    }
                }
                Text("实时任务探测 · 今日与历史 Token 统计 · 进程调度")
                    .font(.system(size: 10)).foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                HeaderButton(icon: "arrow.clockwise", help: "重新探测并刷新") { manager.refresh() }
                
                if manager.runningCount > 0 {
                    Button(action: { manager.terminateAllRunning() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.circle.fill").font(.system(size: 11))
                            Text("全部关闭").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.25), lineWidth: 1))
                    .help("一键关闭所有运行中的 AI 软件")
                }
                
                HeaderButton(icon: "power", help: "退出 StarButler") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
    
    private var footerView: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(manager.runningCount > 0 ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(manager.runningCount > 0 ? "已接管 \(manager.runningCount) 款活跃 AI 智能体（实时任务与 Token 探针已就绪）" : "全部智能体处于休眠就绪状态")
                    .font(.system(size: 10)).foregroundColor(.secondary)
            }
            Spacer()
            Text("纯净 Token 统计模式 · 拒绝虚假积分")
                .font(.system(size: 9)).foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(Color.primary.opacity(0.02))
    }
}

// MARK: - AIAgentCardView

public struct AIAgentCardView: View {
    let agent: AIAgentApp
    let manager: AIAgentManager
    
    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // App Icon with solid status dot
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: agent.icon)
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                
                Circle()
                    .fill(agent.isRunning ? Color(NSColor.systemGreen) : Color(NSColor.systemGray))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color(NSColor.windowBackgroundColor), lineWidth: 1.5))
                    .offset(x: -2, y: -2)
            }
            .frame(width: 40, height: 40)
            
            // Middle Content: App Name, Task, Real-time Tokens
            VStack(alignment: .leading, spacing: 4) {
                // Row 1: Name, PID, Model Badge, Speed Badge
                HStack(spacing: 6) {
                    Text(agent.displayName)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    
                    if agent.isRunning, let pid = agent.pid {
                        Text("PID: \(pid)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12)).cornerRadius(3)
                            .fixedSize()
                    }
                    
                    if let model = agent.modelName {
                        Text(model)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.10)).cornerRadius(3)
                            .fixedSize()
                    }
                    
                    if agent.tokensPerSec > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bolt.fill").font(.system(size: 7))
                            Text("\(agent.tokensPerSec) T/s")
                        }
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                        .fixedSize()
                    }
                }
                
                // Row 2: Current Task or Status
                HStack(spacing: 5) {
                    if agent.isRunning {
                        if let task = agent.currentTask, !task.isEmpty {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                            Text("任务: \(task)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary.opacity(0.9))
                                .lineLimit(1)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.green)
                            Text("监听待命中")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Image(systemName: "circle.dashed")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("未启动")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                
                // Row 3: Token In / Out
                HStack(spacing: 12) {
                    // Token Input
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 8.5))
                            .foregroundColor(.blue)
                        Text("入: \(agent.formattedInputTokens) T")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    // Token Output
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 8.5))
                            .foregroundColor(.purple)
                        Text("出: \(agent.formattedOutputTokens) T")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Right Content: Today & History Token metrics + Control Buttons
            HStack(spacing: 14) {
                // Pure Token Metrics (Today & History)
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 3) {
                        Text("今日:")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                        Text("\(agent.formattedTodayTokens) T")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    .fixedSize()
                    
                    HStack(spacing: 3) {
                        Text("历史:")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary.opacity(0.8))
                        Text("\(agent.formattedHistoryTokens) T")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .fixedSize()
                }
                
                // Control Buttons
                HStack(spacing: 8) {
                    if agent.isRunning {
                        ActionButton(icon: "macwindow.on.rectangle", color: .primary, isDestructive: false) {
                            manager.bringToFront(agent)
                        }
                        .help("展开并置顶窗口")
                        
                        ActionButton(icon: "xmark", color: .red, isDestructive: true) {
                            manager.terminateApp(agent)
                        }
                        .help("快速关闭此应用")
                    } else {
                        ActionButton(icon: "play.fill", color: .accentColor, isDestructive: false, filled: true) {
                            manager.launchApp(agent)
                        }
                        .help("启动此应用")
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 9)
            .fill(agent.isRunning ? Color.primary.opacity(0.04) : Color.primary.opacity(0.015)))
        .overlay(RoundedRectangle(cornerRadius: 9)
            .stroke(agent.isRunning ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Reusable Buttons

struct HeaderButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(PlainButtonStyle())
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .help(help)
    }
}

struct ActionButton: View {
    let icon: String
    let color: Color
    let isDestructive: Bool
    var filled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(filled ? .white : color)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(PlainButtonStyle())
        .background(RoundedRectangle(cornerRadius: 7)
            .fill(filled ? color : color.opacity(isDestructive ? 0.10 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 7)
            .stroke(filled ? Color.clear : color.opacity(isDestructive ? 0.25 : 0.15), lineWidth: 1))
    }
}

// MARK: - Visual Effect

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
