import Foundation
import AppKit

public final class StarButlerCloudRelaySupervisor {
    public static let shared = StarButlerCloudRelaySupervisor()

    private let port = 8765
    private var childProcess: Process?
    // 默认 false：后台服务不静默安装，需用户在云控台显式开启
    private let kRelayEnabledKey = "starbutler_cloud_relay_enabled"

    private init() {}

    public var isRelayEnabled: Bool {
        UserDefaults.standard.bool(forKey: kRelayEnabledKey)
    }

    public func setRelayEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: kRelayEnabledKey)
        if enabled {
            ensureRunning()
        } else {
            stopRelayService()
        }
    }

    public func ensureRunning() {
        guard isRelayEnabled else {
            print("[RelaySupervisor] Cloud relay disabled by user; not starting.")
            return
        }
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

    private var relayInstallDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("StarButler")
            .appendingPathComponent("cloud-relay")
    }

    private var relayPlistURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LaunchAgents")
            .appendingPathComponent("com.starbutler.cloudrelay.plist")
    }

    public func stopRelayService() {
        let launchctl = Process()
        launchctl.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        launchctl.arguments = ["unload", relayPlistURL.path]
        try? launchctl.run()
        launchctl.waitUntilExit()

        try? FileManager.default.removeItem(at: relayPlistURL)

        if let p = childProcess, p.isRunning {
            p.terminate()
        }
        childProcess = nil
        print("[RelaySupervisor] Cloud relay service stopped and LaunchAgent removed.")
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
            "/usr/bin/node"
        ]
        
        let fm = FileManager.default
        for path in candidates {
            let expanded = NSString(string: path).expandingTildeInPath
            if fm.fileExists(atPath: expanded) {
                return expanded
            }
        }

        // nvm installs live under ~/.nvm/versions/node/<version>/bin — pick the newest
        let nvmVersionsDir = NSString(string: "~/.nvm/versions/node").expandingTildeInPath
        if let versions = try? fm.contentsOfDirectory(atPath: nvmVersionsDir) {
            for v in versions.sorted().reversed() {
                let nodeBin = (nvmVersionsDir as NSString).appendingPathComponent(v) + "/bin/node"
                if fm.fileExists(atPath: nodeBin) { return nodeBin }
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
        let appSupport = relayInstallDir

        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        
        let targetScriptURL = appSupport.appendingPathComponent("server.cjs")
        
        // Locate bundled server.cjs
        let sourceScriptURL = Bundle.main.url(forResource: "server", withExtension: "cjs")
        
        if let source = sourceScriptURL {
            try? fm.removeItem(at: targetScriptURL)
            try? fm.copyItem(at: source, to: targetScriptURL)
        }
        
        guard fm.fileExists(atPath: targetScriptURL.path) else {
            print("[RelaySupervisor] server.cjs could not be located.")
            return
        }
        
        // 1. Try LaunchAgent registration for permanent background survival
        let launchAgentsDir = relayPlistURL.deletingLastPathComponent()
        try? fm.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        let plistURL = relayPlistURL
        
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
