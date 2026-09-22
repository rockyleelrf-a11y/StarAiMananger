import Foundation
import Network

@main
struct CompanionCheckRunner {
    static func main() {
        print("[Companion Check] Starting StarButler Companion architecture test...")
        
        let manager = AIAgentManager()
        
        // Wait briefly for listener to enter .ready state
        var waited = 0
        while !manager.companionServer.isRunning && waited < 40 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            waited += 1
        }
        
        assert(manager.companionServer.isRunning, "Companion server must be running")
        print("  [Pass] CompanionServer initialized and listening on port \(manager.companionServer.port)")
        
        let semaphore = DispatchSemaphore(value: 0)
        var receivedSnapshot = false
        var agentCount = 0
        
        // Connect to localhost server
        let params = NWParameters.tcp
        let nwEndpoint = NWEndpoint.hostPort(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: manager.companionServer.port) ?? 58240
        )
        let connection = NWConnection(to: nwEndpoint, using: params)
        
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                print("  [Pass] Client connected to StarButler Host Server")
                
                // Read snapshot
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                    if let data = data, !data.isEmpty {
                        let chunks = data.split(separator: 0x0A)
                        for chunk in chunks {
                            if let msg = try? JSONDecoder().decode(CompanionMessage.self, from: chunk) {
                                if let agents = msg.agents {
                                    receivedSnapshot = true
                                    agentCount = agents.count
                                    print("  [Pass] Received snapshot with \(agents.count) agents from Mac Host")
                                }
                            }
                        }
                    }
                    semaphore.signal()
                }
            }
        }
        
        connection.start(queue: .global())
        
        let result = semaphore.wait(timeout: .now() + 5.0)
        assert(result == .success, "Connection and snapshot receive timed out")
        assert(receivedSnapshot, "Should have received snapshot message")
        assert(agentCount > 0, "Agent count in snapshot should be > 0")
        
        connection.cancel()
        manager.companionServer.stop()
        
        print("[Companion Check] All StarButler Companion networking and serialization assertions passed successfully!")
    }
}
