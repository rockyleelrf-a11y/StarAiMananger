import AppKit
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var manager = AIAgentManager()
    private var eventMonitor: Any?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the Status Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            updateStatusButton(button)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Create the Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 720, height: 560)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PopoverContentView(manager: manager))
        self.popover = popover
        
        // Listen to manager changes to update status button indicator
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onManagerUpdated),
            name: NSNotification.Name("AIAgentManagerDidRefresh"),
            object: nil
        )
    }
    
    private func updateStatusButton(_ button: NSStatusBarButton) {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let iconName = "sparkles.rectangle.stack.fill"
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "AI 智能体管家") {
            button.image = image.withSymbolConfiguration(config)
            button.imagePosition = .imageLeading
        }
        
        let running = manager.runningCount
        if running > 0 {
            button.title = " \(running)"
        } else {
            button.title = ""
        }
    }
    
    @objc private func onManagerUpdated() {
        if let button = statusItem.button {
            updateStatusButton(button)
        }
    }
    
    @objc public func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(button)
        }
    }
    
    private func showPopover(_ sender: NSStatusBarButton) {
        manager.refresh()
        updateStatusButton(sender)
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        
        // Close popover when clicked outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover.isShown {
                strongSelf.closePopover(event)
            }
        }
    }
    
    private func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
