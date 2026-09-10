import Foundation
import IOKit

struct HardwareInfo {
    let identifier: String

    static func current() -> HardwareInfo {
        // IORegistry works even when hw.model is unavailable in a restricted process.
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return HardwareInfo(identifier: L("Unknown model", "未知型号")) }
        defer { IOObjectRelease(service) }
        guard let value = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return HardwareInfo(identifier: L("Unknown model", "未知型号"))
        }
        if let data = value as? Data {
            return HardwareInfo(identifier: String(decoding: data.prefix(while: { $0 != 0 }), as: UTF8.self))
        }
        return HardwareInfo(identifier: value as? String ?? L("Unknown model", "未知型号"))
    }

    var displayName: String {
        switch identifier {
        case "Mac14,7": return L("MacBook Pro 13-inch · M2 · 2022 (Mac14,7)", "MacBook Pro 13 英寸 · M2 · 2022（Mac14,7）")
        case "Mac14,2": return L("MacBook Air · M2 · 2022 (Mac14,2)", "MacBook Air · M2 · 2022（Mac14,2）")
        case "Mac14,15": return L("MacBook Air 15-inch · M2 · 2023 (Mac14,15)", "MacBook Air 15 英寸 · M2 · 2023（Mac14,15）")
        default: return identifier
        }
    }

    // Compatibility information: samhenrigold/LidAngleSensor, HardwareCompat.swift.
    // This is an explanation after probing fails, never a block on probing a device.
    var knownLimitation: String? {
        switch identifier {
        case "Mac14,7":
            return L("Continuous lid angle reading is unsupported on this 13-inch M2 MacBook Pro. An M2 chip does not imply a readable angle sensor, and lid-open status is not an angle. Use the Touch Bar or panel slider; physical lid tracking is unavailable.", "这款 13 英寸 M2 MacBook Pro 的连续铰链角度读取目前不受支持。M2 芯片本身不代表具备可读取的角度传感器；合盖状态也不能替代角度。可用 Touch Bar 或面板滑块控制折叠，无法随实体屏幕开合同步。")
        case "MacBookPro17,1", "MacBookAir10,1":
            return L("Continuous lid angle reading is unsupported on this model. Use the Touch Bar or panel slider; physical lid tracking is unavailable.", "这款机型的连续铰链角度读取目前不受支持。可用 Touch Bar 或面板滑块控制折叠，无法随实体屏幕开合同步。")
        default: return nil
        }
    }
}
