import Foundation
import FoldCore

/// Resolve once per launch so AppKit menus, stored diagnostics, and SwiftUI agree.
/// A changed preference takes effect on the next launch.
enum AppLocalization {
    static let preferenceKey = "interfaceLanguage"
    static let language = AppLanguage(savedValue: UserDefaults.standard.string(forKey: preferenceKey))
}

func L(_ english: String, _ simplifiedChinese: String) -> String {
    AppLocalization.language.text(english: english, simplifiedChinese: simplifiedChinese)
}
