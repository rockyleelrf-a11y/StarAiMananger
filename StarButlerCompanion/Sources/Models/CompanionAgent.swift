import Foundation
import SwiftUI

public enum CompanionAgentState: String, Codable {
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
    
    public var color: Color {
        switch self {
        case .stopped: return .gray
        case .idle: return .green
        case .activeFocus: return .orange
        case .inferencing: return .purple
        }
    }
}

public struct CompanionAgent: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let displayName: String
    public let bundleId: String
    public let isRunning: Bool
    public let pid: Int?
    public let state: String
    public let currentTask: String?
    public let modelName: String?
    public let inputTokens: Int
    public let outputTokens: Int
    public let todayTokens: Int
    public let historyTokens: Int
    public let tokensPerSec: Int
    
    public var agentState: CompanionAgentState {
        CompanionAgentState(rawValue: state) ?? (isRunning ? .idle : .stopped)
    }
    
    public var formattedInputTokens: String { formatTokenNumber(inputTokens) }
    public var formattedOutputTokens: String { formatTokenNumber(outputTokens) }
    public var formattedTodayTokens: String { formatTokenNumber(todayTokens) }
    public var formattedHistoryTokens: String { formatTokenNumber(historyTokens) }
    
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

public struct CompanionMessagePayload: Codable {
    public let type: String
    public let timestamp: Double
    public let agents: [CompanionAgent]?
    public let action: String?
    public let targetId: String?
    
    public init(type: String, agents: [CompanionAgent]? = nil, action: String? = nil, targetId: String? = nil) {
        self.type = type
        self.timestamp = Date().timeIntervalSince1970
        self.agents = agents
        self.action = action
        self.targetId = targetId
    }
}
