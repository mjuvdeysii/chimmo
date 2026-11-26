# 《咩哞 · Mie & Mou》开发方法论与 Apple Design Awards 持续打磨宪法（v2.2）

> 文档状态：v2.2（V2.0 战略升维 · 从“音乐欣赏 + 旋律编曲”正式跃迁为「**咩哞 · Mie & Mou 脑波共振场**」，中英文定名 `咩哞 / Mie & Mou`；同步完备 TestFlight 外部公测审核合规链路；全局零 Emoji）。  
> 适用范围：iOS 主应用（SwiftUI / AVAudioEngine / CoreHaptics）、OpenMotion 互动官网与短片、IP 资产管线及 TestFlight 公测与上架交付链路。

---

## 核心总纲

**「声波共振，松绑大脑」（与姊妹作《摸索台灯 / Moss & Otto》同处一座温暖画室宇宙）**：
- **状态先行、零学习负荷**：彻底取消“上音乐课 / 交编曲作业”的功能认知负担，采用 Headspace 式空气感分时旅程 + 2x2 脑波状态入口 + 活体触声共振球 + Airbnb/Headspace 非说教档案页，3 秒触发即时体感舒缓与颅内战栗（Acoustic Frisson）；
- **同源共感、独立锋芒**：沿用摸索台灯同源日光棉纸（`#FBF7F0`）、深夜靛蓝（`#0E1430`）、温暖琥珀（`#FFB547`）、纯净纸卡（`#FFFFFF` / `#19213F`）、悬浮 Liquid Glass 导航与无障碍严谨标准；同时拥有咩哞专属窑陶红（`#C4513A`）、影青瓷（`#3D7A77`）与 100% 离线实时脑波 DSP + CoreHaptics 声触共振个性；
- **严格守门 1.4.1 非医疗与苹果隐私审计红线**：一切文案与文档严格界定为“声学放松、专注氛围与感官艺术体验（非医疗器械）”；强制要求 `PrivacyInfo.xcprivacy`（`CA92.1`）、后台音频合理启停、麦克风权限拒批无损替代路径及 100% 零联网探针通过。

---

## V2.0 四屏空气感架构（今日 · 共振 · 探索 · 我的）

1. **Tab 0 · 今日（`TodayJourneyView`）**：顶部弧形渐变天幕 + 「最近共振 / 我的收藏」快捷胶囊 + 3 步纵向今日脑波旅程阶梯 + 此刻精选推荐。
2. **Tab 1 · 共振（`ResonanceFieldView`）**：核心「脑波快感」活体触声场。覆盖 `Delta 2.5 Hz / Theta 6.0 Hz / Alpha 10.0 Hz / Gamma 40.0 Hz` 双耳差频（外放自动切换温和等时脉动）；轻点播停、左右滑频、长按蓄力松手引爆五度/八度泛音战栗瀑布；3 秒轻哼锁住个人自然声纹（未开麦自动提供三档人声预设）。
3. **Tab 2 · 探索（`ExploreResonanceView`）**：2x2 状态直达格 + 「闭眼夜灯零光盲操」特别体验卡 + 8 首精选「颅内战栗 · 声波乐章胶囊」 + 12 套离线声景配方 + 完整 28 首典藏曲本入口。
4. **Tab 3 · 我的（`ProfileSanctuaryView`）**：弧形天幕双子星身份 + Airbnb 洁净三项沉淀卡 + 非说教温暖陪伴语 + 声学家族与夜灯微缩双卡 + 三态外观预览 + 触觉/锁屏后台偏好 + 「声学安全与非医疗声明 (`ChimmoAcousticSafetyView`)」及法务文档中心。

---

## 一、六大核心方法论支柱（v2.0 Spin-Off Canons）

### 1. 四屏纯血叙事架构（聆听 · 创作 · 曲本 · 工坊）
模仿并呼应《摸索台灯》四标签叙事节奏，彻底终结功能混杂与迷宫层级：
1. **Tab 0 · 聆听（`ChimmoTab.showcase` · `OrbitalStageView`）**：非破坏性音乐剧场。精简为「顶部选曲调音头栏 -> 纯净绘本主舞台卡 -> 故事分幕导览条 -> 七小只彩键 + 软胶主控坞」四块纯净区块，默认展示山坡乐谱舞台（兼可切换音乐盒花环与星环），`allowsEditing: false` 严防误改名曲，仅 via 显式「去改编」复制至创作域。
2. **Tab 1 · 创作（`ChimmoTab.create` · `CreateStudioView`）**：独立无冲突编曲画室。去除顶栏冗余跳转键，空画布提供直达「轻哼一段旋律」与三颗软胶灵感种子；收拢工具条为「轻哼捕音 / 节奏灵感 / 音色和声」三键；底部常驻高对比窑陶「保存作品」与「试听 / 停止」软胶主控。
3. **Tab 2 · 曲本（`ChimmoTab.songbook` · `MusicBoxShelfView`）**：一等公民作品阁与 28 首典藏曲库。分类与心情筛选全数升级为 `ChimmoFlowRow` 自适应折行（零横向滚动截断），支持内联试听、一键切换至聆听跟灯或进入创作改编。
4. **Tab 3 · 工坊（`ChimmoTab.settings` · `SettingsView`）**：对标商业级 Apple HIG 与《摸索台灯 · YouView》打造——品牌身份卡、主题哲学横幅（直通 `CharacterSoundTestView`）、日光/夜灯/自动三联画布预览卡、声学偏好卡片，以及原生结构化 `ChimmoLegalDocumentView`（隐私政策、使用条款、开源与曲库鸣谢）。

### 2. 窑陶棉纸 × 哑光软胶视觉语言（告别浓墨重边与假按钮）
- **褪去浓墨描边**：用柔和的纸卡接触阴影（`ChimmoAtelierCardModifier`）、细腻顶部受光微沿与低饱和彩色光洗替代厚黑轮廓线与笨重偏移色块，使界面平静耐看。
- **嵌套圆角与留白纪律**：全站严格统一 `ChimmoRadius`（`stage: 28` > `card: 22` > `inner: 16` > `tile: 14` > `chip: 10`）与 `16pt` 呼吸边距；各标签背景光洗严格受系统「减弱透明度（`accessibilityReduceTransparency`）」门控。
- **两极交互语义不变**：只读信息标签采用纯净胶囊/微字号底色，绝不冒充实体立体按键；一切交互按钮坚持 `>= 40–44pt` 可触热区与 `.contentShape(...)`，杜绝误触发与穿透。

### 3. 零横向滚动与无摩擦手势人体工学
- 曲库标签与工坊身份徽章全部使用 `ChimmoFlowRow` 自动换行，杜绝横滑筛选条与纵向滚动抢手势或边缘裁字；
- 赏析与创作双空间各持独立快照 `WorkspaceSnapshot` 与 `hasUnsavedCreationChanges` 脏状态追踪，从「曲本」跳转到任意空间前务必先同步目标 `StudioSpace`，防止快照回溯覆盖新选曲目。

### 4. 深度克制的 IP 有机融合（Non-Intrusive Living IP）
- 小羊 **咩（`Mie`）** 司职主旋律，小牛 **哞（`Mou`）** 司职低音与四幕和弦织体，`1–7` 七声小偶（`Taono / Doko / Plokko / Udo / Corllo / Bomo / Tinki`）将首调音级力学转化为姿态、耳翼微笑/垂耳与微光。
- **表达红线**：全员 **绝对不说话（零气泡、零字幕、零嘴型）**，只用真实声学触发后的呼吸、倾角与微光回应。

### 5. Apple Design Awards 工艺、无障碍与硬件键盘联动
- **全维度无障碍闭环**：全站动画 100% 受 `accessibilityReduceMotion` 门控；顶部光洗受 `accessibilityReduceTransparency` 门控；标准 UI 字号全面使用语义 Dynamic Type（`.headline / .subheadline / .footnote / .caption / .caption2`）配合 `.minimumScaleFactor` 与无障碍大字号纵向重排；
- **双空间硬件快捷键**：聆听空间支持 `Space` 播停；创作空间支持 `Space` 试听、`Cmd+S` 保存、`Cmd+Z` 撤销、`Cmd+N` 新建，各随 `activeSpace` 动态激活，互不抢键；
- **全局零 Emoji 与零例行 `statusToast`**。

### 6. 流水线化零模拟器 CI 节奏与窗口交接纪律
- **本机构建红线**：严禁启动、构建或调用 iOS Simulator；仅使用无模拟器编译门禁检验全工程与测试目标：
  `set -o pipefail && xcodegen generate && xcodebuild build-for-testing -project Chimmo.xcodeproj -scheme Chimmo -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGNING_IDENTITY=""`
  要求输出 `** TEST BUILD SUCCEEDED **`、`0` error、`0` Swift/Xcode 编译警告。
- **错峰推包铁律**：静默查询 GitHub Actions 队列，绝不在运行中强推覆盖；等待期间并行本地打磨下一轮，绿灯后稳步送测。

---

## 二、每轮提交前自检清单（Pre-Commit Self-Audit）

1. **四域与快照边界**：`聆听 / 创作 / 曲本 / 工坊` 切换与跨页跳转（尤其从曲本进入聆听或创作）是否正确保序不回滚？
2. **软胶质感与触控热区**：全站卡片是否统一 `.chimmoAtelierCard`（无杂乱浓黑外框），全部操作按钮是否 `>= 40pt` 且带 `.contentShape(...)`？
3. **零横向滚动筛选**：曲库与工坊标签是否采用 `ChimmoFlowRow` 自动折行，无 `ScrollView(.horizontal)` 筛选栏？
4. **无障碍与自适应**：是否保持 `UNGATED_MOTION_HITS == 0`、`accessibilityReduceTransparency` 支持、Dynamic Type 与完整中文 VoiceOver 标签/提示？
5. **全局零 Emoji 与零警告构建**：源码、单测、`docs/`、`project.yml`、`CHANGELOG.md` 新增行零 Emoji，且无模拟器 `build-for-testing` `0 error / 0 warning`。
