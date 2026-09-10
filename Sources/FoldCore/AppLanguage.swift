/// The interface language is independent of the macOS language preference.
public enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public init(savedValue: String?) {
        self = savedValue.flatMap(Self.init(rawValue:)) ?? .english
    }

    public func text(english: String, simplifiedChinese: String) -> String {
        self == .simplifiedChinese ? simplifiedChinese : english
    }
}
