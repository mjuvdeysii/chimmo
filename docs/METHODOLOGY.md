# 咩哞 · Mie & Mou 声学工程与零依赖方法论

## 一、严格半双工音频状态机（[`HalfDuplexAudioRouter`](../Chimmo/Audio/HalfDuplexAudioRouter.swift)）

- **播放态 (`.playback`)**：采用独立 `.playback` 类别与 `.longFormAudio` 路由策略（无 `.mixWithOthers`），确保 AirPods 蓝牙 A2DP 48 kHz 立体声保真输出及锁屏/控制中心 `MPRemoteCommandCenter` 正常响应。
- **采集态 (`.recording`)**：切换 `.playAndRecord` + `.measurement` 模式，在激活 `AVAudioSession` 之前优先选择机身内置麦克风，隔离蓝牙 HFP 通话采样率降级；结束或意外中断后自动回调恢复播放路由。
- **耳机识别准确性**：明确区分真实立体声耳机路由（`.headphones` / `.bluetoothA2DP` / `.bluetoothLE` / `.usbAudio`），排除单声道 `.bluetoothHFP` 与手机外放，按真实设备物理通路切换双耳差频与等时脉动。
- **中断与拔插保护**：完整处理 iOS 27 `resumptionRecommendationNotification`（仅 `.shouldResume` 自动恢复；`.shouldNotResume` 静默暂停并同步 UI）、`mediaServicesWereResetNotification` 以及拔除耳机 `.oldDeviceUnavailable` 安全暂停。

## 二、无锁实时声学合成与分离通道（[`FeltPianoSynth`](../Chimmo/Audio/FeltPianoSynth.swift)）

- **采样率无关滤波器**：每次音频回调先依据实际硬件采样率计算一阶平滑系数与噪声滤波器衰减参数，确保 44.1 kHz、48 kHz 与 96 kHz 音色包络一致。
- **纯净双耳干声通道隔离**：左右声道双耳正弦差频信号绕过 11 ms / 17 ms 跨声道早期反射缓存直接混合输出，防止双耳频率互相串联串扰；同时解除外放等时脉动 14 Hz 上限，支持完整 1.5–42 Hz 节律调谐。
- **无缝跨周期相位保护**：所有瞬态与持续正弦振荡器仅对整数倍频或独立累加相位的泛音执行整数周期回绕，杜绝多小时连续播放时的相位跳变杂音；引擎休眠或录音切换前均执行 15 ms 零交叉淡出。

## 三、离线轻量音高提取（[`PitchDetector`](../Chimmo/Audio/PitchDetector.swift)）

- **纯 Swift + Accelerate/vDSP YIN**：零第三方二进制模型依赖，使用前置柔和 AGC 提升轻声哼唱追踪灵敏度的同时，保留未缩放真实 `-46 dBFS` RMS 静音门限，避免静默房间的环境噪底误锁定。
- **跨设备音高折叠**：将人声自然基频平稳折叠回 `120–260 Hz` 温暖载波窗口，兼顾耳机双耳差频舒适响度。

## 四、高能效实时绘制与离线导出

- **按需时间轴**：主舞台 `TimelineView` 仅在激活「声场」页且音频播放/按压蓄力时开启高刷动画；后台、`Reduce Motion` 或非激活标签页均即时暂停渲染与触觉引擎。
- **异步明信片渲染**：[`ResonanceCardExporter`](../Chimmo/Domain/ResonanceCardExporter.swift) 在后台线程离线绘制 `1080×1350` 不透明 sRGB PNG 图像，无主线程掉帧。
