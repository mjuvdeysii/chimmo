# 咩哞 · Mie & Mou (v2.0.0) TestFlight 外部公测准备与过审手册

> 套装标识 (Bundle ID)：`app.chimmo`  
> 版本：v2.0.0（完全离线、零账号、零广告、零追踪、非医疗声学放松工具）

---

## 一、端内硬件与系统合规核验清单（V2.0 已全部落盘）

1. **Required Reason API (`ITMS-91053` 零阻断)**
   - [PrivacyInfo.xcprivacy](file:///Users/someone/Projects/chimmo/Chimmo/Resources/PrivacyInfo.xcprivacy) 已申报 `NSPrivacyAccessedAPICategoryUserDefaults` 并附合规原因码 `CA92.1`；
   - `NSPrivacyTracking = false`、`NSPrivacyTrackingDomains = []`、`NSPrivacyCollectedDataTypes = []`。
2. **加密出口合规 (`ITSAppUsesNonExemptEncryption`)**
   - [Info.plist](file:///Users/someone/Projects/chimmo/Chimmo/Resources/Info.plist) 已配置 `<key>ITSAppUsesNonExemptEncryption</key><false/>`，上传 TestFlight 无需反复人工点选加密问卷。
3. **后台音频声明与停播边界 (`UIBackgroundModes: audio`)**
   - [Info.plist](file:///Users/someone/Projects/chimmo/Chimmo/Resources/Info.plist) 已配置 `audio` 后台能力；
   - App 仅在用户主动播放脑波声床或乐章且打开「锁屏继续收听声场」时运行后台音频，暂停或开启关闭开关时进入后台立即停止，避免触发滥用后台音频退回。
4. **双语权限与本地化显示名称**
   - [InfoPlist.xcstrings](file:///Users/someone/Projects/chimmo/Chimmo/Resources/InfoPlist.xcstrings)：简体中文 `咩哞`、英文 `Mie & Mou`；
   - 明确声明 `NSMicrophoneUsageDescription` 仅用于本机实时捕捉轻哼基频、从不上传联网；即使审核员在弹出框点击 **不允许 (Don't Allow)**，也可直接通过三档预设人声基频（`136 Hz / 174 Hz / 216 Hz`）流畅体验无障碍降级路线。
5. **Apple Guideline 1.4.1（非医疗宣称红线）**
   - 全端文案、公测介绍及 [ProfileSanctuaryView.swift](file:///Users/someone/Projects/chimmo/Chimmo/Views/ProfileSanctuaryView.swift) 内置的 `ChimmoAcousticSafetyView`（「我的 -> 声学安全与非医疗声明」）严禁出现治疗失眠、临床康复、缓解疾病等医学词汇，统一界定为 **声学放松、专注氛围与感官艺术体验（非医疗器械）**。

---

## 二、App Store Connect 外部公测提审资料（可直接复制或由 CI 同步）

### 1. 公测测试简介 (`Beta App Description`)
- **简体中文 (`zh-Hans`)**：
  「咩哞（Mie & Mou）」是一款 100% 本机离线的脑波共振与声触放松应用（非医疗器械）。无需注册账号、不联网、零广告。提供 Delta / Theta / Alpha / Gamma 四大声波频段、立体声双耳差频（外放自动切换等时脉动）、长按蓄力松手即发触发颅内战栗和声瀑布，以及 3 秒轻哼同频包裹、闭眼夜灯触觉盲操与 8 首高张力声波乐章。适用于日常放松、阅读专注与睡前静心。
- **English (`en-US`)**：
  Mie & Mou (`app.chimmo`) is a 100% offline brainwave resonance and tactile sound relaxation studio (sensory art and relaxation only, not a medical device). No account, no internet connection, no ads. Features Delta, Theta, Alpha, and Gamma acoustic beds with stereo binaural beats (and automatic speaker isochronic pulse fallback), a hold-and-release acoustic frisson cascade, 3-second offline hum frequency matching (with mic-denied presets), a zero-glare Night Lamp tactile mode, and 8 curated musical relaxation capsules.

### 2. 测试重点 (`What to Test`)
- 优先测试四项核心体感知觉：
  1. 「今日」tab 的分时脑波旅程 Hero 卡与「最近 / 收藏」快捷抽屉；
  2. 「共振」tab 轻点共振球播停、左右滑频切换 Delta/Theta/Alpha/Gamma，以及长按 1.5 秒再松手触发颅内战栗和声瀑布 + 掌心 CoreHaptics；
  3. 「轻哼同频」麦克风捕捉与拒绝权限后的预设人声基频无缝回退；
  4. 佩戴耳机（立体声双耳差频）与拔出耳机（自动外放等时共振）无缝切换及锁屏后台收听。

### 3. 公测审核备注 (`Review Notes`) 与免登录声明
- `Sign-in required`：**取消勾选**（`demoAccountRequired = false`，无账号登录系统）。
- **Privacy Policy URL**：`https://mjuvdeysii.github.io/chimmo/privacy.html`
- **Support / Marketing URL**：`https://mjuvdeysii.github.io/chimmo/`
- **Review Notes 原文**：

```text
Thank you for reviewing Mie & Mou (咩哞, v2.0.0) for TestFlight External Beta.

1. Non-Medical Wellness & Sensory Art Positioning (Guideline 1.4.1):
   Mie & Mou is strictly an offline sound-art, focus ambiance, and acoustic relaxation tool. It is NOT a medical device and makes zero diagnostic, therapeutic, or clinical claims.

2. Zero Login & 100% Offline Verification:
   No sign-in, account, or network access is required. All audio DSP (AVAudioEngine), CoreHaptics, and on-device pitch detection (YIN/vDSP) run locally without outbound requests.

3. How to Test Key Features in External Beta:
   - Today Tab (今日): Tap the warm hero card or presets to launch an instant brainwave session.
   - Resonance Field Tab (共振): Tap the center orb to play/pause; drag horizontally across the orb to sweep between Delta (2.5 Hz), Theta (6 Hz), Alpha (10 Hz), and Gamma (40 Hz); press & hold the orb or "按住战栗" for ~1.5s and release to trigger the harmonic Frisson swell + CoreHaptics exhale.
   - Hum Frequency Matching (轻哼同频): Tap "轻哼同频", allow microphone access, hum softly for 2-3s, and tap stop to match your vocal pitch. If microphone permission is denied, 3 one-tap fallback presets (136 Hz / 174 Hz / 216 Hz) remain immediately usable.
   - Background Audio (UIBackgroundModes audio): Playback continues smoothly when locking the screen unless toggled off in Profile -> "锁屏继续收听声场". Only active soundscapes use background audio.
   - Explore & Profile Tabs (探索 / 我的): Includes 2x2 quick states, Night Lamp zero-glare mode, 8 curated relaxation music capsules, and Acoustic Safety / Privacy / Legal disclosures.
```

---

## 三、外部测试群组、公开链接与一键提交审核流程

1. **补充 App Store Connect 联系资料（首次提交外部公测必填）**
   - 到 App Store Connect -> 我的 App -> `咩哞` -> **TestFlight -> 一般信息 -> 测试信息**，确认已填写 **反馈电子邮件 (Feedback Email)** 与 **测试员审核联系信息（名 / 姓 / 邮箱 / 电话）**；
   - （可选）在 GitHub 仓库 `Settings -> Secrets -> Actions` 配置 `BETA_FEEDBACK_EMAIL`、`BETA_CONTACT_FIRST`、`BETA_CONTACT_LAST`、`BETA_CONTACT_EMAIL`、`BETA_CONTACT_PHONE`，即可全自动同步。
2. **通过 GitHub Actions 一键创建外测群组并提交公测审核**
   - 运行 [ios.yml](file:///Users/someone/Projects/chimmo/.github/workflows/ios.yml) 的 **Run workflow (`workflow_dispatch`)**，勾选：
     - `submit_public_beta = true`
     - `public_beta_group = Public Beta`
     - `enable_public_link = true`
   - 脚本 [Tools/asc.py](file:///Users/someone/Projects/chimmo/Tools/asc.py) 将自动等待 Build 状态变为 `VALID`，同步双语 Beta 资料与审核备注、把 Build 加入外部群组并提交 `betaAppReviewSubmissions` 公测审核。审核通过（通常 24–48 小时）后即可启用 Public Link 邀请最多 10,000 名外部测试员。
