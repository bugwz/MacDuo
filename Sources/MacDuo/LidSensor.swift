import Foundation
import IOKit.hid
import FoldCore

final class LidSensor {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var timer: Timer?
    private var failedReads = 0
    let hardware = HardwareInfo.current()
    private(set) var diagnostic = ""
    var onUpdate: ((Double?, String) -> Void)?

    func start() {
        stop()
        diagnostic = L("Model: \(hardware.displayName)", "机型：\(hardware.displayName)")
        if let limitation = hardware.knownLimitation {
            diagnostic += "\n" + limitation + L("\nHID access skipped. Use Touch Bar / manual mode.", "\n已跳过 HID 访问，使用 Touch Bar / 手动模式。")
            onUpdate?(nil, L("Use Touch Bar / manual angle", "使用 Touch Bar / 手动角度"))
            return
        }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        diagnostic = L("Model: \(hardware.displayName)", "机型：\(hardware.displayName)")
        // Restrict before opening: opening all Apple HID devices also opens protected
        // keyboard/mouse collections and can trigger Input Monitoring denial.
        let match: [String: Any] = [kIOHIDVendorIDKey: 0x05AC,
                                   kIOHIDDeviceUsagePageKey: 0x20,
                                   kIOHIDDeviceUsageKey: 0x8A]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else {
            diagnostic += L("\nCould not open HID manager: \(status)", "\nHID 管理器打开失败：\(status)")
            onUpdate?(nil, status == kIOReturnNotPermitted ? L("Angle interface access restricted; use manual mode", "角度接口访问受限，可使用手动模式") : L("Could not open angle interface (\(status))", "角度接口打开失败（\(status)）"))
            return
        }
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        let candidates = devices.filter { candidate in
            if Self.number(candidate, kIOHIDPrimaryUsagePageKey) == 0x20 && Self.number(candidate, kIOHIDPrimaryUsageKey) == 0x8A { return true }
            let pairs = IOHIDDeviceGetProperty(candidate, kIOHIDDeviceUsagePairsKey as CFString) as? [[String: Any]] ?? []
            return pairs.contains {
                ($0[kIOHIDDeviceUsagePageKey] as? NSNumber)?.intValue == 0x20 &&
                ($0[kIOHIDDeviceUsageKey] as? NSNumber)?.intValue == 0x8A
            }
        }
        let vendorCount = devices.filter { Self.number($0, kIOHIDProductIDKey) == 0x8104 }.count
        diagnostic += L("\nMatching angle HID collections: \(devices.count); standard angle collections: \(candidates.count); 0x8104 collections: \(vendorCount)", "\n匹配的角度 HID 集合：\(devices.count)；标准角度集合：\(candidates.count)；0x8104 集合：\(vendorCount)")
        for candidate in candidates {
            let openStatus = IOHIDDeviceOpen(candidate, IOOptionBits(kIOHIDOptionsTypeNone))
            guard openStatus == kIOReturnSuccess else {
                diagnostic += L("\nCould not open angle device: \(openStatus)", "\n角度设备打开失败：\(openStatus)")
                continue
            }
            if let angle = Self.read(candidate) {
                device = candidate
                diagnostic += L("\nValid angle received.", "\n已读取有效角度。")
                onUpdate?(angle, L("Sensor connected", "传感器已连接"))
                let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] _ in self?.poll() }
                self.timer = timer
                RunLoop.main.add(timer, forMode: .common)
                return
            }
            diagnostic += L("\nAngle device opened, but feature report 1 returned no valid angle.", "\n角度设备已打开，但 feature report 1 未返回有效角度。")
            IOHIDDeviceClose(candidate, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        if !candidates.isEmpty {
            onUpdate?(nil, L("Angle device found, but reading failed", "发现角度设备，但读取失败"))
        } else if let limitation = hardware.knownLimitation {
            diagnostic += "\n" + limitation
            onUpdate?(nil, L("Continuous angle reading unsupported on this model", "当前机型不支持连续角度读取"))
        } else if vendorCount > 0 {
            diagnostic += L("\n0x8104 is also used by other SPU devices and does not confirm an angle sensor.", "\n0x8104 也用于其他 SPU 设备，不能据此认定存在角度传感器。")
            onUpdate?(nil, L("Apple HID device found, but no readable angle interface", "发现 Apple HID 设备，但没有可读取的角度接口"))
        } else {
            onUpdate?(nil, L("No angle interface found; compatibility unconfirmed", "当前未发现角度接口，兼容性待确认"))
        }
    }

    private static func number(_ device: IOHIDDevice, _ key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }

    private static func read(_ device: IOHIDDevice) -> Double? {
        var report = [UInt8](repeating: 0, count: 8)
        var length = report.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }
        return LidReport.angle(bytes: Array(report.prefix(length)))
    }

    private func poll() {
        guard let device else { return }
        if let angle = Self.read(device) {
            failedReads = 0
            onUpdate?(angle, L("Sensor connected", "传感器已连接"))
        } else {
            failedReads += 1
            if failedReads == 15 { onUpdate?(nil, L("Angle signal lost; detect again", "角度信号中断，请重新检测")) }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        device = nil
        if let manager { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        manager = nil
        failedReads = 0
    }
    deinit { stop() }
}
