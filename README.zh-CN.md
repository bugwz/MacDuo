<p align="center">
  <img src="assets/MacDuo.png" width="128" alt="MacDuo">
</p>

<h1 align="center">MacDuo</h1>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.0.1-blue" alt="Version 0.0.1">
  <img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/Apple_Silicon_%26_Intel-universal-blue" alt="Apple Silicon and Intel">
  <img src="https://img.shields.io/badge/languages-English_%7C_简体中文-green" alt="English / 简体中文">
</p>

<p align="center">
  让桌面随 MacBook 屏幕一起折叠。
</p>

<p align="center">
  <a href="README.md">English</a> | <strong>简体中文</strong>
</p>

---

随 MacBook 实体屏幕角度实时折叠整个桌面的 macOS 原型。合上与向后展开对应两个折叠方向，停手后保持当前形状；桌面内容仍实时更新。

## 功能亮点

- **实时桌面效果**：桌面沿屏幕高度连续弯曲，两侧随开合收窄、远端渐进失焦；角度停止后保持姿态，桌面内容持续更新。
- **多种角度输入**：兼容设备使用实体铰链传感器，也可使用面板或 Touch Bar 手动控制。
- **便捷退出**：点击折叠画面、菜单栏停止或按 ⌃⌥⌘F；手动预览 60 秒后自动结束。
- **双语界面**：支持 English 和简体中文，保存语言偏好。
- **本地处理**：不采集音频、不保存画面、不上传桌面内容。

## 语言设置

README 默认展示英文，通过顶部链接切换简体中文。应用默认使用英文，在控制面板的 **Language / 语言** 中选择 **简体中文** 或 **English**，退出并重新打开 MacDuo 后生效。选择会保留至下次启动；macOS 自身的授权弹窗遵循系统语言设置。

## 运行

要求 macOS 14+、Xcode Command Line Tools（开发构建）。不依赖第三方包。

```sh
./scripts/build-app.sh
open dist/MacDuo.app
```

也可以在 Xcode 打开 `Package.swift`。屏幕录制权限与应用身份有关，实际使用优先运行打包的 `.app`，保持其路径稳定。本地可通过 `.local-signing-identity` 或 `CODE_SIGN_IDENTITY` 配置固定签名；无证书时生成临时签名开发版本。正式发行的签名、公证和 GitHub Actions 配置见 `docs/RELEASING.md`。

1. 在面板检查传感器状态；没有传感器也可以用“手动预览”滑块查看折叠。
2. 将屏幕放到舒适角度，点击“以当前角度校准”。默认基准为 90°。
3. 点击“开启桌面效果”，按系统提示授权屏幕录制。只采集内置屏幕；找不到内置屏幕时使用主屏幕。不采集音频、不写入画面文件、不上传。
4. 缓慢开合实体屏幕。相对基准角度的偏移控制折叠幅度；“开合行程”越小，效果越敏感。不要超过设备铰链的正常行程。
5. 点击画面或按 ⌃⌥⌘F 退出覆盖层，恢复桌面操作。关闭面板不会结束菜单栏应用。

**退出桌面效果：按 Control + Option + Command + F（⌃⌥⌘F），点击折叠画面，或从菜单栏选择“停止桌面效果”。** 手动桌面预览在 60 秒后自动退出。快捷键注册失败时不会开启全屏覆盖。

## 兼容性与边界

- 硬件输入使用 Apple HID orientation collection（usage page `0x20`、usage `0x8A`）的 feature report 1。它不是苹果公开承诺稳定的铰链角度 API；“合盖开关”不等于连续角度传感器。
- 对硬件的读取方式参考 [LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor) 和 [PyBookLid](https://github.com/tcsenpai/pybooklid) 公开的协议信息，代码独立实现。**只有读到有效角度才显示传感器可用**，不以芯片名称或设备 PID 推断兼容性。部分 M1/M2 Touch Bar 机型及 M1 Air 已有不兼容报告。
- 未读到传感器时提供手动模式，不用其他传感器数据伪装角度。重新检测可重试；不会自动要求管理员权限或关闭 SIP。
- 这是实时桌面画面的视觉覆盖，不改写 WindowServer 或各 App 的窗口。折叠状态下点击会退出，不对折叠后的控件做点击坐标反算。系统真实鼠标保持正常位置，采集画面不包含第二个鼠标。
- 普通桌面和全屏 App 使用跨 Space 覆盖层；系统锁屏、受保护视频、系统高层窗口等不保证可覆盖。控制面板与菜单栏保留在效果上方，便于操作。
- 合盖睡眠、屏幕睡眠、会话切换、显示器配置改变、传感器持续读失败及采集异常会停止效果。唤醒后需主动重新开启；不接管系统锁屏或登录画面。
- 当前仅处理一块屏幕，上限 2560 像素宽、30 fps。渲染使用 Core Image / Metal 连续曲面采样、渐进模糊与深色柔边，效果输出上限 1920 像素宽；屏幕采集使用 ScreenCaptureKit 并排除自身进程，避免递归捕获。尚未做多显示器、HDR 色彩或高刷新率优化。

## 验证

```sh
swift test
.build/debug/MacDuo --diagnose
```

单元测试验证双向角度映射、停止/反向行为、传感器畸形数据的拒绝。`--diagnose` 只检测硬件，不启动 UI、不请求屏幕录制。

实际验收：

- 手动模式从 90° 拖到 60°、暂停、再到 120°；两方向均应折叠，暂停时形状不漂移，文字不倒置。
- 授予屏幕录制后，打开视频或变化中的窗口，开启桌面效果，确认内容更新且没有递归画面。
- 点击覆盖层、使用紧急快捷键、切换显示器和进入睡眠，确认真实桌面可恢复。
- 兼容硬件上选择传感器模式，校准后缓慢开合并暂停，确认实际角度与画面同步。

自动编译和单元测试不能替代传感器实机测试、屏幕录制授权后的视觉验收。

## Mac14,7（13 英寸 M2 MacBook Pro）

此型号与 M2 Air、14/16 英寸 M2 Pro/Max 机型不同。现有 [LidAngleSensor 兼容性资料](https://github.com/samhenrigold/LidAngleSensor/blob/main/LidAngleSensor/HardwareCompat.swift) 将 Mac14,7 列为没有连续铰链角度传感器的机型。MacDuo 对此显示具体机型与限制，保留手动预览；软件更新并未使这款机器支持实体角度联动。

已知不支持的机型跳过 HID 访问。其他机型仅匹配标准方向传感器接口，再打开设备；分别报告设备缺失、设备打开失败与角度读取失败。控制面板的“查看检测详情”提供型号和匹配集合计数，不收集设备序列号。

## Touch Bar 角度控制

启动时读到有效角度的机器默认选择铰链传感器；未读到角度时默认选择“手动 / Touch Bar”。有 Touch Bar 的机型会显示原生角度控制条：

- **开启 / 停止**：控制实时桌面效果；首次开启仍需屏幕录制授权。
- **角度滑块（10°–160°）**：持续拖动实时更新，松手后保持角度。与面板滑块双向同步，未开启采集时也能控制示意预览。
- **归位**：回到已校准的基准角度，不改动基准设置。

传感器模式下 Touch Bar 显示实际角度，滑块与归位按钮不可操作，防止覆盖真实输入；切换到手动模式后即可拖动。手动实时桌面预览仍保留 60 秒自动结束与紧急退出快捷键。

角度控件使用 NSTouchBar / NSSliderTouchBarItem；另通过私有 Control Strip 接口注册常驻电脑图标入口。启动、打开面板与唤醒时仅注册入口，不主动接管 Touch Bar。点击电脑图标，或面板、菜单栏的「展开 Touch Bar 控制」才展开。窗口最小化、关闭或切换到其他应用后，点击此入口可直接展开独立的角度控制条，无需恢复主窗口。角度控制条最多展开 60 秒；点「收起」、面板的「恢复系统 Touch Bar」或按 ⌃⌥⌘F 都会停止桌面效果并收回控制条；退出应用时注销入口。唤醒和用户会话恢复时重新注册，不自动展开控制条。

此入口通过运行时检测并加载 DFRFoundation 和系统 Touch Bar 方法，不修改系统文件，也不要求额外输入监控权限。由于是非公开接口，macOS 更新可能使其失效；失效时保留菜单栏与应用面板入口。系统隐藏 Control Strip、显示功能键、锁屏等情况可能遮住按钮，无法保证在这些系统模式下始终可见。系统设置中需允许显示 Control Strip。没有 Touch Bar 的设备继续使用面板或传感器。

常驻实现参考了 [touchtest](https://github.com/mrmekon/touchtest) 和 [EnergyBar 的接口声明](https://github.com/billziss-gh/EnergyBar/blob/master/src/System/NSTouchBar%2BSystemModal.m)，独立实现运行时桥接。项目经 GitHub 站外发行，不适用于 App Store 的公开 API 限制；实际 Developer ID 公证仍以 CI 结果为准。

## GitHub 正式发行与权限保持

完整配置见 [docs/RELEASING.md](docs/RELEASING.md)。正式发行使用固定 Bundle ID、Developer ID Application 签名及公证；通过 GitHub 分发，不上架 App Store。开发构建可以配置 `.local-signing-identity` 使用固定证书。未配置证书的临时签名构建仍可能在重新编译后要求重新授权。

Mac14,7 的 Touch Bar 模式不再访问 HID。其他机型只匹配角度用途后再打开设备，避免枚举并打开键盘导致 Input Monitoring 错误。屏幕录制只在明确点击开启时尝试，不自动重试；由 ScreenCaptureKit 返回真实授权结果，不使用预检或历史标记阻止重试。

## 屏幕铰链效果

完整桌面保持原有高度，沿开合方向连续弯曲。减小角度时上部向内收窄并逐渐失焦，底部保持清晰；增大角度超过基准后反向弯曲。角度停下后保持姿态。基准角度处隐藏覆盖层，恢复正常桌面操作。

曲面使用逐像素连续映射，上下边界固定，最大横向收窄为 24%，避免整张桌面缩成悬浮卡片。清晰、轻模糊和重模糊纹理在同一曲面坐标上混合，底部到远端平滑失焦，两侧过渡到深色背景。GPU 渲染在后台执行，同时最多处理一帧，后续输入只保留最新画面与角度；回到基准立即显示原图。

## Logo 资源

Logo 使用上下折叠的屏幕与透视底座、纯深色轮廓。`assets/MacDuo.svg` 为透明矢量版本，`assets/MacDuo.png` 为 1024 px 应用图标预览，`assets/MacDuo.icns` 用于 macOS 应用打包。菜单栏与 Touch Bar 使用同一几何造型的系统自适应单色版本。

修改 `Sources/MacDuo/BrandIcon.swift` 后运行 `./scripts/generate-icon.sh` 更新资源，再运行 `./scripts/build-app.sh` 打包。生成过程只依赖系统 AppKit、Swift 和 Python 3。
