import AppKit
import SwiftUI
import FoldCore

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppModel: ObservableObject {
    var restoreTouchBar: (() -> Void)?
    var showTouchBar: (() -> Void)?
    @Published var touchBarEntryStatus = ""
    @Published var sensorAngle: Double?
    @Published var sensorDiagnostic = ""
    @Published var hardwareName = ""
    @Published var hardwareLimitation: String?
    @Published var sensorStatus = L("Detecting sensor…", "正在检测传感器…")
    @Published var manual = true { didSet { if enabled || starting { stop() }; refreshProgress() } }
    @Published var manualAngle = 90.0 { didSet { refreshProgress() } }
    @Published var reference = 90.0 { didSet { refreshProgress(); UserDefaults.standard.set(reference, forKey: "reference") } }
    @Published var travel = 60.0 { didSet { refreshProgress(); UserDefaults.standard.set(travel, forKey: "travel") } }
    @Published var progress = 0.0
    @Published var enabled = false
    @Published var starting = false
    @Published var message = L("Drag the angle slider to preview, then start the desktop effect.", "先拖动角度滑块预览，再开启桌面效果。")
    @Published var hotKeyAvailable = false
    let previewImage = makePreviewImage()
    private let sensor = LidSensor()
    private var latch = AngleLatch()
    private var capture: DesktopCapture?
    private var overlay: OverlayWindow?
    private var foldView: FoldView?
    private var generation = UUID()
    private var firstFrame = false
    private var timeoutTask: Task<Void, Never>?
    private var previewTimeout: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    var angle: Double { manual ? manualAngle : sensorAngle ?? reference }

    init() {
        if let saved = UserDefaults.standard.object(forKey: "reference") as? Double { reference = max(30, min(150, saved)) }
        if let saved = UserDefaults.standard.object(forKey: "travel") as? Double { travel = max(20, min(90, saved)) }
        sensor.onUpdate = { [weak self] angle, status in
            guard let self else { return }
            self.sensorAngle = angle.map { self.latch.update($0) }
            self.sensorStatus = status
            self.sensorDiagnostic = self.sensor.diagnostic
            self.hardwareName = self.sensor.hardware.displayName
            self.hardwareLimitation = angle == nil ? self.sensor.hardware.knownLimitation : nil
            if angle == nil && !self.manual && (self.enabled || self.starting) {
                self.stop()
                self.message = L("Sensor unavailable. The desktop effect has stopped. Switch to manual preview.", "传感器信号不可用，已退出桌面效果。可切换到手动预览。")
            }
            self.refreshProgress()
        }
        sensor.start()
        manual = sensorAngle == nil
        if sensorAngle != nil {
            message = L("Lid sensor selected. Position your display comfortably, calibrate, then start the effect.", "已选择铰链传感器。将屏幕放到舒适角度，校准后开启桌面效果。")
        } else {
            message = L("Manual mode selected. Use the Touch Bar or panel slider to adjust the angle.", "已选择手动模式。有 Touch Bar 时可直接拖动角度滑块，也可使用面板滑块。")
        }
    }

    func detectSensor() { latch = AngleLatch(); sensor.start() }
    func calibrate() { reference = angle }

    private func refreshProgress() {
        progress = FoldMapping(reference: reference, travel: travel).progress(angle: angle)
        foldView?.progress = progress
        updateVisibility()
    }

    private func updateVisibility() {
        guard enabled, firstFrame else { overlay?.orderOut(nil); return }
        if abs(progress) < 0.001 { overlay?.orderOut(nil) }
        else { overlay?.orderFrontRegardless() }
    }

    func start() {
        guard !starting, !enabled else { return }
        guard hotKeyAvailable else { message = L("Could not register the emergency shortcut. Quit conflicting software and restart MacDuo.", "紧急退出快捷键注册失败，请退出冲突软件后重启 MacDuo。"); return }
        guard manual || sensorAngle != nil else { message = L("No lid angle available. Use manual preview first.", "尚未读到铰链角度，请先使用手动预览。"); return }
        guard let screen = NSScreen.screens.first(where: { CGDisplayIsBuiltin(Self.displayID($0)) != 0 }) ?? NSScreen.main else { return }
        starting = true
        message = L("Requesting screen recording access and preparing your desktop…", "正在请求屏幕录制并准备画面…")
        let token = UUID()
        generation = token
        let window = OverlayWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.touchBar = NSApp.touchBar
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = true
        window.backgroundColor = .white
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        let view = FoldView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.autoresizingMask = [.width, .height]
        view.progress = progress
        view.onDismiss = { [weak self] in self?.stop() }
        window.contentView = view
        overlay = window
        foldView = view
        let capture = DesktopCapture()
        self.capture = capture
        firstFrame = false
        capture.onFrame = { [weak self] image in
            DispatchQueue.main.async {
                guard let self, self.generation == token else { return }
                self.foldView?.setImage(image)
                self.firstFrame = true
                self.updateVisibility()
            }
        }
        capture.onFailure = { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.generation == token else { return }
                self.stop()
                self.message = L("Screen capture stopped: \(error)", "画面采集停止：\(error)")
            }
        }
        startupTask = Task { [weak self] in
            do {
                try await capture.start(displayID: Self.displayID(screen))
                guard let self, self.generation == token, !Task.isCancelled else { await capture.stop(); return }
                self.starting = false
                self.enabled = true
                self.message = self.manual ? L("Manual desktop preview started; ends after 60 seconds. Click the background or press ⌃⌥⌘F to exit.", "手动桌面预览已开启，60 秒后自动退出。点击背景或按 ⌃⌥⌘F 可立即退出。") : L("Following the lid angle. Click the image or press ⌃⌥⌘F to exit.", "正在跟随铰链角度。点击画面或按 ⌃⌥⌘F 退出。")
                self.updateVisibility()
                self.timeoutTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    guard !Task.isCancelled, let self, self.generation == token, !self.firstFrame else { return }
                    self.stop()
                    self.message = L("No screen frames received. Effect stopped. Check screen recording permission.", "没有收到屏幕画面，已退出。请检查屏幕录制权限。")
                }
                if self.manual {
                    self.previewTimeout = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: 60_000_000_000)
                        guard !Task.isCancelled, let self, self.generation == token else { return }
                        self.stop()
                        self.message = L("Manual desktop preview ended automatically after 60 seconds.", "手动桌面预览已在 60 秒后自动结束。")
                    }
                }
            } catch {
                guard let self, self.generation == token else { return }
                self.stop()
                let detail = error as NSError
                self.message = L("Unable to capture screen: \(detail.localizedDescription)\nError: \(detail.domain) / \(detail.code). Open App & Permission Details to check the current app path.", "无法采集屏幕：\(detail.localizedDescription)\n错误：\(detail.domain) / \(detail.code)。点击「运行与授权详情」确认当前应用路径。")
            }
        }
    }

    func stop() {
        generation = UUID()
        starting = false
        enabled = false
        firstFrame = false
        timeoutTask?.cancel()
        previewTimeout?.cancel()
        startupTask?.cancel()
        overlay?.orderOut(nil)
        overlay?.close()
        overlay = nil
        foldView = nil
        let oldCapture = capture
        capture = nil
        Task { await oldCapture?.stop() }
        message = L("Desktop effect stopped.", "桌面效果已关闭。")
    }

    func suspend() {
        stop()
        sensor.stop()
        sensorAngle = nil
        sensorStatus = L("Sensor paused; detection resumes after wake", "传感器已暂停，唤醒后重新检测")
        message = L("System sleep or session change: desktop effect stopped.", "系统睡眠或会话切换，桌面效果已关闭。")
    }
    static func displayID(_ screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
    }
}
