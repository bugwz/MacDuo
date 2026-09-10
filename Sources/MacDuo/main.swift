import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var panel: NSWindow!
    private var statusItem: NSStatusItem!
    private var persistentTouchBar: PersistentTouchBar!
    private var angleTouchBar: AngleTouchBar!
    private let hotKey = EmergencyHotKey()
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: L("About MacDuo", "关于 MacDuo"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: L("Hide MacDuo", "隐藏 MacDuo"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        applicationMenu.addItem(withTitle: L("Quit MacDuo", "退出 MacDuo"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
        model = AppModel()
        angleTouchBar = AngleTouchBar(model: model)
        NSApp.touchBar = angleTouchBar.bar
        hotKey.action = { [weak self] in self?.persistentTouchBar?.dismiss(); self?.model.stop() }
        model.hotKeyAvailable = hotKey.register()
        panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 550, height: 740),
                         styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        panel.touchBar = angleTouchBar.bar
        panel.title = "MacDuo"
        panel.isReleasedWhenClosed = false
        let content = NSHostingView(rootView: ControlPanel(model: model))
        content.touchBar = angleTouchBar.bar
        panel.contentView = content
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.center()
        persistentTouchBar = PersistentTouchBar(model: model)
        model.showTouchBar = { [weak self] in self?.showTouchBar() }
        model.restoreTouchBar = { [weak self] in self?.persistentTouchBar.dismiss() }
        persistentTouchBar.install()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = BrandIcon.image(size: 20, template: true)
        let menu = NSMenu()
        menu.addItem(withTitle: L("Open MacDuo", "打开 MacDuo"), action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: L("Show Touch Bar Controls", "展开 Touch Bar 控制"), action: #selector(showTouchBar), keyEquivalent: "")
        menu.addItem(withTitle: L("Stop Desktop Effect", "停止桌面效果"), action: #selector(stopEffect), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Quit MacDuo", "退出 MacDuo"), action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.persistentTouchBar.suspend(); self?.model.suspend() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.model.detectSensor(); self?.persistentTouchBar.resume() }
            })
        }
        NotificationCenter.default.addObserver(self, selector: #selector(stopEffect), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        showPanel()
    }
    @objc func showPanel() {
        if panel.isMiniaturized { panel.deminiaturize(nil) }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showTouchBar() { persistentTouchBar.present() }
    @objc func stopEffect() { persistentTouchBar.dismiss() }
    @objc func quit() { model.stop(); NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel(); return true
    }
    func applicationWillTerminate(_ notification: Notification) { persistentTouchBar.uninstall(); model.stop() }
}

if CommandLine.arguments.contains("--diagnose") {
    let sensor = LidSensor()
    sensor.onUpdate = { angle, status in
        print("\(status)\(angle.map { "：\($0)°" } ?? "")")
    }
    sensor.start()
    print(sensor.diagnostic)
    sensor.stop()
} else {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
