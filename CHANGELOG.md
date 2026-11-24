# Changelog

## 0.69.0 - 2026-11-25
- 闭眼夜灯动态字体、周边音脊可读性与圆角命中区收口：在 [NightLampTactileSheet.swift](Chimmo/Views/NightLampTactileSheet.swift) 中将夜灯画布数字音高标签全面升级为 `.footnote` / `.caption2` 语义 Dynamic Type（配 `.minimumScaleFactor(0.75)`），并将未悬停周边音脊数字/图腾的可见不透明度从多重衰减提升至清晰护眼的 `0.90`（保持引导横条 `0.24` 柔和低刺激），同时将 `tactilePad` 命中边界精确对齐至 `RoundedRectangle(cornerRadius: 28, style: .continuous)`。
- OpenMotion Design Studio 互动官网升至 `v13` 并精确同步 [docs/index.html](docs/index.html)：全面同步 R59–R62 成果——引入日夜双态 8 音阶窑墨高对比 CSS 变量（`--xylo-1..7` 与 `--xylo-ink`）重构五音彩块琴键与七小只数字徽章可读性，在「创作」页签新增「轻触三偶迎宾和弦」触发器，在「曲本」页签新增「空白书架 1-3-5 迎宾和弦」交互预览并更新至 `v0.69.0`（通过 `openmotion_design_project` 导出 `1,104,336 bytes` 整页 PNG 视觉核验、嵌入式脚本 `node --check` 零报错与全页零 Emoji）。
- 回归校验：新增 `@MainActor` 单测 `testCreativeAlchemyRound62NightLampDynamicTypeAndOpenMotionV13Sync`，保持全局零 Emoji 与无模拟器编译全绿。

## 0.68.0 - 2026-11-25
- 全 8 音阶彩键与舞台音珠窑墨 WCAG AA/AAA 对比度升级：在 [XylophoneRollEngine.swift](Chimmo/Domain/XylophoneRollEngine.swift) 新增单源 `barForegroundHex(isNight:)` / `barForegroundColor(isNight:)` 方法，并将日光 `6 La`（`0x5C84F0`）与 `7 Si`（`0x9973F0`）窑彩微调至全 8 键对比 `#1C1D19` 均达 `>= 4.65:1`（AA）、夜灯全 8 键对比 `#0E1430` 均达 `>= 7.17:1`（AAA）。
- 全舞台音珠图腾、彩键唱名与导图明信片同步落地窑墨前景色：全面更新 [OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift) 音乐盒花环、流光河谷、星环舞台与底部 `StageChoirKeyboardBar` 音阶图腾/数字/延音刻度前景，以及 [VinylPostcardExporter.swift](Chimmo/Domain/VinylPostcardExporter.swift) 三套导出渲染图腾，彻底解决亮橙/明黄/薄荷夜彩底面叠白字难以辨识的痛点。
- 捕梦工坊夜间录音按键对比度与页签热区修复：在 [DreamCaptureSheet.swift](Chimmo/Views/DreamCaptureSheet.swift) 中将 `isRec == true` 录制圆钮前景接入 `palette.contrastInkOnAccent`（修复夜灯 `0xF08A6C` 叠白字仅 `2.45:1` 问题至 `7.37:1`），同步更新 `SeedPitchFaderColumn` 推子图腾前景色并将顶部模式按钮命中区贴合 `RoundedRectangle(cornerRadius: 12)`。
- 回归校验：新增 `@MainActor` 单测 `testCreativeAlchemyRound61EightLaneKilnInkWCAGAndHumRecordingContrast`，保持全局零 Emoji 与无模拟器编译全绿。

## 0.67.0 - 2026-11-25
- 四幕彩色和声条 WCAG AA >= 4.5:1 窑彩升级与命中边界对齐：在 [TheoryLensEngine.swift](Chimmo/Domain/TheoryLensEngine.swift) 为 `DiatonicChord` 新增 `colorHex(isNight:)` 单源十六进制函数并将日光 I–vi 色值全面校准为 >= 4.5:1 可读窑彩（对纯白高亮前景与 `#FBF7F0` 棉纸均满足 AA），夜灯六色对 `#0E1430` 与 `#19213F` 亦保持 >= 5.88:1；同步更新 [OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift) `StageHarmonyRibbonView` 激活前景色至 `palette.contrastInkOnAccent` 并将小牛伴奏、和弦分幕与开启伴奏胶囊全面切至 `.contentShape(Capsule())`。
- 声调盒、步进键与筛选条精准触控边界纯化：清理 [SoundPaletteBoxSheet.swift](Chimmo/Views/SoundPaletteBoxSheet.swift) 示波窗（`RoundedRectangle(cornerRadius: 12)`）、双主角试听（`Circle()`）、七小只按钮（`RoundedRectangle(cornerRadius: 12)`）及重复覆盖胶囊的 `"试听"` 热区定义；同步将 [CreateStudioView.swift](Chimmo/Views/CreateStudioView.swift) 单拍步进按钮与 [MusicBoxShelfView.swift](Chimmo/Views/MusicBoxShelfView.swift) 分类/重置筛选胶囊贴合各自视觉圆角边界。
- 空白书架四重奏灵动迎宾和弦：将 [MusicBoxShelfView.swift](Chimmo/Views/MusicBoxShelfView.swift) 书架空态的陶诺、咩哞、噗咯与壳咯升级为无边框触控按钮，点按即以 `.celesta` 与 `.warmBass` 轻奏 `C` 大调 `1-3-5` 迎宾三和弦并触发 `reduceMotion` 门控合声动画，同时随内联停播与页面退出自动清理任务。
- 回归校验：新增 `@MainActor` 单测 `testCreativeAlchemyRound60HarmonyWCAGContrastAndHitShapePurity` 自动校验全部 6 级和弦昼夜 4 组对比度 `>= 4.5`，保持全局零 Emoji 与无模拟器编译全绿。

## 0.66.0 - 2026-11-25
- 创作空白舞台交互灵动升级与层叠解耦：[CreateStudioView.swift](Chimmo/Views/CreateStudioView.swift) 将空白画布底部的陶诺、咩哞与壳咯三重奏与“轻哼一段旋律 / 起音种子”从上下叠压解耦为单一有序纵列，并让主角三重奏成为可触碰的欢迎和弦按钮（点按触发 `auditionDuoGreeting()` 并激活三偶动态合声反馈，同时在 `.onDisappear` 严密回收异步计时任务，背景山坡保持穿透点击画布），严守零多余文案与零重边框降噪原则。
- 曲本上下文菜单、VoiceOver 自定义动作与精确命中边界对齐：[MusicBoxShelfView.swift](Chimmo/Views/MusicBoxShelfView.swift) 为自创作品长按菜单与 VoiceOver 补齐「在聆听区播放 / 打开编辑 / 分享导出 / 重命名 / 复制副本 / 删除作品」全套动作，将管理圆按钮修正为 `34x34` 正圆配合柔和接触投影及 `40x40` `Circle()` 命中区；同时为典藏曲目卡补全长按菜单与条件化 VoiceOver 操作（仅在可改编时暴露「改编创作」），并将全部胶囊与圆形按钮的 `.contentShape(Rectangle())` 替换为精确匹配的 `Capsule()` / `Circle()`。
- 回归校验：新增 `testCreativeAlchemyRound59LivingEmptyStageAndSongbookActionParity`，保持全局零 Emoji 与无模拟器编译全绿。

## 0.65.0 - 2026-11-25
- 窑纸软胶接触投影与对比前景色全站单一数据源收口：
  - 在 [ChimmoTheme.swift](Chimmo/Theme/ChimmoTheme.swift) 新增 `elevationShadowColor(isNight:dayOpacity:nightOpacity:)` / `elevationShadow(...)` 柔和投影单源公式、`contrastInkOnAccent`、`contrastInkOnHighlight`、`warmButterHighlight` 与 `figureContourInk` 语义 Token。
  - 清零 [AboutSheetView.swift](Chimmo/Views/AboutSheetView.swift)、[CreateStudioView.swift](Chimmo/Views/CreateStudioView.swift)、[DreamCaptureSheet.swift](Chimmo/Views/DreamCaptureSheet.swift)、[MusicBoxShelfView.swift](Chimmo/Views/MusicBoxShelfView.swift)、[OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift)、[SoundPaletteBoxSheet.swift](Chimmo/Views/SoundPaletteBoxSheet.swift)、[ChimmoDesignLanguage.swift](Chimmo/Theme/ChimmoDesignLanguage.swift) 与 [VinylPostcardExporter.swift](Chimmo/Domain/VinylPostcardExporter.swift) 中 35+ 处散落 `0x7A5230`、`0x0E1430`、`0x19213F`、`0xF2E2C4` 与 `0xFFB547` 原始十六进制硬编码（其中捕梦工坊「闭眼滑音」夜空入口卡改用 `ChimmoPalette(isNight: true)` 语义驱动，曲本卡片角色渐变光晕改用 `hero.bodyColor`）。
- 声音调色盒触摸热区胶囊纯化：优化 [SoundPaletteBoxSheet.swift](Chimmo/Views/SoundPaletteBoxSheet.swift) 节拍律动、移调与双主角试听按钮 `.contentShape(Capsule())` 贴合边界与 `40pt` 可触尺寸一致性。
- 回归校验：新增 `testCreativeAlchemyRound58SemanticElevationAndContrastClosure`，保持全局零 Emoji 与无模拟器编译全绿。

## 0.64.0 - 2026-11-25
- 全链路 OpenMotion 官网 v12 与 12 秒导演短片 v18 同源跃迁：
  - OpenMotion Design Studio 互动官网升至 `v12` 并同步至 [docs/index.html](docs/index.html)：全站同步 R50–R56 窑纸软胶规范，清除曲本封面偏置硬砖影与粗黑 UI 外框，明暗双态同步日光/夜灯对位月蓝（`#2E7DB2` / `#7EC8E3`）；声调盒示波窗升级为 `40pt+` 可点击试听按钮，声波山坡表联动 `1-7` 音高实时聚光；四标签纯血空间展示盒支持「聆听去创作改编」、「创作 40pt 铅笔原地改名 + 1-5 液态竖琴归档印音」、「曲本对称聆听/编辑分流」与「工坊 8 音脊闭眼夜灯直触声场（`1 Do` ~ `1↑ Do↑`）+ 3 颗琥珀余韵指示灯」。
  - OpenMotion Director 12 秒动画短片升至 `v18`：第一幕接入直触示波脉冲环与 `#2E7DB2` 唤醒光晕；第二幕融入夜灯直触音阶徽标、3 颗延迟点亮的琥珀余韵珠与 `#7EC8E3` 壳咯夜光聚焦；第三幕优化 `v0.64` 闭环徽标垂直留白并联动 `1-5` 液态竖琴和弦波纹与七彩音点接力跃动（`lint-project.mjs` 零报错零警告，MP4 技术核验 14/14 通过，`ffmpeg volumedetect` `mean_volume -17.0 dB` / `max_volume -2.6 dB`，全 6 抽帧视觉复检无遮挡）。
- 回归校验：新增 `testCreativeAlchemyRound57FullEcosystemDocsAndOpenMotionV12Sync`，完成全仓零 Emoji、`docs/index.html` 嵌入式脚本 `node --check` 零报错与无模拟器 `xcodebuild build-for-testing` 零错误零警告。

## 0.63.0 - 2026-11-25
- 语义色板单一数据源与日光银月对比度修复：在 [ChimmoTheme.swift](Chimmo/Theme/ChimmoTheme.swift) 新增 `counterpointMoon`（日光强化至 `#2E7DB2` 以达到 >= 4.6:1 可读对比、夜灯保持 `#7EC8E3`）及 `nightLampBackdrop` / `nightLampPadSurface` / `nightLampHillSurface` 三层夜灯 OLED 语义色，全面替换 [OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift)、[SoundPaletteBoxSheet.swift](Chimmo/Views/SoundPaletteBoxSheet.swift) 与 [VinylPostcardExporter.swift](Chimmo/Domain/VinylPostcardExporter.swift) 中 9 处散落 `0x4EA8DE` / `0x7EC8E3` 硬编码。
- 工坊与闭眼夜灯零原始十六进制净澈收官：[SettingsView.swift](Chimmo/Views/SettingsView.swift) 全部外观预览小窗与品牌印记徽章改用 `ChimmoPalette` 双态实例化，[NightLampTactileSheet.swift](Chimmo/Views/NightLampTactileSheet.swift) 与 [SettingsView.swift](Chimmo/Views/SettingsView.swift) 达成全文件 `Color(hex:` 零残余。
- 回归校验：新增 `testCreativeAlchemyRound56SemanticTokenClosureAndZeroRawHexSettingsNightLamp`，保持全局零 Emoji 与无模拟器编译全绿。

## 0.62.0 - 2026-11-25
- 商业级离线偏好持久化闭环：[StudioView.swift](Chimmo/Views/StudioView.swift) `StudioViewModel` 新增可注入 `UserDefaults` 离线存储（`StudioView` 正式启用 `.standard`，测试默认传 `nil` 隔离），跨启动持久记住用户所选「外观显示（自动 / 日光 / 夜灯）」、「舞台默认视图（山坡 / 花环 / 星环）」与「节拍触感反馈」开关状态。
- 工坊细节与主舞台语义底面对齐：在 [ChimmoTheme.swift](Chimmo/Theme/ChimmoTheme.swift) 新增 `stageBoardSurface` 语义底面色并接入 [OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift)（清零 `0x101733` 硬编码）；[SettingsView.swift](Chimmo/Views/SettingsView.swift) 将五音/震动开关改经 `togglePentatonicSafe()` / `toggleMusicHaptics()` 统一输出触觉反馈，导出行动态显示当前作品名称并在空画布态柔和禁用，同时等高对齐「仅本机离线 / 开源与曲目鸣谢」双列卡片。
- 回归校验：新增 `testCreativeAlchemyRound55UserPreferencesPersistenceAndSettingsPolish`，保持全局零 Emoji 与无模拟器编译全绿。

## 0.61.0 - 2026-11-25
- 闭眼夜灯触觉工坊软胶纯化与 `40pt` 热区闭环：在 [NightLampTactileSheet.swift](Chimmo/Views/NightLampTactileSheet.swift) 中彻底废除关闭、撤销、播停、五/八音与「写入」按钮下方的 5 处生硬 `0x03050F` 偏移黑色砖块底影及过重粗框，统一升级为 `nightPalette = ChimmoPalette(isNight: true)` 柔和接触投影与细腻细框（保留 `#070B1A` Zero-Vision OLED 夜幕底色）；将已录夜灯音珠芯片热区扩展至 `>= 40pt`（显式 `.contentShape(Capsule())`）便于盲操点按回听。
- 指尖即显音级唱名与延音微珠：在 [OrbitalStageEngine.swift](Chimmo/Domain/OrbitalStageEngine.swift) `NightLampPhraseHelper` 新增 `statusPillTitle(hoverLaneIndex:pentatonicSafe:)`，单指在夜灯音脊滑动时顶部状态胶囊轻柔显示当下音级唱名与 3 段延音微珠指示（松手即回归模式标签），并使写入空态文案与无障碍标签更清晰；同步将 [SoundPaletteBoxSheet.swift](Chimmo/Views/SoundPaletteBoxSheet.swift) 五音拨杆开关色同步为 `palette.celadonAccent`。
- 回归校验：新增 `testCreativeAlchemyRound54NightLampSoftVinylAndPitchBeacon`，保持全局零 Emoji 与无模拟器编译全绿。

## 0.60.0 - 2026-11-25
- 里程碑 60 · 轻哼电台音高聚光灯合唱反馈：在 `StorybookChoirMeterKinematics` 新增纯函数 `pitchFocusedBuddyIndex(normalizedPitch:isRecording:buddyCount:)`，将实时哼唱归一化音高直接映射至 `1-7` 领唱小偶，实时亮起主音色主题柔光圈、底座高亮胶囊与轻跃表情反馈（绝不新增解释文字，并 100% 受 `reduceMotion` 门控；同步为 [DreamCaptureSheet.swift](Chimmo/Views/DreamCaptureSheet.swift) 录音麦环呼吸缩放补齐 `reduceMotion` 防眩晕门控）。
- 内嵌微舞台语义色阶收口：在 [ChimmoTheme.swift](Chimmo/Theme/ChimmoTheme.swift) 新增 `insetStageSurface` 语义色（日光 `#F7EFE2` / 夜灯 `#131B38`），彻底消除 [DreamCaptureSheet.swift](Chimmo/Views/DreamCaptureSheet.swift) 与 [SoundPaletteBoxSheet.swift](Chimmo/Views/SoundPaletteBoxSheet.swift) 中 5 处 `0x10193C` / `0xFFF7E2` 硬编码十六进制色值，使轻哼音准区、节奏条、调音音域柱与示波底窗在日夜模式下完全呼吸一体。
- 回归校验：新增 `testCreativeAlchemyRound53PitchChoirSpotlightAndInsetSurfaceToken`，保持全局零 Emoji 与无模拟器编译全绿。

## 0.59.0 - 2026-11-25
- 全站硬描边零残余收口：彻底清理 [OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift)、[DreamCaptureSheet.swift](Chimmo/Views/DreamCaptureSheet.swift)、[SoundPaletteBoxSheet.swift](Chimmo/Views/SoundPaletteBoxSheet.swift) 与 [ChimmoDesignLanguage.swift](Chimmo/Theme/ChimmoDesignLanguage.swift) 全部剩余 `cartoonOutline` 调用（全站 `Views/`、`Domain/` 与设计语言绘制层 `cartoonOutline` 与 `cartoonShadow` 双双归零），将音珠外缘、星核印章、山坡线、手绘笔刷拖尾与小偶发丝边全面柔化为奥托夜色/窑纸正典 `primaryInk` 半透明细线（彻底消除夜间模式亮黄生硬框线）。
- 声场波形窗一键试听：[SoundPaletteBoxSheet.swift](Chimmo/Views/SoundPaletteBoxSheet.swift) 顶部 `SoundBoxOscilloscopeWindow` 升级为 `>= 40pt` 可触试听控件，轻点实时波形即可直接触发 `auditionDuoGreeting()` 合奏耳返与波纹扫描动效。
- 回归校验：新增 `testCreativeAlchemyRound52ZeroCartoonOutlineAndInteractiveOscilloscope`，保持全局零 Emoji 与无模拟器编译全绿。

## 0.58.0 - 2026-11-25
- 全仓明信片与绘本封面窑纸纯化：彻底清除 [VinylPostcardExporter.swift](Chimmo/Domain/VinylPostcardExporter.swift) 中最后 3 处 `0x18234E` 残色、5 处硬砖 `cartoonShadow` 及粗黑 `cartoonOutline` 外框（全部 Domain + Views 文件实现 `cartoonShadow = 0` 与旧夜色六进制零残留），离线导出 PNG 统一接入日/夜双态窑陶软胶质感；同步柔化 [MusicBoxShelfView.swift](Chimmo/Views/MusicBoxShelfView.swift) 书页与空态边框。
- 创作命名、存盘回声与曲本双动线闭环：[CreateStudioView.swift](Chimmo/Views/CreateStudioView.swift) 创作顶栏升级为显式 `pencil.line` 点按重命名按钮（同时严格保留聆听区不可误改边界）；`saveCurrentToNotebook()` 在非播停状态下轻奏温润 `1-5` 窑印和声封缄回音（零例行弹窗）；[MusicBoxShelfView.swift](Chimmo/Views/MusicBoxShelfView.swift)、[OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift) 与 [StudioView.swift](Chimmo/Views/StudioView.swift) 联合为「我的曲本」补齐「聆听」（保护创作快照切入剧场欣赏）与「编辑」对称双动线。
- 回归校验：新增 `testCreativeAlchemyRound51PostcardZeroShadowAndCreationSongbookLoop` 校验日/夜三态明信片离线导出、创作快照跨区隔离与双回调实例化，保持全局零 Emoji 与无模拟器编译全绿。

## 0.57.0 - 2026-11-25
- 里程碑 50 主舞台与全视图纯化：彻底清零 `Chimmo/Views/` 全部 12 份视图中的 `cartoonShadow`（消除音乐盒花环旧投影砖块、`0x18234E` 残色及 `2.4pt` 粗黑描边），并将主舞台错误横幅升级为 `Capsule` + 高对比 `prominentFill` 白字胶囊。
- 遗留夜灯六进制全面消杀：将 [DreamCaptureSheet.swift](Chimmo/Views/DreamCaptureSheet.swift)、[NightLampTactileSheet.swift](Chimmo/Views/NightLampTactileSheet.swift)、[MusicBoxShelfView.swift](Chimmo/Views/MusicBoxShelfView.swift)、[SoundPaletteBoxSheet.swift](Chimmo/Views/SoundPaletteBoxSheet.swift)、[OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift) 与 [ChimmoFigureView.swift](Chimmo/Views/ChimmoFigureView.swift) 剩余旧暗色/暖金 hex 全面同步至 `ChimmoPalette` 正典体系，柔化轻哼示波与筛选空态细框，并更新 [StudioView.swift](Chimmo/Views/StudioView.swift) 四标签架构注释。
- 回归校验：新增 `testCreativeAlchemyRound50ZeroCartoonShadowAndFullOttoNightCohesion` 校验三态画布视窗与全弹窗双态协同，保持全局零 Emoji 与零模拟器编译全绿。

## 0.56.0 - 2026-11-24
- 全生态《摸索台灯》同宇宙统一：通过 OpenMotion Design Studio 升级官网交互绘本（`v11`，同步至 `docs/index.html`）及三大法务页面（`docs/privacy.html`、`docs/terms.html`、`docs/licenses.html`）至「轻哼成曲，七声和鸣」四标签（聆听 / 创作 / 曲本 / 工坊）窑纸软胶语系；通过 OpenMotion Director 升级 12 秒声学短片至 `v16` 并完成音画技术与多帧检查。
- 闭眼夜灯同源对齐：[NightLampTactileSheet.swift](Chimmo/Views/NightLampTactileSheet.swift) 保留 `#070B1A` OLED 暗幕以呵护夜间盲操体验，将夜灯强调色、卡片底色与月白字色全面同步至 `ChimmoPalette(isNight: true)`（`0xFFB547` / `0x19213F` / `0xF2E2C4`）。
- 回归校验：新增 `testCreativeAlchemyRound49NightLampAndFullEcosystemSync` 并保持全局零 Emoji 与零模拟器编译门禁全绿。

## 0.55.0 - 2026-11-24
- 视觉同源收口：将调音百宝箱 SoundPaletteBoxSheet、灵光捕手 DreamCaptureSheet（轻哼电台 / 节奏画线 / 折纸工坊）、明信片导出卡片 VinylPostcardShareSheet、跟弹指示条与绘本主舞台伴奏色带全面接入 0.54.0「窑纸软胶工作室」设计语言，废除遗留厚卡通框与硬偏移砖块阴影。
- 触控与对比度收敛：为 SoundPaletteBoxSheet 移调与速度调节胶囊补齐 44pt 级交互安全热区；统一主动作采用高对比釉红 prominentFill + 白字，避免暗夜下黄底白字或浅底灰字混淆；曲库绘本空态按钮与迷你封面同步接入软胶层级。
- 回归校验：新增 `testCreativeAlchemyRound48ModalSheetsAtelierCohesion` 校验全量次级弹窗与跟弹视图昼夜状态构建，保持全局零 Emoji 与零本地模拟器直连校验。

## 0.54.0 - 2026-11-24
- Round 47 (Mossling Spin-Off Architecture & Soft-Vinyl Atelier Refactor — Theme: "Hum a spark. Hear seven voices answer."):
  - Harmonized `ChimmoTheme.swift` and `AmbientPaperBackdrop.swift` with sibling app Moss & Otto (`#FBF7F0` cotton paper / `#0E1430` night indigo / `#19213F` night cards / `#FFB547` lamp amber + Reduce Transparency per-space top washes), anchored by Chimmo's own Kiln Terracotta (`#C4513A` / `prominentFill #B8442E`) and Celadon (`#3D7A77` / `#7EC8C3`) signature accents.
  - Added Mossling-harmonized atelier design primitives in `ChimmoDesignLanguage.swift`: `ChimmoRadius`, `ChimmoResonanceBead`, `ChimmoSectionTitle`, `ChimmoFlowRow`, `ChimmoAtelierCardModifier`, and `ChimmoVinylButtonStyle`, while softening existing surfaces away from heavy dark cartoon borders.
  - Upgraded root navigation (`StudioView.swift`) to a 4-Tab narrative architecture (`聆听 · 创作 · 曲本 · 工坊`, promoting `MusicBoxShelfView` to `.songbook` Tab 2 with snapshot-safe `switchSpace` handoffs and app-wide `.fontDesign(.rounded)`).
  - De-noised `OrbitalStageView` (removed redundant harmony ribbon from Tab 0 to give the musical stage prominence; soft-vinyl dock & choir keys) and `CreateStudioView` (clean header without redundant drawer pill, 3-pill tool strip, prominent hum launchpad).
  - Upgraded `MusicBoxShelfView` filter ribbon to zero-horizontal-scroll `ChimmoFlowRow` wrapping and `.large` tab navigation bar.
  - Redesigned `SettingsView` (`工坊`) and `CharacterSoundTestView` to a calm editorial atelier layout with brand identity badges, philosophy banner, interactive visual Daylight/NightLamp/Auto swatch previews, grouped studio preferences, and transparent legal/offline cards.
  - Updated `docs/METHODOLOGY.md` to v2.0 and added `testCreativeAlchemyRound47MosslingSpinOffFourTabAtelierArchitecture` in `ChimmoTests/SpecimenIntegrityTests.swift`.

## 0.53.0 - 2026-11-24
- Round 46 (100% App-Wide Dynamic Type UI Completion & Final >= 40pt Button Hit-Target Closure):
  - Added `StorybookAffordanceMetrics.compactPillMinimumScaleFactor` (`0.75`) in `OrbitalStageEngine.swift`.
  - Upgraded 17 UI label and button glyph font sites in `OrbitalStageView.swift` and 15 UI label/button/card sites in `MusicBoxShelfView.swift` to semantic Dynamic Type styles (`.footnote`, `.caption`, `.caption2` with `.lineLimit(1)` and minimum scale factors), preserving only 5 intentional fixed-geometry instrument/cover micro-glyphs app-wide.
  - Expanded remaining `< 40pt` interactive hit targets in `OrbitalStageView` (`modeReliefPillSwitcher`, `activeFeaturesOverlay`), `MusicBoxShelfView` (`打开编辑`, `管理作品 ...`, `欣赏`, `跟灯`, `改编`, `套用风格`), `SoundPaletteBoxSheet` (appearance switcher, groove pills, character audition buttons), and `NightLampTactileSheet` (captured bead scroll strip `44pt`) to `>= 40pt` (`compactToolMinHitDimension`) with explicit `.contentShape(...)`.
  - Added `testCreativeAlchemyRound46DynamicTypeAndZeroSub40ptHitTargets` in `ChimmoTests/SpecimenIntegrityTests.swift`.

## 0.52.0 - 2026-11-24
- Round 45 (100% Reduce Motion Compliance + Active-Space Hardware Keyboard Studio + Dynamic Type Scaling):
  - Completed app-wide Reduce Motion gating by adding `@Environment(\.accessibilityReduceMotion)` to `AmbientPaperBackdrop` (night/day transition) and guarding `.symbolEffect(.bounce, value: vm.lastSavedPulse)` behind a `@ViewBuilder` `saveStatusIcon(needsSave:)` helper in `CreateStudioView`.
  - Added `StorybookShortcutSpace`, `StorybookKeyboardShortcutSpec`, and `StorybookAffordanceMetrics.keyboardShortcuts(for:)` alongside `View.storybookKeyboardShortcut(_:enabled:)` in `ChimmoDesignLanguage.swift`, scoping hardware shortcuts strictly to active tabs (`Space` in Showcase; `Space`, `Cmd+S`, `Cmd+Z`, `Cmd+N` in Create) with VoiceOver keyboard hints.
  - Upgraded fixed `.font(.system(size: ...))` UI labels and icons to semantic Dynamic Type text styles (`.footnote`, `.caption`, `.caption2` with `.lineLimit(1)` / `.minimumScaleFactor(0.75)`) across `CreateStudioView`, `AboutSheetView`, `DreamCaptureSheet`, `NightLampTactileSheet`, and `SoundPaletteBoxSheet`.
  - Added `testCreativeAlchemyRound45ReduceMotionKeyboardAndDynamicTypeContract` in `ChimmoTests/SpecimenIntegrityTests.swift`.

## 0.51.0 - 2026-11-24
- Round 44 (Complete 28-Specimen Interactive Storybook Coverage):
  - Populated curated `GuidedStoryMoment` chapter scripts across all 17 remaining classic and original specimens in `SpecimenLibrary` (`schubertSerenade`, `bachCelloSuite1Prelude`, `bachInventionDialogue`, `pachelbelCanonGround`, `mozartTwinkleVariation`, `debussyClairDeLune`, `debussyFlaxenHair`, `satieGymnopedieSeed`, `beethovenMoonlight1`, `beethovenEliseResolve`, `teaHousePentatonic`, `tinkiResolution`, `rainyChromaticWalk`, `midnightCoastCityPop`, `bittersweetDaylight`, `teardropSlashBass`, `stardustCounterpoint`), achieving 28/28 Showcase storybook chapter flip availability.
  - Added exhaustive `testCreativeAlchemyRound44All28SpecimensHaveStorybookChapters` validating monotonic timestamps, bounds, non-empty Kids' Book copy, zero Emoji, `StorybookGuidedMomentKinematics.chapterNavigation` + `chipModel` consistency, and `StudioViewModel` switching across every single specimen in `SpecimenLibrary.all`.

## 0.50.0 - 2026-11-24
- Round 43 (ADA Craft & Tactile Creation Polish):
  - Activated pitch-stepping controls (`shiftSelectedBeadPitch(delta: -1 / +1)`) in `CreateStudioView.compactCreationBeatBar`, backed by pure engine helper `CreateBeatAdjustmentDescriptor` (pentatonic-safe bounds, digit/member/duration badge using borderless `StorybookQuietTag`, VoiceOver `accessibilityAdjustableAction`, and >= 40pt hit targets).
  - Upgraded all remaining sub-40pt interactive hit targets across `CreateStudioView`, `OrbitalStageView`, `SoundPaletteBoxSheet`, `DreamCaptureSheet`, `MusicBoxShelfView`, and `AboutSheetView` to `>= StorybookAffordanceMetrics.compactToolMinHitDimension` (`40pt`) with explicit `.contentShape(...)` while preserving compact visual geometry.
  - Completed `SettingsView` and `CharacterSoundTestView` VoiceOver `accessibilityLabel / accessibilityValue / accessibilityHint` coverage and `@Environment(\.accessibilityReduceMotion)` animation gating.
  - Added `testCreativeAlchemyRound43BeatPitchAdjustmentAndCompactHitTargets` in `ChimmoTests/SpecimenIntegrityTests.swift`.

## 0.49.0 - 2026-11-24
- Round 42 (Visual-First Alchemy Loop): Full-chain OpenMotion brand synchronization & Three-Space Showcase alignment:
  - OpenMotion Design Studio website upgraded to v10 (`f60f9ab2-f447-4d3c-a5ef-ae1c270c0f7d`) and synced to `docs/index.html` (`SHA-256: 2232fe7343ecf876c7edf01ea6f1f4adaa5d965e9f04a8ff475d0393d7d37286`), showcasing the Three-Space Showcase/Create/Settings architecture, interactive Creation starter seeds, Swan chapter navigation, and Two-Pole Affordance tag polish (no pill outlines on read-only badges).
  - OpenMotion Director short film upgraded to v15 (`ea36d037-a0fb-479e-bdd1-3d1ccf653b14`), removing legacy corner pins (`.s1-pin*`/`.s2-pin*`), scalloped top awnings (`#s1-awning`/`#s2-awning`), and floating stray dots while upgrading to borderless storybook hills, quiet kickers, and Three-Space copy; verified with 0-error/0-warning Hyperframes lint, 14/14 MP4 technical checks (`1894621 bytes`), `ffmpeg volumedetect` (`mean_volume: -17.0 dB`, `max_volume: -2.6 dB`), 8-frame PNG visual review, and `record_review` passed.
  - Added `testCreativeAlchemyRound42FullChainThreeSpaceAndOpenMotionAlignment` verifying Three-Space tab identity, starter seed scale/prefix invariants, Two-Pole affordance metrics, and `StorybookGuidedMomentKinematics` chapter navigation bounds on `SpecimenLibrary.dvorakGoingHome`.

## 0.48.0 - 2026-11-24
- Codified the user-calibrated development methodology and 10-point Pre-Commit Self-Audit Checklist in [docs/METHODOLOGY.md](file:///Users/someone/Projects/chimmo/docs/METHODOLOGY.md).
- Added 3 curated starter seeds (`CreationStarterSeed` with live inline playback), live `StageHarmonyRibbonView` chord exploration, `CreationDraftMetrics` note-count/duration header readout, and a non-trapping `Follow-Glow` exit bar in `CreateStudioView`.
- Closed remaining creation dirty-tracking gaps (`setChordPreset`, `setAccompanimentTexture`, `setMelodyVoice`, `setRootMIDI`, `undo`), prevented note-write collisions during Follow-Glow mode, and added explicit chapter navigation (`StorybookGuidedMomentKinematics.chapterNavigation`, `stepGuidedMoment`, `jumpToGuidedMoment`) with live chapter playback in `OrbitalStageView`.
- Polished `NightLampTactileSheet` (replaced decorative dot/mode pills with flat `RoundedRectangle` styling and clearer labels) and guarded empty follow-along action in `DreamCaptureSheet`.

## 0.47.0 - 2026-11-24
- Separated Showcase/Interactive Guide ("欣赏") from a dedicated Creation Space ("创作") and commercial-standard Settings tab ("设置") in `StudioView` and `CreateStudioView`, preserving independent workspace snapshots and `hasUnsavedCreationChanges` state so browsing classics never overwrites unsaved creations.
- Replaced top-left title rename with an explicit Song Picker pill ("切换曲目") opening `MusicBoxShelfView`, removed misleading floating corner chips/drop-shadow stage framing, and added clear labeled "试听" (Audition), "保存作品" (Save), "作品" drawer, and "来一段起音灵感" starter controls.
- Enforced strict button-vs-label visual grammar across `ChimmoDesignLanguage`, `OrbitalStageView`, `MusicBoxShelfView`, `DreamCaptureSheet`, and `SoundPaletteBoxSheet` (reserving pill/outline/hard-shadow treatment exclusively for interactive controls and using flat non-capsule styling for read-only labels).
- Built commercial-standard native `insetGrouped` `SettingsView`, `ChimmoLegalDocumentView` (Privacy, Terms, Open Source Licenses), `CharacterSoundTestView`, and refactored `AboutSheetView` to match Apple HIG conventions.

## 0.46.0 - 2026-11-24
- Upgraded OpenMotion Design Studio website to v9 and synced `docs/index.html` (`v0.46.0`): replaced vinyl sleeve and tonearm metaphors with the open storybook songbook cover, bookmark ribbon, minimalist music-box wreath, default full-width hill stage, and refined 29pt-safe 1-3-5 trio AppIcon triptych.
- Upgraded OpenMotion Director short film (`ea36d037-a0fb-479e-bdd1-3d1ccf653b14`) to v14 with `0` lint errors/warnings: replaced the vinyl ending with a borderless rolling meadow hill, 12-o'clock golden star bookmark wreath, and clean three-beat 12s export verified visually and acoustically.
- Added Round 39 (`v0.46.0`) full-chain storybook identity consistency tests in `ChimmoTests/SpecimenIntegrityTests.swift`, bumped `MARKETING_VERSION` to `0.46.0`, and passed static gates and no-simulator `xcodebuild build-for-testing` with `0` errors and `0` warnings.

## 0.45.0 - 2026-11-24
- **告别黑胶隐喻 × 全宽绘本山坡默认主舞台 × 29pt 提纯 1-3-5 AppIcon（Pure Storybook Identity Edition v0.45.0）**：
  - **修复 CI NaN 境界校验漏洞（`TheoryLensEngine`）**：修复 `GuidedStoryMoment.init` 中 `min(1, .nan)` 返回 `1.0` 的 Swift 浮点数边界问题（改用 `timeFraction.isFinite ? max(0.0, min(1.0, timeFraction)) : 0.0`），确保 `testCreativeAlchemyRound36AppIconCanonsAndStorybookGuidedMoments` 全绿通过；
  - **全宽绘本山坡默认主舞台 & 极简音乐盒花环（`StudioView`、`OrbitalStageEngine`、`OrbitalStageView`、`VinylPostcardExporter`）**：主舞台默认切换为全宽扁平绘本山坡乐谱模式（`StageVisualMode.flowingRiver` / 标签「山坡」），彻底消灭竖屏圆形主舞台上下留白并叠加无描边远景草坡与书签星章读谱指针；重塑圆形「花环」模式与离线明信片，彻底移除 22 道黑胶音槽、12 枚刻度、外环铜边及右上角机械唱臂，升级为轻盈 12 点钟金色书签星阅读指针；
  - **TabBar 与「绘本曲谱书架」全面去黑胶化（`StudioView`、`MusicBoxShelfView`、`ChimmoDesignLanguage`、`AboutSheetView`）**：主底栏告别 `record.circle.fill` 与 `opticaldisc.fill`，改用 `music.quarternote.3`（「演奏」）与 `books.vertical.fill`（「曲库」）；曲库页升级为「绘本曲谱书架」（`StorybookSongbookCoverThumb` 替代滑盘唱臂封套，呈现翻开奶油乐谱页、丝带书签、硬朗偏移阴影与一键试听章）；`ChimmoCraftSymbol.vinylSeal` 重绘为开卷双页书本与四芒旋律星章；
  - **极简提纯 29pt 1-3-5 扁平卡通应用图标（`Tools/ip/render_flat_app_icons.py`）**：剥离浅色云日射线、深色背景灰环/零散星点与双层描边山丘，改用单层无描边草坡并放大居中 1-3-5 三人组（`+13%` 比例与加粗暖墨描边），三态 1024×1024 不透明 PNG 已重新生成并逐一视觉核验；
  - **单元测试补强**：新增 `testCreativeAlchemyRound38StorybookHillStageWreathAndSongbookShelf`，覆盖 `GuidedStoryMoment` NaN/Inf 归零、默认山坡模式、非黑胶图标契约、绘本封面运动学及三态明信片导出。

## 0.44.0 - 2026-11-24
- **交互热区修复 × 全局视觉降噪 × 两极交互视觉契约（Quiet Flat-Cartoon Affordance Edition v0.44.0）**：
  - **两极交互视觉契约与紧凑预算引擎（`StorybookAffordanceMetrics` & `ChimmoDesignLanguage`）**：严格区分可交互贴纸按钮（暖墨实线描边 + 无模糊偏移阴影 + `StorybookTactileButtonStyle` 按下物理下沉）与静态展示容器/只读信息标签（新增零硬阴影 `StorybookQuietCardSurface` 与无描边 `StorybookQuietTag`，`ChimmoWoodResonatorTray` 与 `ChimmoEditorialPill` 降噪为轻柔背景容器）；彻底废除全站 `ChimmoBrassFrameAccent` 双层套框叠加与四角圆钉（`showCornerPins`）；
  - **全画幅降噪底纸与主舞台热区修复（`AmbientPaperBackdrop` & `OrbitalStageView`）**：精简背景底纸，移除 18 颗散点与被卡片遮断的云日装饰，仅留纯净暖纸/夜蓝与底部无描边起伏绘本山坡；修复 `modeReliefPillSwitcher` 与 `activeFeaturesOverlay` 透明胶囊热区过小及向底层 `Canvas` 手势穿透问题（统一扩大至 `36–42pt` 完整 `.contentShape(Capsule())` 热区）；顶栏曲名追加铅笔重命名提示并移除右侧外层双层套框；和声轨、游标卡尺与底部控台消除假按钮框与重边框；
  - **曲库与弹窗 `.medium` 半屏直达减负（`MusicBoxShelfView`、`SoundPaletteBoxSheet`、`DreamCaptureSheet`、`AboutSheetView`、`NightLampTactileSheet`、`VinylPostcardExporter`）**：将 `MusicBoxShelfView` 三层吸顶头栏收紧为紧凑双行结构（默认隐藏搜索栏，一键展开；单行横向滚动分类与情绪筛选条），曲目卡升级为无硬阴影 `StorybookQuietCardSurface` 并在标题旁补充铅笔重命名提示；合并 `DreamCaptureSheet` 顶栏与标签轨、压低 `SoundPaletteBoxSheet` 示波舞台高度并清除双层框与多余分隔彩带，全面修复浅/深/视窗透明切换胶囊手势穿透并让 `.medium` 半屏立即可用；
  - **单元测试与构建门禁**：新增 `testCreativeAlchemyRound37AffordanceContractHitTargetsAndCompactChrome`，通过零渐变零模糊阴影、零圆钉双框、零 Emoji 及无模拟器 `xcodebuild build-for-testing`（0 error / 0 warning）校验。

## 0.43.0 - 2026-11-24
- **1-3-5 扁平卡通应用图标 × 主舞台绘本分幕角标 × 全站零拟物首触闭环（Kids' Book First-30-Seconds Edition v0.43.0）**：
  - **全新 `1-3-5` 三音主和弦应用图标套件（`AppIcon-Light` / `AppIcon-Dark` / `AppIcon-Tinted` + `Tools/ip/render_flat_app_icons.py`）**：彻底淘汰早年 3D 拟物圆盘图标，严格遵循 IP 正典《1-3-5 主三和弦三人组》（居中前立的珊瑚赤陶铃「1 陶诺」与胸口金珠 + 左后探出的「3 拍咯」+ 右后探出的「5 壳咯」螺旋贝耳）重绘为 1024×1024 零渐变扁平卡通童书图标三态（含 29pt 高辨识粗暖墨描边、星月夜守望态及高对比度单色着染态）；
  - **主舞台绘本分幕轻故事角标 & 纯平涂唱盘（`StorybookGuidedMomentKinematics` & `OrbitalStageView`）**：盘活 `vm.activeGuidedMoment` 实时分幕数据，在小羊咩与小牛哞双子底座之间的底部安全区嵌入紧凑扁平贴纸 `storybookStoryChipButton`，展示当前曲目分幕名与领唱小偶，轻点即响小偶声音并展开单行编曲手账气泡与「试听此段」快捷跳转；同步清除主舞台音珠 3D 玻璃反光椭圆、金属唱臂描边与顶栏 `brassHairline` 细线，全面统一至清晰暖墨描边扁平卡通画风；
  - **OpenMotion Design Studio 互动绘本官网 `v8` 与三份法务绘本页全面对齐（`docs/index.html`、`privacy.html`、`licenses.html`、`terms.html`）**：通过 `openmotion-design` 将官网升级至 `v8`（`v0.43.0` 徽章、1-3-5 新图标三态与《天鹅》三幕可听角标），导出整页 PNG 验收后同步仓库；将 `privacy.html`、`licenses.html` 与 `terms.html` 全面改版为统一的暖窑宣纸 `#F4EDE0` / 深夜靛蓝 `#0E142C` 扁平卡通绘本卡风格并补充 PNG 明信片/WAV/MIDI 导出说明；
  - **单测与静态校验**：新增 `testCreativeAlchemyRound36AppIconCanonsAndStorybookGuidedMoments`，通过无模拟器 `xcodebuild build-for-testing`（0 error、0 warning）、零渐变零模糊阴影及全局零 Emoji 门禁。

## 0.42.0 - 2026-11-24
- **零拟物零渐变最终收口 × 星夜绘本盲操台 × OpenMotion 短片七小只 Solo v12（Zero-Gradient Flat Cartoon Kids' Book Edition v0.42.0）**：
  - **夜灯绘本舞台（`NightLampTactileSheet` & `StorybookNightLampInclusivityKinematics`）**：全面废除夜灯画布背景、闲置提示条与触控光斑中的全部 `LinearGradient` / `RadialGradient`，重构为深靛蓝 `#0B112B` 星月夜丘童书舞台；修复盲操与音珠试听冷启动静音隐患，在 `previewTactileLane(_:)` 与 `previewCapturedBead(_:index:)` 中补全 `vm.synth.ensureRunning()`，新增无障碍撤销转子操作 `.accessibilityAction(named: "撤销上一音")` 与实时声名状态朗读 `accessibilityCanvasValue`；同步兼容系统「减弱动态效果」分档直控圈径，并保留实时悬停音位对应的 `ChimmoCartoonKeyBuddyView` 陪唱小偶；
  - **全仓库零渐变零模糊阴影历史性里程碑（`OrbitalStageView` & `AboutSheetView`）**：彻底清零 `OrbitalStageView` Canvas 绘制路径中最后 10 处圆盘高光、`LinearGradient` 彩虹虹膜与星河光晕渐变，全部重绘为高饱和柔粉彩平涂胶片圆盘、奶酥奶油中枢轴与清晰暖墨 `#231B15` 卡通描边；重构 `AboutSheetView` 首屏为扁平童书画框舞台卡片 + 七小只足下扁平草坡舞台，全面对齐零拟物零无意义留白铁律；
  - **OpenMotion 导演短片 v12 七小只个体化演出（`compositions/s2-choir.html`）**：遵循 OpenMotion 技能工作流升级 `s2-choir`（`versionNumber: 12`），为陶诺、豆叩、拍咯、呜嘟、壳咯、钵莫、叮尖编排 7 段独立器官微动与轮唱光环，完成 `lint-project.mjs`（0 error / 0 warning）、MP4 音频 `volumedetect`（-17.0 dB / -2.6 dB）与 6 帧抽检门禁；
  - **单测补强（`SpecimenIntegrityTests`）**：新增 `testCreativeAlchemyRound35NightLampStarryInclusivityAndSoloAudio`，覆盖星空锚点边界、减弱动态光环分档、VoiceOver 摘要文案及夜灯音段提交状态；通过本机无模拟器 `xcodebuild build-for-testing`（0 error、0 warning）及全库零渐变/零模糊阴影/零 Emoji 静态扫描。

## 0.41.0 - 2026-11-24
- **黑胶唱片工坊与离线明信片全面扁平卡通绘本化 × OpenMotion 官网 v7（Flat Cartoon Kids' Book Edition v0.41.0）**：
  - [OrbitalStageEngine.swift](Chimmo/Domain/OrbitalStageEngine.swift) 与 [ChimmoDesignLanguage.swift](Chimmo/Theme/ChimmoDesignLanguage.swift)：新增纯值域引擎 `StorybookPostcardAndShelfKinematics`（曲目主角小偶选取 `heroMember(for:)`、封套贴纸位移 `sleevePlacement(...)` 与太阳光线生成器 `radialRaySegments(...)`），以及全域复用的零渐变童书风景图层 `StorybookCartoonSceneBackground`（日光太阳射线 / 夜灯新月纸星、单一闭合墨线纸艺云朵、双层手绘草坡）；
  - [MusicBoxShelfView.swift](Chimmo/Views/MusicBoxShelfView.swift)：清除全部残余 `LinearGradient` 与模糊 `.shadow(...)`，补充空作品直接试听守卫 `guard !doc.notes.isEmpty`；将 `VinylBoutiqueSleeveThumb` 重构为零延迟 `Button` 互动绘本封面（内嵌草坡起伏与实时欢唱晃头的曲目主角 `ChimmoCartoonKeyBuddyView`），将「唱片架暂无作品」与筛选空态重绘为汇聚 `taono / plokko / corllo` 与双子星的全幅草原绘本跨页；
  - [VinylPostcardExporter.swift](Chimmo/Domain/VinylPostcardExporter.swift) 与 [AboutSheetView.swift](Chimmo/Views/AboutSheetView.swift)：彻底消除 `VinylPostcardCanvasView` 与 `VinylPostcardShareSheet` 内的 16 处渐变及模糊浮动投影，重构为带暖墨漫画框、四角彩色圆钉贴纸、扇形顶帘、双层草坡、`咩 × 主角小偶 × 哞` 静态合影以及不遮挡文字的标题铭牌；PNG / WAV / MIDI 分享卡同步升级为硬朗无模糊偏移阴影贴纸卡片；
  - OpenMotion Design Studio 互动绘本官网推进至 `v7`（`f60f9ab2-f447-4d3c-a5ef-ae1c270c0f7d` -> [docs/index.html](docs/index.html)）：统一小羊咩无内接缝闭合云朵轮廓、为跳跃声波小山坡加入随音量点头亮灯的七小只微缩合唱排、为唱片封套加入陶诺主角小偶，并新增「绘本星轨明信片交互印制台」卡片支持星轨转盘 / 极光琴河 / 八角星座实时切换与和弦发声，完成无头 PNG 渲染图目视验收；
  - 在 [SpecimenIntegrityTests.swift](ChimmoTests/SpecimenIntegrityTests.swift) 新增 `testCreativeAlchemyRound34StorybookShelfAndPostcardFlatCartoon`。

## 0.40.0 - 2026-11-24
- **声音调色盒、捕梦工坊 × 双子星轮廓 × OpenMotion 短片 v10 全扁平卡通绘本化（Flat Cartoon Kids' Book Edition v0.40.0）**：
  - [SoundPaletteBoxSheet.swift](Chimmo/Views/SoundPaletteBoxSheet.swift)：彻底移除木架与开关中的全部渐变及模糊投影，将顶部示波器升级为含太阳/新月、纸艺云朵、草坡与「咩 × 1·3·5 三音偶 × 哞」交互演出的绘本草坡舞台；将拨杆重构为漫画拨片贴纸开关，并用 `StorybookScallopDivider` 扇形彩带分隔混音三层，在「咩 · 音色」「哞 · 伴奏」标题胶囊内直接嵌入活体微缩双子视图；
  - [DreamCaptureSheet.swift](Chimmo/Views/DreamCaptureSheet.swift) 与 [OrbitalStageEngine.swift](Chimmo/Domain/OrbitalStageEngine.swift)：新增 `StorybookChoirMeterKinematics` 纯函数引擎并以「七小只声浪合唱舞台」`StorybookChoirLevelStageView` 取代原机械黄铜指针 `AnalogHumVUMeterView`（声压升高逐个唤醒七小只点赞微笑并与 9 座彩色糖果音山坡共舞）；Tab 0 绘板叠加起伏草坡与墨线漫画笔触、Tab 1 广播麦按钮与 1/5 定音贴纸嵌入 `taono`/`corllo` 头像、Tab 2 变奏推子柱顶集成随调音欢笑点头的 `ChimmoCartoonKeyBuddyView`；
  - [ChimmoDuoMascotView.swift](Chimmo/Views/ChimmoDuoMascotView.swift) 与 [StudioView.swift](Chimmo/Views/StudioView.swift)：为「咩」与「哞」升级与七小只同源的暖墨闭合漫画轮廓与扁平接地投影；为 `recordRhythmDrumTap`、`previewSeedShift` 与指尖画盘试听补齐 `synth.ensureRunning()` 音频引擎首触唤醒；
  - OpenMotion 绘本动画短片推进至 `v11`（`ea36d037-a0fb-479e-bdd1-3d1ccf653b14`）：全三幕清除 `<radialGradient>` / `<linearGradient>`、金属铆钉与模糊阴影，重构为含扇形顶帘、太阳/新月、双层低矮草坡与粗墨线卡通黑胶唱盘的绘本跨页，完成 1080p MP4 导出、音频响度检查与六时刻抽帧视觉验收；
  - 在 [SpecimenIntegrityTests.swift](ChimmoTests/SpecimenIntegrityTests.swift) 新增 `testCreativeAlchemyRound33StorybookChoirMeterAndDreamAudioReadiness`。

## 0.39.0 - 2026-11-24
- **零拟物扁平卡通 × 深度融合 IP × 绘本全幅舞台跃迁（Flat Cartoon Kids' Book Edition v0.39.0）**：
  - 彻底清除全站木纹渐变、金属拉丝描边、黄铜铆钉、镜面高光与模糊硬件阴影，建立纯粹明快的扁平卡通童书绘本语言（清晰暖墨描边 `#231B15` / `#FFB94E` + 高饱和平涂水粉块 + 无模糊硬朗漫画偏移阴影 `radius: 0`）；
  - [ChimmoTheme.swift](Chimmo/Theme/ChimmoTheme.swift) 与 [ChimmoDesignLanguage.swift](Chimmo/Theme/ChimmoDesignLanguage.swift)：新增扁平绘本色票（`cartoonOutline`、`cartoonShadow`、`storybookButter`、`storybookMint`、`storybookHillBack`、`storybookHillFront`）、`StorybookScallopDivider` 波浪花边与 `ChimmoCartoonKeyBuddyView` 琴键小偶头像，并原地重构 `ChimmoWoodResonatorTray`、`ChimmoBrassFrameAccent` 与 `ChimmoKilnPillButtonSurface` 为全局共用的扁平卡通绘本容器与贴纸按钮；
  - [AmbientPaperBackdrop.swift](Chimmo/Views/AmbientPaperBackdrop.swift) 与 [ChimmoFigureView.swift](Chimmo/Views/ChimmoFigureView.swift)：重绘全画幅扁平卡通太阳/新月星辰、纸艺云朵、双层山坡草地与星尘音点以消灭背景无效留白；七小只彻底去除径向立体渐变，换装平涂水粉填色 + 暖墨闭合轮廓；
  - [OrbitalStageEngine.swift](Chimmo/Domain/OrbitalStageEngine.swift) 与 [OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift)：新增 `StorybookIllustrationLayout` 纯函数引擎；收紧主舞台无意义边缘留白，将空画布重塑为「草原山坡 + 咩哞家族齐聚折页舞台」，将七小只 `ChimmoCartoonKeyBuddyView` 直接融进 8 枚彩色合唱琴键顶部（大/小调 3 号拍咯扬翅/轻倾、弹唱瞬间变弯弯笑眼）并重塑顶栏、角落草地贴纸底座、底部扁平控制台与和声彩带；
  - OpenMotion Design Studio 互动官网同步演进至 `v6`（[docs/index.html](docs/index.html)）：全站去拟物化并融合绘本山坡、太阳、IP 合唱琴键、调色示波木盒与跳跃声波小山坡交互，完成渲染 PNG 目视验收；
  - 在 [SpecimenIntegrityTests.swift](ChimmoTests/SpecimenIntegrityTests.swift) 新增 `testCreativeAlchemyRound32StorybookFlatCartoonLayoutAndIPKeyBuddies`。

## 0.38.0 - 2026-11-24
- **主舞台冠栏、角落木铜底座与黄铜游标卡尺重构（StageHardwareCaliperKinematics v0.38.0）**：
  - 在 [OrbitalStageEngine.swift](Chimmo/Domain/OrbitalStageEngine.swift) 新增纯函数运动学引擎 `StageHardwareCaliperKinematics`，解耦音符时长刻度尺、位置浮标与「咩 / 哞」舞台底座激活/静卧态光效及减弱动态效果位移；
  - 在 [OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift) 全面升级主舞台核心硬件语法：
    - `kilnCrownHeader` 左侧双子铭牌增加活体调色圈拉丝黄铜外圈与边饰，右侧撤销/收藏/分享/关于圆键收纳入一体化嵌入式 `ChimmoWoodResonatorTray` 黄铜键槽；
    - `stageDuoCornerPerches` 抽取统一共用底座 `cornerPerchTile`，内置顶部黄铜微铆钉、底部蜂蜡桦木小木架与发声抬升反馈；
    - `compactSelectionPill` 重构为「黄铜音符游标卡尺面板」（四角黄铜铆钉木托盘 + 8 格点亮时值刻尺 + 节拍序列滑标轨 + 窑釉倒角编辑按键），并将 `activeFeaturesOverlay` 对齐至统一 `ChimmoKilnPillButtonSurface`。
- **OpenMotion Design Studio 互动绘本官网同步 v4（`docs/index.html`）**：
  - 按 `openmotion-design` 工作流将互动绘本官网升级至 `v0.38.0` 并回写 [index.html](docs/index.html)：新增「童书声音调色木盒（4 种音色实时 SVG 示波窗、3 种调式联动 `1·3·5` 三音偶及双机械拨杆）」与「模拟黄铜 VU 声压表（9 段灯条 + 指针联动全站发声）」交互工作台，同步修正 `mouSleepArcs` 牛角避让弧线并完成桌面 PNG 渲染验收。
- **全局对齐、生命周期修复与单元测试（Fix, Alignment & Tests）**：
  - 为 [OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift) `.onDisappear` 与 `.onChange(of: vm.document.id)` 补齐 `rippleWakeTask` 与 `coastTask` 取消及归零，为 [StudioView.swift](Chimmo/Views/StudioView.swift) 增加 `deferredPostcardTask` 退场取消保护；
  - 将 [AboutSheetView.swift](Chimmo/Views/AboutSheetView.swift) 中 `VinylPostcardShareSheet` 顶栏控件统一接入 `ChimmoWoodResonatorTray`、`ChimmoBrassFrameAccent` 与 `ChimmoKilnPillButtonSurface`；
  - 在 [SpecimenIntegrityTests.swift](ChimmoTests/SpecimenIntegrityTests.swift) 新增 `testCreativeAlchemyRound31StageHardwareCaliperAndPerchKinematics`。

## 0.37.0 - 2026-11-24
- **童书声音调色木盒硬件重构（SoundPaletteBoxSheet & SoundPaletteBoxKinematics v0.37.0）**：
  - 将原扁平 `MoodAndSoundSheet` 全面重构为 [SoundPaletteBoxSheet.swift](Chimmo/Views/SoundPaletteBoxSheet.swift) 暖窑象牙 × 蜂蜡桦木 × 拉丝黄铜童书调色木盒：
    - 顶栏集成 `ChimmoCraftBadge(.atmosphereHorizon)`、内嵌式三态外观黄铜拨盘（自动 / 日光 / 夜灯）与窑瓷完成按键；
    - 顶部核心内凹木框示波窗实时渲染 [SoundPaletteBoxKinematics](Chimmo/Domain/OrbitalStageEngine.swift) 驱动的平滑声学波形，并在下方共鸣木架呈现实体可点试听的「咩 × 1·3·5 三音小偶（陶诺 / 拍咯 / 壳咯）× 哞」合唱联动，切换大/小调时 `3 拍咯` 实时扬翅或微沉呼应；
    - 构造机械黄铜拨杆三连开关木槽（五音 / 伴唱 / 震动，带位移倾斜运动学与珠宝微光指示灯）、五色极光调式木槽、倍速/节拍/音区三层黄铜混音柜，以及带四角铆钉边框的「咩 · 音色」与「哞 · 伴奏」独立共鸣盒。
- **OpenMotion 绘本动画短片 v9 升级（OpenMotion Director）**：
  - 全三幕（`s1-wake` / `s2-choir` / `s3-finale`）重绘为统一 `#F4EDE0` 暖窑宣纸典藏绘本版画内页框（`y: 46..942px` 完全避开抓帧边界缝隙，配拉丝黄铜双线与四角铆钉）：
    - `s1-wake` 新增晨光斜光束、木盒示波窗扫频联动、小羊咩扇耳 `svgOrigin` 随动及小牛哞新月黄铜牛角、避让角尖呼吸弧线与不裁切木架的安全醒目金色声环；
    - `s2-choir` 将深夜绒靛蓝画板嵌入宣纸画框内消除底部浅条，升级七小只哑光陶泥径向明暗与高光眼眸，并在 `7.30s` 主音重音处新增 `7 叮尖 -> 1 陶诺` 金色解决弧动画（叮尖瞬间回正、陶诺胸口铜珠亮起）；
    - `s3-finale` 忠实还原 AppIcon 同源瓷盘声学唱机立体绘本展开图（木质外环、象牙瓷盘、琥珀玻璃利萨如轴心、七彩陶珠、黄铜唱臂落针激起三重晶透声波涟漪），并通过 SVG viewBox `svgOrigin`（`180 180` / `336 36`）锁定瓷盘外缘与唱臂枢轴、仅驱动七颗陶珠随唱盘顺时针旋转且贴合小木台接触阴影。
- **修复、全局对齐与单元测试（Fix, Alignment & Tests）**：
  - 为 `StudioViewModel` 的 `setScaleMode`、`setAccompanimentTexture`、`setMelodyVoice`、`setRootMIDI` 与暂停态 `setPlaybackRate` 补齐 `synth.ensureRunning()` 音频引擎首触预热，并为 `setGrooveStrength` 增加幂等撤销栈守卫防止重复点击产生空撤销记录；
  - 为 [AboutSheetView.swift](Chimmo/Views/AboutSheetView.swift) 补充 `.onDisappear` 试听重置任务取消，并将 `AboutSheetView`、`NightLampTactileSheet` 与 `OrbitalStageView` 全部遗留深蓝色值统一收敛为 `#0E142C`；
  - 在 [SpecimenIntegrityTests.swift](ChimmoTests/SpecimenIntegrityTests.swift) 新增 `testCreativeAlchemyRound30SoundPaletteBoxKinematicsAndAudioReadiness`。

## 0.36.0 - 2026-11-24
- **捕梦工坊实体创作工作台重构（Kiln Workbench & Analog VU Console v0.36.0）**：
  - 彻底摆脱原生 `NavigationStack` 标题栏、`UISegmentedControl` 与平白卡片，重构 [DreamCaptureSheet.swift](Chimmo/Views/DreamCaptureSheet.swift) 为暖窑象牙 × 蜂蜡桦木 × 拉丝黄铜三维创作台：
    - 顶栏换装随当前模式切换徽标的 `ChimmoCraftBadge`、`ChimmoEditorialPill` 实时状态胶囊与暖瓷 `"完成"` 按钮，并构建三槽木框黄铜切换轨（「节奏画室」 / 「轻哼电台」 / 「折纸工坊」）；
    - Tab 0「节奏画室」升级双子木框监视窗、蜂蜡桦木桌面木鼓机（内凹背光拍条窗口与拍数铜牌）、带 5/8 线音阶标尺与左缘彩色定位珠的手绘宣纸木框画盘及带柔和渐变阴影填充的 2×2 山坡浮雕卡；
    - Tab 1「轻哼电台」重构为内置物理感黄铜指针模拟声压表 `AnalogHumVUMeterView`（9 档刻度弧 + 红区警告刻线 + 9 段实时灯条）的温暖广播木柜，配合黄铜外圈录音键、内凹示波窗与 1/5 定音调音珠；
    - Tab 2「折纸工坊」统一夜灯剧场 / 跟灯 / 新画布硬件三联卡、带凹槽背景条的双曲线变形成长卡，并将三通道音高变奏推子收入带四角黄铜铆钉的木制混音盒。
- **OpenMotion 导演动画短片 v7 视觉校准（OpenMotion Director）**：
  - 同步校准 `s1-wake` / `s2-choir` / `s3-finale` 至暖窑象牙 `#F4EDE0`、深夜靛蓝 `#0E142C` 与拉丝黄铜视觉体系，并将片尾黄铜画框缩进安全视口高度内避免底部裁切。
- **修复、引擎与单元测试（Fix & Engine）**：
  - 为 [HumCapturePipeline.swift](Chimmo/Audio/HumCapturePipeline.swift) 新增带 `captureGeneration` 并发代数保护的 `cancelRecording()`，并在 [StudioView.swift](Chimmo/Views/StudioView.swift) 暴露 `cancelHumCapture()`，确保切换标签、打开夜灯剧场或关闭工坊时干净终止麦收音与节奏打点；
  - 修复 Tab 0 画板仅轻触不足 2 点时误把已敲节奏展平为低音平线的问题，在 [OrbitalStageEngine.swift](Chimmo/Domain/OrbitalStageEngine.swift) 新增 `HumVUMeterKinematics` 并在 [SpecimenIntegrityTests.swift](ChimmoTests/SpecimenIntegrityTests.swift) 补齐 `testCreativeAlchemyRound29HumVUMeterKinematicsAndDreamWorkbenchCleanup`。

## 0.35.0 - 2026-11-24
- **曲库黑胶精品店与展示工坊重构（Boutique Vinyl Cabinet & Design Studio v0.35.0）**：
  - 彻底移除系统默认分段控件与平白列表卡片，重构 [MusicBoxShelfView.swift](Chimmo/Views/MusicBoxShelfView.swift) 为窑陶 × 蜂蜡桦木 × 拉丝黄铜黑胶唱片工坊：
    - 顶栏集成 `ChimmoCraftBadge(.vinylSeal)`、响应式「咩 × 哞」活体双子与内嵌窑陶搜曲槽，取消原生导航栏割裂感；
    - 新增实体木纹/黄铜双槽唱片切换轨（「我的黑胶」与「名曲殿堂」）及四角铆钉黑胶筛选木柜（`ChimmoKilnPillButtonSurface` 分类瓷块与五色极光调式亮盘，附一键重置键）；
    - 新增 `VinylBoutiqueSleeveThumb` 实景唱片封套缩略件（含封脊色带、四幕色码、中心几何音徽、通过 `VinylBoutiqueKinematics` 滑动半露的旋转黑胶唱片及黄铜机械唱臂落针动画）。
  - 升级 OpenMotion Design Studio 互动绘本首页并同步导出至 [docs/index.html](docs/index.html)（`v0.35.0`），接入暖窑象牙宣纸纹理、蜂蜡桦木框、交互式 3D 木琴五音琴块与黑胶落针试听样片。
- **修复与稳定性增强（Fix）**：
  - 修复曲库切换分段、筛出在播曲目或打开分享抽屉时后台试听音频残留未停播的问题，自动调用 `stopInlinePlay()`；
  - 补全名曲卡片主舞台在播对勾徽章的无障碍语义标注，并将 `MiniOrbitalDiscPreview` 进度外弧接入 `StageTransportRingMapper.loopProgress` 周期循环；
  - 修复 `MelodyNotebookStore.duplicate` 重复复制同一首已带 `"副本"` 作品时产生重名碰撞的问题，保留首份 `"xxx 副本"` 命名兼容性的同时为连续副本自动递补序号。
- **引擎与单元测试（Engine & Tests）**：
  - 在 [OrbitalStageEngine.swift](Chimmo/Domain/OrbitalStageEngine.swift) 新增 `VinylBoutiqueKinematics` 纯值运动学状态机；
  - 在 [SpecimenIntegrityTests.swift](ChimmoTests/SpecimenIntegrityTests.swift) 新增 `testCreativeAlchemyRound28VinylBoutiqueKinematicsAndDuplicateNaming`。

## 0.34.0 - 2026-11-24
- **建筑级主舞台视觉与材质重构（Global Materials & Stage Instrument Redesign）**：
  - 升级全局 `ChimmoPalette` 与启动纸色资产：将日光底盘重构为暖窑象牙宣纸（`#F4EDE0`）、蜂蜡桦木与拉丝黄铜，夜灯重构为深夜天鹅绒靛蓝（`#0E142C`）、烟熏胡桃木与暖钨丝琥珀，并扩充 `woodTrayTop`、`woodTrayBottom`、`brassHairline`、`glazeHighlight`、`recessShadow` 物理材质原语；
  - 升级 [AmbientPaperBackdrop.swift](Chimmo/Views/AmbientPaperBackdrop.swift) 与 [ChimmoDesignLanguage.swift](Chimmo/Theme/ChimmoDesignLanguage.swift)：加入确定性零功耗手抄陶纸矿物微粒/纤维肌理与工作室斜光束，新增可复用实体原语 `ChimmoWoodResonatorTray`、`ChimmoBrassFrameAccent` 与 `ChimmoKilnPillButtonSurface`；
  - 重构主舞台 [OrbitalStageView.swift](Chimmo/Views/OrbitalStageView.swift)：
    - 移除系统默认导航栏，改用一体式「双子窑陶铭牌胶囊」与 34pt 硬件圆形陶瓷按键构成的 `kilnCrownHeader`；
    - 为主声盘/山河/星云共鸣腔披上带四角黄铜微铆钉的蜂蜡桦木框，并将浮雕三态模式切换仪收入右上角、于左下/右下四角增加可点按试听/唤醒的双子舞台角守护底座（`stageDuoCornerPerches`）；
    - 为四幕和声触控轨增添内凹陶槽与顶部釉光高光层；
    - 将底部蒙氏彩虹琴键重构为带双根拉丝黄铜共鸣导轨、微铆钉与 `KilnKeyPhysics` 真实 3D 压感立面的窑陶木琴共鸣箱；
    - 将底部控制区重构为悬浮暖瓷黄铜发条中控台，左设 `StageTransportRingMapper` 驱动的循环播放进度光弧轮，右设 5/7 点五音守护刻度表盘。
- **OpenMotion 导演动画短片全画幅精修（OpenMotion Director）**：
  - 为 `ea36d037-a0fb-479e-bdd1-3d1ccf653b14` 工程 `index.html` 显式声明 1920x1080 主宿主几何并统一暖窑象牙底色 `#F4EDE0`，通过 `0` error / `0` warning 校验并重出 12 秒成片（同时确认并记录 macOS 宿主快速抓帧视口 `993px` 高度上限）。
- **物理引擎与单元测试（Engine & Tests）**：
  - 在 [OrbitalStageEngine.swift](Chimmo/Domain/OrbitalStageEngine.swift) 新增 `KilnKeyPhysics` 与 `StageTransportRingMapper`；
  - 在 [SpecimenIntegrityTests.swift](ChimmoTests/SpecimenIntegrityTests.swift) 新增 `testCreativeAlchemyRound27KilnHardwareMaterialsTransportRingAndStageRedesign`。

## 0.33.0 - 2026-11-24
- **修复与稳定性提升（Fix）**：
  - 修复 `StudioViewModel.undo()` 撤销音阶调式后声学混响空间配置 `AcousticSpaceProfile` 与 `pentatonicSafe` 未同步恢复的问题，`undo()` 后自动同步调用 `synth.applySpaceProfile` 并按文档音高重算五声安全锁；
  - 修复 `DreamCaptureSheet` Tab 0（节奏与轮廓速写）轻触画板即清空整首旋律并覆盖为 6 个平直音符的误触隐患（新增 `2pt` 以上有效拖拽位移门限），并修复切换标签或点按重置后 `lastBrushLane` 残留问题；
  - 移除 `MoodAndSoundSheet` 中「咩」头像的常驻 `isSinging: true` 硬编码，切换为仅在试听声脉冲周期内高歌。
- **创意炼金术 × IP 动画联动（Creative Alchemy & Motion）**：
  - 新增纯函数运动学引擎 `DreamBrushKinematics`，在 `DreamCaptureSheet` 顶部实装可随画笔归一化高度/横向方位实时倾身注视并在高音区欢唱的「咩」与按四拍周期脉动高亮的「哞」双子联动视窗；
  - 新增 `AcousticSignatureAnimationHelper` 光点扫频游标，驱动 `MoodAndSoundSheet` 音色包络波形 `VoiceEnvelopeSparkView` 与伴奏点阵 `AccompanimentDotPatternView` 实现点选试听 0.65s 实时扫频点亮与点阵波纹反馈；
  - 同步推进 OpenMotion 导演动画工程，完成 12 秒 1080p 30fps「咩 × 哞 × 七小只」三幕陶瓷角色动画短片与原创合成伴奏音轨整合。
- **全局视觉与交互对齐（Global Alignment）**：
  - 在 `ChimmoDuoMascotView` 抽离可复用组件 `LivingChimmoDuoBadgeView`（24fps 轻量呼吸周期并完整尊重 `accessibilityReduceMotion`），统一主舞台顶栏、空画布、夜灯面板与曲库空态的活体双子形态；
  - 对齐 `DreamCaptureSheet` Tab 0 四套山丘弧线卡片与主舞台山丘视觉语言，补齐金色起音尖端圆点与双字短标。
- **单元测试（Tests）**：
  - 新增 `testCreativeAlchemyRound26DreamBrushKinematicsSignaturePulseAndUndoSync`，完整覆盖速写双子联动运动学、声音脉冲扫频游标索引边界与 `undo()` 声场/五声安全锁回退契约。

## 0.32.0 - 2026-11-24

- **活体「咩 × 哞」生命运动学 × 七小只窑陶合唱木架 × OpenMotion 互动绘本展示页 × 曲库单屏分类短标与舞台一致性修复 · 创意炼金术第 25 轮重构**：
  - **「咩 × 哞」生命运动学与七小只合唱台复活（`ChimmoDuoMotionKinematics`、`ChimmoDuoMascotView` & `AboutSheetView`）**：为小羊「咩」与小牛「哞」注入错峰呼吸起伏、自然眨眼、发声护角声波、音级眼神跟随与闭眼小憩漂浮呼吸弧（完整兼容减弱动态效果）；在「关于咩哞」复活 7 只活体窑陶小偶（`ChimmoFigureView`）同台矮木架，支持单点试听与单指横扫七音连奏，其余伙伴实时转眼注视发声者，并同步点亮哼唱页小羊与曲库空态双子呼吸动态。
  - **空画布破冰与状态一致性修复（`StudioViewModel`、`OrbitalStageView`）**：新增 `plantDuoStarterMotif()` 让空白星盘一键奏出五音示范短句并可直入写旋律；打通「星云」模式在空白画布落指即刻记入首颗音符；补齐 `adjustSelectedBeadDuration` 与 `deleteSelectedBead` 的停播、改写标记、`NaN` 钳位及清空画布重置状态。
  - **曲库单屏短分类控制台与 OpenMotion 官网绘本更新（`LibraryCategoryBadgeMapper`、`MusicBoxShelfView` & `docs/index.html`）**：将 5 组冗长曲库分类收束为单屏均分无滚动图标短标并与五色情绪极光圆钮整合为一整块紧凑筛选面板；为「我的作品」补齐主舞台当前在播对勾徽章；通过 OpenMotion Design Studio 创作可点击试听「咩 × 哞 × 七小只」的互动 SVG 绘本展示页并同步更新官网主页。

## 0.31.0 - 2026-11-24

- **主舞台四幕和声彩色触控轨 × 五档和弦进行彩色条码卡 × 全站状态与手感修复 · 创意炼金术第 24 轮重构**：
  - **主舞台「哞 · 四幕和声触控轨」（`StageHarmonyRibbonView` & `HarmonyCurtainStripMapper`）**：在「星盘 / 山河 / 星云」三大模式舞台下方统一嵌入灵巧的四幕彩色和声步进轨——左侧点按小牛「哞」一秒切换纯清唱小憩与伴奏开启；右侧 4 格按乐曲真实时值比例展现各幕 `I~vi` 和弦色彩并随播放同步高亮，在任意画境点按任一幕即可直接切换和声并与琴键共鸣微光、山河天际帽带实时联动。
  - **消灭全站最后一枚原生开关：五档可视化和弦进行条码（`ChordPresetBarcodeStrip` & `MoodAndSoundSheet`）**：将声音抽屉里的「哞 · 伴奏」系统开关重塑为「休息 / 智能 / 1564 / 4536 / 1645」五档彩色条码卡，用 4 色小音块直觉区分和弦走向，点选即由小牛「哞」即时弹出双和弦对比试听。
  - **交互与状态一致性修复（`StudioViewModel`、`MusicBoxShelfView` & `DreamCaptureSheet`）**：补齐在转盘或山河画布横向拖拽音珠微调时间时自动暂停播放、标记「我的改写」及刷新所属和弦区间；修复在曲库删除当前正打开的作品时主舞台书签高亮未清零的同步问题；修复在「写旋律 · 节奏鼓」面板敲击后手势下滑关闭时未取消节奏输入状态的问题，并进一步收束「关于咩哞」分享横条与曲库重置按钮文案。

## 0.30.0 - 2026-11-24

- **旋律变形双曲线图谱 × 直拖彩色音高推子 × 导航栏活体双子冠徽 · 创意炼金术第 23 轮重构**：
  - **扩写旋律双曲线预览与直拖音高推子（`DreamCaptureSheet`、`MotifMorphPreviewGeometry` & `SeedPitchFaderMapper`）**：把「写旋律 · 更多」的 4 项扩写磁贴升级为「原旋律虚线 vs 扩写彩色实线」对比曲线图，不用读字一眼看懂升高、倒影、收尾与扩四句的变化；把开头三音变奏 `-`/`+` 小按钮升级为 3 根可单指直接上下滑拖的彩色音高推子（带中央归零刻度、色盲图腾滑帽、实时试听耳返与 VoiceOver 转子）。
  - **主舞台活体双子冠徽与音符时长视觉条（`OrbitalStageView` & `StudioViewModel`）**：导航栏顶心升级为随旋律和伴奏呼应的「咩 × 哞」可点冠徽，轻点即奏响小羊高音与小牛低音问候和音；收回曲名旁重复双子徽章并释放主舞台纵向呼吸空间；选中微调坞同步加入彩色时值比例进度条。
  - **闭眼滑音时长比例条与关于页再减字（`NightLampTactileSheet` & `AboutSheetView`）**：闭眼滑音底部已录颗粒按真实时长动态拉伸宽度并内嵌时值刻条，短音与长延音一目了然；关于页双子试听卡加入极简扬声器提示微标并进一步削减品牌副标题长句。

## 0.29.0 - 2026-11-24

- **「咩 × 哞」声学双子 IP 形象体系 × 声音物理波形调色台 × 曲库彩线与全局减字对齐 · 创意炼金术第 22 轮重构**：
  - **原创「咩 · Mie（小羊高音主旋律）× 哞 · Mou（小牛低音伴奏）」双子陶偶全面上线（`ChimmoDuoMascotView` & `docs/IP.md`）**：把羊叫（咩）与牛叫（哞）的声学联想做成窑陶 × 黄铜极简工艺双子角色，轻巧融入主舞台顶栏微标、空画布静候水印、声音调色台、哼唱侧耳倾听、曲库空态、明信片印章与「关于咩哞」可点即唱二重奏小剧场，演奏与拖拽全程零干扰。
  - **修复断点与窄屏溢出**：修通曲库空态加号按钮直达「写旋律」创作抽屉；将主舞台选中浮条重排为窄屏绝不截断的双行视觉微调坞（同步展示选中音珠彩色图腾）；消除声音抽屉情绪风格 3+2 孤儿网格分裂。
  - **声音调色台可视化重构（`MoodAndSoundSheet`、`AcousticSignatureGeometry`）**：用 3 枚陶瓷矢量开关垫取代传统文字开关列表，五色情绪升级为单行均分极光带，节拍律动改用疏密点阵图示，「咩 · 音色」绘制 4 种乐器物理声学包络波形，「哞 · 伴奏」绘制 4 种和声织体节奏点阵。
  - **全站减字与交互对齐（`MusicBoxShelfView`、`DreamCaptureSheet`、`AboutSheetView`、`VinylPostcardExporter`）**：曲库去掉每张卡片重复播放键并新增彩色微型旋律走势曲线与极光图标快筛；哼唱页面加入小羊倾听与 `1 Do / 5 Sol` 定调试听音珠；写旋律移除重复入口；分享页对齐纯日月开关并收敛为 `PNG / WAV / MIDI` 三列紧凑导出坞，精简明信片多余底栏文字；关于页复活可点即唱双子舞台并折叠合规声明。

## 0.28.0 - 2026-11-24

- **音符时距磁吸微调与防撞邻拍 × 个人作品全局搜索、情绪快筛与音色音数胶囊 · 创意炼金术第 21 轮重构**：
  - **主舞台音符节拍微调与拖拽刻度触觉（`BeatTimingNudgeHelper`、`StudioViewModel` & `OrbitalStageView`）**：选中浮条与主画布 VoiceOver 转子动作新增「提前微调 / 延后微调」（每按一格自动安全避让相邻前后音符不重拍并即时声耳返），且在转盘或曲线画布拖拽音符移动时间时跨越每 `120ms` 节拍刻度送出清脆棘轮轻震并随律动设置柔和吸附。
  - **曲库统一关键词检索、跨标签五色情绪快筛与作品详情标签（`MusicBoxShelfView`）**：接入原生 `.searchable` 曲名检索，将「梦幻 / 明亮 / 温暖 / 清新 / 忧郁」五色天光筛查同时扩展至「我的作品」与「经典曲库」（附零结果一键重置筛查），并在个人作品卡片副栏清晰呈现实用音色与音符数量标识。

## 0.27.0 - 2026-11-24

- **曲库轻点改名与副本另存 × 五音零死键连滑净化 × 明信片简谱音码可选印记 · 创意炼金术第 20 轮重构**：
  - **个人曲库重命名与副本另存（`MelodyNotebookStore`、`StudioViewModel`、`OrbitalStageView` & `MusicBoxShelfView`）**：主舞台左上角轻点作品标题或在「曲库 · 我的作品」卡片点按标题/长按菜单/旁白转子即可直接改名，并支持「复制副本」以全新独立草稿另存变奏；改名与复制均采用零 Toast 静默反馈并即时持久化。
  - **五音模式琴键连滑零死键净化（`OrbitalStageView.rainbowKeyRibbon`）**：修复 5 音模式下快速横扫琴键经过 `4 Fa` 或 `7 Si` 静音键时触发虚假按沉的问题，扫过琴条更加顺滑跟手。
  - **离线黑胶明信片简谱音符可视条开关（`VinylPostcardExporter` & `VinylPostcardShareSheet`）**：分享抽屉顶栏新增数字音符开关，开启后于明信片底部生成带色盲彩点编码的简谱音符条，兼顾纯极简画报美感与清晰识谱分享。

## 0.26.0 - 2026-11-24

- **工作室级立体声 WAV 音频离线导出 × 倍速切换即时节奏耳返 · 创意炼金术第 19 轮重构**：
  - **100% 离线立体声可播放音频导出（`StudioAudioExporter` & `FeltPianoSynth.renderOfflineSongPCM`）**：新增完全隔离的音频离线混音管线，原汁原味复刻主舞台所选五声部乐器音色、调式声学空间混响、左手 4 种和声伴奏织体、巴赫影子对位与实时播放倍速，输出 16-bit 立体声标准 `.wav`（自带柔和防爆音归一化与 60ms 淡出尾迹）；「分享作品」与「关于咩哞」页面同步提供「分享音频 (.wav)」直接发给微信或电脑试听。
  - **播放倍速实时两拍节奏耳返（`StudioViewModel.setPlaybackRate`）**：暂停状态下切换 `0.65× / 0.85× / 1× / 1.25×` 时，立即按新速度隔拍送出主属双音耳返与微弱节拍触觉，无需开启循环播放即可用耳朵感受律动快慢变化。

## 0.25.0 - 2026-11-24

- **双声部手鼓重音与动态间距柱 × 变奏三音即点耳返 × 曲库迷你唱片和弦彩环与发光卡片 · 创意炼金术第 18 轮重构**：
  - **节奏鼓四拍立体声韵律与按距宽窄节奏柱（`RhythmDrumAccentMapper`、`StudioViewModel` & `DreamCaptureSheet`）**：敲击「写旋律 · 节奏鼓」现按 4 拍强弱自动分配左右声像与 `1 / 3 / 5` 主属和声响度，每次轻击泛起金色环震波；已录节奏条按前后真实时距自动拉开宽窄比例并高亮每小节重拍，敲满两拍即可在鼓面右上角或旁白转子一键成曲。
  - **开头三音变奏即点试听（`StudioViewModel.previewSeedShift` & `DreamCaptureSheet`）**：「更多 · 变奏」微调前 3 音高低高度柱时，左中右立体声同步奏响变奏后实时音高与触觉微震，不靠想象靠耳朵微调。
  - **曲库迷你唱片和弦彩环与发光现播卡片（`MusicBoxShelfView`）**：「我的作品」与「28 首经典」统一采用主题色微光发光边框标出正在试听的黑胶卡片；迷你旋转黑胶盘缘嵌入预缓存的 4 幕彩色和弦环带并按播放进度同步点亮，Inline 试听同步送出掌心节拍脉冲。

## 0.24.0 - 2026-11-24

- **8 键琴席立体声场与共鸣箱泛音弦 × 盲人乐句跃迁与前奏速览 × 零文字撤销反馈 · 创意炼金术第 17 轮重构**：
  - **底栏琴席立体声场与木质共鸣箱泛音联动（`SympatheticResonanceMapper` & `StudioViewModel`）**：底栏 8 键木琴与自由演奏现按琴席从左至右展开真实立体声摆位（`-0.46` 到 `+0.46` 并随调式声学展宽同步微调）；奏响琴音时按 75ms 节流轻柔唤醒同调纯五度/八度泛音共鸣余韵，并点亮对应谐振琴键的细腻微光边缘与星点。
  - **盲人/零基础乐句级跃迁与开头速览（`PhraseNavigationMapper` & `OrbitalStageView`）**：为主画布 VoiceOver 转子新增「试听开头」「跳到下一句」「跳到上一句」三项快捷导航（共 10 项全能操作），选中音符时自动更新所在乐句与和弦边框光晕，旁白实时报读所在句数与情绪词。
  - **彻底清零例行文字提示（`StudioViewModel.undo`）**：撤销编辑不再弹出文字提示条，改用清脆机械触觉与瞬时声场重锚完成无字反馈。

## 0.23.0 - 2026-11-24

- **闭眼录曲即点试听与单音删改 × 星环力学响度响应 × 舞台声学状态标 · 创意炼金术第 16 轮重构**：
  - **闭眼滑音面板实时试听走带与单音删改（`NightLampTactileSheet` & `NightLampPhraseHelper`）**：在闭眼滑音面板新增一键试听播放/停止按钮（旁白转子同步支持「试听已录旋律」），试听时底部已录颗粒逐个高光闪烁并随双耳声像发声；点按任意颗粒即可单独试听，长按或旁白转子选择「删除此音」后后续节拍自动无缝前移补齐，落指滑奏或完成保存均自动打断试听绝不抢声。
  - **星环命中偏心距力学响度与亮度响应（`StarHitDynamicsMapper` & `OrbitalStageView`）**：弹奏星空盘星辰时计算落指到星心的距离，正中星心触发饱满清亮泛音共鸣，轻掠星缘则发出温和轻声余韵。
  - **舞台左上角统一极简声学状态标（`OrbitalStageView.activeFeaturesOverlay`）**：除伴唱与倍速外，开启音区移调（如 `+5` / `-2`）或节拍律动对齐时同步亮起紧凑视觉标识，无需文字说明，轻点直达声音设置调节。

## 0.22.0 - 2026-11-24

- **工作室级多轨乐器 MIDI 导出 × 曲线流光延音尾迹 × 明信片律动拍线同步 · 创意炼金术第 15 轮重构**：
  - **多通道通用乐器标准 MIDI 导出（`MIDIExporter`）**：按通道分配 General MIDI 原声乐器音色映射（`ch0` 钢琴/大提琴/竖琴/钢片琴、`ch1` 轻声伴奏、`ch2` 巴赫影子伴唱，配合强拍与跳音动态力度），在「关于与分享」页一键保留当前音色、伴奏、和声与伴唱导出给 GarageBand / Logic Pro。
  - **曲线流光延音尾迹（`OrbitalStageView`）**：把「曲线」视图里单色直方块尾迹升级为双层水平流光渐变拖尾，发声音符长尾瞬时绽放外柔光晕，声光视觉与「转盘」弧形长尾浑然一体。
  - **明信片律动拍线与移调印章同步（`VinylPostcardExporter`）**：离线生成的高清 PNG 明信片现自动同步转盘黄金辐射拍线、曲线拍点竖线与音区移调标记，分享图片所见即所得。

## 0.21.0 - 2026-11-24

- **木质琴房早期声学反射 × 曲线同步节拍竖线 × 上下文全息声场一致 · 创意炼金术第 14 轮重构**：
  - **早期木质沙龙交叉反射引擎（`FeltPianoSynth`）**：在实时音频合成器新增零堆分配 `2048` 样本双耳环形反射延迟线，为每颗发声的音符注入 `11ms / 17ms` 不对称经低通吸收后的木墙早期反射（并在停音时同步瞬时清零），大幅提升耳机与外放的近场立体包覆感与真木质温度。
  - **曲线主舞台节拍律动对齐竖线（`GrooveAlignmentEngine.beatTimestamps`）**：与转盘辐射拍线同源联动，在「微稳 / 整齐」模式下「曲线」视野同步随乐谱滚出温和黄金拍点竖线，每四拍重拍线高亮标示小节边界。
  - **上下文试音与切曲声场一致**：逐音微调前两拍连听（`playContextEcho`）、打开名曲跟弹及套用情绪风格时，即时同步对应 `AcousticSpaceProfile` 空间气候与双耳方位声像。

## 0.20.0 - 2026-11-24

- **全曲胸腔音区移调 × 无损弹性律动吸附与辐射拍线 × 掌心重拍呼吸 · 创意炼金术第 13 轮重构**：
  - **音区胸腔移调（`RootTranspositionHelper` & `StudioViewModel.setRootMIDI`）**：在声音面板新增一键音高重心档位（`−5 · −2 · 0 · +2 · +5` 半音），点按立刻试听共鸣五度和声；彻底保留原有简谱数字与指法色彩，却能瞬间将整首作品切换为温暖大提琴低音区或清亮晨铃音区。
  - **无损弹性节拍吸附与辐射拍线（`GrooveAlignmentEngine` & `StudioViewModel.setGrooveStrength`）**：针对哼唱、手敲或手绘形成的自由节奏旋律，提供「自由 / 微稳 / 整齐」三档平滑律动混合；开启后自动生成不毁坏原始时间轴的无损网格点，转盘表面同步浮现温和共转的黄金辐射拍线，所见所听一起微调入拍。
  - **掌心重拍呼吸脉冲（`AcousticHapticsEngine.playPlaybackNotePulse`）**：循环播放时每逢乐句首音与每四拍小节重拍送出深沉温厚的触觉呼吸重音，视障与听障用户在掌心即可直接摸出小节周期律动。

## 0.19.0 - 2026-11-24

- **有声手绘音画笔 × 曲库情绪光谱与立体声场 × 和声潮汐边框 · 创意炼金术第 12 轮重构**：
  - **单指手绘有声光墨画笔（`SketchPitchBrushMapper`）**：在「写旋律」画线板单指上下拖曳轨迹时，每划过调式安全音高即同步发出轻柔和弦铃声（左画左入耳、右画右入耳，含 `55ms` 防连响节流）与指尖微颤，线条化作带发光星端的彩色渐变音迹，“画一笔就听见一串旋律”。
  - **曲库情绪光谱快滤与同源空间试听（`MusicBoxShelfView`）**：28 首曲库顶部增设「梦幻 / 明亮 / 温暖 / 清新 / 忧郁」五色情绪色点快滤（点按即刻试听情绪琶音并自动跨类兜底，绝不空屏）；曲库内迷你黑胶试听同步启用 `AcousticSpaceProfile` 空间气候、`AcousticSpatialPanMapper` 立体声定位与摇摆律动拍点，让曲库耳朵体验对齐主舞台。
  - **主舞台和声大幕潮汐边框**：播放开启伴奏时，画布圆角边光与柔影随当前和声大幕色温平滑呼吸流转，不加任何文字即可靠色彩变化听懂和声走向。

## 0.18.0 - 2026-11-24

- **弦长物理阻尼律 × 琴条垂直柔揉光柱 × 盲人全能 7 项创作转子 · 创意炼金术第 11 轮重构**：
  - **跨音高声学弦长阻尼律（`PitchScaledAcousticEnvelope`）**：所有 5 种乐器音色在触发瞬间遵循物理弦长按音高缩放有效延音衰减与空气高频吸收——高音短促剔透如露水、低音宽厚共鸣如木箱（无音频渲染线程额外耗能）。
  - **底栏 8 键琴条垂直表现微光与轻揉颤音（`KeyRibbonExpressionMapper`）**：保留 8pt 点击与横滑零误触死区，按住任一琴键上下推拉可生长出白金水银光柱并激发 `±20` 音分柔和弦乐微颤，松手、滑邻键或离场瞬时平滑收音。
  - **旁白无障碍全能 7 项创作转子与和谐报读**：主画布转子补齐「延长当前拍」「缩短当前拍」并实时播报具体秒数；底部 8 键彩虹琴条主动播报「当前亮灯」「和谐音」状态，非视觉作曲与跟弹一气呵成。

## 0.17.0 - 2026-11-24

- **全息立体空间声场 × 调式声学气候 × 三态所见即所得明信片 · 创意炼金术第 10 轮重构**：
  - **调式声学空间气候（`AcousticSpaceProfile`）与全息声像定位（`AcousticSpatialPanMapper`）**：为「梦幻 / 明亮 / 温暖 / 清新 / 忧郁」五种情绪风格配备专属混响湿度、音板温暖阻尼与立体声展宽；播放时旋律随「转盘 / 曲线 / 星环」的当前视觉几何坐标柔和游走左右声道，巴赫伴唱以对称镜像方位轻声对答，左手伴奏自动在双耳铺开。
  - **三态所见即所得高清黑胶明信片（`VinylPostcardExporter` & `VinylPostcardShareSheet`）**：从主舞台任意视图分享作品时，离线导出画境直接同步「转盘星轨」「极光曲线山水」「双星星座星环」三种原生矢量版画，分享抽屉支持纯图标一键互切浅色/深色与三态版画。

## 0.16.0 - 2026-11-24

- **活体歌声光丝带 × 呼吸延音脉冲 × 黑胶试听进度环 · 创意炼金术第 9 轮重构**：
  - **实时哼唱活体光丝带（`LivePitchContourFilter` & `HumCapturePipeline`）**：在哼唱捕捉管线增加自适应 RMS 噪底门限、三点中值去毛刺滤波与实时音高追踪（`livePitchTrace`），让哼唱面板化作随歌声高低实时流动发光的曲线丝带（无文字即看清音高走势），并彻底清除残余旧提示用语。
  - **闭眼滑音呼吸延音脉冲（`TactileSustainStage`）**：按住音脊线停留跨越 `0.45s / 0.90s / 1.40s` 时，指尖触觉会发出轻柔节拍脉冲并向外绽放暖琥珀呼吸光圈，无需睁眼或文字即可感知短音与长音；同步扩充旁白（VoiceOver）转子支持快捷记录短音与长音。
  - **曲库黑胶试听进度环与实时点亮（`MiniOrbitalDiscPreview`）**：在曲库或自建作品列表点击迷你唱片试听时，外圈会流淌一圈顺时针暖金进度光弧，当前唱出的音符同步泛起金色高光，并与减弱动态效果（Reduce Motion）模式完整兼容。

## 0.15.0 - 2026-11-24

- **棱镜音程丝线 × 盲人可演奏主舞台 · 创意炼金术第 8 轮重构**：
  - **全舞台棱镜音程丝线（`IntervalSilkStyle`）**：在「转盘 / 曲线 / 星环」三大主舞台与离线黑胶明信片中，将单色调的旋律连线升级为起止双音渐变发光丝线，小级进轻盈流动、三度以上大跳自动加粗并亮起柔和外光晕，让旋律的高低落差与戏剧性跳跃零文字直观可见。
  - **旁白全功能主舞台操作**：为主画布直接接入 VoiceOver 可调节拍子滑动与五项转子快捷操作（播放/暂停、升高一音、降低一音、插入一拍、删除当前拍），配合五音安全跳跃与 `stageAccessibilitySummary` 实时播报，视障用户在主画布中央即可完成完整创作与编曲微调。

## 0.14.0 - 2026-11-24

- **弦振共鸣 × 纯净音高定锚 · 创意炼金术第 7 轮重构**：
  - **星环微揉弦与根音泛音共鸣**：在「星环」视图按住任意星辰轻微晃动即可唤醒 `±24` 音分柔和弦乐揉弦与主音共鸣托底（`HarmonicVibratoMapper`），伴随细微弓弦微震触感与同心驻波光环，松手、划出或切换视图时瞬时平滑收音防长鸣。
  - **全视野统一无字和声线索**：星环星辰与底部彩虹琴键共用底弧/底条白金和声微光；转盘、曲线与声纹明信片的 `1`（主音）与 `5`（属音）音高轨采用略厚光学线重定锚，助色弱与乐盲一眼定位音高坐标。
  - **彻底去字的黑胶明信片空盘设计**：将 [VinylPostcardExporter.swift](file:///Users/someone/Projects/chimmo/Chimmo/Domain/VinylPostcardExporter.swift) 空画布导引从文字彻底改为同心暖金呼吸引导环。

## 0.13.0 - 2026-11-24

- **活体声学共鸣体 · 创意炼金术第 6 轮重构（声音真实驱动画面与触感）**：
  - **实时声学包络共鸣**：`FeltPianoSynth` 音频渲染线程以无锁零分配方式实时输出响度、暖度与亮度三路包络（`AcousticEnvelopeSnapshot`），让转盘利萨如核心、陶瓷盘缘微光、旋律山河波形与星云中心直接随真实乐器声压一起呼吸缩放（严格尊重系统减弱动态效果开关）。
  - **五音色微声学雕琢**：细腻优化大提琴弓弦微滑起音、毛毡钢琴双弦立体声宽、竖琴拨弦泛音、温暖低音共鸣与八音盒音栓瞬态。
  - **琴键纵向力度表达与无字和弦微光**：点击或滑奏彩虹琴条上方声音更清亮有力、下方更轻柔温润，震动触感与音珠涟漪大小同步随力度呼吸；伴奏开启时，当前和弦对应的三个调内共鸣键底部会泛起柔和白金微光，不加任何文字即可靠眼睛看出哪些音最和谐。

## 0.12.0 - 2026-11-24

- **无字之乐 · 创意炼金术第 5 轮重构（声光引导取代说教文字）**：
  - 主舞台去掉顶部整行提示语、画布角落评分字样与外环绕圈文字，改用空盘同心呼吸引导环、选中音符径向滑轨、以及跟灯弹状态下从发光音符直连对应琴条的金色光桥曲线。
  - 所有琴键永久保留干净数字与几何图腾，按钮、浮条、视图切换与底部主键全面纯图标 / 极简数字雕塑化；清理例行操作弹窗。
  - **先响后选的声音设置**：点击任何情绪风格、乐器音色或伴奏，立刻弹出辨识度琶音与实声试音；辅助开关改为原生极简单行拨片，倍速仅保留 `0.65× / 0.85× / 1× / 1.25×`。
  - **可点即唱的黑胶曲库与无字创作**：28 首内置曲库隐藏两行赏析长文，点击迷你黑胶唱片即可原地旋转试听；节奏/画线、哼唱与闭眼滑音面板用虚线声波与高度能量柱取代文字说明。

## 0.11.0 - 2026-11-24

- **全面简化界面文案（大白话重整）**：去掉“捕梦、护网、火种、天光、陶诺/呜嘟、借景、凝结星珠、夜灯摸音”等生造词与晦涩比喻，统一替换为“写旋律、五音模式、伴奏、梦幻/明亮/温暖/清新/忧郁、转盘/曲线/星环、演奏、曲库、闭眼滑音”等一眼看懂的日常中文。
- **声音设置与和弦展示更直白**：精简音色、伴奏、调式与和弦色彩提示，保留全局零 Emoji 约束与所有核心音频/触觉/离线 PNG 导出功能。

## 0.10.0 - 2026-11-24

- 音频引擎真机无声彻底根治与创意炼金术第 3 轮重构（全局零 Emoji 定制设计语言 × 闭眼夜灯触觉剧场 × 离线黑胶明信片）：
  - 彻底修复真机无声故障（iOS 27 `error -10868`）：`FeltPianoSynth` 将混响输入与输出双端显式锁定为同一硬件采样率双声道格式、修正会话恢复通知反逻辑与全作用域配置监听，并新增混响失效时的直通免静音兜底与 180ms 首帧后后台预热
  - 全局清除全部 Emoji 符号，原创打造「窑陶 × 黄铜 × 光学几何」定制矢量设计语言（`ChimmoDesignLanguage`：`ChimmoCraftMark`、`ChimmoCraftBadge`、`ChimmoEditorialPill` 与公用无障碍图腾）
  - 全新「闭眼夜灯触觉剧场（Night-Lamp Theater）」：OLED 深曜夜幕 + Schmitt 迟滞防抖磁吸音阶脊线，闭眼单指滑寻音高、松手即落珠（停留越久拖音越长），完整支持 VoiceOver 转子记录
  - 美术馆级离线高清「黑胶星轨明信片 PNG」渲染导出（1080×1360 日光暖瓷 / 深夜曜蓝双版）与标准 `.mid` 一键分享，以及 28 首名曲一键「借天光」氛围移植

## 0.9.0 - 2026-11-23

- 创意炼金术第 2 轮精雕（星云万花筒 × 巴赫影子新月对位 × 掌心音乐触觉）：
  - 第三感官主舞台「✦ 星云万花筒（Resonance Nebula）」：8 颗釉面陶瓷星座音星环绕中央大尺度利萨如谐振星核，旋律化作流星沿星座轨迹飞舞，单指点按或滑过星辰即可即兴共鸣
  - 「👥 巴赫影子对位」正式登台：在星盘内偏轨与流动山河下方化作银蓝新月浮现（星云模式下亮起双星和声弧弦），主旋律留白呼吸处自动响起轻柔竖琴/钢片琴应答
  - 旋转星盘外环悬浮永远正立不倒置的四幕中文情绪锚词（归家 / 漫步 / 微光 / 托举 / 推力 / 怀旧），零乐理一眼看懂全曲情绪转折
  - 听障友好「🫀 掌心音乐触觉」与零跳变「⏱ 呼吸播放速度（0.65× ~ 1.25×）」：播放期间实时把音高质感与和声转折传递到掌心，慢放细品每颗音珠转动毫厘不跳帧
  - 修复 `ChimmoTests.testPlaybackClockAndScrubbing` 中折纸成诗 4 音种子生成 15 颗音珠的断言数量

## 0.8.0 - 2026-11-23

- 创意炼金术第 1 轮精雕（活体陶瓷玻璃声盘 × 零门槛魔法创作）：
  - 雕塑级陶瓷音槽唱盘：盘面新增 22 道同心声学微音槽、工作室柔光穹顶高光与 12 枚随盘旋转刻度锚点，配合 12 点钟双层拉丝黄铜唱针物理弹簧微颤与 8 颗零堆分配星尘迸溅微粒，每次音符发声都充满真实触感与生命力
  - 真实黑胶手摇惯性滑行：手推拨转声盘松手后按指数阻尼自然滑行约 0.35 秒，滑过音珠逐一唱响并伴随轻巧机械棘轮触感
  - 流动山河「湖面倒影」升级：28% 处固定金光束搭配柔光湖面倒影轮廓与迸溅星尘，在《天鹅》等名曲播放时呈现水天一色
  - 捕梦创作新增「魔法·跟弹」二合一面板：把短短 2～3 颗音珠一键「🌱 旋律折纸生长（爬楼 / 倒影 / 迟到半秒 / 四句成诗）」长成完整乐章，或直接拨动「🧅 大师 3 颗火种」即时生出专属个人变奏
  - 修复系统自动深色/浅色模式动态响应，日光暖瓷与深夜台灯随时丝滑切换

## 0.7.0 - 2026-11-23

- 彻底修复 iOS 27.3 / iPhone 17 首次打开卡死与闪退根因：将 `AVAudioEngine` / `AVAudioUnitReverb` 移至后台专用串行队列并按真机硬件采样率懒装配、音频渲染线程全面改为非阻塞尝试加锁（零优先级反转）、`CHHapticEngine` 改为全异步启动、移除全屏持续 15fps 背景重绘，并引入零 SwiftUI 视图广播的 `PlaybackClock` + `StageRippleBus`，实现瞬时启动与 120Hz 顺滑运行
- 全新旗舰「旋转音乐盒星盘（◎ 星盘）⇄ 流动山河（〰 山河）」双态声画主舞台：
  - 「星盘」随旋律真实平滑旋转，每颗音珠在发声瞬间精准行至正上方 12 点钟黄铜唱针下方绽放水波涟漪，圆心同步映照利萨如声学谐振花纹，还支持单指直接手摇搓盘、拖珠改高、点外环换和声；
  - 「山河」将金色光束锚定于屏幕 28% 处，让整片山河画卷随歌声平稳向左流淌，永远停留在视线中心不跑屏
- 顶级无障碍与零乐理包容重构：全曲珠与底部 8 键彩虹琴条采用「颜色 + 轨道高低 + 8 种独特几何图腾（● ■ ▲ ◆ ★ 💧 ✦ ◎）」三重编码（色盲友好），内置音高映射 Core Haptics 触觉反馈、完整 VoiceOver 语义读音与「减弱动态效果」自适应
- 全新精简 3 键「捕梦创作」抽屉：支持「敲节奏木鼓 + 单指一笔画山坡」、完全不怕跑调的「相对起伏轻哼捉珠」与「亮灯跟弹」
- 100% 原创工业设计级 App 图标（日光暖瓷 + 深夜曜蓝 + iOS 27 Tinted 钛金石英三态）：以雕塑感同心音乐盒声盘、光泽音阶宝石珠与黄铜唱针激起玻璃涟漪为核心意象，彻底告别家族换色旧稿

## 0.6.0 - 2026-11-23

- 全新 Moss & Otto 家族同脉 3D 软胶应用图标（日光暖纸 + 深夜台灯双态）：暖珊瑚软胶陶诺 + 大白眼黑瞳 + 弯曲发光金音符触角 + 实体四色彩虹蒙氏木琴，主屏幕一眼认出音乐感官玩具与家族 IP
- 极简大瘦身，告别一切抽象弥漫菜单：全 App 精简为「木琴画板 · 音乐盒」双标签实体玩具架构，打开即玩，零开场弹窗阻拦
- 全新「实体彩虹木琴 × 音乐盒打孔敲画板」：借鉴《摸索台灯》蒙氏木琴，左侧是 8 根下长上短、带双黄铜钉与敲击涟漪的彩虹木琴条（支持点按与上下滑奏），右侧是 1:1 严格对齐的打孔纸带与台阶数字线（+2↗ / -1↘ / =）
- 四大可视化防盲试神器，零基础 15 秒把脑放敲成准确旋律：
  1)「前后连听」：拖动音珠或点击左侧木琴条调音时，自动把「前两拍 → 这一拍」连着唱给你听，人耳 0.2 秒就能听出高了还是低了；
  2)「4 座山坡快选」：敲完节奏直接一键套用「↗ 爬坡 / ⌒ 拱桥 / ↘ 下坡 / 〰 波浪」，先选最像脑放的山坡再微调 1～2 拍；
  3)「💡 亮灯帮找」：像验光师一样每次只点亮左侧最搭的 3 根木琴条，告别 8 选 1 盲猜；
  4)「🎙 哼高低走势」：完全不管跑不跑调，只抓取你哼唱的相对升降贴合到已敲好的节奏拍子上
- 节奏全面灵活：底部内联木鼓直接边敲边看纸带立起拍柱，敲完后随时拖珠调前后时间、点「+ 插拍 / - 短 / + 长 / 删」自由增删改拍，底部只留 3 块直观心情积木（☀️晴朗 / 🌙微酸 / 🎋安心5音）
- 28 首公版与原创名曲彻底玩具化：在「音乐盒」点任意名曲（圣桑《天鹅》、巴赫、李斯特等）一键「✨ 亮灯跟弹」，跟着左侧发光彩条按自己的速度演奏，或直接拖珠改写

## 0.5.0 - 2026-11-23

- 全面融入 Moss & Otto 家族正典美学与温度：日光采用清亮暖白纸面（#F8F9FC）配柔和日光光柱与缓飘微粒，夜灯统一家族深夜蓝（#1B2245）配暖琥珀台灯光晕（#FFB84D）；所有七只咩哞永不贴对话气泡、只用呼吸与转眼温柔相伴
- 全新「4 秒无字点灯开场」：1·陶诺点亮暖光，踮脚微颤的 7·叮尖连着一根紧绷金丝，轻点一下瞬间蹦回陶诺身旁、大提琴与水波竖琴齐鸣释然归家（在桌面连点 1·陶诺 3 次可随时重温）
- 「桌面 · 声学房 · 手账册」三标签极简低认知架构：桌面只留今日剥洋葱名曲、声学小房、闭眼夜灯摸音与脑放捕捉三件套，底部永远摆着全尺寸活体呼吸七小只木架；完整精修工作台一键展开，不打扰第一眼宁静
- 颠覆性「名曲剥洋葱倒拆 + 换种重生」：默认打开圣桑《天鹅》（支持一键切换李斯特《爱之梦》、巴赫、柴可夫斯基《天鹅湖》、德沃夏克《念故乡》及全部 28 首公版/原创名曲），一根滑轨从 100% 完整织体剥回最初 3 颗火种，改写任意 1 颗火种再拉回 100% 瞬间长出属于你的大师变奏，伴随「声学余影」缓缓消散
- 6 间 OTTOSSOM 风格「零说教声学小房间」+ 蒙氏金色串珠链：《熄灯前回家》《换一盏脚下的灯》《拉住那半秒》《两根弦的莲花》《镜子湖的回声》《一根弦上的五片天》，先用指尖和掌心震动点亮暖灯，点亮后才可按需展开 1 行「💡 音乐家叫它…」注解
- 终极无障碍包容「闭眼夜灯摸音剧场」+「胶带声音明信片手账册」：深夜不刺眼，哪怕闭上眼睛单指上下滑动也能靠掌心磁吸触觉摸出旋律并自动无声录成贴着半透明纸胶带的斜角明信片，带着心情贴纸、旋律山水画与利萨如小印章，在纸面上直接点击回放

## 0.4.0 - 2026-11-21

- 全新「音符哲学馆」6 座全屏沉浸式声学装置：摒弃枯燥术语考卷，用眼睛、耳朵与 iPhone Core Haptics 掌心震动直接触摸音符世界的 6 条底层哲学——《一颗音的五种人生》（和声即关系）、《波纹对称与掌心震动》（连续双声波利萨如几何 × 触觉共振）、《半秒迟到，一滴泪诞生》（亲手按住延留音感受催泪释放）、《一根弦上的五片天空》（五色光谱）、《三颗音的折纸森林》（分形生长）、《圣桑水波与巴赫对话》（三声部 X 光混音台）
- 升级至 44 声部「五声部室内乐」音频引擎：新增带真实运弓呼吸与 5.1Hz 细腻揉弦的「歌唱大提琴」、晶莹「湖面竖琴」、双弦立体声「音乐厅毛毡钢琴」、「温暖低音」与「星光钢片琴」——圣桑《天鹅》、巴赫《G弦上的咏叹调》《大提琴前奏曲》、柴可夫斯基《天鹅湖》与德沃夏克《念故乡》全部换上深情歌唱大提琴与湖面竖琴水波
- 终极无障碍脑放捕手「敲拍画坡」：将「节奏心跳」与「音高坡度」解耦——五音不全或在公共场合不方便唱歌时，只需先在光感玻璃鼓面上敲出脑海里的节奏，再用一根手指一抹高低走势（支持「五声安全护网」绝不撞音），10 秒复现脑放旋律
- 「三层无障碍认知翻译透镜」+「五色天光光谱」：主画布顶部一键在「🌿诗意直觉 ⇄ 💠逻辑哲学（带实时利萨如波纹显微镜）⇄ 🎼音乐母语（动态半音窄缝实时迁移）」间自由切换；从「云端失重 → 晴空 → 落日余晖 → 森林晨雾 → 暮雨」滑过，每步恰好只让 1 只咩哞下降半格
- 「3 音种子折纸生长器」+「👥 巴赫影子对位副旋律」：脑海里只有短短几颗音也能一键「🌱爬楼模进 / 🪞水面倒影 / 💧迟到半秒 / ✨四句成诗」长成起承转合完整乐章，并随时召唤影子对位声部在长音留白处与你温柔对话
