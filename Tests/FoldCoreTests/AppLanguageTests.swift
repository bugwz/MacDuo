import XCTest
@testable import FoldCore

final class AppLanguageTests: XCTestCase {
    func testFirstLaunchAndInvalidPreferenceUseEnglish() {
        XCTAssertEqual(AppLanguage(savedValue: nil), .english)
        XCTAssertEqual(AppLanguage(savedValue: "unsupported"), .english)
        XCTAssertEqual(AppLanguage(savedValue: ""), .english)
    }

    func testSavedLanguageSelectsMatchingText() {
        XCTAssertEqual(AppLanguage(savedValue: "zh-Hans").text(english: "Start", simplifiedChinese: "开启"), "开启")
        XCTAssertEqual(AppLanguage(savedValue: "en").text(english: "Start", simplifiedChinese: "开启"), "Start")
    }
}
