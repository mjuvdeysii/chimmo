import SwiftUI

public enum ChimmoLegalDocumentKind: String, Identifiable, Sendable {
    case privacy
    case terms
    case licenses

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .privacy: return String(localized: "legal_privacy_title", defaultValue: "隐私与安全声明")
        case .terms: return String(localized: "legal_terms_title", defaultValue: "使用条款")
        case .licenses: return String(localized: "legal_licenses_title", defaultValue: "公版谱源与致谢")
        }
    }

    public var subtitle: String {
        switch self {
        case .privacy: return String(localized: "legal_privacy_sub", defaultValue: "100% 本地离线 · 零追踪 · 无账户")
        case .terms: return String(localized: "legal_terms_sub", defaultValue: "非医疗声明 · 自愿收听 · 知识版权归你")
        case .licenses: return String(localized: "legal_licenses_sub", defaultValue: "公版古典名作与自研音频数学")
        }
    }

    public var sections: [(heading: String, body: String)] {
        switch self {
        case .privacy:
            return [
                (
                    String(localized: "legal_p_h1", defaultValue: "一、100% 本地离线，无网络请求"),
                    String(localized: "legal_p_b1", defaultValue: "「咩哞 · Mie & Mou」运行于完全本地离线架构：不集成任何第三方统计、广告、崩溃追踪 SDK，不包含账户体系或服务器同步，您的所有设置与声场参数只保存在本机系统存储中。")
                ),
                (
                    String(localized: "legal_p_h2", defaultValue: "二、麦克风与照片权限边界"),
                    String(localized: "legal_p_b2", defaultValue: "1. 麦克风仅在您主动开启「轻哼找同频」时临时采样计算基频（Hz），纯内存瞬时处理后即刻释放，从不落盘、从不上传。\n2. 相册添加权限仅在您主动点击「存入相册」时将生成的静态 PNG 卡片写入相册，绝不读取既有照片。\n3. 本机仅声明 Apple Privacy Manifest 所需的 CA92.1（用户偏好）与 35F9.1（系统运行时间片统计）两项必要 API。")
                ),
                (
                    String(localized: "legal_p_h3", defaultValue: "三、数据清理控制权"),
                    String(localized: "legal_p_b3", defaultValue: "您可以随时关闭系统权限、重置本地统计偏好或直接卸载应用，本应用在云端或外部均不留存任何痕迹。")
                )
            ]
        case .terms:
            return [
                (
                    String(localized: "legal_t_h1", defaultValue: "一、非医疗健康与声学边界"),
                    String(localized: "legal_t_b1", defaultValue: "「咩哞 · Mie & Mou」是专注聆听放松、规律呼吸陪伴与和声体验的离线声学艺术工具，不属于医疗器械或临床诊疗软件，不用于诊断、治疗、治愈或预防任何身体或心理疾病（含失眠障碍、神经系统疾病、耳鸣治疗或注意缺陷等）。如有健康困扰请及时咨询专业执业医师。")
                ),
                (
                    String(localized: "legal_t_h2", defaultValue: "二、导出分享授权"),
                    String(localized: "legal_t_b2", defaultValue: "您可自由导出保存本地生成的静态共鸣 PNG 卡片并与亲友分享，请勿将本应用曲目或声音生成物用于误导性医疗疗效宣传。")
                ),
                (
                    String(localized: "legal_t_h3", defaultValue: "三、收听安全提示"),
                    String(localized: "legal_t_b3", defaultValue: "双耳差频与等时脉动声场仅为艺术氛围营造，请佩戴舒适音量收听。若您存在癫痫病史、规律声光脉冲敏感、耳鸣发作或佩戴植入式助听装置，请优先在声床抽屉中启用无脉冲的「纯自然声床（零声波脉冲）」或咨询医师后再决定是否使用 40 Hz 频段；驾驶与机械作业时切勿开启睡前静息或夜灯模式。")
                )
            ]
        case .licenses:
            return [
                (
                    String(localized: "legal_l_h1", defaultValue: "一、离线音频引擎与基频计算"),
                    String(localized: "legal_l_b1", defaultValue: "App 内 44 声部室内乐与双耳波合成引擎（FeltPianoSynth）、纯 Swift / Accelerate vDSP 音高检测模块以及所有视觉绘制均为自研零外部二进制依赖实现。")
                ),
                (
                    String(localized: "legal_l_h2", defaultValue: "二、公版古典乐谱与原创示范集"),
                    String(localized: "legal_l_b2", defaultValue: "声库中的古典战栗胶囊全部取材于已进入国际公版领域（Public Domain）的传世作品，并在其之上加入自研多声部室内乐伴奏织体；现代夏日及星尘示范曲目为本作品 100% 原创。全部许可与公版参考清单已完整内置本机离线展示。")
                )
            ]
        }
    }
}

public struct ChimmoLegalDocumentView: View {
    public let kind: ChimmoLegalDocumentKind
    public let palette: ChimmoPalette

    public init(kind: ChimmoLegalDocumentKind, palette: ChimmoPalette) {
        self.kind = kind
        self.palette = palette
    }

    public var body: some View {
        ZStack {
            AmbientPaperBackdrop(palette: palette)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            ChimmoCraftMark(.cardSeal, color: palette.homeAnchor)
                                .frame(width: 24, height: 24)
                            Text(kind.title)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                        }
                        Text(kind.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: palette.homeAnchor)

                    ForEach(Array(kind.sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.heading)
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                            Text(section.body)
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryInk)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Non-medical acoustic safety & 40 Hz sensitivity disclosure view.
public struct ChimmoAcousticSafetyView: View {
    public let palette: ChimmoPalette

    public init(palette: ChimmoPalette) {
        self.palette = palette
    }

    public var body: some View {
        ZStack {
            AmbientPaperBackdrop(palette: palette)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    safetyCard(
                        title: String(localized: "safety_title_boundary", defaultValue: "声学艺术边界（非医疗软件）"),
                        detail: String(localized: "safety_body_boundary", defaultValue: "咩哞提供的 Delta / Theta / Alpha / Gamma 声场、轻哼定频共振与睡眠渐弱定时均属于纯粹离线感官艺术与放松陪伴体验，不构成医疗诊断、康复介入或疾病治疗手段。"),
                        tint: palette.homeAnchor
                    )
                    safetyCard(
                        title: String(localized: "safety_title_headphones", defaultValue: "耳机双耳差频与外放模式"),
                        detail: String(localized: "safety_body_headphones", defaultValue: "佩戴立体声有线/蓝牙耳机时，左右耳分别呈现差频双声波；使用手机扬声器外放时，系统自动切换为低失真柔和等时包络脉冲，确保随时保持清晰听感与舒适温和音量。"),
                        tint: palette.celadonAccent
                    )
                    safetyCard(
                        title: String(localized: "safety_title_caution", defaultValue: "特殊人群与 40 Hz Gamma 收听留意"),
                        detail: String(localized: "safety_body_caution", defaultValue: "1. 若您对规律脉冲声响、光声节律变化敏感，或存在癫痫病史、耳鸣发作期或植入式助听装置，请优先在声床抽屉里开启无脉冲的「纯自然声床（零声波脉冲）」，或遵照医嘱再决定是否收听 40 Hz 频段。\n2. 驾驶、高空作业或需要高度警觉操作机械期间，请勿使用深睡（Delta / Theta）睡前静息及闭眼夜灯模式。"),
                        tint: palette.nightLampGold
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(String(localized: "safety_nav_title", defaultValue: "收听安全与非医疗边界"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func safetyCard(title: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ChimmoResonanceBead(size: 10, isNight: palette.isNight, tint: tint)
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.primaryInk)
            }
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .chimmoAtelierCard(palette: palette, radius: ChimmoRadius.card, tint: tint)
    }
}
