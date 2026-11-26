import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// V2.1 纯离线「脑波共振纪念卡」高清 PNG 渲染与分享面板（1080×1350 · 零网络）。
@MainActor
public enum ResonanceCardExporter {

    public static func renderPNGData(
        band: BrainwaveBand,
        beatHz: Double,
        carrierHz: Double,
        matchedHumHz: Double?,
        totalMinutes: Int,
        frissonCount: Int,
        isNight: Bool
    ) -> Data? {
        #if os(iOS)
        let size = CGSize(width: 1080, height: 1350)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let cg = ctx.cgContext

            // 1. 纸底色（与端内棉纸/深靛夜灯严格同源）
            let bgColor = isNight
                ? UIColor(red: 14 / 255.0, green: 20 / 255.0, blue: 48 / 255.0, alpha: 1.0)
                : UIColor(red: 251 / 255.0, green: 247 / 255.0, blue: 240 / 255.0, alpha: 1.0)
            let cardColor = isNight
                ? UIColor(red: 25 / 255.0, green: 33 / 255.0, blue: 63 / 255.0, alpha: 1.0)
                : UIColor(red: 255 / 255.0, green: 255 / 255.0, blue: 255 / 255.0, alpha: 1.0)
            let inkColor = isNight
                ? UIColor(red: 242 / 255.0, green: 226 / 255.0, blue: 196 / 255.0, alpha: 1.0)
                : UIColor(red: 28 / 255.0, green: 29 / 255.0, blue: 25 / 255.0, alpha: 1.0)
            let subInk = isNight
                ? UIColor(red: 184 / 255.0, green: 190 / 255.0, blue: 212 / 255.0, alpha: 1.0)
                : UIColor(red: 77 / 255.0, green: 78 / 255.0, blue: 85 / 255.0, alpha: 1.0)
            let accent = accentUIColor(for: band, isNight: isNight)

            bgColor.setFill()
            cg.fill(rect)

            // 内框纯净画纸卡
            let innerRect = CGRect(x: 64, y: 64, width: size.width - 128, height: size.height - 128)
            let cardPath = UIBezierPath(roundedRect: innerRect, cornerRadius: 56)
            cardColor.setFill()
            cardPath.fill()
            inkColor.withAlphaComponent(isNight ? 0.14 : 0.08).setStroke()
            cardPath.lineWidth = 3.0
            cardPath.stroke()

            // 2. 顶部印章抬头
            let topParagraph = NSMutableParagraphStyle()
            topParagraph.alignment = .left
            let topAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: subInk,
                .paragraphStyle: topParagraph
            ]
            NSString(string: "MIE & MOU · BRAINWAVE RESONANCE CARD").draw(
                in: CGRect(x: 124, y: 128, width: 832, height: 42),
                withAttributes: topAttrs
            )

            // 3. 中央同心脑波声场图腾
            let orbCenter = CGPoint(x: size.width * 0.5, y: 515)
            for idx in 0..<5 {
                let rad = 110.0 + CGFloat(idx) * 44.0
                let ringRect = CGRect(x: orbCenter.x - rad, y: orbCenter.y - rad, width: rad * 2, height: rad * 2)
                let ringPath = UIBezierPath(ovalIn: ringRect)
                accent.withAlphaComponent(0.32 - CGFloat(idx) * 0.05).setStroke()
                ringPath.lineWidth = idx == 0 ? 6.0 : 3.5
                ringPath.stroke()
            }

            let coreRad: CGFloat = 118
            let corePath = UIBezierPath(
                ovalIn: CGRect(x: orbCenter.x - coreRad, y: orbCenter.y - coreRad, width: coreRad * 2, height: coreRad * 2)
            )
            accent.withAlphaComponent(isNight ? 0.36 : 0.16).setFill()
            corePath.fill()
            accent.setStroke()
            corePath.lineWidth = 5.0
            corePath.stroke()

            // 核心读数
            let centerPara = NSMutableParagraphStyle()
            centerPara.alignment = .center
            let hzStr = String(format: "%.1f Hz", beatHz.isFinite ? beatHz : band.defaultBeatHz)
            NSString(string: hzStr).draw(
                in: CGRect(x: orbCenter.x - 160, y: orbCenter.y - 38, width: 320, height: 58),
                withAttributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .heavy),
                    .foregroundColor: inkColor,
                    .paragraphStyle: centerPara
                ]
            )
            NSString(string: band.shortCode.uppercased()).draw(
                in: CGRect(x: orbCenter.x - 120, y: orbCenter.y + 24, width: 240, height: 32),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                    .foregroundColor: accent,
                    .paragraphStyle: centerPara
                ]
            )

            // 4. 状态标题与个人声纹说明
            NSString(string: band.title).draw(
                in: CGRect(x: 112, y: 805, width: 856, height: 76),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 64, weight: .heavy),
                    .foregroundColor: inkColor,
                    .paragraphStyle: centerPara
                ]
            )

            let carrierText: String = {
                if let hum = matchedHumHz, hum.isFinite {
                    return "专属轻哼共振基频 \(Int(hum.rounded())) Hz · \(band.somaticHook)"
                }
                return "双耳载波 \(Int(carrierHz.rounded())) Hz · \(band.somaticHook)"
            }()
            NSString(string: carrierText).draw(
                in: CGRect(x: 112, y: 892, width: 856, height: 48),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
                    .foregroundColor: subInk,
                    .paragraphStyle: centerPara
                ]
            )

            // 5. 温柔陪伴寄语 + 沉淀指标
            let message = ResonanceKinematics.gentleCompanionMessage(
                totalMinutes: totalMinutes,
                frissonCount: frissonCount,
                favoriteBand: band
            )
            NSString(string: message).draw(
                in: CGRect(x: 140, y: 970, width: 800, height: 120),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 28, weight: .medium),
                    .foregroundColor: subInk,
                    .paragraphStyle: centerPara
                ]
            )

            // 6. 底部纯离线印章
            let statSummary = "累计共振 \(totalMinutes) 分钟 · 颅内战栗 \(frissonCount) 次"
            NSString(string: statSummary).draw(
                in: CGRect(x: 124, y: 1140, width: 832, height: 40),
                withAttributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 26, weight: .bold),
                    .foregroundColor: accent,
                    .paragraphStyle: centerPara
                ]
            )

            NSString(string: "咩哞 · MIE & MOU · 100% OFFLINE · 非医疗声学放松").draw(
                in: CGRect(x: 124, y: 1202, width: 832, height: 34),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
                    .foregroundColor: subInk.withAlphaComponent(0.78),
                    .paragraphStyle: centerPara
                ]
            )
        }

        return image.pngData()
        #else
        return nil
        #endif
    }

    public static func writeTemporaryCardURL(
        band: BrainwaveBand,
        beatHz: Double,
        carrierHz: Double,
        matchedHumHz: Double?,
        totalMinutes: Int,
        frissonCount: Int,
        isNight: Bool
    ) -> URL? {
        guard let data = renderPNGData(
            band: band,
            beatHz: beatHz,
            carrierHz: carrierHz,
            matchedHumHz: matchedHumHz,
            totalMinutes: totalMinutes,
            frissonCount: frissonCount,
            isNight: isNight
        ) else {
            return nil
        }
        let filename = "MieMou_\(band.shortCode)_\(Int(beatHz.rounded()))Hz.png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return url
    }

    #if os(iOS)
    private static func accentUIColor(for band: BrainwaveBand, isNight: Bool) -> UIColor {
        switch (band, isNight) {
        case (.delta, false): return UIColor(red: 111 / 255.0, green: 84 / 255.0, blue: 184 / 255.0, alpha: 1.0)
        case (.delta, true): return UIColor(red: 179 / 255.0, green: 155 / 255.0, blue: 255 / 255.0, alpha: 1.0)
        case (.theta, false): return UIColor(red: 196 / 255.0, green: 81 / 255.0, blue: 58 / 255.0, alpha: 1.0)
        case (.theta, true): return UIColor(red: 240 / 255.0, green: 138 / 255.0, blue: 108 / 255.0, alpha: 1.0)
        case (.alpha, false): return UIColor(red: 61 / 255.0, green: 122 / 255.0, blue: 119 / 255.0, alpha: 1.0)
        case (.alpha, true): return UIColor(red: 126 / 255.0, green: 200 / 255.0, blue: 195 / 255.0, alpha: 1.0)
        case (.gamma, false): return UIColor(red: 53 / 255.0, green: 119 / 255.0, blue: 168 / 255.0, alpha: 1.0)
        case (.gamma, true): return UIColor(red: 110 / 255.0, green: 180 / 255.0, blue: 242 / 255.0, alpha: 1.0)
        }
    }
    #endif
}

/// 脑波共振纪念卡预览与系统分享弹出页
public struct ResonanceShareCardSheet: View {
    @ObservedObject public var vm: ResonanceViewModel
    public let palette: ChimmoPalette
    @Environment(\.dismiss) private var dismiss

    public init(vm: ResonanceViewModel, palette: ChimmoPalette) {
        self.vm = vm
        self.palette = palette
    }

    public var body: some View {
        let pngData = ResonanceCardExporter.renderPNGData(
            band: vm.selectedBand,
            beatHz: vm.beatHz,
            carrierHz: vm.carrierHz,
            matchedHumHz: vm.matchedHumHz,
            totalMinutes: vm.stats.totalMinutes,
            frissonCount: vm.stats.frissonPeakCount,
            isNight: palette.isNight
        )
        let fileURL = ResonanceCardExporter.writeTemporaryCardURL(
            band: vm.selectedBand,
            beatHz: vm.beatHz,
            carrierHz: vm.carrierHz,
            matchedHumHz: vm.matchedHumHz,
            totalMinutes: vm.stats.totalMinutes,
            frissonCount: vm.stats.frissonPeakCount,
            isNight: palette.isNight
        )

        return NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    #if os(iOS)
                    if let data = pngData, let uiImg = UIImage(data: data) {
                        Image(uiImage: uiImg)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: ChimmoRadius.card, style: .continuous))
                            .shadow(color: palette.elevationShadow(dayOpacity: 0.14, nightOpacity: 0.34), radius: 14, y: 6)
                            .accessibilityLabel("脑波共振纪念卡预览，\(vm.selectedBand.title) \(String(format: "%.1f", vm.beatHz)) 赫兹")
                    }
                    #endif

                    if let shareURL = fileURL {
                        ShareLink(
                            item: shareURL,
                            preview: SharePreview("咩哞 · \(vm.selectedBand.title) 共振纪念卡")
                        ) {
                            Label("保存或分享共振纪念卡", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.chimmoVinyl(palette: palette, tint: vm.selectedBand.accentColor(isNight: palette.isNight), prominent: true, large: true))
                        .accessibilityHint("通过系统分享表单存储到相册或发送给朋友")
                    }
                }
                .padding(20)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("脑波共振纪念卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
