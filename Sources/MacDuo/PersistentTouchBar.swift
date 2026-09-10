import AppKit
import TouchBarBridge

@MainActor
final class PersistentTouchBar: NSObject {
    private let model: AppModel
    private let controls: AngleTouchBar
    private let item = NSCustomTouchBarItem(identifier: .init("dev.macduo.launcher"))
    private var registered = false
    private var isPresented = false
    private var dismissalTask: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
        controls = AngleTouchBar(model: model, includesClose: true)
        super.init()
        let button = NSButton(title: "", target: self, action: #selector(present))
        button.image = BrandIcon.image(size: 24, template: true)
        button.imagePosition = .imageOnly
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.setAccessibilityLabel(L("Open MacDuo Angle Controls", "打开 MacDuo 角度控制"))
        item.view = button
        controls.onClose = { [weak self] in self?.dismiss() }
    }

    func install() {
        guard !registered else { return }
        registered = MDTBInstall(item)
        model.touchBarEntryStatus = registered
            ? L("Touch Bar entry registered. If it is hidden, click Show Touch Bar Controls.", "已向系统注册 Touch Bar 入口；若未显示，请点「展开 Touch Bar 控制」。")
            : L("Persistent Touch Bar entry unavailable. Open MacDuo from the menu bar.", "当前系统不支持常驻 Touch Bar 入口，请从菜单栏打开 MacDuo。")
    }

    @objc func present() {
        guard !isPresented else { return }
        guard controls.prepareForPresentation() else {
            model.touchBarEntryStatus = L("Unable to create angle controls. The system Touch Bar is unchanged.", "角度控件未能创建，已保留系统 Touch Bar。")
            return
        }
        if !registered { install() }
        // Does not activate MacDuo or restore its window: the captured desktop
        // stays on the user's current application while the modal bar is open.
        guard registered, MDTBPresent(controls.bar, item.identifier.rawValue) else {
            MDTBDismiss(controls.bar)
            model.touchBarEntryStatus = L("The system did not accept the Touch Bar request. Use the panel slider.", "系统未接受 Touch Bar 展开请求；可继续使用面板角度滑块。")
            return
        }
        isPresented = true
        dismissalTask?.cancel()
        dismissalTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(60)) } catch { return }
            self?.dismiss()
        }
        model.touchBarEntryStatus = L("Angle controls requested; dismiss automatically after 60 seconds. If blank, press ⌃⌥⌘F or click Restore System Touch Bar.", "已请求展开角度控制，60 秒后自动收回。若空白，按 ⌃⌥⌘F 或点击「恢复系统 Touch Bar」。")
    }

    func suspend() {
        dismiss()
    }

    func resume() {
        // The Touch Bar agent may have discarded its items across sleep/login.
        if registered { MDTBRemove(item); registered = false }
        install()
        // Re-register only. Waking must not take over another app’s Touch Bar.
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        isPresented = false
        model.stop()
        MDTBDismiss(controls.bar)
        model.touchBarEntryStatus = L("Angle controls dismissed. Click the computer icon or Show Touch Bar Controls to try again.", "已收回角度控制。点击电脑图标或「展开 Touch Bar 控制」体验。")
    }

    func uninstall() {
        dismiss()
        if registered { MDTBRemove(item) }
        registered = false
    }
}
