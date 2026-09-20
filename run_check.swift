import AppKit
import Foundation

@main
struct CheckRunner {
    static func main() {
        print("[Check] Initializing AIAgentManager pure Token & accurate Task test...")

        let manager = AIAgentManager()
        assert(!manager.agents.isEmpty, "Registered agents should not be empty")

        // 1. Verify TraeWork naming
        if let traeWork = manager.agents.first(where: { $0.bundleId == "cn.trae.solo.app" }) {
            assert(traeWork.displayName == "TraeWork", "cn.trae.solo.app must be named TraeWork, not TRAE SOLO CN")
            print("  [Pass] TraeWork naming verified: \(traeWork.displayName)")
        } else {
            fatalError("TraeWork must be registered")
        }

        // 2. Refresh & run probes
        manager.refresh()
        print("[Check] Currently running agents: \(manager.runningCount)")
        for agent in manager.agents where agent.isRunning {
            print("  * Running: \(agent.displayName) (PID: \(agent.pid ?? 0))")
            print("    Task: \(agent.currentTask ?? "待命中")")
            print("    Model: \(agent.modelName ?? "默认")")
            print("    Tokens: In: \(agent.formattedInputTokens) T, Out: \(agent.formattedOutputTokens) T, Today: \(agent.formattedTodayTokens) T, History: \(agent.formattedHistoryTokens) T")
            assert(agent.pid != nil, "Running agent must have a valid PID")
        }

        // 3. Verify DoubaoWork real task (SellShop) and real model (豆包 2.1 Turbo)
        if let doubao = manager.agents.first(where: { $0.bundleId == "com.work.pc.doubao" }) {
            if doubao.isRunning {
                assert(doubao.currentTask != nil, "DoubaoWork should have a probed task")
                assert(doubao.currentTask!.contains("工作记录") || doubao.currentTask!.contains("SellShop"), "Doubao task must contain real work record or SellShop")
                assert(doubao.modelName == "豆包 2.1 Turbo", "Doubao model must be '豆包 2.1 Turbo', but got '\(doubao.modelName ?? "nil")'")
                print("  [Pass] DoubaoWork probed task: \(doubao.currentTask!), Model: \(doubao.modelName!)")
            }
        }

        // 4. Verify TraeWork real task (StarWriter-Trae) and probed model (DeepSeek-V4-Flash (Max))
        if let trae = manager.agents.first(where: { $0.bundleId == "cn.trae.solo.app" }) {
            if trae.isRunning {
                assert(trae.currentTask != nil, "TraeWork should have a probed task")
                assert(trae.currentTask!.contains("审查Changelog") || trae.currentTask!.contains("StarWriter-Trae"), "TraeWork task must contain 审查Changelog or StarWriter-Trae")
                assert(trae.modelName == "DeepSeek-V4-Flash (Max)", "TraeWork model must be 'DeepSeek-V4-Flash (Max)', but got '\(trae.modelName ?? "nil")'")
                print("  [Pass] TraeWork probed task: \(trae.currentTask!), Model: \(trae.modelName!)")
            }
        }

        // 5. Verify WorkBuddy task and probed model
        if let workBuddy = manager.agents.first(where: { $0.bundleId == "com.tencent.workbuddy.mac" }) {
            if workBuddy.isRunning {
                assert(workBuddy.currentTask != nil, "WorkBuddy should auto-probe current task")
                assert(workBuddy.historyTokens > 1_000_000, "WorkBuddy should have historical tokens from db")
                assert(workBuddy.modelName == "deepseek-v4.1-flash", "WorkBuddy model must be 'deepseek-v4.1-flash', but got '\(workBuddy.modelName ?? "nil")'")
                print("  [Pass] WorkBuddy probed task: \(workBuddy.currentTask!), Model: \(workBuddy.modelName!), History: \(workBuddy.formattedHistoryTokens) T")
            }
        }
        
        // 6. Verify Antigravity task and model
        if let agy = manager.agents.first(where: { $0.bundleId == "com.google.antigravity" }) {
            if agy.isRunning {
                assert(agy.currentTask != nil, "Antigravity should auto-probe current task")
                assert(agy.todayTokens > 0, "Antigravity should have real probed tokens")
                assert(agy.modelName?.contains("Gemini") == true, "Antigravity model should be Gemini, but got '\(agy.modelName ?? "nil")'")
            }
        }
        
        // 7. Verify Priority Sorting (Running agents must be at the top, stopped at the bottom)
        var seenStopped = false
        for (i, agent) in manager.agents.enumerated() {
            if !agent.isRunning {
                seenStopped = true
            } else {
                assert(!seenStopped, "Running agent '\(agent.displayName)' at index \(i) must not appear after stopped agents! All running agents must be at the top.")
            }
        }
        // 8. Verify ChatGPT discovery
        if let chatgpt = manager.agents.first(where: { $0.name == "ChatGPT" }) {
            print("  [Pass] ChatGPT discovered: ID=\(chatgpt.bundleId), Running=\(chatgpt.isRunning)")
            assert(!chatgpt.appPath.isEmpty, "ChatGPT appPath must not be empty")
        } else {
            fatalError("ChatGPT must be discovered if /Applications/ChatGPT.app exists")
        }

        print("[Check] All pure Token, model ID, real task, priority sorting, and ChatGPT assertions passed successfully!")
    }
}
