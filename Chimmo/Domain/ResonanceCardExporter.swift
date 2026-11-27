import Foundation
import SwiftUI
#if os(iOS)
import Photos
import UIKit
#endif

/// Offline PNG Resonance Postcard exporter (1080x1350 sRGB).
/// Renders kiln cotton-paper framing, standing-wave harmonics, and SF Pro Rounded numerals off the main actor.
public enum ResonanceCardExporter {
    public struct Spec: Equatable, Sendable {
        public let band: BrainwaveBand
        public let beatHz: Double
        public let carrierHz: Double
        public let washKind: AcousticWashKind
        public let presetTitle: String
        public let totalMinutes: Int
        public let isNight: Bool
        public let generatedDate: Date
        public let pureAmbientWashOnly: Bool

        public init(
            band: BrainwaveBand,
            beatHz: Double,
            carrierHz: Double,
            washKind: AcousticWashKind,
            presetTitle: String,
            totalMinutes: Int,
            isNight: Bool,
            generatedDate: Date = Date(),
            pureAmbientWashOnly: Bool = false
        ) {
            self.band = band
            self.beatHz = beatHz.isFinite ? max(1.5, min(42.0, beatHz)) : band.defaultBeatHz
            self.carrierHz = carrierHz.isFinite ? max(80.0, min(440.0, carrierHz)) : band.defaultCarrierHz
            self.washKind = washKind
            self.presetTitle = presetTitle
            self.totalMinutes = max(0, min(500_000, totalMinutes))
            self.isNight = isNight
            self.generatedDate = generatedDate
            self.pureAmbientWashOnly = pureAmbientWashOnly
        }
    }

    public enum ExportError: LocalizedError {
        case encodingFailed
        case diskWriteFailed
        case photoPermissionDenied
        case photoSaveFailed

        public var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return String(localized: "card_err_encode", defaultValue: "无法编码共鸣明信片 PNG 数据")
            case .diskWriteFailed:
                return String(localized: "card_err_write", defaultValue: "本地临时卡片写入失败，请检查可用空间")
            case .photoPermissionDenied:
                return String(localized: "card_err_photo_perm", defaultValue: "未开启相册添加权限，请通过下方分享按钮保存卡片")
            case .photoSaveFailed:
                return String(localized: "card_err_photo_save", defaultValue: "保存到相册失败，请稍后重试")
            }
        }
    }

    #if os(iOS)
    public static func renderCardImage(spec: Spec) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            buildCardImage(spec: spec)
        }.value
    }

    public static func exportPNGFile(spec: Spec) async throws -> URL {
        let image = await renderCardImage(spec: spec)
        return try await writePNGFile(from: image, band: spec.band, date: spec.generatedDate)
    }

    public static func writePNGFile(from image: UIImage, band: BrainwaveBand, date: Date) async throws -> URL {
        guard let data = image.pngData() else {
            throw ExportError.encodingFailed
        }
        let stamp = Int(date.timeIntervalSince1970)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MieAndMou-Resonance-\(band.rawValue)-\(stamp).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw ExportError.diskWriteFailed
        }
    }

    public static func saveImageToPhotos(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.photoPermissionDenied
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success && error == nil {
                    cont.resume()
                } else {
                    cont.resume(throwing: ExportError.photoSaveFailed)
                }
            }
        }
    }

    /// Deterministic offline 1080x1350 opaque PNG renderer safe on any execution queue.
    nonisolated public static func buildCardImage(spec: Spec) -> UIImage {
        let size = CGSize(width: 1080, height: 1350)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            let night = spec.isNight

            let paperColor = night
                ? UIColor(red: 14 / 255.0, green: 19 / 255.0, blue: 38 / 255.0, alpha: 1.0)
                : UIColor(red: 251 / 255.0, green: 247 / 255.0, blue: 240 / 255.0, alpha: 1.0)
            let surfaceColor = night
                ? UIColor(red: 24 / 255.0, green: 33 / 255.0, blue: 64 / 255.0, alpha: 1.0)
                : UIColor(red: 255 / 255.0, green: 252 / 255.0, blue: 246 / 255.0, alpha: 1.0)
            let primaryInk = night
                ? UIColor(red: 244 / 255.0, green: 238 / 255.0, blue: 226 / 255.0, alpha: 1.0)
                : UIColor(red: 28 / 255.0, green: 29 / 255.0, blue: 25 / 255.0, alpha: 1.0)
            let secondaryInk = night
                ? UIColor(red: 198 / 255.0, green: 206 / 255.0, blue: 232 / 255.0, alpha: 1.0)
                : UIColor(red: 78 / 255.0, green: 74 / 255.0, blue: 66 / 255.0, alpha: 1.0)

            let accent = bandUIColor(for: spec.band, isNight: night)

            paperColor.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            // Kiln paper registration frame
            let cardRect = CGRect(x: 64, y: 64, width: size.width - 128, height: size.height - 128)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 48)
            surfaceColor.setFill()
            cardPath.fill()

            primaryInk.withAlphaComponent(night ? 0.14 : 0.09).setStroke()
            cardPath.lineWidth = 3.0
            cardPath.stroke()

            // Corner kiln marks
            let tickLen: CGFloat = 24
            let tickColor = accent.withAlphaComponent(night ? 0.50 : 0.36)
            tickColor.setStroke()
            cg.setLineWidth(3.0)
            let insetRect = cardRect.insetBy(dx: 28, dy: 28)
            for (cx, cy, dx, dy) in [
                (insetRect.minX, insetRect.minY, 1.0, 1.0),
                (insetRect.maxX, insetRect.minY, -1.0, 1.0),
                (insetRect.minX, insetRect.maxY, 1.0, -1.0),
                (insetRect.maxX, insetRect.maxY, -1.0, -1.0)
            ] {
                cg.move(to: CGPoint(x: cx, y: cy + dy * tickLen))
                cg.addLine(to: CGPoint(x: cx, y: cy))
                cg.addLine(to: CGPoint(x: cx + dx * tickLen, y: cy))
                cg.strokePath()
            }

            // Soft standing-wave radial glow (sRGB color space parity)
            let orbCenter = CGPoint(x: size.width * 0.5, y: 520)
            let maxGlowR: CGFloat = 310
            let glowSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(
                colorsSpace: glowSpace,
                colors: [accent.withAlphaComponent(night ? 0.28 : 0.18).cgColor, paperColor.withAlphaComponent(0.0).cgColor] as CFArray,
                locations: [0.0, 1.0]
            ) {
                cg.drawRadialGradient(gradient, startCenter: orbCenter, startRadius: 20, endCenter: orbCenter, endRadius: maxGlowR, options: [])
            }

            // Concentric Chladni standing-wave mandala rings
            for idx in 0..<5 {
                let baseR = CGFloat(140 + idx * 38)
                let waveAmp = CGFloat(6.0 - Double(idx) * 0.8)
                let lobeCount = 4 + spec.band.bandIndex * 2
                let ring = UIBezierPath()
                let steps = 120
                for step in 0...steps {
                    let theta = CGFloat(step) / CGFloat(steps) * CGFloat.pi * 2.0
                    let r = baseR + sin(theta * CGFloat(lobeCount)) * waveAmp
                    let pt = CGPoint(x: orbCenter.x + cos(theta) * r, y: orbCenter.y + sin(theta) * r)
                    if step == 0 { ring.move(to: pt) } else { ring.addLine(to: pt) }
                }
                ring.close()
                accent.withAlphaComponent(0.36 - Double(idx) * 0.06).setStroke()
                ring.lineWidth = idx == 0 ? 4.5 : 2.2
                ring.stroke()
            }

            // Center glazed bead
            let coreR: CGFloat = 34
            accent.setFill()
            UIBezierPath(ovalIn: CGRect(x: orbCenter.x - coreR, y: orbCenter.y - coreR, width: coreR * 2, height: coreR * 2)).fill()

            // Header kiln brand & duo mark (strictly non-overlapping text rects)
            drawKilnDuoEmblem(in: cg, origin: CGPoint(x: 124, y: 118), accent: accent, ink: primaryInk, isNight: night)

            let brandText = String(localized: "card_brand_header", defaultValue: "咩哞 · MIE & MOU")
            drawText(
                brandText,
                font: roundedFont(size: 24, weight: .bold),
                color: secondaryInk,
                in: CGRect(x: 208, y: 128, width: 416, height: 34),
                alignment: .left
            )

            // Date badge on top-right
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let dateStr = formatter.string(from: spec.generatedDate)
            drawText(
                dateStr,
                font: roundedFont(size: 22, weight: .medium),
                color: secondaryInk,
                in: CGRect(x: 636, y: 128, width: 300, height: 34),
                alignment: .right
            )

            // Hero Beat Frequency or Pure Ambient Wash (tabular SF Pro Rounded digits)
            let heroText = spec.pureAmbientWashOnly
                ? spec.washKind.title
                : String(format: "%.1f Hz", spec.beatHz)
            drawText(
                heroText,
                font: roundedFont(size: spec.pureAmbientWashOnly ? 86 : 112, weight: .bold, tabularNumbers: true),
                color: primaryInk,
                in: CGRect(x: 110, y: spec.pureAmbientWashOnly ? 814 : 800, width: 860, height: 134),
                alignment: .center
            )

            // Band title & subtitle (or pure ambient subtitle)
            let bandLine = spec.pureAmbientWashOnly
                ? String(localized: "wash_pure_sub", defaultValue: "纯自然声床 · 无脉冲")
                : "\(spec.band.title) · \(spec.band.chineseSubtitle)"
            drawText(
                bandLine,
                font: roundedFont(size: 40, weight: .bold),
                color: accent,
                in: CGRect(x: 110, y: 940, width: 860, height: 54),
                alignment: .center
            )

            // Preset Title & Carrier Details
            drawText(
                spec.presetTitle,
                font: roundedFont(size: 32, weight: .semibold),
                color: primaryInk,
                in: CGRect(x: 110, y: 1012, width: 860, height: 44),
                alignment: .center
            )

            let specLine = spec.pureAmbientWashOnly
                ? String(localized: "card_pure_wash_carrier_free", defaultValue: "全自然环境声床 · 零周期声波脉冲")
                : String(
                    format: String(localized: "card_carrier_wash_fmt", defaultValue: "载波 %.0f Hz · %@"),
                    spec.carrierHz,
                    spec.washKind.title
                )
            drawText(
                specLine,
                font: roundedFont(size: 26, weight: .medium),
                color: secondaryInk,
                in: CGRect(x: 110, y: 1068, width: 860, height: 38),
                alignment: .center
            )

            // Divider & clean quiet reflection footer
            primaryInk.withAlphaComponent(0.10).setFill()
            cg.fill(CGRect(x: 180, y: 1144, width: 720, height: 2))

            let summaryText = spec.totalMinutes > 0
                ? String(format: String(localized: "card_minutes_footer", defaultValue: "已安静共振停留 %lld 分钟"), spec.totalMinutes)
                : String(localized: "card_quiet_footer", defaultValue: "离线纯声学静心时刻 · 安静聆听")
            drawText(
                summaryText,
                font: roundedFont(size: 25, weight: .medium),
                color: secondaryInk,
                in: CGRect(x: 110, y: 1172, width: 860, height: 40),
                alignment: .center
            )
        }
    }

    nonisolated private static func roundedFont(size: CGFloat, weight: UIFont.Weight, tabularNumbers: Bool = false) -> UIFont {
        let base = tabularNumbers
            ? UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
            : UIFont.systemFont(ofSize: size, weight: weight)
        if let desc = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: desc, size: size)
        }
        return base
    }

    nonisolated private static func drawText(
        _ string: String,
        font: UIFont,
        color: UIColor,
        in rect: CGRect,
        alignment: NSTextAlignment
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        (string as NSString).draw(in: rect, withAttributes: attrs)
    }

    nonisolated private static func drawKilnDuoEmblem(
        in cg: CGContext,
        origin: CGPoint,
        accent: UIColor,
        ink: UIColor,
        isNight: Bool
    ) {
        // Unified Mie & Mou kiln ceramic duo (core UIKit Y-down coordinates):
        // Mie (left foreground): scalloped wool puffs, warm cream-apricot face, drooping ears, 2 symmetrical spiral ram horns
        // Mou (right): cocoa/plum rounded torso, 2 smooth crescent horns, broad snout, solid glazed eyes
        let sheepWool = isNight
            ? UIColor(red: 237 / 255.0, green: 228 / 255.0, blue: 213 / 255.0, alpha: 1.0)
            : UIColor(red: 255 / 255.0, green: 253 / 255.0, blue: 247 / 255.0, alpha: 1.0)
        let sheepFace = isNight
            ? UIColor(red: 217 / 255.0, green: 200 / 255.0, blue: 180 / 255.0, alpha: 1.0)
            : UIColor(red: 243 / 255.0, green: 230 / 255.0, blue: 212 / 255.0, alpha: 1.0)
        let cowFill = isNight
            ? UIColor(red: 86 / 255.0, green: 74 / 255.0, blue: 118 / 255.0, alpha: 1.0)
            : UIColor(red: 143 / 255.0, green: 95 / 255.0, blue: 78 / 255.0, alpha: 1.0)
        let cowSnout = isNight
            ? UIColor(red: 223 / 255.0, green: 208 / 255.0, blue: 190 / 255.0, alpha: 1.0)
            : UIColor(red: 255 / 255.0, green: 243 / 255.0, blue: 226 / 255.0, alpha: 1.0)
        let sheepHorn = isNight
            ? UIColor(red: 255 / 255.0, green: 184 / 255.0, blue: 77 / 255.0, alpha: 1.0)
            : UIColor(red: 229 / 255.0, green: 153 / 255.0, blue: 0 / 255.0, alpha: 1.0)
        let cowHorn = isNight
            ? UIColor(red: 255 / 255.0, green: 210 / 255.0, blue: 117 / 255.0, alpha: 1.0)
            : UIColor(red: 255 / 255.0, green: 228 / 255.0, blue: 158 / 255.0, alpha: 1.0)
        let eyeCol = UIColor(red: 28 / 255.0, green: 29 / 255.0, blue: 25 / 255.0, alpha: 1.0)
        let contour = ink.withAlphaComponent(0.45)

        // Mou (right) with unobstructed crescent horns, ears & snout
        let cowRect = CGRect(x: origin.x + 36, y: origin.y + 8, width: 32, height: 29)
        for side in [-1.0, 1.0] {
            let sx = CGFloat(side)
            let horn = UIBezierPath()
            let midX = cowRect.midX
            horn.move(to: CGPoint(x: midX + sx * 5.0, y: cowRect.minY + 2))
            horn.addQuadCurve(
                to: CGPoint(x: midX + sx * 13.5, y: cowRect.minY - 7),
                controlPoint: CGPoint(x: midX + sx * 12.5, y: cowRect.minY + 0.5)
            )
            horn.addQuadCurve(
                to: CGPoint(x: midX + sx * 8.5, y: cowRect.minY + 3),
                controlPoint: CGPoint(x: midX + sx * 9.5, y: cowRect.minY - 3)
            )
            horn.close()
            cowHorn.setFill()
            horn.fill()
            contour.setStroke()
            horn.lineWidth = 1.6
            horn.stroke()

            let earRect = CGRect(x: midX + sx * 15.5 - 4.0, y: cowRect.midY - 6.0, width: 8.0, height: 5.0)
            cowFill.setFill()
            UIBezierPath(ovalIn: earRect).fill()
            contour.setStroke()
            UIBezierPath(ovalIn: earRect).stroke()
        }

        cowFill.setFill()
        let cowPath = UIBezierPath(roundedRect: cowRect, cornerRadius: 13)
        cowPath.fill()
        contour.setStroke()
        cowPath.lineWidth = 2.0
        cowPath.stroke()

        cowSnout.setFill()
        let snoutRect = CGRect(x: cowRect.minX + 6, y: cowRect.maxY - 12, width: 20, height: 10)
        let snoutPath = UIBezierPath(ovalIn: snoutRect)
        snoutPath.fill()
        contour.setStroke()
        snoutPath.lineWidth = 1.4
        snoutPath.stroke()

        eyeCol.setFill()
        UIBezierPath(ovalIn: CGRect(x: cowRect.minX + 8.5, y: cowRect.minY + 8.5, width: 3.4, height: 3.4)).fill()
        UIBezierPath(ovalIn: CGRect(x: cowRect.maxX - 11.9, y: cowRect.minY + 8.5, width: 3.4, height: 3.4)).fill()

        // Mie (left foreground) with scalloped wool, cream-apricot face, drooping ears & TWO spiral ram horns
        let sheepCenter = CGPoint(x: origin.x + 18, y: origin.y + 22)
        for side in [-1.0, 1.0] {
            let sx = CGFloat(side)
            let earRect = CGRect(x: sheepCenter.x + sx * 15 - 4.0, y: sheepCenter.y - 2.0, width: 8.0, height: 5.0)
            sheepWool.setFill()
            UIBezierPath(ovalIn: earRect).fill()
            contour.setStroke()
            UIBezierPath(ovalIn: earRect).stroke()
        }

        let puffOffsets: [(CGFloat, CGFloat, CGFloat)] = [
            (-7, -3, 15), (7, -3, 15), (0, -9, 17), (0, 3, 18)
        ]
        contour.setStroke()
        for (ox, oy, rad) in puffOffsets {
            let p = UIBezierPath(ovalIn: CGRect(x: sheepCenter.x + ox - rad * 0.5, y: sheepCenter.y + oy - rad * 0.5, width: rad, height: rad))
            p.lineWidth = 3.2
            p.stroke()
        }
        sheepWool.setFill()
        for (ox, oy, rad) in puffOffsets {
            UIBezierPath(ovalIn: CGRect(x: sheepCenter.x + ox - rad * 0.5, y: sheepCenter.y + oy - rad * 0.5, width: rad, height: rad)).fill()
        }

        // Cream-apricot inner face (consistent with in-app ChimmoSheepView)
        sheepFace.setFill()
        let facePath = UIBezierPath(ovalIn: CGRect(x: sheepCenter.x - 8.5, y: sheepCenter.y - 6.5, width: 17, height: 14))
        facePath.fill()
        contour.setStroke()
        facePath.lineWidth = 1.4
        facePath.stroke()

        // Both symmetrical spiral ram horns
        for side in [-1.0, 1.0] {
            let sx = CGFloat(side)
            let horn = UIBezierPath()
            horn.move(to: CGPoint(x: sheepCenter.x + sx * 4.0, y: sheepCenter.y - 10.5))
            horn.addCurve(
                to: CGPoint(x: sheepCenter.x + sx * 12.5, y: sheepCenter.y - 7.5),
                controlPoint1: CGPoint(x: sheepCenter.x + sx * 8.0, y: sheepCenter.y - 17.5),
                controlPoint2: CGPoint(x: sheepCenter.x + sx * 14.5, y: sheepCenter.y - 14.5)
            )
            horn.addCurve(
                to: CGPoint(x: sheepCenter.x + sx * 8.0, y: sheepCenter.y - 7.5),
                controlPoint1: CGPoint(x: sheepCenter.x + sx * 11.5, y: sheepCenter.y - 4.0),
                controlPoint2: CGPoint(x: sheepCenter.x + sx * 8.0, y: sheepCenter.y - 5.0)
            )
            horn.lineCapStyle = .round
            horn.lineJoinStyle = .round
            contour.setStroke()
            horn.lineWidth = 4.2
            horn.stroke()
            sheepHorn.setStroke()
            horn.lineWidth = 2.4
            horn.stroke()
        }

        // Solid glazed eyes
        eyeCol.setFill()
        UIBezierPath(ovalIn: CGRect(x: sheepCenter.x - 5.0, y: sheepCenter.y - 1.5, width: 3.0, height: 3.0)).fill()
        UIBezierPath(ovalIn: CGRect(x: sheepCenter.x + 2.0, y: sheepCenter.y - 1.5, width: 3.0, height: 3.0)).fill()

        // Harmonic coupling bead centered below
        accent.setFill()
        UIBezierPath(ovalIn: CGRect(x: origin.x + 31, y: origin.y + 40, width: 8, height: 8)).fill()
    }

    nonisolated private static func bandUIColor(for band: BrainwaveBand, isNight: Bool) -> UIColor {
        let hex = isNight ? band.accentHexNight : band.accentHexLight
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    #endif
}
