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

public struct AIAgentApp: Identifiable, Equatable {
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
    public var icon: NSImage {
        didSet {
            Self.iconCache.removeValue(forKey: id)
        }
    }
    
    // Equatable: compare display-relevant fields only (skip icon — NSImage isn't Equatable)
    public static func == (lhs: AIAgentApp, rhs: AIAgentApp) -> Bool {
        lhs.id == rhs.id &&
        lhs.isRunning == rhs.isRunning &&
        lhs.pid == rhs.pid &&
        lhs.state == rhs.state &&
        lhs.displayName == rhs.displayName &&
        lhs.currentTask == rhs.currentTask &&
        lhs.modelName == rhs.modelName &&
        lhs.inputTokens == rhs.inputTokens &&
        lhs.outputTokens == rhs.outputTokens &&
        lhs.todayTokens == rhs.todayTokens &&
        lhs.historyTokens == rhs.historyTokens &&
        lhs.tokensPerSec == rhs.tokensPerSec
    }
    
    // Static icon cache: load icon once per app path, reuse across refresh cycles
    private static var appIconCache: [String: NSImage] = [:]
    
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
        } else if let cached = Self.appIconCache[appPath] {
            self.icon = cached
        } else if FileManager.default.fileExists(atPath: appPath) {
            let loaded = NSWorkspace.shared.icon(forFile: appPath)
            Self.appIconCache[appPath] = loaded
            self.icon = loaded
        } else {
            self.icon = NSImage(size: NSSize(width: 40, height: 40))
        }
    }
    
    // Cached base64 icon data for companion clients
    private static var iconCache: [String: String] = [:]
    
    public var iconBase64: String? {
        if let cached = Self.iconCache[id], !cached.isEmpty {
            return cached
        }
        
        var sourceIcon: NSImage = self.icon
        if sourceIcon.size.width <= 0 || sourceIcon.size.height <= 0 {
            if FileManager.default.fileExists(atPath: appPath) {
                sourceIcon = NSWorkspace.shared.icon(forFile: appPath)
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                sourceIcon = NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        
        let targetSize = NSSize(width: 60, height: 60)
        let img = NSImage(size: targetSize)
        img.lockFocus()
        sourceIcon.draw(in: NSRect(origin: .zero, size: targetSize),
                        from: NSRect(origin: .zero, size: sourceIcon.size),
                        operation: .copy,
                        fraction: 1.0)
        img.unlockFocus()
        
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        
        // Use JPEG 0.8 compression for crystal-clear visuals and ultra-compact ~8KB payload
        let imgData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) ?? rep.representation(using: .png, properties: [:])
        guard let data = imgData else { return nil }
        let b64 = data.base64EncodedString()
        Self.iconCache[id] = b64
        return b64
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
