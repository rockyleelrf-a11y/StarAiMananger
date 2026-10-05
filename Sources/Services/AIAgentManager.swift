import AppKit
import Combine
import Foundation

// Persistent daily and historical usage tracking
public struct DailyUsageStore: Codable {
    public var dateString: String
    public var agentTodayTokens: [String: Int]
    public var agentHistoryTokens: [String: Int]
}

public final class AIAgentManager: ObservableObject {
    @Published public var agents: [AIAgentApp] = []
    @Published public var lastRefreshedAt: Date = Date()
    
    private var timer: AnyCancellable?
    
    private let storeURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AIAgentManager")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("today_usage.json")
    }()
    
    public let companionServer = StarButlerCompanionServer.shared
    public let cloudClient = StarButlerCloudClient.shared
    
    public init() {
        self.agents = Self.defaultAgents()
        self.loadDailyUsage()
        self.refresh()
        
        let handleAction: (_ action: String, _ targetId: String?) -> Void = { [weak self] action, targetId in
            guard let self = self else { return }
            switch action {
            case "terminate":
                if let targetId = targetId,
                   let agent = self.agents.first(where: { $0.id == targetId || $0.bundleId == targetId }) {
                    self.terminateApp(agent)
                }
            case "activate":
                if let targetId = targetId,
                   let agent = self.agents.first(where: { $0.id == targetId || $0.bundleId == targetId }) {
                    if agent.isRunning {
                        self.bringToFront(agent)
                    } else {
                        self.launchApp(agent)
                    }
                }
            case "launch":
                if let targetId = targetId,
                   let agent = self.agents.first(where: { $0.id == targetId || $0.bundleId == targetId }) {
                    self.launchApp(agent)
                }
            case "terminateAll":
                self.terminateAllRunning()
            case "refresh":
                self.refresh()
            default:
                break
            }
        }
        
        // Start companion host server for iPhone / iPad (LAN Bonjour)
        self.companionServer.start()
        self.companionServer.onActionReceived = handleAction
        
        // Cloud Relay action listener (WAN Remote)
        self.cloudClient.onActionReceived = handleAction
        
        // Poll every 3.0 seconds for smooth real-time monitoring
        self.timer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }
    
    public var runningCount: Int { agents.filter(\.isRunning).count }
    
    // Supported AI agents catalog for detection
    public static let supportedAgentCatalog: [(name: String, display: String, bundle: String, path: String)] = [
        ("TraeWork", "TraeWork", "cn.trae.solo.app", "/Applications/TRAE SOLO CN.app"),
        ("TraeCode", "TraeCode", "com.trae.app", "/Applications/Trae.app"),
        ("Trae CN", "Trae CN", "cn.trae.app", "/Applications/Trae CN.app"),
        ("Qoder", "Qoder", "com.qoder.app", "/Applications/Qoder.app"),
        ("QoderCN", "Qoder CN", "com.qodercn.app", "/Applications/Qoder CN.app"),
        ("CodeBuddy", "CodeBuddy", "com.tencent.codebuddy.mac", "/Applications/CodeBuddy.app"),
        ("Manus", "Manus", "ai.manus.app", "/Applications/Manus.app"),
        ("ClaudeCode", "Claude Code", "com.anthropic.claude-code", "/usr/local/bin/claude"),
        ("WorkBuddy", "WorkBuddy", "com.tencent.workbuddy.mac", "/Applications/WorkBuddy.app"),
        ("Antigravity", "Antigravity", "com.google.antigravity", "/Applications/Antigravity.app"),
        ("DoubaoWork", "豆包工作", "com.work.pc.doubao", "/Applications/DoubaoWork.app"),
        ("Cline", "Cline", "bot.cline.app", "/Applications/Cline.app"),
        ("StepFun", "阶跃 AI", "com.stepfun.desktop", "/Applications/阶跃AI.app"),
        ("MiniMax Code", "MiniMax Code", "com.minimax.agent.cn", "/Applications/MiniMax Code.app"),
        ("ChatGPT", "ChatGPT", "com.openai.chat", "/Applications/ChatGPT.app"),
        ("ImaCopilot", "ima.copilot", "com.tencent.imamac", "/Applications/ima.copilot.app"),
        ("Cursor", "Cursor", "com.todesktop.230313mzl4w4u92", "/Applications/Cursor.app"),
        ("Windsurf", "Windsurf", "com.codeium.windsurf", "/Applications/Windsurf.app"),
        ("Claude", "Claude", "com.anthropic.claudefordesktop", "/Applications/Claude.app"),
        ("Kimi", "Kimi", "com.moonshot.kimichat", "/Applications/Kimi.app"),
        ("Ollama", "Ollama", "com.electron.ollama", "/Applications/Ollama.app"),
        ("LM Studio", "LM Studio", "ai.elementlabs.lmstudio", "/Applications/LM Studio.app"),
        ("Goose", "Goose", "com.block.goose", "/Applications/Goose.app"),
        ("StarWriter", "StarWriter", "com.starwriter.app", "/Applications/StarWriter.app"),
        ("ZCode", "ZCode", "dev.zcode.app", "/Applications/ZCode.app"),
        ("OpenCode", "OpenCode", "ai.opencode.desktop", "/Applications/OpenCode.app")
    ]
    
    // Resolve agent ONLY if physically installed on this Mac or currently running
    public static func resolveInstalledAgent(item: (name: String, display: String, bundle: String, path: String), idx: Int, runningMap: [String: NSRunningApplication] = [:]) -> AIAgentApp? {
        let fm = FileManager.default
        var resolvedPath = item.path
        var targetBundleId = item.bundle
        var isInstalled = false
        
        // 1. Direct path check in /Applications or ~/Applications
        if fm.fileExists(atPath: resolvedPath) {
            isInstalled = true
        } else {
            let userApp = NSHomeDirectory() + "/Applications/" + (item.path as NSString).lastPathComponent
            if fm.fileExists(atPath: userApp) {
                resolvedPath = userApp
                isInstalled = true
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundle) {
                resolvedPath = url.path
                isInstalled = true
            }
        }
        
        // 2. Specific alias / alternative paths
        if !isInstalled {
            switch item.name {
            case "QoderCN":
                if fm.fileExists(atPath: "/Applications/Qoder CN.app") {
                    resolvedPath = "/Applications/Qoder CN.app"; isInstalled = true
                }
            case "Qoder":
                if fm.fileExists(atPath: "/Applications/Qoder.app") {
                    resolvedPath = "/Applications/Qoder.app"; isInstalled = true
                }
            case "TraeCode":
                if fm.fileExists(atPath: "/Applications/Trae.app") {
                    resolvedPath = "/Applications/Trae.app"; isInstalled = true
                }
            case "Trae CN":
                if fm.fileExists(atPath: "/Applications/Trae CN.app") {
                    resolvedPath = "/Applications/Trae CN.app"; isInstalled = true
                }
            case "TraeWork":
                if fm.fileExists(atPath: "/Applications/TRAE SOLO CN.app") {
                    resolvedPath = "/Applications/TRAE SOLO CN.app"; isInstalled = true
                }
            case "StepFun":
                for alt in ["/Applications/阶跃 AI.app", "/Applications/StepFun.app", NSHomeDirectory() + "/Applications/阶跃AI.app"] {
                    if fm.fileExists(atPath: alt) { resolvedPath = alt; isInstalled = true; break }
                }
            case "ClaudeCode":
                // Claude Code is a CLI tool: only show when actively running in terminal
                let pgrep = Process()
                let pipe = Pipe()
                pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
                pgrep.arguments = ["-x", "claude"]
                pgrep.standardOutput = pipe
                if (try? pgrep.run()) != nil {
                    pgrep.waitUntilExit()
                    if pgrep.terminationStatus == 0 {
                        isInstalled = true
                        resolvedPath = "/usr/local/bin/claude"
                    }
                }
            case "ChatGPT":
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
                    resolvedPath = url.path; targetBundleId = "com.openai.codex"; isInstalled = true
                }
            case "Cursor":
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.cursor.Cursor") {
                    resolvedPath = url.path; isInstalled = true
                }
            case "Windsurf":
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.exafunction.windsurf") {
                    resolvedPath = url.path; isInstalled = true
                }
            case "Claude":
                let chromeClaude = NSHomeDirectory() + "/Applications/Chrome Apps.localized/Claude.app"
                if fm.fileExists(atPath: chromeClaude) {
                    resolvedPath = chromeClaude; isInstalled = true
                } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.anthropic.claude") {
                    resolvedPath = url.path; isInstalled = true
                }
            case "Kimi":
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.moonshot.kimi") {
                    resolvedPath = url.path; isInstalled = true
                }
            case "CodeBuddy":
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.tencent.codebuddy") {
                    resolvedPath = url.path; isInstalled = true
                }
            default:
                break
            }
        }
        
        // 3. If not found on disk, check if currently running in memory
        if !isInstalled {
            let bid = item.bundle.lowercased()
            if runningMap[bid] != nil ||
               (item.name == "QoderCN" && runningMap["com.qodercn.app"] != nil) ||
               (item.name == "Qoder" && runningMap["com.qoder.app"] != nil) ||
               (item.name == "TraeCode" && runningMap["com.trae.app"] != nil) ||
               (item.name == "Trae CN" && runningMap["cn.trae.app"] != nil) ||
               (item.name == "CodeBuddy" && (runningMap["com.tencent.codebuddy"] != nil || runningMap["com.tencent.codebuddy.mac"] != nil)) ||
               (item.name == "Kimi" && (runningMap["com.moonshot.kimichat"] != nil || runningMap["com.moonshot.kimi"] != nil)) {
                isInstalled = true
            }
        }
        
        // Strictly return nil if app is neither installed nor running!
        guard isInstalled else { return nil }
        
        if let actualId = Bundle(path: resolvedPath)?.bundleIdentifier {
            targetBundleId = actualId
        }
        
        return AIAgentApp(
            id: "\(item.name)_\(targetBundleId)",
            name: item.name,
            displayName: item.display,
            bundleId: targetBundleId,
            appPath: resolvedPath,
            sortOrder: idx
        )
    }
    
    public static func defaultAgents() -> [AIAgentApp] {
        let runningApps = NSWorkspace.shared.runningApplications
        var runningMap: [String: NSRunningApplication] = [:]
        for app in runningApps {
            if let bid = app.bundleIdentifier { runningMap[bid.lowercased()] = app }
        }
        return supportedAgentCatalog.enumerated().compactMap { idx, item in
            resolveInstalledAgent(item: item, idx: idx, runningMap: runningMap)
        }
    }
    
    // MARK: - Daily & History Usage Persistence
    
    private func loadDailyUsage() {
        guard let data = try? Data(contentsOf: storeURL),
              let store = try? JSONDecoder().decode(DailyUsageStore.self, from: data) else { return }
        
        let todayStr = Self.todayString()
        for i in 0..<agents.count {
            let bid = agents[i].bundleId
            if store.dateString == todayStr {
                if let t = store.agentTodayTokens[bid] { agents[i].todayTokens = t }
            }
            if let h = store.agentHistoryTokens[bid] { agents[i].historyTokens = h }
        }
    }
    
    private func saveDailyUsage() {
        var todayMap: [String: Int] = [:]
        var historyMap: [String: Int] = [:]
        for a in agents {
            todayMap[a.bundleId] = a.todayTokens
            historyMap[a.bundleId] = a.historyTokens
        }
        let store = DailyUsageStore(
            dateString: Self.todayString(),
            agentTodayTokens: todayMap,
            agentHistoryTokens: historyMap
        )
        if let data = try? JSONEncoder().encode(store) {
            try? data.write(to: storeURL)
        }
    }
    
    // MARK: - Priority Sorting (Running on Top, Stopped at Bottom)
    
    public func sortAgents() {
        agents.sort { a, b in
            if a.isRunning != b.isRunning {
                return a.isRunning && !b.isRunning
            }
            return a.sortOrder < b.sortOrder
        }
    }
    
    // MARK: - Process Monitoring & Automatic Probing
    
    private var isRefreshing = false
    
    public func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        // Snapshot existing data before going off main thread
        let existingMap = Dictionary(agents.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let runningApps = NSWorkspace.shared.runningApplications
            var runningMap: [String: NSRunningApplication] = [:]
            for app in runningApps {
                if let bid = app.bundleIdentifier { runningMap[bid.lowercased()] = app }
            }
            
            let currentDetected = Self.defaultAgents()
            var updatedAgents: [AIAgentApp] = []
            
            for var agent in currentDetected {
                if let existing = existingMap[agent.name] {
                    agent.todayTokens = existing.todayTokens
                    agent.historyTokens = existing.historyTokens
                    agent.currentTask = existing.currentTask
                    agent.modelName = existing.modelName
                    agent.tokensPerSec = existing.tokensPerSec
                    agent.inputTokens = existing.inputTokens
                    agent.outputTokens = existing.outputTokens
                    // icon intentionally not copied: AIAgentApp.init already restores it
                    // from the static appIconCache; reassigning would clear iconBase64 cache
                }
                updatedAgents.append(agent)
            }
            
            for i in 0..<updatedAgents.count {
                let bid = updatedAgents[i].bundleId.lowercased()
                var matchedApp = runningMap[bid]
                if matchedApp == nil {
                    if updatedAgents[i].name == "QoderCN" && runningMap["com.qodercn.app"] != nil {
                        matchedApp = runningMap["com.qodercn.app"]
                    } else if updatedAgents[i].name == "Qoder" && runningMap["com.qoder.app"] != nil {
                        matchedApp = runningMap["com.qoder.app"]
                    } else if updatedAgents[i].name == "TraeCode" && runningMap["com.trae.app"] != nil {
                        matchedApp = runningMap["com.trae.app"]
                    } else if updatedAgents[i].name == "Trae CN" && runningMap["cn.trae.app"] != nil {
                        matchedApp = runningMap["cn.trae.app"]
                    } else if updatedAgents[i].name == "CodeBuddy" && (runningMap["com.tencent.codebuddy"] != nil || runningMap["com.tencent.codebuddy.mac"] != nil) {
                        matchedApp = runningMap["com.tencent.codebuddy"] ?? runningMap["com.tencent.codebuddy.mac"]
                    } else if updatedAgents[i].name == "Kimi" && (runningMap["com.moonshot.kimichat"] != nil || runningMap["com.moonshot.kimi"] != nil) {
                        matchedApp = runningMap["com.moonshot.kimichat"] ?? runningMap["com.moonshot.kimi"]
                    }
                }
                
                if let app = matchedApp {
                    updatedAgents[i].isRunning = true
                    updatedAgents[i].pid = app.processIdentifier
                    updatedAgents[i].cpuPercent = app.isActive ? 6.5 : 0.8
                    updatedAgents[i].state = app.isActive ? .activeFocus : .idle
                    if let appIcon = app.icon, updatedAgents[i].icon !== appIcon {
                        // Only reassign on a real icon change; assignment clears iconBase64 cache
                        updatedAgents[i].icon = appIcon
                    }
                } else if updatedAgents[i].name == "ClaudeCode" || updatedAgents[i].bundleId.contains("claude-code") {
                    var cliPid: Int32?
                    let pgrep = Process()
                    let pipe = Pipe()
                    pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
                    pgrep.arguments = ["-x", "claude"]
                    pgrep.standardOutput = pipe
                    if (try? pgrep.run()) != nil {
                        pgrep.waitUntilExit()
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                           let first = str.components(separatedBy: .whitespacesAndNewlines).first,
                           let p = Int32(first) {
                            cliPid = p
                        }
                    }
                    if let pid = cliPid {
                        updatedAgents[i].isRunning = true
                        updatedAgents[i].pid = pid
                        updatedAgents[i].cpuPercent = 2.5
                        updatedAgents[i].state = .idle
                    } else {
                        updatedAgents[i].isRunning = false
                        updatedAgents[i].pid = nil
                        updatedAgents[i].cpuPercent = 0.0
                        updatedAgents[i].state = .stopped
                        updatedAgents[i].tokensPerSec = 0
                    }
                } else {
                    updatedAgents[i].isRunning = false
                    updatedAgents[i].pid = nil
                    updatedAgents[i].cpuPercent = 0.0
                    updatedAgents[i].state = .stopped
                    updatedAgents[i].tokensPerSec = 0
                }
                
                AIAgentProber.probe(agent: &updatedAgents[i])
            }
            
            updatedAgents.sort { a, b in
                if a.isRunning != b.isRunning { return a.isRunning && !b.isRunning }
                return a.sortOrder < b.sortOrder
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Only trigger SwiftUI re-render if data actually changed
                if self.agents != updatedAgents {
                    self.agents = updatedAgents
                }
                self.saveDailyUsage()
                self.companionServer.broadcast(agents: self.agents)
                self.cloudClient.sendSnapshot(agents: self.agents)
                self.lastRefreshedAt = Date()
                self.isRefreshing = false
                NotificationCenter.default.post(name: NSNotification.Name("AIAgentManagerDidRefresh"), object: nil)
            }
        }
    }
    
    // MARK: - App Actions
    
    public func launchApp(_ agent: AIAgentApp) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: agent.appPath), configuration: config) { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self?.refresh() }
        }
    }
    
    public func terminateApp(_ agent: AIAgentApp) {
        let bid = agent.bundleId.lowercased()
        for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier?.lowercased() == bid {
            if !app.terminate() { app.forceTerminate() }
        }
        if let pid = agent.pid {
            kill(pid, SIGTERM)
        }
        if let idx = agents.firstIndex(where: { $0.id == agent.id }) {
            agents[idx].isRunning = false
            agents[idx].pid = nil
            agents[idx].state = .stopped
            agents[idx].tokensPerSec = 0
            agents[idx].currentTask = nil
        }
        sortAgents()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.refresh() }
    }
    
    public func terminateAllRunning() {
        agents.filter(\.isRunning).forEach { terminateApp($0) }
    }
    
    public func bringToFront(_ agent: AIAgentApp) {
        let bid = agent.bundleId
        let scriptSource = "tell application id \"\(bid)\"\nactivate\nreopen\nend tell"
        if let script = NSAppleScript(source: scriptSource) {
            var err: NSDictionary?
            script.executeAndReturnError(&err)
        }
        for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier?.lowercased() == bid.lowercased() {
            app.unhide()
            app.activate(options: [.activateIgnoringOtherApps])
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: agent.appPath), configuration: config, completionHandler: nil)
    }
    
    private static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
}
