import SwiftUI

/// 零乐理 3 秒「捕梦创作」抽屉：
/// - 1) 🥁 拍节奏 · 画山坡：先按脑海里的快慢轻敲木鼓，再单指画一条起伏山坡（或一键套用 4 座山坡），五音不全也能一次写对；
/// - 2) 🎙 随口轻哼：不管跑不跑调，只听你的相对高低起伏自动排上星盘；
/// - 3) ✨ 亮灯跟弹 & 空白星盘：随时跟着亮灯体验名曲，或铺开一张全新的安心 5 音画布。
public struct DreamCaptureSheet: View {
    @ObservedObject public var vm: StudioViewModel
    public let palette: ChimmoPalette

    @Environment(\.dismiss) private var dismiss
    @State private var modeTab: Int = 0
    @State private var drumScale: CGFloat = 1.0
    @State private var sketchPoints: [CGPoint] = []
    @State private var sketchSize: CGSize = CGSize(width: 300, height: 140)
    @State private var seedShifts: [Int] = [0, 0, 0]

    public init(vm: StudioViewModel, palette: ChimmoPalette) {
        self.vm = vm
        self.palette = palette
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("创作方式", selection: $modeTab) {
                    Text("拍节奏·画山坡").tag(0)
                    Text("随口轻哼").tag(1)
                    Text("魔法·跟弹").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 6)

                ScrollView {
                    VStack(spacing: 16) {
                        if modeTab == 0 {
                            rhythmAndSketchSection
                        } else if modeTab == 1 {
                            forgivingHumSection
                        } else {
                            followAndBlankSection
                        }
                    }
                    .padding(16)
                }
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("捕梦创作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if vm.isTappingRhythm {
                            vm.cancelRhythmTap()
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Tab 0: Drum Tap + 1-Finger Mountain Sketch + 4 Instant Hills

    private var rhythmAndSketchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // A. 拍节奏木鼓
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("第 1 步 · 随手敲出脑海里的快慢节奏")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Spacer()
                    if !vm.liveTapTimestamps.isEmpty {
                        Button("重敲") {
                            vm.resetRhythmTaps()
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)
                    }
                }

                // 实时拍柱预览条
                HStack(spacing: 5) {
                    if vm.liveTapTimestamps.isEmpty {
                        Text("哒、哒、哒 — 敲几下试试（也可跳过直接画下方山坡）")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    } else {
                        ForEach(0..<vm.liveTapTimestamps.count, id: \.self) { idx in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(palette.homeAnchor.opacity(idx == vm.liveTapTimestamps.count - 1 ? 1.0 : 0.65))
                                .frame(width: 12, height: idx == 0 ? 28 : 20)
                        }
                        Spacer()
                        Text("\(vm.liveTapTimestamps.count) 拍")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(palette.homeAnchor)
                    }
                }
                .frame(height: 30)

                Button {
                    if !vm.isTappingRhythm {
                        vm.startRhythmTap()
                    }
                    vm.recordRhythmDrumTap()
                    drumScale = 0.94
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) {
                        drumScale = 1.0
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(palette.nightLampGold.opacity(0.24))
                                .frame(width: 46, height: 46)
                            Image(systemName: "hand.tap.fill")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(palette.nightLampGold)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("轻敲这里定下节奏")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                            Text("完全不用管音高，只按你心里的节拍点按")
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryInk)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(palette.cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(palette.homeAnchor.opacity(0.5), lineWidth: 1.8)
                            )
                    )
                    .scaleEffect(drumScale)
                }
                .buttonStyle(.plain)
            }

            // B. 单指画一座旋律山坡
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("第 2 步 · 用一根手指画出起伏山坡")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Spacer()
                    if !sketchPoints.isEmpty {
                        Button("重写") { sketchPoints.removeAll() }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.secondaryInk)
                    }
                }

                GeometryReader { geo in
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(palette.cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(palette.divider, lineWidth: 1.2)
                            )

                        if sketchPoints.isEmpty {
                            VStack(spacing: 4) {
                                Image(systemName: "scribble.variable")
                                    .font(.title2)
                                    .foregroundStyle(palette.homeAnchor.opacity(0.65))
                                Text("从左向右一笔画下高低走势，松手立刻飞上声盘")
                                    .font(.caption2)
                                    .foregroundStyle(palette.secondaryInk)
                            }
                        } else {
                            Canvas { ctx, _ in
                                var path = Path()
                                path.move(to: sketchPoints[0])
                                for pt in sketchPoints.dropFirst() {
                                    path.addLine(to: pt)
                                }
                                ctx.stroke(
                                    path,
                                    with: .color(palette.homeAnchor),
                                    style: StrokeStyle(lineWidth: 4.0, lineCap: .round, lineJoin: .round)
                                )
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                sketchSize = geo.size
                                let clamped = CGPoint(
                                    x: max(0, min(geo.size.width, val.location.x)),
                                    y: max(0, min(geo.size.height, val.location.y))
                                )
                                if sketchPoints.isEmpty {
                                    sketchPoints = [clamped]
                                } else if hypot(clamped.x - sketchPoints.last!.x, clamped.y - sketchPoints.last!.y) > 4 {
                                    sketchPoints.append(clamped)
                                }
                            }
                            .onEnded { _ in
                                let targetSlots = max(6, vm.liveTapTimestamps.count >= 2 ? vm.liveTapTimestamps.count : max(6, vm.document.notes.count))
                                let heights = ContourSketchSampler.sampleContour(points: sketchPoints, in: geo.size, slotCount: targetSlots)
                                if vm.liveTapTimestamps.count >= 2 {
                                    vm.commitRhythmTaps(withDrawnHeights: heights)
                                } else {
                                    vm.applyDrawnHillContour(heights)
                                }
                                dismiss()
                            }
                    )
                }
                .frame(height: 132)
            }

            // C. 或者一键套用 4 座现成山坡
            VStack(alignment: .leading, spacing: 8) {
                Text("或直接选一座喜欢的山坡")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryInk)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(MelodyHillTemplate.allCases) { hill in
                        Button {
                            if vm.liveTapTimestamps.count >= 2 {
                                vm.commitRhythmTaps()
                            }
                            vm.applyHillTemplate(hill)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                DreamMiniHillShape(profile: hill.previewProfile, color: palette.homeAnchor)
                                    .frame(width: 28, height: 14)
                                Text(hill.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(palette.primaryInk)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.cardSurface))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Tab 1: Forgiving Hum Capture

    private var forgivingHumSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(palette.melodyTerracotta.opacity(0.14))
                    .frame(width: 118, height: 118)
                    .scaleEffect(1.0 + CGFloat(vm.capturePipeline.inputLevel) * 0.35)

                Circle()
                    .fill(vm.capturePipeline.isRecording ? palette.melodyTerracotta : palette.homeAnchor)
                    .frame(width: 78, height: 78)

                Image(systemName: vm.capturePipeline.isRecording ? "stop.fill" : "mic.fill")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
            }
            .onTapGesture {
                if vm.capturePipeline.isRecording {
                    vm.finishRelativeContourHum()
                    dismiss()
                } else {
                    vm.startHumCapture()
                }
            }

            Text(vm.capturePipeline.isRecording ? "正在聆听… 哼完再点一下红色圆球" : "轻哼捉珠 · 完全不怕跑调")
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.primaryInk)

            Text(
                vm.document.notes.isEmpty
                    ? "用轻柔的 da / la 哼出一小句，系统会自动吸附到当前好听的音阶星盘上。"
                    : "只抓取你哼唱的相对高低走势，原封不动贴合到当前曲子的节奏上！"
            )
            .font(.caption)
            .foregroundStyle(palette.secondaryInk)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)

            if !vm.capturePipeline.statusMessage.isEmpty {
                Text(vm.capturePipeline.statusMessage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.homeAnchor)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(palette.cardSurface))
    }

    // MARK: - Tab 2: Magic Origami, Seed Variations, Follow-the-Glow & Blank Canvas

    private var followAndBlankSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                if !vm.followGlowActive {
                    vm.toggleFollowGlow()
                }
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(palette.nightLampGold)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("✨ 亮灯跟弹当前曲目")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text("转盘自动转到下一颗发光星珠，按你的速度跟着敲下方彩虹条即可亲自演奏！")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.cardSurface))
            }
            .buttonStyle(.plain)

            // 🌱 旋律折纸生长（把短短 3 颗音长成完整乐章）
            VStack(alignment: .leading, spacing: 8) {
                Text("🌱 旋律折纸生长（零基础一键扩写完整乐章）")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryInk)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(MotifGrowthOperation.allCases) { op in
                        Button {
                            vm.growCurrentWithOrigami(op)
                            dismiss()
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: op.iconName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(palette.homeAnchor)
                                Text(op.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(palette.primaryInk)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.cardSurface))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 🧅 大师火种微调（改掉前 3 颗火种音，即刻生出专属个人变奏）
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("🧅 改 3 颗火种 · 长出专属名曲变奏")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)
                    Spacer()
                    if seedShifts != [0, 0, 0] {
                        Button("重置") { seedShifts = [0, 0, 0] }
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.secondaryInk)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { idx in
                        VStack(spacing: 6) {
                            Text("火种 \(idx + 1)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.secondaryInk)
                            HStack(spacing: 8) {
                                Button {
                                    seedShifts[idx] = max(-3, seedShifts[idx] - 1)
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.caption2.weight(.bold))
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(palette.shelfSurface))
                                }
                                .buttonStyle(.plain)

                                Text(seedShifts[idx] == 0 ? "0" : (seedShifts[idx] > 0 ? "+\(seedShifts[idx])" : "\(seedShifts[idx])"))
                                    .font(.caption.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(seedShifts[idx] == 0 ? palette.primaryInk : palette.homeAnchor)
                                    .frame(minWidth: 20)

                                Button {
                                    seedShifts[idx] = min(3, seedShifts[idx] + 1)
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.caption2.weight(.bold))
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(palette.shelfSurface))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.cardSurface))
                    }
                }

                Button {
                    let applied = seedShifts == [0, 0, 0] ? [1, -1, 2] : seedShifts
                    vm.applyMasterpieceSeedShifts(applied)
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.caption.weight(.bold))
                        Text(seedShifts == [0, 0, 0] ? "随机轻改火种 · 生出我的变奏" : "按火种微调长出我的变奏")
                            .font(.caption.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(palette.homeAnchor))
                    .foregroundStyle(palette.isNight ? Color(hex: 0x1B2245) : .white)
                }
                .buttonStyle(.plain)
            }

            Button {
                vm.startBlankCanvas()
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(palette.homeAnchor)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("铺一张全新空白安心星盘")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text("清空当前音珠并打开「安心 5 音」，用手指直接在圆环上点亮属于你的星座旋律。")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.cardSurface))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct DreamMiniHillShape: View {
    let profile: [Double]
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            guard profile.count > 1 else { return }
            var p = Path()
            for (idx, h) in profile.enumerated() {
                let x = CGFloat(idx) / CGFloat(profile.count - 1) * size.width
                let y = size.height - 1.5 - CGFloat(h) * (size.height - 3.0)
                if idx == 0 { p.move(to: CGPoint(x: x, y: y)) }
                else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
    }
}
