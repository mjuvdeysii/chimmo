# 咩哞 · Mie & Mou (`app.chimmo`) App Store 审核与上架核对单

## 一、元数据与分类定位

- **Bundle ID**: `app.chimmo`
- **产品名称**: 简体中文 `咩哞` / English `Mie & Mou`
- **App Store 分类**:
  - **Primary Category**: `Music`（音乐）
  - **Secondary Category**: `Lifestyle`（生活）
- **定界红线（Apple Guideline 1.4.1）**:
  - 明确界定为 **纯离线声音艺术、环境声景与室内乐放松陪伴工具（非医疗器械）**。
  - 全站与商店元数据严禁出现医疗诊疗功效词（如临床康复、诊断干预、病理改善等医疗用语）。

## 二、权限与隐私清单核验（Privacy & Guidelines §2.5 / §5.1）

| 检查项 | 实际配置位置 | 用途与合规说明 |
| :--- | :--- | :--- |
| `ITSAppUsesNonExemptEncryption` | [`Chimmo/Resources/Info.plist`](../Chimmo/Resources/Info.plist) | `false`（纯离线合成，无自研网络加密） |
| `UIBackgroundModes` | [`Chimmo/Resources/Info.plist`](../Chimmo/Resources/Info.plist) | `audio`（支持锁屏继续播放与睡眠渐弱定时收尾） |
| `NSMicrophoneUsageDescription` | [`Chimmo/Resources/Info.plist`](../Chimmo/Resources/Info.plist) / [`InfoPlist.xcstrings`](../Chimmo/Resources/InfoPlist.xcstrings) | 仅在用户主动点按「轻哼找同频」时临时采样计算基频，内存处理不落盘、不上传 |
| `NSPhotoLibraryAddUsageDescription` | [`Chimmo/Resources/Info.plist`](../Chimmo/Resources/Info.plist) / [`InfoPlist.xcstrings`](../Chimmo/Resources/InfoPlist.xcstrings) | 仅在用户主动点选「存入相册」保存生成的静态 1080×1350 PNG 共振卡片时触发，从不读取相册 |
| `NSPrivacyAccessedAPICategoryUserDefaults` | [`Chimmo/Resources/PrivacyInfo.xcprivacy`](../Chimmo/Resources/PrivacyInfo.xcprivacy) | 原因代码 `CA92.1`（保存外观偏好、收藏与本地分钟统计） |
| `NSPrivacyAccessedAPICategorySystemBootTime` | [`Chimmo/Resources/PrivacyInfo.xcprivacy`](../Chimmo/Resources/PrivacyInfo.xcprivacy) | 原因代码 `35F9.1`（单调音频与交互节奏时钟 `CACurrentMediaTime`） |
| `NSPrivacyTracking` | [`Chimmo/Resources/PrivacyInfo.xcprivacy`](../Chimmo/Resources/PrivacyInfo.xcprivacy) | `false`，空跟踪域与空采集数据类型 |

## 三、双语完整性与资产检查

- `Chimmo/Resources/Localizable.xcstrings` 完整覆盖简体中文 (`zh-Hans`) 与英文 (`en`) 所有界面、语音无障碍（VoiceOver）及安全披露文本。
- `AppIcon.appiconset` 包含经过 `sips` 校验的三套不透明 sRGB `1024×1024` 图标（Light / Dark / Tinted）。
- 数据导出仅支持静态 PNG 卡片分享与写入相册，无未实装占位菜单或失效导出入口。

## 四、支持与法律页

- 交互展示与支持主页：[docs/index.html](index.html)
- 隐私声明：[docs/privacy.html](privacy.html)
- 使用条款与 40 Hz 安全留意：[docs/terms.html](terms.html)
- 公版古典曲谱致谢：[docs/licenses.html](licenses.html)
