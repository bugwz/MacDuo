import SwiftUI

struct ControlPanel: View {
    @ObservedObject var model: AppModel
    @AppStorage(AppLocalization.preferenceKey) private var interfaceLanguage = "en"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Image(nsImage: BrandIcon.image(size: 56, appIcon: true))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MacDuo").font(.system(size: 30, weight: .semibold, design: .rounded))
                        Text(L("Fold your desktop with your display", "让桌面随屏幕一起折叠")).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(model.enabled ? L("Running", "运行中") : L("Preview", "预览"))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(model.enabled ? Color.green.opacity(0.18) : Color.white.opacity(0.08), in: Capsule())
                }
                HStack {
                    Picker(L("Language", "语言"), selection: $interfaceLanguage) {
                        Text("English").tag("en")
                        Text("简体中文").tag("zh-Hans")
                    }
                    .frame(width: 230)
                    Spacer()
                    Text("v" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.2"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if interfaceLanguage != AppLocalization.language.rawValue {
                    Text("Restart MacDuo to apply the language. / 重启 MacDuo 后语言设置生效。")
                        .font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                FoldPreview(progress: model.progress, image: model.previewImage)
                    .frame(height: model.hardwareLimitation == nil ? 210 : 160)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .bottomLeading) {
                        Text(L("Illustration · Start to use your live desktop", "示意画面 · 开启后使用实时桌面"))
                            .font(.caption2).foregroundStyle(.white.opacity(0.65))
                            .padding(10)
                    }
                HStack {
                    Label(model.sensorStatus, systemImage: model.sensorAngle == nil ? "sensor" : "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(model.sensorAngle == nil ? .orange : .green)
                    Spacer()
                    Button(L("Detect Again", "重新检测")) { model.detectSensor() }.controlSize(.small)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.hardwareName).font(.caption.weight(.medium))
                    if let limitation = model.hardwareLimitation {
                        Text(limitation).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(L("Detection Details", "查看检测详情")) {
                        let alert = NSAlert()
                        alert.messageText = L("Sensor Detection Details", "传感器检测详情")
                        alert.informativeText = model.sensorDiagnostic
                        alert.addButton(withTitle: L("Close", "关闭"))
                        alert.runModal()
                    }.controlSize(.small)
                }
                Picker(L("Angle Source", "角度来源"), selection: $model.manual) {
                    Text(L("Lid Sensor", "铰链传感器")).tag(false)
                    Text(L("Manual / Touch Bar", "手动 / Touch Bar")).tag(true)
                }.pickerStyle(.segmented)
                VStack(spacing: 12) {
                    HStack {
                        Text(model.manual ? L("Simulated Display Angle", "模拟屏幕角度") : L("Current Display Angle", "当前屏幕角度"))
                        Spacer()
                        Text(!model.manual && model.sensorAngle == nil ? "—" : String(format: "%.1f°", model.angle))
                            .monospacedDigit().font(.system(size: 22, weight: .medium))
                    }
                    if model.manual {
                        Slider(value: $model.manualAngle, in: 10...160, step: 1)
                            .accessibilityLabel(L("Simulated Display Angle", "模拟屏幕角度"))
                    }
                    HStack {
                        Text(L("Reference Angle", "角度基准")).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f°", model.reference)).monospacedDigit()
                        Button(L("Calibrate Current Angle", "以当前角度校准")) { model.calibrate() }
                            .disabled(!model.manual && model.sensorAngle == nil)
                    }
                    HStack {
                        Text(L("Angle Travel", "开合行程")).foregroundStyle(.secondary)
                        Slider(value: $model.travel, in: 20...90, step: 1)
                            .accessibilityLabel(L("Angle Travel", "开合行程"))
                            .frame(width: 180)
                        Text(String(format: "%.0f°", model.travel)).monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                }.padding(16).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                Button(L("App & Permission Details", "运行与授权详情")) {
                    let alert = NSAlert()
                    alert.messageText = L("Running MacDuo", "当前运行的 MacDuo")
                    alert.informativeText = RuntimeIdentity.details
                    alert.addButton(withTitle: L("Close", "关闭"))
                    alert.addButton(withTitle: L("Show in Finder", "在 Finder 中显示"))
                    if alert.runModal() == .alertSecondButtonReturn {
                        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                    }
                }.controlSize(.small)
                Text(model.message)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 35, alignment: .topLeading)
                HStack {
                    Button(L("Screen Recording Settings", "屏幕录制设置")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }.controlSize(.small)
                    Spacer()
                    Button(model.enabled || model.starting ? L("Stop Desktop Effect", "停止桌面效果") : L("Start Desktop Effect", "开启桌面效果")) {
                        if model.enabled || model.starting { model.stop() } else { model.start() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(!model.enabled && !model.starting && !model.manual && model.sensorAngle == nil)
                }
                HStack {
                    Button(L("Show Touch Bar Controls", "展开 Touch Bar 控制")) { model.showTouchBar?() }
                    Button(L("Restore System Touch Bar", "恢复系统 Touch Bar")) { model.restoreTouchBar?() }
                }
                .controlSize(.small)
                Text(model.manual
                     ? L("\(model.touchBarEntryStatus) Drag to preview; dismiss to stop. Ends after 60 seconds. Emergency exit: ⌃⌥⌘F.", "\(model.touchBarEntryStatus) 拖动角度体验，收起退出效果。60 秒自动结束；⌃⌥⌘F 紧急退出。")
                     : L("Following the physical display angle. Click the folded image to exit and interact with your desktop.", "正在使用实体屏幕角度。折叠时点击画面即可退出；退出效果后可正常操作桌面。"))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(26)
        }
        .frame(width: 550, height: min(820, (NSScreen.main?.visibleFrame.height ?? 900) - 80))
        .background(Color(red: 0.075, green: 0.09, blue: 0.11))
        .preferredColorScheme(.dark)
    }
}
