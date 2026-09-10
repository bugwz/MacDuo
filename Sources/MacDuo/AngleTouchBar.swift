import AppKit
import Combine

/// Angle controls shared by the foreground bar and a separate system-modal bar.
@MainActor
final class AngleTouchBar: NSObject, NSTouchBarDelegate {
    var onClose: (() -> Void)?
    private static let closeID = NSTouchBarItem.Identifier("dev.macduo.close")
    private static let angleID = NSTouchBarItem.Identifier("dev.macduo.angle")
    private static let resetID = NSTouchBarItem.Identifier("dev.macduo.reset")
    private static let toggleID = NSTouchBarItem.Identifier("dev.macduo.toggle")
    private let model: AppModel
    private var observation: AnyCancellable?
    private var sliderItem: NSSliderTouchBarItem?
    private var resetButton: NSButton?
    private var toggleButton: NSButton?
    let bar = NSTouchBar()

    init(model: AppModel, includesClose: Bool = false) {
        self.model = model
        super.init()
        bar.delegate = self
        bar.defaultItemIdentifiers = (includesClose ? [Self.closeID] : []) + [Self.toggleID, Self.angleID, Self.resetID]
        bar.principalItemIdentifier = Self.angleID
        // objectWillChange precedes the mutation; render after the new value is stored.
        observation = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case Self.closeID:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSButton(title: L("Dismiss", "收起"), target: self, action: #selector(closeControls))
            return item
        case Self.angleID:
            let item = NSSliderTouchBarItem(identifier: identifier)
            item.slider.minValue = 10
            item.slider.maxValue = 160
            item.slider.isContinuous = true
            item.minimumSliderWidth = 180
            item.maximumSliderWidth = 360
            item.target = self
            item.action = #selector(dragAngle(_:))
            item.slider.setAccessibilityLabel(L("Simulated Lid Angle", "模拟屏幕开合角度"))
            sliderItem = item
            refresh()
            return item
        case Self.resetID:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: L("Reset", "归位"), target: self, action: #selector(resetAngle))
            button.setAccessibilityLabel(L("Restore Calibrated Angle", "恢复校准角度"))
            resetButton = button
            item.view = button
            refresh()
            return item
        case Self.toggleID:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: L("Start", "开启"), target: self, action: #selector(toggleEffect))
            toggleButton = button
            item.view = button
            refresh()
            return item
        default: return nil
        }
    }

    func prepareForPresentation() -> Bool {
        // Resolve and retain all items before taking over the modal surface.
        let items = bar.defaultItemIdentifiers.compactMap { bar.item(forIdentifier: $0) }
        guard items.count == bar.defaultItemIdentifiers.count, sliderItem != nil else { return false }
        bar.templateItems = Set(items)
        refresh()
        return true
    }

    private func refresh() {
        sliderItem?.doubleValue = model.angle
        sliderItem?.label = String(format: model.manual ? L("Angle %.0f°", "角度 %.0f°") : L("Sensor %.0f°", "感知 %.0f°"), model.angle)
        sliderItem?.slider.isEnabled = model.manual
        resetButton?.isEnabled = model.manual
        toggleButton?.title = model.enabled || model.starting ? L("Stop", "停止") : L("Start", "开启")
        toggleButton?.bezelColor = model.enabled || model.starting ? .systemRed : .systemTeal
        toggleButton?.isEnabled = model.enabled || model.starting || (model.hotKeyAvailable && (model.manual || model.sensorAngle != nil))
    }

    @objc private func dragAngle(_ sender: NSSliderTouchBarItem) {
        guard model.manual else { return }
        model.manualAngle = min(160, max(10, sender.doubleValue))
    }
    @objc private func closeControls() { onClose?() }
    @objc private func resetAngle() {
        guard model.manual else { return }
        model.manualAngle = model.reference
    }
    @objc private func toggleEffect() {
        if model.enabled || model.starting { model.stop() } else { model.start() }
    }
}
