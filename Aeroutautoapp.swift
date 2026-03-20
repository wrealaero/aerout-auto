import SwiftUI
import AppKit

@main
struct AeroutAutoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var mainWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        NotificationCenter.default.addObserver(self, selector: #selector(updateIcon), name: .clickerStateChanged, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.openMainWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.checkForUpdates() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { AutoClicker.shared.saveSettings() }

    private func makeIcon(active: Bool) -> NSImage {
        let size = NSSize(width: 20, height: 18)
        let img = NSImage(size: size, flipped: false) { _ in
            let color: NSColor = active ? .systemGreen : .labelColor
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .black),
                .foregroundColor: color
            ]
            NSAttributedString(string: "AA", attributes: attrs).draw(at: NSPoint(x: 0, y: 3))
            return true
        }
        img.isTemplate = !active
        return img
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let btn = statusItem.button else { return }
        btn.image = makeIcon(active: false)
        btn.target = self
        btn.action = #selector(barButtonClicked)
        btn.sendAction(on: [.leftMouseUp, .rightMouseUp])

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 460)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(clicker: AutoClicker.shared, onOpenMain: openMainWindow)
        )
    }

    @objc func barButtonClicked() {
        guard let ev = NSApp.currentEvent else { return }
        if ev.type == .rightMouseUp { showContextMenu() } else { togglePopover() }
    }

    func showContextMenu() {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Aerout Auto", action: #selector(openFromMenu), keyEquivalent: "")
        open.target = self; menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func togglePopover() {
        if popover.isShown { popover.performClose(nil) }
        else {
            guard let btn = statusItem.button else { return }
            popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func openFromMenu() { openMainWindow() }

    func openMainWindow() {
        popover.performClose(nil)

        if mainWindowController == nil {
            let hosting = NSHostingController(rootView: ContentView(clicker: AutoClicker.shared))
            let w = NSWindow(contentViewController: hosting)
            w.title = "Aerout Auto"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.setContentSize(NSSize(width: 440, height: 590))
            w.center()
            w.isReleasedWhenClosed = false
            w.delegate = self
            mainWindowController = NSWindowController(window: w)
        }

        NSApp.setActivationPolicy(.regular)
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func checkForUpdates() {
        let current = "1.0.0"
        guard let url = URL(string: "https://api.github.com/repos/wrealaero/aerout-auto/releases/latest") else { return }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag  = json["tag_name"] as? String else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard latest != current else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .updateAvailable, object: latest)
            }
        }.resume()
    }

    @objc func updateIcon() {
        let on = AutoClicker.shared.isRunning
        statusItem.button?.image = makeIcon(active: on)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        AutoClicker.shared.saveSettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

extension Notification.Name {
    static let clickerStateChanged = Notification.Name("aerout.clickerStateChanged")
    static let updateAvailable     = Notification.Name("aerout.updateAvailable")
}
