# 咩哞 · Mie & Mou TestFlight 外测与公测发布指南

## 一、发版前置自动化核验

在推送至 Apple TestFlight 之前，工作流会在本地及云端自动执行 [`Tools/ci_guard.py`](../Tools/ci_guard.py) 与完整单元单测，强制拦截以下任一越界：

1. **隐私与清单完整**：
   - [`Chimmo/Resources/PrivacyInfo.xcprivacy`](../Chimmo/Resources/PrivacyInfo.xcprivacy) 仅申报 `NSPrivacyAccessedAPICategoryUserDefaults (CA92.1)` 与 `NSPrivacyAccessedAPICategorySystemBootTime (35F9.1)`，零未申报 Required Reason API。
   - [`Chimmo/Resources/Info.plist`](../Chimmo/Resources/Info.plist) 已申报 `ITSAppUsesNonExemptEncryption=false`、`audio` 后台能力、`NSMicrophoneUsageDescription` 及 `NSPhotoLibraryAddUsageDescription`。
   - [`Chimmo/Resources/InfoPlist.xcstrings`](../Chimmo/Resources/InfoPlist.xcstrings) 与 [`Chimmo/Resources/Localizable.xcstrings`](../Chimmo/Resources/Localizable.xcstrings) 完整覆盖 `zh-Hans` / `en` 双语，三版 `1024×1024` sRGB 不透明应用图标无透明通道。
2. **非医疗与安全文案对齐**：
   - 应用内 [`Chimmo/Views/AtelierLegalViews.swift`](../Chimmo/Views/AtelierLegalViews.swift)、官网页 [`docs/terms.html`](terms.html) 与端外商店文本均清晰声明非医疗器械定位（Apple Guideline 1.4.1）以及 40 Hz 高频与纯自然声床使用说明。
3. **无网络请求验证与工具链测试**：
   - 云端 CI 工作流 [`.github/workflows/ios.yml`](../.github/workflows/ios.yml) 内置 Zero-network 探针（强制验证 `shots/net_raw.log` 生成并断言零外联条目）及 [`Tools/tests/test_asc.py`](../Tools/tests/test_asc.py) 离线单测（覆盖 JWT/DER 解析、429/503/401 退避重试、Build 号单调递增与送审联系信息预检）。

## 二、云端构建与 TestFlight 分发流程

- **路径门控的 `main` 构建**：推送至 `main` 时仅当 `Chimmo/` 或 `project.yml` 发生变更才触发 `testflight` 归档与上传；纯文档或官网改动只跑静态门禁与单测验证。Build 号通过 `Tools/asc.py next-build-number` 自动取 ASC 现有最高构建号 +1 与运行号下界的较大值，保证严格单调递增。
- **凭据最小化隔离**：临时 `.p8` 私钥在 `$RUNNER_TEMP` 下以 `umask 077` / `600` 权限落盘，并在 `always()` 步骤中连同归档产物一并清除；Action 依赖全部锁定至不可变 Commit SHA 且禁用 `persist-credentials`。
- **手动触发 (`workflow_dispatch`) 精细控制**：
  - `upload_testflight`（默认 `true`）与 `existing_build`：允许直接复用已上传的 Build 号补充同步双语说明或送审，免重复编译上传。
  - `sync_beta_metadata=true`：仅同步双语 Beta 应用描述、反馈邮箱与审核联系人（支持从同一开发者团队名下已有 App 记录零 PII 自动继承缺失字段），不提交外部公测审核。
  - `audit_only=true`：仅运行只读 App Store Connect 公测就绪审计。
  - `extract_filing_cert=true`：仅在需要备案 SHA-1 与公钥时按需导出本地 IPA 提取证书指纹。
  - `submit_public_beta=true`：强制启用 `--strict` 预检并关闭静默容错——若缺少外部审核必填联系人或反馈邮箱，工作流直接显式报错阻断。

## 三、外部公测送审前必配 Secrets 与 ASC 检查

向外部群组提交 TestFlight 公测审核（`submit_public_beta=true`）或同步元数据（`sync_beta_metadata=true`）前，请在 GitHub 仓库 `Settings -> Secrets and variables -> Actions` 或 App Store Connect 网页端确认：

1. **核心签名与接口凭据**：`ASC_KEY_ID`、`ASC_ISSUER_ID`、`ASC_KEY_P8`、`APPLE_TEAM_ID`。
2. **外部测试审核与反馈联系人**：
   - `BETA_FEEDBACK_EMAIL` 与 `BETA_CONTACT_EMAIL`（用于 `BetaAppLocalizations` 双语反馈邮箱与审核联系邮箱，可在仓库 Secrets 中按需覆写）。
   - `BETA_CONTACT_FIRST`、`BETA_CONTACT_LAST`、`BETA_CONTACT_PHONE`（可选覆写；若目标 App 未填写且未配置独立 Secret，工具默认从同一开发者账号下已有 App 的审核联系人自动继承，且全程不向终端或日志打印任何个人联系字段值）。
3. **App Store Connect 应用名称对齐**：建议确认 ASC 后台显示名已从早期旧名同步为「咩哞」/「Mie & Mou」，以与 [`InfoPlist.xcstrings`](../Chimmo/Resources/InfoPlist.xcstrings) 及官网保持一致。
