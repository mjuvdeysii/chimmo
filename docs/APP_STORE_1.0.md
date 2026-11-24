# 咩哞琴盒 · Mie & Mou｜App Store 1.0 提审与建项资料包

直接复制以下字段填入 [App Store Connect](https://appstoreconnect.apple.com) 即可完成新 App 创建与提审配置。

---

## 1. 新建 App 必填四项（App Store Connect → 我的 App → `+` 新建 App）

- **平台**：`iOS`
- **名称（简体中文）**：`咩哞琴盒`（若想带副标题检索词可用：`咩哞琴盒 - 轻哼成曲，七声和鸣`）
- **主要语言**：`简体中文 (Simplified Chinese)`
- **套装 ID (Bundle ID)**：`app.chimmo`（CI 已自动通过 App Store Connect API 注册）
- **SKU**：`chimmo`
- **用户访问权限**：`完全访问权限`

---

## 2. 应用信息与网址（GitHub Pages 自动托管）

- **副标题（简体中文，30 字内）**：`把脑海里的旋律唱出来、看得见`
- **应用名称（English）**：`Mie & Mou`
- **副标题（English，30 chars max）**：`Hum & See Your Melodies`
- **主分类**：`音乐 (Music)`
- **副分类**：`教育 (Education)` 或 `娱乐 (Entertainment)`
- **年龄分级**：`4+`（无不良内容、无账号、无联网、无广告）
- **技术支持网址 (Support URL)**：`https://mjuvdeysii.github.io/chimmo/`
- **营销网址 (Marketing URL)**：`https://github.com/mjuvdeysii/chimmo`
- **隐私政策网址 (Privacy Policy URL)**：`https://mjuvdeysii.github.io/chimmo/privacy.html`

---

## 3. 推广文本与描述（简体中文）

### 推广文本（170 字内）
脑海里突然冒出一段旋律，却不会五线谱也不会乐器？对「咩哞琴盒」轻轻哼一声，七只哑光窑陶音级小偶就会把它凝结成纸上看得见的音珠，再托起一汪温暖的现代和声。完全离线，无账号，无广告。

### 描述
你有没有过这样的时刻：走在路上或临睡前，脑子里忽然转着一段很好听的旋律；或者听一首喜欢的曲子时，好奇编曲家眼里的音符到底长什么样？

「咩哞琴盒（Mie & Mou）」把复杂的五线谱和乐理藏在身后，换成了坐在矮木架上的**七只哑光窑陶声学小偶**——它们正好对应调里的 `1 2 3 4 5 6 7` 七个音级：
· 1 号 陶诺（家）：稳重的赤陶倒钟，旋律落到他身上，整句就回到了家
· 2 号 豆叩（迈步）：微微前倾的暖杏小木鱼，走出家门的第一步
· 3 号 拍咯（晴雨）：胭脂珊瑚不倒翁，大调双耳轻扬、小调微垂，一眼看懂晴雨情绪
· 4 号 呜嘟（悬步）：影青瓷小陶笛，轻轻吸一口气的悬浮感
· 5 号 壳咯（远望）：宣瓷螺旋号角贝，和 1 号一起撑起整句的天空
· 6 号 钵莫（怀旧）：焙赭陶小手碟，副歌里最温柔微酸的阴影
· 7 号 叮尖（踮脚）：永远踮着脚朝 1 号倾斜的尖芽，让你一眼看懂什么叫“张力与解决”

**主要特性**
· 轻哼捉珠：用轻柔的 da / la 哼出旋律，端侧离线引擎瞬间将声音凝结为纸面陶珠；唱偏的音旁会浮现半透明“幽灵备选珠”，一指轻点就能吸准，也可以直接上下微拖修音。
· 边听边拍定重拍：录音时不用被节拍器束缚；回放时轻拍空白纸面 4 下即可对齐心跳速度，还能在“自然呼吸”与“工整律动”之间无损滑动。
· 水面托底现代和声：一键托起底部水面，切换「毛毡暖阳」「透明水波」「电影微光」三种现代开放和声色温，亲眼看见同一颗旋律音珠随底层和声变化亮起张力弦丝。
· 16 首可拆解编曲标本：内置 8 首自编公版古典（巴赫、萨蒂、德彪西、肖邦等）与 8 首原创现代编曲技法标本（四度悬浮、City Pop 2-5-1、下行低音楼梯等），支持单听主旋律、单听水面和声、0.5× 慢放，还能把标本的和声色温一键借给自己的旋律。
· 日光与夜灯：白天是温润的暖棉纸手账，夜里是深夜蓝与微亮的金珠；支持导出标准 MIDI（.mid）文件继续在 GarageBand 或 Logic Pro 中编曲。
· 纯净离线：不需要注册账号，不连接网络，不收集任何个人数据，无广告。

### 关键词（100 字符内）
哼唱,作曲,编曲,旋律,音乐可视化,乐理,钢琴,音准,和弦,八音盒,灵感,录音,MIDI,单机,治愈

---

## 4. App 隐私营养标签（App Privacy）

- **数据收集**：选择 **「不收集数据 (Data Not Collected)」**（工程内已内置 `PrivacyInfo.xcprivacy` 且 CI 每次运行零联网探针核查）。

---

## 5. App Review 审核备注（Review Notes）

```text
Thank you for reviewing Mie & Mou (咩哞琴盒).

1. No Account & 100% Offline:
   Mie & Mou runs completely offline on the device. No login, account, or internet connection is required.

2. How to Test Core Features:
   - Browse & Deconstruct Specimens: Tap "标本" (Specimens) in the top-left toolbar to explore 16 built-in interactive musical arrangements, toggle "单听旋律 / 单听水面 / 完整合奏" to isolate melody vs. harmony, or switch between Daylight and Night-Lamp themes.
   - Play the 7 Chimmos: Tap or slide across the 7 ceramic characters at the bottom shelf to play notes in key with real-time felt-piano synthesis and modern open-voicing harmony.
   - Hum to Melody: Tap "轻哼捉珠" at the bottom center and hum a short melody using "da / la" syllables. When stopped, your hummed melody condenses into interactive ceramic beads on the paper scroll with one-tap ghost-bead pitch correction.
   - Export MIDI: Tap the info icon in the top-right toolbar to export the current melody and harmony as a standard .mid file.
```
