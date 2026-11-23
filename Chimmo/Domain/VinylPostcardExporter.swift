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
    public let visualMode: StageVisualMode

    public init(
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        melodyVoice: MelodyVoice? = nil,
        shadowEnabled: Bool = false,
        isNight: Bool = false,
        headline: String? = nil,
        visualMode: StageVisualMode = .orbitalDisc
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
        self.visualMode = visualMode
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

                // 中央画境视觉（随当前主舞台模式所见即所得切换：转盘 / 曲线 / 星环）
                Canvas { ctx, size in
                    switch snapshot.visualMode {
                    case .orbitalDisc:
                        drawPostcardDisc(ctx: &ctx, size: size, palette: palette)
                    case .flowingRiver:
                        drawPostcardRiver(ctx: &ctx, size: size, palette: palette)
                    case .resonanceNebula:
                        drawPostcardNebula(ctx: &ctx, size: size, palette: palette)
                    }
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
            let isAnchor = PreLinguisticGuideGeometry.isStructuralAnchorLane(laneIdx)
            let trackW: CGFloat = laneIdx == 0 ? 1.55 : (isAnchor ? 1.25 : 0.85)
            let trackAlpha: Double = isAnchor ? (snapshot.isNight ? 0.34 : 0.38) : (snapshot.isNight ? 0.20 : 0.22)
            ctx.stroke(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                with: .color(col.opacity(trackAlpha)),
                lineWidth: trackW
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
            for i in 1..<pts.count {
                let d0 = pts[i - 1]
                let d1 = pts[i]
                let p0 = d0.pt
                let p1 = d1.pt
                let ctrl = CGPoint(
                    x: (p0.x + p1.x) * 0.5 + (center.x - (p0.x + p1.x) * 0.5) * 0.14,
                    y: (p0.y + p1.y) * 0.5 + (center.y - (p0.y + p1.y) * 0.5) * 0.14
                )
                var seg = Path()
                seg.move(to: p0)
                seg.addQuadCurve(to: p1, control: ctrl)
                let c0 = XylophoneLane.lane(at: d0.laneIdx).barColor(isNight: snapshot.isNight)
                let c1 = XylophoneLane.lane(at: d1.laneIdx).barColor(isNight: snapshot.isNight)
                let style = IntervalSilkStyle.metrics(fromLane: d0.laneIdx, toLane: d1.laneIdx, isNight: snapshot.isNight)
                if style.glowWidth > 0 {
                    ctx.stroke(
                        seg,
                        with: .linearGradient(
                            Gradient(colors: [c0.opacity(style.glowOpacity), c1.opacity(style.glowOpacity)]),
                            startPoint: p0,
                            endPoint: p1
                        ),
                        style: StrokeStyle(lineWidth: style.glowWidth, lineCap: .round)
                    )
                }
                ctx.stroke(
                    seg,
                    with: .linearGradient(
                        Gradient(colors: [c0.opacity(style.coreOpacity), c1.opacity(style.coreOpacity)]),
                        startPoint: p0,
                        endPoint: p1
                    ),
                    style: StrokeStyle(lineWidth: style.coreWidth, lineCap: .round)
                )
            }
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
            for ring in PreLinguisticGuideGeometry.emptyCanvasPulseRadii(phase: 0.28, maxRadius: outerR * 0.85) {
                let rRect = CGRect(x: center.x - ring.radius, y: center.y - ring.radius, width: ring.radius * 2, height: ring.radius * 2)
                ctx.stroke(
                    Path(ellipseIn: rRect),
                    with: .color(palette.nightLampGold.opacity(ring.opacity * 0.72)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 6])
                )
            }
        }
    }

    private func drawPostcardRiver(ctx: inout GraphicsContext, size: CGSize, palette: ChimmoPalette) {
        let cardRect = CGRect(x: 12, y: 20, width: size.width - 24, height: size.height - 40)
        let cardPath = RoundedRectangle(cornerRadius: 24, style: .continuous).path(in: cardRect)
        ctx.fill(
            cardPath,
            with: .linearGradient(
                Gradient(colors: snapshot.isNight
                    ? [Color(hex: 0x1D2551), Color(hex: 0x121836)]
                    : [Color(hex: 0xFFFFFF), Color(hex: 0xF1E8D9)]),
                startPoint: CGPoint(x: size.width * 0.5, y: cardRect.minY),
                endPoint: CGPoint(x: size.width * 0.5, y: cardRect.maxY)
            )
        )
        let rimColor = snapshot.isNight ? Color(hex: 0x524036).opacity(0.8) : Color(hex: 0xD2B48C).opacity(0.88)
        ctx.stroke(cardPath, with: .color(rimColor), lineWidth: 2.2)

        let padX: CGFloat = 28
        let usableW = max(1, size.width - padX * 2)
        let topY: CGFloat = 48
        let bottomY: CGFloat = size.height - 48
        let usableH = max(1, bottomY - topY)
        let total = snapshot.totalDuration

        // 1. 和声天光色带
        for span in snapshot.chordSpans {
            let x0 = padX + CGFloat(span.startTime / total) * usableW
            let x1 = padX + CGFloat(span.endTime / total) * usableW
            guard x1 > x0 + 2 else { continue }
            let col = span.chord.color(isNight: snapshot.isNight)
            let bandRect = CGRect(x: x0 + 1, y: topY - 8, width: x1 - x0 - 2, height: usableH + 16)
            ctx.fill(RoundedRectangle(cornerRadius: 10).path(in: bandRect), with: .color(col.opacity(snapshot.isNight ? 0.14 : 0.09)))
            let barRect = CGRect(x: x0 + 6, y: topY - 12, width: max(6, x1 - x0 - 12), height: 4)
            ctx.fill(Capsule().path(in: barRect), with: .color(col.opacity(0.80)))
        }

        // 2. 8 道水平音高线与 1/5 结构锚定
        for laneIdx in 0..<8 {
            let norm = CGFloat(laneIdx) / 7.0
            let y = bottomY - norm * usableH
            let col = XylophoneLane.lane(at: laneIdx).barColor(isNight: snapshot.isNight)
            let isAnchor = PreLinguisticGuideGeometry.isStructuralAnchorLane(laneIdx)
            var line = Path()
            line.move(to: CGPoint(x: padX, y: y))
            line.addLine(to: CGPoint(x: size.width - padX, y: y))
            ctx.stroke(
                line,
                with: .color(col.opacity(isAnchor ? (snapshot.isNight ? 0.42 : 0.44) : 0.18)),
                style: StrokeStyle(lineWidth: isAnchor ? 1.45 : 0.85, dash: isAnchor ? [] : [4, 5])
            )
        }

        if snapshot.notes.isEmpty {
            let c = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            for r in [24.0, 44.0, 66.0] {
                let cr = CGFloat(r)
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: c.x - cr, y: c.y - cr, width: cr * 2, height: cr * 2)),
                    with: .color(palette.nightLampGold.opacity(0.42)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 6])
                )
            }
            return
        }

        var pts: [(pt: CGPoint, laneIdx: Int, bead: NoteBead)] = []
        for bead in snapshot.notes {
            let onset = bead.displayOnset(grooveStrength: snapshot.grooveStrength)
            let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
            let x = padX + CGFloat(max(0.0, min(1.0, onset / total))) * usableW
            let y = bottomY - (CGFloat(laneIdx) / 7.0) * usableH
            pts.append((CGPoint(x: x, y: y), laneIdx, bead))
        }

        if pts.count > 1 {
            // 倒影剪影
            var area = Path()
            area.move(to: CGPoint(x: pts[0].pt.x, y: bottomY))
            area.addLine(to: pts[0].pt)
            for i in 1..<pts.count {
                let p0 = pts[i - 1].pt
                let p1 = pts[i].pt
                let mid = CGPoint(x: (p0.x + p1.x) * 0.5, y: p0.y)
                let mid2 = CGPoint(x: (p0.x + p1.x) * 0.5, y: p1.y)
                area.addCurve(to: p1, control1: mid, control2: mid2)
            }
            area.addLine(to: CGPoint(x: pts.last!.pt.x, y: bottomY))
            area.closeSubpath()
            ctx.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [palette.homeAnchor.opacity(0.18), .clear]),
                    startPoint: CGPoint(x: size.width * 0.5, y: topY),
                    endPoint: CGPoint(x: size.width * 0.5, y: bottomY)
                )
            )

            // 棱镜音程渐变曲线
            for i in 1..<pts.count {
                let d0 = pts[i - 1]
                let d1 = pts[i]
                let p0 = d0.pt
                let p1 = d1.pt
                let c1 = CGPoint(x: (p0.x + p1.x) * 0.5, y: p0.y)
                let c2 = CGPoint(x: (p0.x + p1.x) * 0.5, y: p1.y)
                var seg = Path()
                seg.move(to: p0)
                seg.addCurve(to: p1, control1: c1, control2: c2)
                let col0 = XylophoneLane.lane(at: d0.laneIdx).barColor(isNight: snapshot.isNight)
                let col1 = XylophoneLane.lane(at: d1.laneIdx).barColor(isNight: snapshot.isNight)
                let style = IntervalSilkStyle.metrics(fromLane: d0.laneIdx, toLane: d1.laneIdx, isNight: snapshot.isNight)
                if style.glowWidth > 0 {
                    ctx.stroke(
                        seg,
                        with: .linearGradient(Gradient(colors: [col0.opacity(style.glowOpacity), col1.opacity(style.glowOpacity)]), startPoint: p0, endPoint: p1),
                        style: StrokeStyle(lineWidth: style.glowWidth, lineCap: .round)
                    )
                }
                ctx.stroke(
                    seg,
                    with: .linearGradient(Gradient(colors: [col0.opacity(style.coreOpacity), col1.opacity(style.coreOpacity)]), startPoint: p0, endPoint: p1),
                    style: StrokeStyle(lineWidth: style.coreWidth, lineCap: .round)
                )
            }
        }

        if snapshot.shadowEnabled && !snapshot.shadowNotes.isEmpty {
            for shadow in snapshot.shadowNotes {
                let sLaneIdx = XylophoneLane.laneIndex(degree: shadow.degree, octaveOffset: shadow.octaveOffset)
                let sx = padX + CGFloat(max(0.0, min(1.0, shadow.onset / total))) * usableW
                let sy = min(bottomY + 10, bottomY - (CGFloat(sLaneIdx) / 7.0) * usableH + 14)
                let cr: CGFloat = 5.4
                var crescent = Path()
                let topTip = CGPoint(x: sx + cr * 0.35, y: sy - cr * 0.86)
                let botTip = CGPoint(x: sx + cr * 0.35, y: sy + cr * 0.86)
                crescent.move(to: topTip)
                crescent.addCurve(to: botTip, control1: CGPoint(x: sx - cr * 1.05, y: sy - cr * 0.55), control2: CGPoint(x: sx - cr * 1.05, y: sy + cr * 0.55))
                crescent.addCurve(to: topTip, control1: CGPoint(x: sx - cr * 0.20, y: sy + cr * 0.42), control2: CGPoint(x: sx - cr * 0.20, y: sy - cr * 0.42))
                crescent.closeSubpath()
                ctx.fill(crescent, with: .color(Color(hex: 0x7EC8E3).opacity(0.85)))
            }
        }

        for item in pts {
            let col = XylophoneLane.lane(at: item.laneIdx).barColor(isNight: snapshot.isNight)
            let orbR: CGFloat = 8.4
            let orbRect = CGRect(x: item.pt.x - orbR, y: item.pt.y - orbR, width: orbR * 2, height: orbR * 2)
            ctx.fill(Path(ellipseIn: orbRect), with: .color(col))
            ctx.stroke(Path(ellipseIn: orbRect), with: .color(.white.opacity(0.62)), lineWidth: 0.9)
            let gs = orbR * 1.1
            let gRect = CGRect(x: item.pt.x - gs * 0.5, y: item.pt.y - gs * 0.5, width: gs, height: gs)
            ctx.fill(PitchGlyphShape.glyph(forLaneIndex: item.laneIdx).path(in: gRect), with: .color(.white.opacity(0.95)), style: FillStyle(eoFill: true))
        }
    }

    private func drawPostcardNebula(ctx: inout GraphicsContext, size: CGSize, palette: ChimmoPalette) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let maxR = min(size.width, size.height) * 0.44
        let haloR = maxR * 0.98
        let platterR = maxR * 0.89
        let starRingR = platterR * 0.72
        let total = snapshot.totalDuration

        // 1. 和声外弧与珍珠定锚
        for span in snapshot.chordSpans {
            let a0 = -Double.pi / 2.0 + (span.startTime / total) * 2.0 * Double.pi + 0.04
            let a1 = -Double.pi / 2.0 + (span.endTime / total) * 2.0 * Double.pi - 0.04
            guard a1 > a0 else { continue }
            let col = span.chord.color(isNight: snapshot.isNight)
            var arc = Path()
            arc.addArc(center: center, radius: haloR, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
            ctx.stroke(arc, with: .color(col.opacity(0.24)), style: StrokeStyle(lineWidth: 9.0, lineCap: .round))
            ctx.stroke(arc, with: .color(col.opacity(0.80)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        }

        // 2. 星盘底盘与同心星环
        let platterRect = CGRect(x: center.x - platterR, y: center.y - platterR, width: platterR * 2, height: platterR * 2)
        ctx.fill(
            Path(ellipseIn: platterRect),
            with: .radialGradient(
                Gradient(colors: snapshot.isNight ? [Color(hex: 0x1E295E), Color(hex: 0x101638)] : [Color(hex: 0xFFFDF8), Color(hex: 0xEFE5D4)]),
                center: center,
                startRadius: 8,
                endRadius: platterR
            )
        )
        let rimColor = snapshot.isNight ? Color(hex: 0x524036).opacity(0.8) : Color(hex: 0xD2B48C).opacity(0.88)
        ctx.stroke(Path(ellipseIn: platterRect), with: .color(rimColor), lineWidth: 3.2)

        for mult in [0.42, 0.72] {
            let rr = platterR * CGFloat(mult)
            ctx.stroke(
                Path(ellipseIn: CGRect(x: center.x - rr, y: center.y - rr, width: rr * 2, height: rr * 2)),
                with: .color(palette.nightLampGold.opacity(snapshot.isNight ? 0.22 : 0.26)),
                style: StrokeStyle(lineWidth: 1.0, dash: [3, 5])
            )
        }

        // 3. 星环音程丝线轨迹（在 8 颗星座星之间穿梭）
        let touchedLanes = Set(snapshot.notes.map { XylophoneLane.laneIndex(degree: $0.degree, octaveOffset: $0.octaveOffset) })
        if snapshot.notes.count > 1 {
            for i in 1..<snapshot.notes.count {
                let l0 = XylophoneLane.laneIndex(degree: snapshot.notes[i - 1].degree, octaveOffset: snapshot.notes[i - 1].octaveOffset)
                let l1 = XylophoneLane.laneIndex(degree: snapshot.notes[i].degree, octaveOffset: snapshot.notes[i].octaveOffset)
                let p0 = ConstellationGeometry.starPoint(laneIndex: l0, center: center, radius: starRingR)
                let p1 = ConstellationGeometry.starPoint(laneIndex: l1, center: center, radius: starRingR)
                let ctrl = CGPoint(x: (p0.x + p1.x) * 0.5 + (center.x - (p0.x + p1.x) * 0.5) * 0.28,
                                   y: (p0.y + p1.y) * 0.5 + (center.y - (p0.y + p1.y) * 0.5) * 0.28)
                var seg = Path()
                seg.move(to: p0)
                seg.addQuadCurve(to: p1, control: ctrl)
                let c0 = XylophoneLane.lane(at: l0).barColor(isNight: snapshot.isNight)
                let c1 = XylophoneLane.lane(at: l1).barColor(isNight: snapshot.isNight)
                let style = IntervalSilkStyle.metrics(fromLane: l0, toLane: l1, isNight: snapshot.isNight)
                if style.glowWidth > 0 {
                    ctx.stroke(
                        seg,
                        with: .linearGradient(Gradient(colors: [c0.opacity(style.glowOpacity), c1.opacity(style.glowOpacity)]), startPoint: p0, endPoint: p1),
                        style: StrokeStyle(lineWidth: style.glowWidth, lineCap: .round)
                    )
                }
                ctx.stroke(
                    seg,
                    with: .linearGradient(Gradient(colors: [c0.opacity(style.coreOpacity), c1.opacity(style.coreOpacity)]), startPoint: p0, endPoint: p1),
                    style: StrokeStyle(lineWidth: style.coreWidth, lineCap: .round)
                )
            }
        }

        // 4. 8 颗星座定音星 + 1/5 锚定外晕
        for laneIdx in 0..<8 {
            let pt = ConstellationGeometry.starPoint(laneIndex: laneIdx, center: center, radius: starRingR)
            let col = XylophoneLane.lane(at: laneIdx).barColor(isNight: snapshot.isNight)
            let active = touchedLanes.contains(laneIdx)
            let isAnchor = PreLinguisticGuideGeometry.isStructuralAnchorLane(laneIdx)
            let starR: CGFloat = active ? 11.0 : 8.5
            if active || isAnchor {
                let hr = starR + 4.5
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: pt.x - hr, y: pt.y - hr, width: hr * 2, height: hr * 2)),
                    with: .color(col.opacity(active ? 0.55 : 0.26)),
                    lineWidth: isAnchor ? 1.4 : 1.0
                )
            }
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - starR, y: pt.y - starR, width: starR * 2, height: starR * 2)), with: .color(col.opacity(active ? 0.96 : 0.58)))
            let gs = starR * 1.05
            ctx.fill(PitchGlyphShape.glyph(forLaneIndex: laneIdx).path(in: CGRect(x: pt.x - gs * 0.5, y: pt.y - gs * 0.5, width: gs, height: gs)), with: .color(.white.opacity(0.95)), style: FillStyle(eoFill: true))
        }

        // 5. 中央大尺度利萨如星核 / 空盘呼吸导引环
        let coreR = platterR * 0.30
        let coreRect = CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2)
        ctx.fill(
            Path(ellipseIn: coreRect),
            with: .radialGradient(
                Gradient(colors: snapshot.isNight ? [Color(hex: 0xFFB84D).opacity(0.32), Color(hex: 0x242F63)] : [Color(hex: 0xFFE3A3).opacity(0.68), Color(hex: 0xF5E7CE)]),
                center: center,
                startRadius: 2,
                endRadius: coreR
            )
        )
        ctx.stroke(Path(ellipseIn: coreRect), with: .color(palette.nightLampGold.opacity(0.6)), lineWidth: 1.4)

        let amp = coreR * 0.62
        var wave = Path()
        for i in 0...100 {
            let u = (Double(i) / 100.0) * Double.pi * 2.0
            let wx = center.x + CGFloat(sin(Double(snapshot.harmonyPhysics.ratioA) * u + 0.45)) * amp
            let wy = center.y + CGFloat(sin(Double(snapshot.harmonyPhysics.ratioB) * u)) * amp
            if i == 0 { wave.move(to: CGPoint(x: wx, y: wy)) } else { wave.addLine(to: CGPoint(x: wx, y: wy)) }
        }
        ctx.stroke(wave, with: .color(palette.homeAnchor.opacity(0.88)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

        if snapshot.notes.isEmpty {
            for ring in PreLinguisticGuideGeometry.emptyCanvasPulseRadii(phase: 0.28, maxRadius: starRingR * 0.88) {
                let rRect = CGRect(x: center.x - ring.radius, y: center.y - ring.radius, width: ring.radius * 2, height: ring.radius * 2)
                ctx.stroke(
                    Path(ellipseIn: rRect),
                    with: .color(palette.nightLampGold.opacity(ring.opacity * 0.72)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 6])
                )
            }
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
        headline: String? = nil,
        visualMode: StageVisualMode = .orbitalDisc
    ) -> Data? {
        let snapshot = VinylPostcardSnapshot(
            document: document,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides,
            melodyVoice: melodyVoice,
            shadowEnabled: shadowEnabled,
            isNight: isNight,
            headline: headline,
            visualMode: visualMode
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
        headline: String? = nil,
        visualMode: StageVisualMode = .orbitalDisc
    ) throws -> URL {
        guard let data = renderPNGData(
            document: document,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides,
            melodyVoice: melodyVoice,
            shadowEnabled: shadowEnabled,
            isNight: isNight,
            headline: headline,
            visualMode: visualMode
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
