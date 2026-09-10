import AppKit
import ScreenCaptureKit
import CoreImage

final class DesktopCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "MacDuo.capture", qos: .userInteractive)
    private let context = CIContext(options: [.cacheIntermediates: false])
    var onFrame: ((CGImage) -> Void)?
    var onFailure: ((String) -> Void)?

    func start(displayID: CGDirectDisplayID) async throws {
        guard Bundle.main.bundleURL.pathExtension == "app",
              Bundle.main.bundleIdentifier == "dev.macduo.app" else {
            throw NSError(domain: "MacDuo", code: 4, userInfo: [NSLocalizedDescriptionKey:
                L("You are running a standalone executable, which has separate permissions from MacDuo.app. Quit and launch the app bundle with scripts/run-app.sh.", "当前运行的是裸可执行程序，系统会将它与 MacDuo.app 分开授权。请退出此进程，使用 scripts/run-app.sh 启动完整应用包。")])
        }
        // ScreenCaptureKit is authoritative. CGPreflightScreenCaptureAccess can be
        // stale for a running/rebuilt process; never turn it into a permanent denial.
        // This is called only by an explicit Start action, never by a polling loop.
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw NSError(domain: "MacDuo", code: 1, userInfo: [NSLocalizedDescriptionKey: L("Target display not found. Start the effect again.", "找不到目标屏幕，请重新开启。")])
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        guard !ownApps.isEmpty else {
            throw NSError(domain: "MacDuo", code: 2, userInfo: [NSLocalizedDescriptionKey: L("Unable to exclude MacDuo from capture. Run the packaged MacDuo.app to avoid recursive capture.", "无法识别 MacDuo 的采集排除项。请运行打包后的 MacDuo.app，以避免画面递归。")])
        }
        // Excluding this process prevents an infinite screen-within-screen feedback loop.
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let config = SCStreamConfiguration()
        let pixelWidth = CGDisplayPixelsWide(displayID)
        let factor = min(1, 2560.0 / Double(max(1, pixelWidth)))
        config.width = Int(Double(pixelWidth) * factor)
        config.height = Int(Double(CGDisplayPixelsHigh(displayID)) * factor)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 3
        config.showsCursor = false
        config.capturesAudio = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = stream
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
    }

    func stop() async {
        guard let stream else { return }
        self.stream = nil
        try? await stream.stopCapture()
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onFailure?(error.localizedDescription)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: raw) == .complete,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let input = CIImage(cvPixelBuffer: buffer)
        guard let image = context.createCGImage(input, from: input.extent) else { return }
        onFrame?(image)
    }
}
