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
    
    public init() {
        self.agents = Self.defaultAgents()
        self.loadDailyUsage()
        self.refresh()
        
        // Poll every 2.0 seconds for smooth real-time monitoring
        self.timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }
    
    public var runningCount: Int { agents.filter(\.isRunning).count }
    
    // Default agents catalog
    public static func defaultAgents() -> [AIAgentApp] {
        let defs: [(name: String, display: String, bundle: String, path: String)] = [
            ("TraeWork", "TraeWork", "cn.trae.solo.app", "/Applications/TRAE SOLO CN.app"),
            ("WorkBuddy", "WorkBuddy", "com.tencent.workbuddy.mac", "/Applications/WorkBuddy.app"),
            ("Antigravity", "Antigravity", "com.google.antigravity", "/Applications/Antigravity.app"),
            ("DoubaoWork", "豆包工作", "com.work.pc.doubao", "/Applications/DoubaoWork.app"),
            ("MiniMax Code", "MiniMax Code", "com.minimax.agent.cn", "/Applications/MiniMax Code.app"),
            ("ChatGPT", "ChatGPT", "com.openai.chat", "/Applications/ChatGPT.app"),
            ("ZCode", "ZCode", "dev.zcode.app", "/Applications/ZCode.app"),
            ("OpenCode", "OpenCode", "ai.opencode.desktop", "/Applications/OpenCode.app"),
            ("Trae CN", "TRAE CN", "cn.trae.app", "/Applications/Trae CN.app")
        ]
        
        let fm = FileManager.default
        return defs.enumerated().compactMap { idx, item in
            var path = item.path
            var targetBundleId = item.bundle

            if !fm.fileExists(atPath: path) {
                let home = NSHomeDirectory() + "/Applications/" + (path as NSString).lastPathComponent
                if fm.fileExists(atPath: home) {
                    path = home
                } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundle) {
                    path = url.path
                } else if item.name == "ChatGPT", let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
                    path = url.path
                }
            }
            
            // Check if app bundle exists or is known to workspace
            let exists = fm.fileExists(atPath: path) || NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundle) != nil || (item.name == "ChatGPT" && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") != nil)
            guard exists else { return nil }

            // Extract the actual bundle ID if available on disk
            if let actualId = Bundle(path: path)?.bundleIdentifier {
                targetBundleId = actualId
            } else if item.name == "ChatGPT" && NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") != nil {
                targetBundleId = "com.openai.codex"
            }

            return AIAgentApp(
                id: targetBundleId,
                name: item.name,
                displayName: item.display,
                bundleId: targetBundleId,
                appPath: path,
                sortOrder: idx
            )
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
    
    public func refresh() {
        let runningApps = NSWorkspace.shared.runningApplications
        var runningMap: [String: NSRunningApplication] = [:]
        for app in runningApps {
            if let bid = app.bundleIdentifier { runningMap[bid.lowercased()] = app }
        }
        
        // Dynamically discover newly installed agents
        let currentIds = Set(agents.map { $0.id.lowercased() })
        for defAgent in Self.defaultAgents() {
            if !currentIds.contains(defAgent.id.lowercased()) {
                agents.append(defAgent)
            }
        }
        
        for i in 0..<agents.count {
            let bid = agents[i].bundleId.lowercased()
            if let app = runningMap[bid] {
                agents[i].isRunning = true
                agents[i].pid = app.processIdentifier
                agents[i].cpuPercent = app.isActive ? 6.5 : 0.8
                agents[i].state = app.isActive ? .activeFocus : .idle
            } else {
                agents[i].isRunning = false
                agents[i].pid = nil
                agents[i].cpuPercent = 0.0
                agents[i].state = .stopped
                agents[i].tokensPerSec = 0
            }
            
            // Execute automated probe
            AIAgentProber.probe(agent: &agents[i])
        }
        
        sortAgents()
        saveDailyUsage()
        lastRefreshedAt = Date()
        NotificationCenter.default.post(name: NSNotification.Name("AIAgentManagerDidRefresh"), object: nil)
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
        if let idx = agents.firstIndex(where: { $0.bundleId == agent.bundleId }) {
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
