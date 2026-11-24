# 《咩哞琴盒 · Mie & Mou》开发方法论与 Apple Design Awards 持续打磨宪法（v2.1）

> 文档状态：v2.1（Round 74 · 正式确立中英文命名「咩哞琴盒 / Mie & Mou」对标姊妹作《摸索台灯 / Moss & Otto》，保留 `app.chimmo` 与 `Chimmo` 家族代号；全局零 Emoji）。  
> 适用范围：iOS 主应用（SwiftUI / AVAudioEngine）、OpenMotion 互动官网（`docs/index.html`）与导演动画短片、IP 资产管线及 TestFlight 持续交付链路。

---

## 核心总纲

**「轻哼成曲，七声和鸣」**（与姊妹作《摸索台灯 · 孩子摸索，大人点灯》同处一座温暖画室宇宙）：
- **同源共感**：沿用同一套日光棉纸（`#FBF7F0`）、深夜天鹅绒靛蓝（`#0E1430`）、温暖台灯琥珀（`#FFB547` / `#CF8420`）、可印刷纸卡（`#FFFFFF` / `#19213F`）、柔和软胶触控物理、嵌套圆角尺度与商业级透明工坊格局；
- **独立锋芒**：保留「咩哞琴盒 · Mie & Mou」专属窑陶赤陶主色（`#C4513A` / `#F08A6C`）、呜嘟影青瓷辅助色（`#3D7A77` / `#7EC8C3`）、章首窑陶共鸣珠（`ChimmoResonanceBead`）、双子星与调内 1–7 七声小偶互动舞台，让人一眼认出「同一位创作者手下的衍生声学绘本」，却又有耳目一新的律动个性。

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
