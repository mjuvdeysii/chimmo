# 《咩哞 · Chimmo》开发方法论与 Apple Design Awards 持续打磨宪法

> 文档状态：由真实实机反馈、用户纠偏与连续 40+ 轮高强度打磨蒸馏固化（零 Emoji · 全局可执行门禁）。  
> 适用范围：iOS 主应用（SwiftUI / AVAudioEngine）、OpenMotion 互动官网（`docs/index.html`）与导演动画短片、IP 资产管线及 TestFlight 持续交付链路。

---

## 一、六大核心方法论支柱（User-Calibrated Engineering Canons）

### 1. 三域严格空间分离（欣赏 · 创作 · 商业设置）
- **实机痛点根源**：当演示曲欣赏、自由编曲、重命名与设置混杂在同一个屏幕时，用户既容易误改经典曲目，又找不到“怎么试听自己写的歌”与“怎么保存到曲库”。
- **铁律架构**：
  1. **「欣赏」引导域（`StudioSpace.showcase` · `OrbitalStageView`）**：非破坏性聆听与交互探索。点按琴键仅为即兴伴奏或「跟灯弹」对照；主舞台设置 `allowsEditing: false` 防止误拖走音珠；通过显式 **「去改编」**（`forkCurrentShowcaseIntoCreate()`）才将曲目深拷贝至创作域。
  2. **「创作」自由域（`StudioSpace.create` · `CreateStudioView`）**：独立 `WorkspaceSnapshot` 与 `hasUnsavedCreationChanges` 脏状态追踪，在三标签间切换绝不互相覆盖；顶栏直连 **「作品」** 抽屉，画布下方常驻直接和声试改与单拍微调，底部固定不可错过的 **「试听 / 停止」** 与 **「保存作品 / 已保存」** 双主力触控按键，并在新建/清空时对未保存草稿弹出 `.confirmationDialog` 保护。
  3. **「设置」商业工具域（`ChimmoTab.settings` · `SettingsView`）**：严格遵循 Apple HIG `NavigationStack` + `List(.insetGrouped)` 商用软件标准；结构化二级页面承载 `ChimmoLegalDocumentView`（隐私政策、使用条款、开源许可与曲目鸣谢，文案内外一致对齐 `docs/*.html`）与按需进入的 `CharacterSoundTestView`，严禁在系统设置页堆砌玩具化实验装饰。

### 2. 两极交互视觉契约（Button vs. Label Affordance Contract）
- **实机痛点根源**：只读标签套用胶囊（`Capsule()`）与粗边框会让用户误点击；反过来，标题纯文字绑定弹窗会让用户“点一下左上角天鹅标题却跳出改名框”产生强烈挫败感；透明未选态按钮若漏掉 `.contentShape(...)` 或热区低于 `40–44pt`，手势会穿透至底层 `Canvas DragGesture`。
- **铁律语法**：
  1. **可交互控件**：唯一允许同时拥有暖墨实线描边 + 无模糊硬偏移阴影 + `StorybookTactileButtonStyle` 按下物理下沉效果的视觉物种（`ChimmoKilnPillButtonSurface`）；所有交互热区强制 `>= 40–44pt` 并显式声明 `.contentShape(...)`；标签文案必须是明确动词或标准视觉提示（如曲目切换用 `chevron.down`、分段跳转用 `play.fill`、次级操作收归 `...` `Menu`）。
  2. **隐蔽入口清零**：左上角曲目名在欣赏区必须是清晰显式的 **「切换曲目」选择器（`music_picker`）**，严禁绑定改名弹窗；作品改名仅归属创作域 `Menu` 与作品卡菜单。
  3. **静态展示容器（`quietContainer`）**：曲目卡片、舞台相框、功能托盘统一使用 `StorybookQuietCardSurface`（`1–1.2pt` 柔和细边、**零偏移阴影**），杜绝整卡冒充可点按钮的误导。
  4. **只读信息标签（`readOnlyLabel`）**：计数、保存状态、调式角标、章节进度统一使用无描边、无阴影、非胶囊圆角矩形（`RoundedRectangle(cornerRadius: 6)` 如 `StorybookQuietTag`、`ChimmoEditorialPill`）或纯排版次要文字，**严禁对只读标签使用 `Capsule()`**。

### 3. 极简降噪扁平卡通绘本美学（Minimalist Flat-Cartoon Kids' Book Design）
- **全局视觉红线**：
  - **零渐变**：禁止 `LinearGradient`、`RadialGradient`、`AngularGradient`（包括 Web/SVG/Canvas/SwiftUI 视图）；
  - **零模糊阴影**：禁止任何 `.shadow(...)`，立体层次仅由双层实色几何硬偏移构成；
  - **零拟物与双层套框**：零木纹、零金属高光、零黑胶 22 道刻槽与机械唱臂（全面升级为默认全宽「绘本山坡」舞台与极简「童书音乐盒花环」+ 12 点钟书签星指针、`StorybookSongbookCoverThumb` 开卷绘本封面、非黑胶 TabBar 图标）、零 `ChimmoBrassFrameAccent` 双层套框调用、零四角圆钉 `showCornerPins`；
  - **单屏聚焦与半屏可用**：精简 `AmbientPaperBackdrop` 仅保留纯净底纸与克制底部山坡；单屏只有 1 个视觉主角；所有 `.medium` 半屏抽屉首屏即达核心操作，不强迫用户二次上拉。

### 4. 深度克制的 IP 有机融合（Non-Intrusive Living IP）
- 小羊 **咩（`Mie`）** 司职主旋律，小牛 **哞（`Mou`）** 司职低音与四幕和弦织体，`1–7` 七声小偶（`Taono / Doko / Plokko / Udo / Corllo / Bomo / Tinki`）将首调音级力学转化为身体姿态、耳翼微笑/垂耳、微斜倾角与共鸣光环。
- **IP 表现底线**：全员 **零对话气泡、零字幕、零遮挡谱面浮窗**；`AppIcon`（Light / Dark / Tinted）严格遵循 `1-3-5` 主三和弦三人组居中放大构图与单一无描边草坡，保证系统 `29pt` 小尺寸下轮廓一眼可辨。

### 5. Apple Design Awards 工艺、无障碍与零状态陷阱
- **首次触达 30 秒惊艳**：音频引擎启动 `180ms` 后静默预热，点按零冷启动延迟；音色包全离线且自成声场空间配置，配合真实半音几何间距（`3-4` 与 `7-1↑` 窄缝可见）与 `Core Haptics` 双编码。
- **双维度全覆盖**：完整 `VoiceOver` 语义标签/值/提示/转子动作与系统「减弱动态效果（`accessibilityReduceMotion`）」静态优雅降级；全端 **零例行 `statusToast`**（仅保留异常/权限定位报错）与 **全局零 Emoji**。
- **零状态陷阱**：模式切换（如在创作域退出跟灯练习 `followGlowActive`、空曲禁点无效引导、改音高/换和弦/移调/撤销后同步更新 `hasUnsavedCreationChanges`）必须前后闭环，不得把用户困在异常模态下。

### 6. 流水线化零模拟器 CI 节奏与窗口交接纪律
- **本机构建红线**：严禁启动、构建或调用 iOS Simulator；仅使用无模拟器编译门禁检验全工程与测试目标：
  `set -o pipefail && xcodegen generate && xcodebuild build-for-testing -project Chimmo.xcodeproj -scheme Chimmo -destination 'generic/platform=iOS' CODE_SIGN_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGNING_IDENTITY=""`
  要求输出 `** TEST BUILD SUCCEEDED **`、`0` error、`0` Swift/Xcode 编译警告。
- **流水线交付节奏**：
  1. 当 Round `N` 在 GitHub Actions 执行 TestFlight 上传期间，本地同步设计、实现并编译验证 Round `N+1`；
  2. 通过 `git credential fill` 静默核查 Actions 队列（严禁打印凭证）；仅当 `QUEUE_CLEAR_FOR_PUSH: True` 且前序提交绿灯通过时，再 `git push origin main` 触发下一包 TestFlight，绝不强推覆盖运行中队列；
  3. 端内大版本结构或视觉语言跃迁后，严格经由 `openmotion-design` / `openmotion-director` 技能同步官网（`docs/index.html`）与宣传短片并逐帧实测验收；
  4. 每次上下文接近饱满时主动触发干净交接，将精确提交 SHA、CI 运行号、OpenMotion 版本及待办同步写入 `alchemy_loop_log.md`。

---

## 二、每轮提交前十项自检清单（Pre-Commit Self-Audit）

1. **边界隔离**：欣赏域任意点按、翻页、即兴伴奏是否绝对不破坏名曲正典或创作域草稿？创作域的 `ChordPreset / Texture / Voice / RootMIDI / Undo` 改动是否正确同步 `hasUnsavedCreationChanges`？
2. **按钮与标签语义**：全页面是否存在未包 `.contentShape(...)` 或小于 `40pt` 的按钮？是否存在把可点击外观（边框+偏移阴影+胶囊）贴在只读标签上的假按钮，或左上角曲名误绑改名之类反直觉隐藏手势？
3. **商业页洁净度**：「设置」及全部法务子页是否严格保持原生 `NavigationStack` + `List(.insetGrouped)`？版本号、隐私边界、开源鸣谢是否与 `docs/*.html` 一致？
4. **扁平与降噪门槛**：UI / Theme / Postcard / Web 是否全部实现 `0` 渐变、`0` 模糊 `.shadow(...)`、`0` 双层套框调用、`0` 四角圆钉、`0` 黑胶图标或 22 槽黑胶暗纹？
5. **状态陷阱防护**：是否处理了创作区处于 `followGlowActive` 时继续点琴键的冲突？空曲谱时是否禁用了依赖已有音符的按钮？
6. **无障碍与减弱动态效果**：新增控件是否均有准确中文 `accessibilityLabel / Value / Hint`，且动画均读取 `@Environment(\.accessibilityReduceMotion)`？
7. **全局零 Emoji**：源码、单测、`docs/*.md`、`docs/*.html`、`project.yml`、`CHANGELOG.md` 新增行、提交信息均保持 `EMOJI_HITS == 0`。
8. **测试与向后兼容**：新增纯值引擎与状态流转是否已在 `ChimmoTests/SpecimenIntegrityTests.swift` 补齐确定性单元测试，并保持既有测试公开构造器签名向后兼容（新增参数设默认值）？
9. **无模拟器零警告编译**：是否先跑 `xcodegen generate` 再以 `set -o pipefail` 执行 `build-for-testing` 并实测 `0 error / 0 warning`？
10. **诚实汇报与流水线队列安全**：最终汇报是否严格区分已跑验证与 `not_run`（如真机手势实测、待云端完成之 XCTest/TestFlight），并确保未在队列 `queued / in_progress` 时盲目 `git push`？
