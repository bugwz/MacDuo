# GitHub 分发、签名与授权

不上架 App Store。正式包使用 **Developer ID Application 签名 + Apple 公证**，从 GitHub Releases 下载。公证是站外分发的安全检查，不是 App Store 上架。

## 为什么开发时反复授权

macOS TCC 按代码签名的 designated requirement（DR）识别应用。`codesign --sign -` 的临时签名通常与当前二进制哈希绑定，重编译会改变身份。固定 Bundle ID 或安装路径本身不能弥补不稳定签名。

本项目固定 `dev.macduo.app`。正式版本持续使用同一个 Developer Team 的 Developer ID Application 签名，并安装到 `/Applications/MacDuo.app`。正常覆盖升级时可保持身份，从而避免每次更新都被当作新应用。首次授权、用户撤销、系统策略要求的再次确认，以及从临时签名/Apple Development 切到 Developer ID 的一次迁移授权无法由应用取消。不要把“系统定期提醒”与“每次重新安装后丢失身份”混为一谈。

不要使用 TCC 数据库写入、关闭 SIP、移除隔离属性或不校验证书的自定义 DR 来规避授权。

## 本地开发

在 Keychain Access/Xcode 中准备可用于代码签名的 Apple Development 或 Developer ID Application 证书及其私钥。获取证书哈希：

```sh
security find-identity -v -p codesigning
```

将选定证书的 40 位 SHA-1 哈希写入仓库根目录 `.local-signing-identity`（已 gitignore，**不是私钥**）。之后执行：

```sh
./scripts/build-app.sh
```

也可使用 `CODE_SIGN_IDENTITY='你的证书哈希或完整名称' ./scripts/build-app.sh`。不要每次重建证书。保持使用同一签名渠道；为了与正式下载包共用身份，使用同一 Team 的 Developer ID Application。

无证书时脚本仍可生成临时签名开发包，但会明确警告：不能保证跨构建保留权限。不存在只加一个 plist 或 entitlement 就能把临时签名变成稳定正式身份的开关。

退出旧进程，将构建出的 `dist/MacDuo.app` 放到 `/Applications` 并覆盖旧版本，然后从该位置启动。首次从旧临时签名迁移后，在系统设置的屏幕录制列表中授权新安装版本；必要时手动移除旧的失效条目。应用不在启动时申请录屏：只有明确点击“开启”才调用 ScreenCaptureKit；不持久缓存授权失败，不使用 CGPreflightScreenCaptureAccess 的结果拦截真实采集。不自动轮询或重试权限。

## GitHub Actions

- `build.yml`：main 分支和 PR 构建 universal（arm64 + x86_64）临时签名开发 ZIP，无证书 secrets、不发布 Release。ZIP 保留可执行权限。
- `release.yml`：推送 `vX.Y.Z` 标签，或手动选择已有标签；生成正式签名、公证并 stapled 的 universal ZIP、DMG、SHA256SUMS，创建 **草稿 Release**。人工检查后发布。不会覆盖已发布版本。
- 发布环境为 `release`，建议在 GitHub 配置该环境仅允许受保护的版本标签；签名 secrets 仅供发布环境使用。

推送标签前，必须将对应版本的发布说明 `release/X.Y.Z.md` 提交到该标签指向的提交中。Actions 会读取该文件，去掉首行一级标题和紧随其后的空行，将其余 Markdown 正文写入对应 tag 的 Release 描述，保留双语内容；缺失或正文为空时任务失败，不使用链接或自动生成的说明替代。

签名、公证和打包成功后，Actions 会检查并将 `MacDuo-X.Y.Z-universal.zip`、`MacDuo-X.Y.Z-universal.dmg` 和 `SHA256SUMS.txt` 上传到对应 tag 的 Release Assets，同时保留 Actions artifacts。重跑时会更新同一草稿的正文和附件；已公开的 Release 不会被覆盖。任务成功后检查草稿正文、三个附件及签名公证结果，再发布草稿，用户即可从该 Release 下载软件包。

在 GitHub 的 `release` Environment 添加：

| Secret | 内容 |
|---|---|
| `MACOS_CERTIFICATE_P12_BASE64` | 从钥匙串导出的 Developer ID Application 证书和私钥的加密 `.p12`，再 base64 编码 |
| `MACOS_CERTIFICATE_PASSWORD` | `.p12` 导出密码（必须非空） |
| `APPLE_ID` | 公证使用的 Apple 开发者账号 |
| `APPLE_APP_SPECIFIC_PASSWORD` | 该账号的 App 专用密码 |
| `APPLE_TEAM_ID` | Developer Team ID |

发布示例：

```sh
git tag v0.0.2
git push origin v0.0.2
```

证书导入临时钥匙串，仅允许签名工具使用，作业结束后清理。没有证书、证书类型错误或公证失败时发布任务失败，**不会退回临时签名并发布**。私钥、证书导出文件、密码都不提交到仓库。不需要 Mac App Store provisioning profile，也不添加 App Sandbox entitlement。

`VERSION` 来自标签，`BUILD_NUMBER` 来自 GitHub run number。本地默认为 0.0.2 / 1。`NATIVE_ONLY=1` 可用于本地单架构编译；发版始终使用默认 universal 架构。

## HID 错误

`-536870174` 对应 `kIOReturnNotPermitted`。之前以全部 Apple HID 集合调用 Open，会涉及键盘等受保护设备。现在 Mac14,7 等已知不可读取角度的机型直接进入 Touch Bar / 手动路径，不打开 HID；其他机型在 Open 之前限定标准角度用途 `0x20 / 0x8A`，不会为效果请求键盘输入监控权限。

## 依据

- [Apple TN3127：签名要求、TCC 与临时签名身份](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
- [Apple：公证 macOS 软件](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

签名、公证 CI 需要仓库实际配置 secrets 后才能验证。应用交互和升级后授权保持情况由用户实机验收。

## 开关已打开却仍被拒绝

旧版本把 `CGPreflightScreenCaptureAccess == false` 与持久化的 `didRequestScreenCaptureAccess` 标记结合，直接拒绝采集，导致没有尝试 ScreenCaptureKit 就报错。新版删除这两个门禁，只在用户点击开启后实际调用 ScreenCaptureKit，以其结果为准；旧标记保留在偏好设置中也不再有作用。

“运行与授权详情”显示当前路径、Bundle ID、签名类型和 PID，可区分同名记录。普通 Swift Package 的 Xcode Run 会运行裸可执行文件，不能当作完整 `.app` 授权；使用 `scripts/run-app.sh` 或打开固定安装的应用包。裸进程现在会在采集前显示明确说明，不再创建另一种录屏授权请求。

系统已经保留的重复/失效条目不会被应用自动删除。需要用户在系统设置中手动移除旧的 MacDuo 条目并添加准确的 `.app`。代码修复不能将临时签名的旧 TCC 记录迁移成新证书身份；没有固定签名证书时，不能承诺跨构建免重新授权。

### 固定启动位置

`run-app.sh` 现在只启动 `/Applications/MacDuo.app`，不再每次启动都编译、临时重签并运行 dist 副本。首次本地安装执行 `scripts/install-app.sh`；它原样复制已构建的签名应用，不重签、不修改权限数据库，也不覆盖现有安装。已有版本更新时先退出应用，再在 Finder 中替换。
