import SwiftUI

/// 零乐理 3 秒「捕梦创作」抽屉：
/// - 1) 拍节奏 · 画山坡：先按脑海里的快慢轻敲木鼓，再单指画一条起伏山坡（或一键套用 4 座山坡），五音不全也能一次写对；
/// - 2) 随口轻哼：不管跑不跑调，只听你的相对高低起伏自动排上星盘；
/// - 3) 魔法 · 跟弹 · 夜灯剧场：随时进入闭眼夜灯触觉剧场、跟着亮灯体验名曲，或铺开一张全新的安心 5 音画布。
public struct DreamCaptureSheet: View {
    @ObservedObject public var vm: StudioViewModel
    public let palette: ChimmoPalette

    @Environment(\.dismiss) private var dismiss
    @State private var modeTab: Int = 0
    @State private var drumScale: CGFloat = 1.0
    @State private var sketchPoints: [CGPoint] = []
    @State private var sketchSize: CGSize = CGSize(width: 300, height: 140)
    @State private var seedShifts: [Int] = [0, 0, 0]
    @State private var showNightLampTheater: Bool = false

    public init(vm: StudioViewModel, palette: ChimmoPalette) {
        self.vm = vm
        self.palette = palette
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("创作方式", selection: $modeTab) {
                    Text("敲节奏·画线").tag(0)
                    Text("哼唱").tag(1)
                    Text("更多玩法").tag(2)
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
            .navigationTitle("写旋律")
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
        .fullScreenCover(isPresented: $showNightLampTheater) {
            NightLampTactileSheet(vm: vm) {
                dismiss()
            }
        }
    }

    // MARK: - Tab 0: Drum Tap + 1-Finger Mountain Sketch + 4 Instant Hills

    private var rhythmAndSketchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // A. 敲节奏
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("第 1 步 · 敲出节奏")
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
                        Text("按心里快慢点几下，或直接画下方线条")
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
                        ChimmoCraftBadge(
                            .drumPulse,
                            accent: palette.nightLampGold,
                            surface: palette.shelfSurface,
                            size: 46
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("点这里敲节奏")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(palette.primaryInk)
                            Text("不管音高，只敲快慢")
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

            // B. 单指画高低线
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("第 2 步 · 画一条高低线")
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
                                Text("从左往右画出起伏，松手即生成")
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

            // C. 或者套用预设起伏
            VStack(alignment: .leading, spacing: 8) {
                Text("或直接套用预设起伏")
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

            // D. 一键切入闭眼夜灯触觉剧场
            Button {
                showNightLampTheater = true
            } label: {
                HStack(spacing: 10) {
                    ChimmoCraftBadge(
                        .nightLampHalo,
                        accent: palette.nightLampGold,
                        surface: palette.shelfSurface,
                        size: 32
                    )
                    Text("闭眼滑音 · 靠震动选音高")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.primaryInk)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.cardSurface))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(palette.nightLampGold.opacity(0.32), lineWidth: 1.0)
                )
            }
            .buttonStyle(.plain)
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

            Text(vm.capturePipeline.isRecording ? "正在录音，哼完点红色按钮停止" : "随口哼一段（跑调也没关系）")
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.primaryInk)

            Text(
                vm.document.notes.isEmpty
                    ? "轻声哼一句，自动转成旋律"
                    : "按你哼的高低变化，套用到当前节奏"
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

    // MARK: - Tab 2: Night-Lamp Theater, Magic Origami, Seed Variations, Follow-the-Glow & Blank Canvas

    private var followAndBlankSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 闭眼夜灯触觉剧场入口卡片（深曜夜色 × 温暖琥珀矢量夜灯图标）
            Button {
                showNightLampTheater = true
            } label: {
                HStack(spacing: 12) {
                    ChimmoCraftBadge(
                        .nightLampHalo,
                        accent: Color(hex: 0xFFB84D),
                        surface: Color(hex: 0x151D3B),
                        size: 42
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("闭眼滑音")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color(hex: 0xF4EBDD))
                        Text("不用看屏幕，上下滑动靠震动选音高，松手记下")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: 0xAEB4CC))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: 0xFFB84D))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x121A37), Color(hex: 0x1B244B)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color(hex: 0xFFB84D).opacity(0.40), lineWidth: 1.1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                if !vm.followGlowActive {
                    vm.toggleFollowGlow()
                }
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    ChimmoCraftBadge(
                        .followBeacon,
                        accent: palette.nightLampGold,
                        surface: palette.shelfSurface,
                        size: 38
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("跟灯弹这首曲子")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text("跟着亮起的彩条按自己的速度敲，就能弹完整首")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.cardSurface))
            }
            .buttonStyle(.plain)

            // 扩写旋律
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ChimmoCraftMark(.origamiPrism, color: palette.homeAnchor)
                        .frame(width: 14, height: 14)
                    Text("把几颗音扩成完整旋律")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryInk)
                }

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

            // 改开头 3 个音生成变奏
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        ChimmoCraftMark(.seedBloom, color: palette.homeAnchor)
                            .frame(width: 14, height: 14)
                        Text("改开头 3 个音，生成新变奏")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.secondaryInk)
                    }
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
                            Text("第 \(idx + 1) 音")
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
                        Text(seedShifts == [0, 0, 0] ? "随机改 3 个音" : "生成我的变奏")
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
                        Text("新建空白画布")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text("清空当前音符，开启五音模式从头开始")
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
