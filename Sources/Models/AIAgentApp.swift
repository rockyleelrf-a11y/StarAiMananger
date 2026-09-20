import AppKit
import Foundation

public enum AgentState: String, Codable {
    case stopped
    case idle
    case activeFocus
    case inferencing
    
    public var iconName: String {
        switch self {
        case .stopped: return "circle.dashed"
        case .idle: return "checkmark.circle.fill"
        case .activeFocus: return "sparkles"
        case .inferencing: return "bolt.fill"
        }
    }
    
    public var title: String {
        switch self {
        case .stopped: return "未启动"
        case .idle: return "监听待命"
        case .activeFocus: return "前台交互"
        case .inferencing: return "正在推理生成"
        }
    }
}

public struct AIAgentApp: Identifiable {
    public let id: String
    public let name: String
    public var displayName: String
    public let bundleId: String
    public var appPath: String
    public var isRunning: Bool
    public var pid: pid_t?
    public var cpuPercent: Double
    public var state: AgentState
    
    // Auto-probed real-time task & token metrics
    public var currentTask: String?      // e.g. "审查Changelog与代码质量并启动服务 (StarWriter-Trae)"
    public var modelName: String?        // e.g. "deepseek-v4.1-flash", "Gemini 3.8 Flash"
    public var inputTokens: Int          // Token 输入 (Prompt)
    public var outputTokens: Int         // Token 输出 (Completion)
    public var todayTokens: Int          // 今日全部任务 Token 消耗
    public var historyTokens: Int        // 历史全部任务 Token 消耗
    public var tokensPerSec: Int         // 实时推理吞吐 (T/s)
    public var sortOrder: Int            // 初始排序权重，保证同状态稳定排序
    public var lastProbedTime: Date?
    public var icon: NSImage
    
    public init(
        id: String,
        name: String,
        displayName: String,
        bundleId: String,
        appPath: String,
        sortOrder: Int = 0,
        isRunning: Bool = false,
        pid: pid_t? = nil,
        cpuPercent: Double = 0.0,
        state: AgentState = .stopped,
        currentTask: String? = nil,
        modelName: String? = nil,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        todayTokens: Int = 0,
        historyTokens: Int = 0,
        tokensPerSec: Int = 0,
        icon: NSImage? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.bundleId = bundleId
        self.appPath = appPath
        self.sortOrder = sortOrder
        self.isRunning = isRunning
        self.pid = pid
        self.cpuPercent = cpuPercent
        self.state = state
        self.currentTask = currentTask
        self.modelName = modelName
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.todayTokens = todayTokens
        self.historyTokens = historyTokens
        self.tokensPerSec = tokensPerSec
        self.lastProbedTime = Date()
        
        if let icon = icon {
            self.icon = icon
        } else if FileManager.default.fileExists(atPath: appPath) {
            self.icon = NSWorkspace.shared.icon(forFile: appPath)
        } else {
            self.icon = NSImage(size: NSSize(width: 40, height: 40))
        }
    }
    
    // Formatting helpers
    public var formattedInputTokens: String {
        formatTokenNumber(inputTokens)
    }
    
    public var formattedOutputTokens: String {
        formatTokenNumber(outputTokens)
    }
    
    public var formattedTodayTokens: String {
        formatTokenNumber(todayTokens)
    }
    
    public var formattedHistoryTokens: String {
        formatTokenNumber(historyTokens)
    }
    
    private func formatTokenNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.2fM", Double(n) / 1_000_000.0)
        } else if n >= 1_000 {
            return String(format: "%.1fk", Double(n) / 1_000.0)
        } else {
            return "\(n)"
        }
    }
}
