import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// 黑胶星轨明信片数据快照（100% 离线、纯值传递，支持任意作品或历史唱片生成高分辨率纪念卡片）
public struct VinylPostcardSnapshot: Sendable {
    public let title: String
    public let scaleMode: ScaleMode
    public let notes: [NoteBead]
    public let grooveStrength: Double
    public let totalDuration: Double
    public let chordSpans: [ChordSpan]
    public let shadowNotes: [CounterpointNote]
    public let harmonyPhysics: HarmonicRatioDescriptor
    public let headline: String
    public let shadowEnabled: Bool
    public let melodyVoiceLabel: String
    public let isNight: Bool

    public init(
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        melodyVoice: MelodyVoice? = nil,
        shadowEnabled: Bool = false,
        isNight: Bool = false,
        headline: String? = nil
    ) {
        self.title = document.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "我的旋律" : document.title
        self.scaleMode = document.scaleMode
        self.notes = document.notes.sorted {
            $0.displayOnset(grooveStrength: document.grooveStrength) < $1.displayOnset(grooveStrength: document.grooveStrength)
        }
        self.grooveStrength = document.grooveStrength
        self.totalDuration = max(1.0, document.totalDuration)
        let spans = TheoryLensEngine.buildChordSpans(
            document: document,
            preset: chordPreset,
            overrides: chordOverrides
        )
        self.chordSpans = spans
        self.shadowNotes = shadowEnabled
            ? CounterpointShadowEngine.generateShadowVoice(document: document, spans: spans)
            : []
        let lastDeg = self.notes.last?.degree ?? 1
        let rootDeg = spans.last?.chord.rootDegree ?? 1
        self.harmonyPhysics = HarmonicRatioPhysics.analyze(
            melodyDegree: lastDeg,
            rootDegree: rootDeg,
            mode: document.scaleMode
        )
        if let customHeadline = headline, !customHeadline.isEmpty {
            self.headline = customHeadline
        } else {
            self.headline = TheoryLensEngine.analyze(document: document, spans: spans).headline
        }
        self.shadowEnabled = shadowEnabled
        self.melodyVoiceLabel = (melodyVoice ?? document.preferredVoice ?? .singingCello).label
        self.isNight = isNight
    }
}

/// 美术馆级离线黑胶星轨明信片静态视图（540×680 pt，在 `ImageRenderer` 下 2x 导出为 `1080×1360` 高清 PNG）
public struct VinylPostcardCanvasView: View {
    public let snapshot: VinylPostcardSnapshot

    public init(snapshot: VinylPostcardSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        let palette = ChimmoPalette(isNight: snapshot.isNight)
        let skyColor = snapshot.scaleMode.skyAuroraColor(isNight: snapshot.isNight)

        ZStack {
            LinearGradient(
                colors: snapshot.isNight
                    ? [Color(hex: 0x0F1530), Color(hex: 0x1B244B)]
                    : [Color(hex: 0xFCF8F0), Color(hex: 0xF1E8D7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [skyColor.opacity(snapshot.isNight ? 0.22 : 0.14), .clear],
                center: UnitPoint(x: 0.5, y: 0.44),
                startRadius: 20,
                endRadius: 290
            )

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            palette.nightLampGold.opacity(0.55),
                            skyColor.opacity(0.32),
                            palette.nightLampGold.opacity(0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .padding(16)

            VStack(spacing: 16) {
                // 顶部栏
                HStack(spacing: 8) {
                    Text("咩哞 · CHIMMO")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(palette.secondaryInk)

                    Spacer()

                    Text(snapshot.scaleMode.shortSkyLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(skyColor.opacity(0.18)))
                        .foregroundStyle(skyColor)

                    Text(snapshot.melodyVoiceLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(palette.shelfSurface))
                        .foregroundStyle(palette.primaryInk)
                }
                .padding(.horizontal, 34)
                .padding(.top, 30)

                // 中央声盘视觉
                Canvas { ctx, size in
                    drawPostcardDisc(ctx: &ctx, size: size, palette: palette)
                }
                .frame(width: 392, height: 392)

                // 底部标题与说明
                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryInk)
                        .lineLimit(2)

                    Text(snapshot.headline)
                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Label("\(snapshot.notes.count) 个音", systemImage: "music.note")
                        Text("·")
                        Text(String(format: "%.1fs", snapshot.totalDuration))
                        if snapshot.shadowEnabled {
                            Text("·")
                            Text("含伴唱")
                        }
                        Spacer()
                        Text("离线生成")
                            .foregroundStyle(palette.nightLampGold)
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryInk.opacity(0.88))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 34)
                .padding(.bottom, 30)
            }
        }
        .frame(width: 540, height: 680)
    }

    private func drawPostcardDisc(ctx: inout GraphicsContext, size: CGSize, palette: ChimmoPalette) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let maxR = min(size.width, size.height) * 0.44
        let haloR = maxR * 0.98
        let platterR = maxR * 0.89
        let innerR = platterR * 0.31
        let outerR = platterR * 0.90
        let total = snapshot.totalDuration

        // 1. 4 幕情绪外弧 + 珍珠锚点（无绕圈文字）
        for span in snapshot.chordSpans {
            let a0 = -Double.pi / 2.0 + (span.startTime / total) * 2.0 * Double.pi + 0.04
            let a1 = -Double.pi / 2.0 + (span.endTime / total) * 2.0 * Double.pi - 0.04
            guard a1 > a0 else { continue }
            let col = span.chord.color(isNight: snapshot.isNight)
            var arc = Path()
            arc.addArc(center: center, radius: haloR, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
            ctx.stroke(arc, with: .color(col.opacity(0.22)), style: StrokeStyle(lineWidth: 9.0, lineCap: .round))
            ctx.stroke(arc, with: .color(col.opacity(0.80)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

            let midA = (a0 + a1) * 0.5
            let lPt = CGPoint(
                x: center.x + CGFloat(cos(midA)) * haloR,
                y: center.y + CGFloat(sin(midA)) * haloR
            )
            let pearlRect = CGRect(x: lPt.x - 3.0, y: lPt.y - 3.0, width: 6.0, height: 6.0)
            ctx.fill(Path(ellipseIn: pearlRect), with: .color(.white.opacity(0.92)))
            ctx.stroke(Path(ellipseIn: pearlRect), with: .color(col), lineWidth: 1.3)
        }

        // 2. 陶瓷/黑胶底盘 + 微音槽 + 12 刻度
        let platterRect = CGRect(x: center.x - platterR, y: center.y - platterR, width: platterR * 2, height: platterR * 2)
        ctx.fill(
            Path(ellipseIn: platterRect.offsetBy(dx: 0, dy: 5)),
            with: .color(Color.black.opacity(snapshot.isNight ? 0.42 : 0.09))
        )
        let discGrad = Gradient(colors: snapshot.isNight
            ? [Color(hex: 0x222D61), Color(hex: 0x131A3C)]
            : [Color(hex: 0xFFFFFF), Color(hex: 0xF1E8D9)]
        )
        ctx.fill(
            Path(ellipseIn: platterRect),
            with: .radialGradient(discGrad, center: CGPoint(x: center.x - platterR * 0.25, y: center.y - platterR * 0.25), startRadius: 6, endRadius: platterR * 1.15)
        )
        for g in 0..<18 {
            let gr = innerR * 0.94 + (CGFloat(g) / 17.0) * (outerR * 1.04 - innerR * 0.94)
            ctx.stroke(
                Path(ellipseIn: CGRect(x: center.x - gr, y: center.y - gr, width: gr * 2, height: gr * 2)),
                with: .color((snapshot.isNight ? Color.white : Color(hex: 0x6B5237)).opacity(0.06)),
                lineWidth: 0.7
            )
        }
        let rimColor = snapshot.isNight ? Color(hex: 0x524036).opacity(0.8) : Color(hex: 0xD2B48C).opacity(0.88)
        ctx.stroke(Path(ellipseIn: platterRect), with: .color(rimColor), lineWidth: 3.4)

        for laneIdx in 0..<8 {
            let r = OrbitalGeometry.orbitRadius(laneIndex: laneIdx, innerRadius: innerR, outerRadius: outerR)
            let col = XylophoneLane.lane(at: laneIdx).barColor(isNight: snapshot.isNight)
            ctx.stroke(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                with: .color(col.opacity(snapshot.isNight ? 0.22 : 0.24)),
                lineWidth: 0.9
            )
        }

        // 3. 音符星座连线 + 色盲几何宝石音珠
        var pts: [(pt: CGPoint, laneIdx: Int, angle: Double, r: CGFloat, bead: NoteBead)] = []
        for bead in snapshot.notes {
            let onset = bead.displayOnset(grooveStrength: snapshot.grooveStrength)
            let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
            let ang = -Double.pi / 2.0 + OrbitalGeometry.noteBaseAngle(onset: onset, totalDuration: total)
            let r = OrbitalGeometry.orbitRadius(laneIndex: laneIdx, innerRadius: innerR, outerRadius: outerR)
            let pt = CGPoint(x: center.x + CGFloat(cos(ang)) * r, y: center.y + CGFloat(sin(ang)) * r)
            pts.append((pt, laneIdx, ang, r, bead))
        }

        if pts.count > 1 {
            var line = Path()
            line.move(to: pts[0].pt)
            for i in 1..<pts.count {
                let p0 = pts[i - 1].pt
                let p1 = pts[i].pt
                let ctrl = CGPoint(
                    x: (p0.x + p1.x) * 0.5 + (center.x - (p0.x + p1.x) * 0.5) * 0.14,
                    y: (p0.y + p1.y) * 0.5 + (center.y - (p0.y + p1.y) * 0.5) * 0.14
                )
                line.addQuadCurve(to: p1, control: ctrl)
            }
            ctx.stroke(line, with: .color(palette.homeAnchor.opacity(0.40)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
        }

        for item in pts {
            let lane = XylophoneLane.lane(at: item.laneIdx)
            let col = lane.barColor(isNight: snapshot.isNight)
            let dur = item.bead.displayDuration(grooveStrength: snapshot.grooveStrength)
            let arcSpan = min(Double.pi * 0.42, max(0.06, (dur / total) * 2.0 * Double.pi * 0.78))
            var tailArc = Path()
            tailArc.addArc(center: center, radius: item.r, startAngle: .radians(item.angle), endAngle: .radians(item.angle + arcSpan), clockwise: false)
            ctx.stroke(tailArc, with: .color(col.opacity(0.76)), style: StrokeStyle(lineWidth: 3.8, lineCap: .round))

            let orbR: CGFloat = 8.4
            let orbRect = CGRect(x: item.pt.x - orbR, y: item.pt.y - orbR, width: orbR * 2, height: orbR * 2)
            ctx.fill(Path(ellipseIn: orbRect), with: .color(col))
            ctx.stroke(Path(ellipseIn: orbRect), with: .color(.white.opacity(0.6)), lineWidth: 0.9)

            let gs = orbR * 1.1
            let gRect = CGRect(x: item.pt.x - gs * 0.5, y: item.pt.y - gs * 0.5, width: gs, height: gs)
            ctx.fill(PitchGlyphShape.glyph(forLaneIndex: item.laneIdx).path(in: gRect), with: .color(.white.opacity(0.95)), style: FillStyle(eoFill: true))
        }

        // 3.5 巴赫影子银月对位（如果已开启）
        if snapshot.shadowEnabled && !snapshot.shadowNotes.isEmpty {
            for shadow in snapshot.shadowNotes {
                let sLaneIdx = XylophoneLane.laneIndex(degree: shadow.degree, octaveOffset: shadow.octaveOffset)
                let sAng = -Double.pi / 2.0 + OrbitalGeometry.noteBaseAngle(onset: shadow.onset, totalDuration: total)
                let sR = max(innerR * 0.90, OrbitalGeometry.orbitRadius(laneIndex: sLaneIdx, innerRadius: innerR, outerRadius: outerR) - 6.0)
                let sPt = CGPoint(x: center.x + CGFloat(cos(sAng)) * sR, y: center.y + CGFloat(sin(sAng)) * sR)
                let cr: CGFloat = 6.2
                var crescent = Path()
                let topTip = CGPoint(x: sPt.x + cr * 0.35, y: sPt.y - cr * 0.86)
                let botTip = CGPoint(x: sPt.x + cr * 0.35, y: sPt.y + cr * 0.86)
                crescent.move(to: topTip)
                crescent.addCurve(to: botTip, control1: CGPoint(x: sPt.x - cr * 1.05, y: sPt.y - cr * 0.55), control2: CGPoint(x: sPt.x - cr * 1.05, y: sPt.y + cr * 0.55))
                crescent.addCurve(to: topTip, control1: CGPoint(x: sPt.x - cr * 0.20, y: sPt.y + cr * 0.42), control2: CGPoint(x: sPt.x - cr * 0.20, y: sPt.y - cr * 0.42))
                crescent.closeSubpath()
                ctx.fill(crescent, with: .color(Color(hex: 0x7EC8E3).opacity(0.86)))
            }
        }

        // 4. 中央利萨如印章与 12 点钟黄铜定锚
        let hubR = innerR * 0.76
        let hubRect = CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)
        ctx.fill(
            Path(ellipseIn: hubRect),
            with: .radialGradient(
                Gradient(colors: snapshot.isNight ? [Color(hex: 0xFFB84D).opacity(0.32), Color(hex: 0x242F63)] : [Color(hex: 0xFFE3A3).opacity(0.68), Color(hex: 0xF5E7CE)]),
                center: center,
                startRadius: 2,
                endRadius: hubR
            )
        )
        ctx.stroke(Path(ellipseIn: hubRect), with: .color(palette.nightLampGold.opacity(0.55)), lineWidth: 1.4)

        let amp = hubR * 0.55
        var wave = Path()
        for i in 0...100 {
            let u = (Double(i) / 100.0) * Double.pi * 2.0
            let wx = center.x + CGFloat(sin(Double(snapshot.harmonyPhysics.ratioA) * u + 0.45)) * amp
            let wy = center.y + CGFloat(sin(Double(snapshot.harmonyPhysics.ratioB) * u)) * amp
            if i == 0 { wave.move(to: CGPoint(x: wx, y: wy)) } else { wave.addLine(to: CGPoint(x: wx, y: wy)) }
        }
        ctx.stroke(wave, with: .color(palette.homeAnchor.opacity(0.85)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        let pinRect = CGRect(x: center.x - 4.0, y: center.y - 4.0, width: 8.0, height: 8.0)
        ctx.fill(Path(ellipseIn: pinRect), with: .color(palette.nightLampGold))

        if snapshot.notes.isEmpty {
            let emptyLabel = Text("空白画布")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryInk.opacity(0.70))
            ctx.draw(emptyLabel, at: CGPoint(x: center.x, y: center.y + hubR + 22.0), anchor: .center)
        }
    }
}

/// 纯离线高清黑胶星轨明信片 PNG 生成与导出器
@MainActor
public enum VinylPostcardExporter {

    public static func renderPNGData(
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        melodyVoice: MelodyVoice? = nil,
        shadowEnabled: Bool = false,
        isNight: Bool = false,
        headline: String? = nil
    ) -> Data? {
        let snapshot = VinylPostcardSnapshot(
            document: document,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides,
            melodyVoice: melodyVoice,
            shadowEnabled: shadowEnabled,
            isNight: isNight,
            headline: headline
        )
        let cardView = VinylPostcardCanvasView(snapshot: snapshot)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 2.0
        renderer.isOpaque = true
        #if os(iOS)
        return renderer.uiImage?.pngData()
        #else
        return nil
        #endif
    }

    public static func writeTemporaryPostcardFile(
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        melodyVoice: MelodyVoice? = nil,
        shadowEnabled: Bool = false,
        isNight: Bool = false,
        headline: String? = nil
    ) throws -> URL {
        guard let data = renderPNGData(
            document: document,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides,
            melodyVoice: melodyVoice,
            shadowEnabled: shadowEnabled,
            isNight: isNight,
            headline: headline
        ) else {
            throw NSError(domain: "app.chimmo.postcard", code: -1, userInfo: [NSLocalizedDescriptionKey: "明信片图像渲染失败"])
        }

        let safeName = document.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = (safeName.isEmpty ? "ChimmoPostcard" : safeName) + "_声纹明信片.png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}
