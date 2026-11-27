# 咩哞 · Mie & Mou TestFlight 外测与公测发布指南

## 一、发版前置自动化核验

在推送至 Apple TestFlight 之前，必须确认仓库通过以下全部静态与编译门槛：

1. **隐私与清单完整**：
   - [`Chimmo/Resources/PrivacyInfo.xcprivacy`](../Chimmo/Resources/PrivacyInfo.xcprivacy) 已申报 `NSPrivacyAccessedAPICategoryUserDefaults (CA92.1)` 与 `NSPrivacyAccessedAPICategorySystemBootTime (35F9.1)`。
   - [`Chimmo/Resources/Info.plist`](../Chimmo/Resources/Info.plist) 已申报 `ITSAppUsesNonExemptEncryption=false`、`audio` 后台能力、`NSMicrophoneUsageDescription` 及 `NSPhotoLibraryAddUsageDescription`。
   - [`Chimmo/Resources/InfoPlist.xcstrings`](../Chimmo/Resources/InfoPlist.xcstrings) 与 [`Chimmo/Resources/Localizable.xcstrings`](../Chimmo/Resources/Localizable.xcstrings) 完整覆盖 `zh-Hans` / `en` 双语。
2. **非医疗与安全文案对齐**：
   - 应用内 [`Chimmo/Views/AtelierLegalViews.swift`](../Chimmo/Views/AtelierLegalViews.swift) 与官网页 [`docs/terms.html`](terms.html) 均清晰声明非医疗器械定位（Apple Guideline 1.4.1）以及 40 Hz 高频与光声敏人群注意事项。
3. **无网络请求验证**：
   - 云端 CI 工作流 [`.github/workflows/ios.yml`](../.github/workflows/ios.yml) 内置 Zero-network 探针，若捕获任何由 `Chimmo` 进程发起的外部连接请求将直接判败。

## 二、云端构建与 TestFlight 分发流程

- 日常推送至 `main` 分支会触发云端 `build` 与 `testflight` 流水线自动打包归档（仅使用仓库 Configured Secrets 凭据，结束时自动清理临时 `.p8` 密钥）。
- 如需同步公测说明与外部测试群组，请通过 GitHub Actions 手动运行 `workflow_dispatch` 并勾选 `submit_public_beta=true`，流水线将调用 [`Tools/asc.py`](../Tools/asc.py) 等待 Build 变为 `VALID`，推送简体中文 (`zh-Hans`) 与英文 (`en-US`) 更新日志与审核备注后提交外部群组公测审核。
