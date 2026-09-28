import Foundation
import AppKit

public final class StarButlerCloudRelaySupervisor {
    public static let shared = StarButlerCloudRelaySupervisor()
    
    private let port = 8765
    private var childProcess: Process?
    
    private init() {}
    
    public func ensureRunning() {
        // 1. Check if already responding on port 8765
        checkHealth { [weak self] isRunning in
            if isRunning {
                print("[RelaySupervisor] Cloud relay service is already running on port 8765.")
                return
            }
            
            print("[RelaySupervisor] Cloud relay service is not running. Initiating auto-start...")
            self?.startRelayService()
        }
    }
    
    public func checkHealth(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:\(port)/api/device/status") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 1.5)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let http = response as? HTTPURLResponse, (http.statusCode == 200 || http.statusCode == 401) {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    private func findNodePath() -> String? {
        let candidates = [
            "/usr/local/bin/node",
            "/opt/homebrew/bin/node",
            "/usr/bin/node",
            "~/.nvm/versions/node/$(ls ~/.nvm/versions/node 2>/dev/null | tail -n 1)/bin/node"
        ]
        
        let fm = FileManager.default
        for path in candidates {
            let expanded = NSString(string: path).expandingTildeInPath
            if fm.fileExists(atPath: expanded) {
                return expanded
            }
        }
        
        // Fallback: which node
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = ["node"]
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
            if fm.fileExists(atPath: output) {
                return output
            }
        }
        
        return nil
    }
    
    private func startRelayService() {
        guard let nodePath = findNodePath() else {
            print("[RelaySupervisor] Warning: Node.js runtime not found on this Mac.")
            return
        }
        
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("StarButler")
            .appendingPathComponent("cloud-relay")
        
        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        
        let targetScriptURL = appSupport.appendingPathComponent("server.cjs")
        
        // Locate bundled or workspace server.cjs
        var sourceScriptURL: URL?
        if let bundled = Bundle.main.url(forResource: "server", withExtension: "cjs") {
            sourceScriptURL = bundled
        } else {
            let devPath = "/Users/removed/Documents/CodingProject/Mac 智能AI 软件启动关闭器/cloud-relay/server.cjs"
            if fm.fileExists(atPath: devPath) {
                sourceScriptURL = URL(fileURLWithPath: devPath)
            }
        }
        
        if let source = sourceScriptURL {
            try? fm.removeItem(at: targetScriptURL)
            try? fm.copyItem(at: source, to: targetScriptURL)
        }
        
        guard fm.fileExists(atPath: targetScriptURL.path) else {
            print("[RelaySupervisor] server.cjs could not be located.")
            return
        }
        
        // 1. Try LaunchAgent registration for permanent background survival
        let launchAgentsDir = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LaunchAgents")
        try? fm.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        let plistURL = launchAgentsDir.appendingPathComponent("com.starbutler.cloudrelay.plist")
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.starbutler.cloudrelay</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(nodePath)</string>
                <string>\(targetScriptURL.path)</string>
            </array>
            <key>WorkingDirectory</key>
            <string>\(appSupport.path)</string>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(appSupport.path)/relay.log</string>
            <key>StandardErrorPath</key>
            <string>\(appSupport.path)/relay_err.log</string>
        </dict>
        </plist>
        """
        
        try? plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
        
        let launchctl = Process()
        launchctl.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        launchctl.arguments = ["load", "-w", plistURL.path]
        try? launchctl.run()
        launchctl.waitUntilExit()
        
        // If launchctl succeeded, verify in 1 second
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkHealth { running in
                if running {
                    print("[RelaySupervisor] Successfully launched via launchd!")
                } else {
                    // Fallback to direct child process
                    self?.spawnChildProcess(nodePath: nodePath, scriptPath: targetScriptURL.path, workingDir: appSupport.path)
                }
            }
        }
    }
    
    private func spawnChildProcess(nodePath: String, scriptPath: String, workingDir: String) {
        guard childProcess == nil || !childProcess!.isRunning else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: nodePath)
        p.arguments = [scriptPath]
        p.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        
        let logPipe = Pipe()
        p.standardOutput = logPipe
        p.standardError = logPipe
        
        try? p.run()
        self.childProcess = p
        print("[RelaySupervisor] Spawned child Process PID: \(p.processIdentifier)")
    }
}
