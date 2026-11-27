# 咩哞 · Mie & Mou (`app.chimmo`)

纯本地离线、零追踪的 iOS 原生声学共振与室内乐工坊（100% Native Swift / SwiftUI / AVFAudio / Accelerate vDSP / Core Haptics）。

## 核心体验与三页架构

- **声场（Resonance Field）**：
  - 打开即达高对比窑陶驻波频段盘（`Delta 1.5–4 Hz` / `Theta 4–8 Hz` / `Alpha 8–14 Hz` / `Gamma 38–42 Hz`）。
  - **真立体声双耳分离 + 外放等时切换**：佩戴立体声耳机呈现纯左右声道差频共振（与早期空间反射干湿隔离）；手机外放自动切换为平滑全频段等时包络脉动（最高支持 42 Hz）。
  - **轻哼找同频（YIN-vDSP）**：严格半双工录音切换，全内存纯 Swift / Accelerate 计算基频并折叠调谐至个人共振载波，不落盘、不联网。
  - **长按蓄力释怀与睡眠渐弱定时**：多声部大提琴/毛毡钢琴和声绽放搭配掌心 Core Haptics 共振；睡眠定时支持最后 15 秒平滑壁钟音量渐弱与会话自动释放。
  - **纯黑 OLED 琥珀夜灯（Night Lamp）**：微弱琥珀色手势盲调表盘与睡眠定时快捷控制。
- **声库（Sound Library）**：
  - 实时昼夜时段动态推荐（晨间 / 午后 / 傍晚 / 深夜），内置 **12 组时间声景配方**、**8 枚和声战栗胶囊** 以及可检索的 **28 首古典公版与原创室乐全集**。
- **工坊（Kiln Atelier）**：
  - 仅存本机的聆听专注统计、昼夜外观切换、掌心触觉总开关、七小只音高声色图鉴、**1080×1350 静态 PNG 共振明信片离线生成导出**，以及透明的非医疗艺术边界与隐私/条款文档。

## 工程构建（无需模拟器）

本仓库通过 XcodeGen 从 `project.yml` 动态生成工程文件（`Chimmo.xcodeproj/` 不纳入 Git 版本管理）：

```bash
xcodegen generate && xcodebuild \
  -project Chimmo.xcodeproj \
  -scheme Chimmo \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGNING_IDENTITY="" \
  build-for-testing
```

## 文档索引

- [App Store 发布与合规核对](docs/APP_STORE_1.0.md)
- [TestFlight 外测与公测指南](docs/TESTFLIGHT_PUBLIC_BETA.md)
- [声学工程与零依赖方法论](docs/METHODOLOGY.md)
- [视觉与窑陶 IP 宪章](docs/CHARTER.md)
- [角色与图标资产规范](docs/IP.md)
- 官网支持与合规页：[官网主页](docs/index.html) · [隐私声明](docs/privacy.html) · [使用条款](docs/terms.html) · [公版致谢](docs/licenses.html)

## 合规与隐私底线

- **100% 离线零追踪**：零第三方 SDK、零广告、零分析统计；`PrivacyInfo.xcprivacy` 仅申报两项必要 API（`CA92.1` 用户偏好、`35F9.1` 音频单调计时）。
- **严格非医疗边界（Apple Guideline 1.4.1）**：本应用属于声音艺术与日常放松工具，非医疗器械，不作任何临床疗效宣称，并在端内及网页端明确提示 40 Hz 脉冲人群注意事项。
