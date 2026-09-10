import AppKit
import Security

/// Read only: never edits TCC records or grants permissions on the user's behalf.
enum RuntimeIdentity {
    static var details: String {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var dictionary: CFDictionary?
        var signature = L("Unable to read signing information", "无法读取签名信息")
        if SecCodeCopySelf([], &code) == errSecSuccess, let code,
           SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
           SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &dictionary) == errSecSuccess,
           let values = dictionary as? [String: Any] {
            let flags = (values[kSecCodeInfoFlags as String] as? NSNumber)?.uint32Value ?? 0
            let team = values[kSecCodeInfoTeamIdentifier as String] as? String
            signature = flags & 2 != 0 ? L("Ad hoc signature: existing permissions may become invalid after rebuilding", "临时签名：重新编译后旧授权可能失效") : L("Certificate signature; Team ID: \(team ?? "No Apple Team ID")", "证书签名；Team ID：\(team ?? "无 Apple Team ID")")
        }
        return L("""
        Path: \(Bundle.main.bundleURL.path)
        Executable: \(Bundle.main.executablePath ?? "Unknown")
        Bundle ID: \(Bundle.main.bundleIdentifier ?? "None (standalone executable)")
        Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
        Build date: \(Bundle.main.object(forInfoDictionaryKey: "MacDuoBuildDate") as? String ?? "Older build")
        Process PID: \(ProcessInfo.processInfo.processIdentifier)
        Signature: \(signature)

        Entries with the same name may refer to different builds. Run a single MacDuo.app from a stable location; avoid mixing Xcode executables, dist bundles, and installed copies.

        If access is still denied after granting permission: quit MacDuo, remove the old entry in screen recording settings, add and authorize the app at the path above, then reopen it. This may be needed after an identity change. A stable signing certificate helps preserve identity across builds.
        """, """
        路径：\(Bundle.main.bundleURL.path)
        可执行文件：\(Bundle.main.executablePath ?? "未知")
        Bundle ID：\(Bundle.main.bundleIdentifier ?? "无（裸程序）")
        版本：\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知")
        构建时间：\(Bundle.main.object(forInfoDictionaryKey: "MacDuoBuildDate") as? String ?? "旧版本")
        进程 PID：\(ProcessInfo.processInfo.processIdentifier)
        签名：\(signature)

        同名条目不一定对应当前运行版本。请只运行一个固定位置的 MacDuo.app，避免同时使用 Xcode 的裸程序、dist 应用包和已安装副本。

        已开启权限仍被系统拒绝时：退出 MacDuo，在系统录屏设置中手动移除旧的 MacDuo 条目，添加并授权上述路径的应用包，再重新打开。首次身份迁移可能需要这样处理；固定证书签名用于避免后续构建反复改变身份。
        """)
    }
}
