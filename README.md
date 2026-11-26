# 咩哞 · Mie & Mou (v2.2.0)

> **把大脑交还给安静的声波。**  
> 家族序列：`Moss（摸索）` · `Otto（台灯）` · `Mosto（魔头）` · **`Chimmo（咩哞 · 七声小偶）`**

**咩哞（Mie & Mou）** 是一款为 iPhone（iOS 27 原生 SwiftUI）打造的 **100% 本机离线窑陶脑波共振工坊**（简体中文显示名「**咩哞**」，英文显示名「**Mie & Mou**」，套装标识 `app.chimmo` 与七声小偶家族代号 `Chimmo` 保持不变）：**完全离线、无账号、无广告、不联网、不收集任何数据、非医疗器械。**

---

## 核心体感知觉与技术栈（v2.2.0）

- **实时离线双耳差频 + 无耳机等时共振**：[FeltPianoSynth.swift](Chimmo/Audio/FeltPianoSynth.swift) 音频渲染线程内无锁零堆分配 `BrainwaveBedState`，覆盖 `Delta 2.5 Hz`（深潜入眠）、`Theta 6.0 Hz`（漂浮放空）、`Alpha 10.0 Hz`（丝滑心流）与 `Gamma 40.0 Hz`（灵感通透）四大频段；结合 [HalfDuplexAudioRouter.swift](Chimmo/Audio/HalfDuplexAudioRouter.swift) 耳机连接检测在立体声双耳差频与外放温和等时脉动之间无缝切换，内置 `0.065 Hz` 立体声空间微漂移（严格锁定左右核心双耳载波不漂移）、xorshift64* 棕红暖雨 / 粉红微风声床及 10 组手工微差窑陶轻叩音效。
- **长按蓄力松手战栗（Acoustic Frisson）+ CoreHaptics**：长按活体共振球或蓄力键约 1.5 秒升温，松手瞬间绽放宽立体声纯五度/大三度/钢片琴和声瀑布，并由 [AcousticHapticsEngine.swift](Chimmo/Audio/AcousticHapticsEngine.swift) 同步输出 `playFrissonBuildTick` 与 `playFrissonCascade` 掌心释然长呼触觉脉冲。
- **3 秒轻哼同频锁频 + 拒麦无障碍兜底**：[HumCapturePipeline.swift](Chimmo/Audio/HumCapturePipeline.swift) 端侧离线提取人声自然基频后按纯八度折叠至舒适共鸣带（`120–260 Hz`）；即使拒绝麦克风权限，仍可一键套用 `136.1 Hz / 174.0 Hz / 216.0 Hz` 三档预设共振基频。
- **活体呼吸驻波球 + 锁屏 Now Playing + 纪念卡导出**：[ResonanceFieldView.swift](Chimmo/Views/ResonanceFieldView.swift) 提供 60fps 音频包络驱动的有机驻波流体光晕、可选 `4 秒吸气 / 6 秒呼气` 引导环（全面受 `accessibilityReduceMotion` 门控降频至 15Hz）及顶栏闭眼夜灯直达；[NowPlayingResonanceController.swift](Chimmo/Audio/NowPlayingResonanceController.swift) 接入 iOS 锁屏与控制中心（含 256×256 窑陶光环专辑封面）；[ResonanceCardExporter.swift](Chimmo/Domain/ResonanceCardExporter.swift) 支持纯离线导出 1080×1350 日/夜双态高清「脑波共振纪念卡」PNG。
- **100% 原创窑陶三标签乐器工作台**：[ResonanceRootView.swift](Chimmo/Views/ResonanceRootView.swift) 默认直达 [ResonanceFieldView.swift](Chimmo/Views/ResonanceFieldView.swift)（「声场」活体共振盆），配合 [AcousticLibraryView.swift](Chimmo/Views/AcousticLibraryView.swift)（「声库」四频段窑陶调音座、12 套离线声景配方、原生深靛夜灯盲操台、`FrissonCapsule` 8 首声波乐章与 28 首典藏曲本）和 [AtelierSettingsView.swift](Chimmo/Views/AtelierSettingsView.swift)（「工坊」1-3-5 窑陶品牌铭牌、纪念卡导出、咩哞与七声小偶试音台、三态外观画布与声学安全声明）。

---

## 咩哞守护家族与七小只

咩哞的双主角（云朵小羊「咩 · Mie」与可可小牛「哞 · Mou」）与**七只哑光窑陶声学小偶**对应调内 `1–7` 音级，在乐章模式与家族图鉴中以姿态、倾角、呼吸与微光回应真实声音：

| 音级 | 成员 | 窑陶原型 | 音乐角色 |
|---|---|---|---|
| **1 · 家 (Do)** | **陶诺 · Taono** *(1-3-5 核心)* | 赤陶倒钟共鸣铃 | 归家老大；旋律落到他身上，全员松气 |
| **2 · 迈步 (Re)** | **豆叩 · Doko** | 暖杏陶小木鱼 | 好奇前倾 5 度，走出家门的第一步 |
| **3 · 晴雨 (Mi)** | **拍咯 · Plokko** *(1-3-5 核心)* | 胭脂珊瑚平衡不倒翁 | 大调双耳轻扬、小调微垂的零术语情绪晴雨表 |
| **4 · 悬步 (Fa)** | **呜嘟 · Udo** | 影青瓷小陶笛 | 轻吸一口气的悬浮牵引，微向 3 号靠拢 |
| **5 · 远望 (Sol)** | **壳咯 · Corllo** *(1-3-5 核心)* | 宣瓷暖白螺旋号角贝 | 与 1 号撑起天空的五度支柱 |
| **6 · 怀旧 (La)** | **钵莫 · Bomo** | 焙赭陶小手碟 | 流行与影视副歌里温柔微酸的 6 级阴影 |
| **7 · 踮脚 (Ti)** | **叮尖 · Tinki** | 窑赭陶小陀螺尖芽 | 天生踮脚微斜 10 度急切望向 1 号，直觉看见张力与解决 |

完整 IP 正典见 [docs/IP.md](docs/IP.md)，立项总纲见 [docs/CHARTER.md](docs/CHARTER.md)，TestFlight 公测过审指南见 [docs/TESTFLIGHT_PUBLIC_BETA.md](docs/TESTFLIGHT_PUBLIC_BETA.md)。

---

## 非医疗定位与隐私合规（Guideline 1.4.1）

- **非医疗器械声明**：本应用严格界定为声学放松、专注氛围与感官艺术体验工具，不提供任何疾病预防、诊断、治疗或临床康复功能。
- **App Privacy & Required Reason API**：[PrivacyInfo.xcprivacy](Chimmo/Resources/PrivacyInfo.xcprivacy) 已声明 `NSPrivacyAccessedAPICategoryUserDefaults: CA92.1`；[Info.plist](Chimmo/Resources/Info.plist) 已声明 `ITSAppUsesNonExemptEncryption: false` 与按需停播的 `UIBackgroundModes: audio`；[InfoPlist.xcstrings](Chimmo/Resources/InfoPlist.xcstrings) 提供双语应用名称与麦克风说明。

---

## 开发、CI 与 TestFlight 自动化

- 目标平台：**iOS 27.0+**（Xcode 27 / SwiftUI / `AVAudioEngine` / `CoreHaptics` / `MediaPlayer` / `Accelerate`）
- 工程生成：`xcodegen generate`（配置见 [project.yml](project.yml)）
- CI 流水线：[`.github/workflows/ios.yml`](.github/workflows/ios.yml) 运行在 `xcode-27` Apple Silicon Runner，自动执行：
  1. 全量单元测试与 `ios_network.txt` 零联网探针核验；
  2. 推送至 `main` 后通过云端自动签名 Archive 上传 TestFlight，并自动同步双语 `What to Test` 与 `audit-beta-readiness` 状态输出；
  3. 通过 `workflow_dispatch (submit_public_beta=true)` 一键联动 [Tools/asc.py](Tools/asc.py) 同步双语公测资料、关联外部群组与提交 TestFlight 公测审核。

## 第三方开源致谢

- 音符动态规划切分算法参考并移植自 [lars76/swift-f0](https://github.com/lars76/swift-f0)（MIT License），预置 `ThirdParty/SwiftF0/model.onnx`（135 KB，MIT）。
