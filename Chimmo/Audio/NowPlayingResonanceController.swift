import Foundation
#if os(iOS)
import MediaPlayer
import UIKit
#endif

/// Offline lock-screen & Control Center media transport controller.
@MainActor
public final class NowPlayingResonanceController {
    private let enabled: Bool
    private var playTargetToken: Any?
    private var pauseTargetToken: Any?
    private var toggleTargetToken: Any?
    private var stopTargetToken: Any?
    private var nextTargetToken: Any?
    private var prevTargetToken: Any?

    private var cachedArtworkKey: String = ""
    #if os(iOS)
    private var cachedArtwork: MPMediaItemArtwork?
    #endif

    public init(enabled: Bool = true) {
        self.enabled = enabled
    }

    deinit {
        #if os(iOS)
        if enabled {
            let capturedPlay = playTargetToken
            let capturedPause = pauseTargetToken
            let capturedToggle = toggleTargetToken
            let capturedStop = stopTargetToken
            let capturedNext = nextTargetToken
            let capturedPrev = prevTargetToken
            DispatchQueue.main.async {
                let center = MPRemoteCommandCenter.shared()
                if let t = capturedPlay { center.playCommand.removeTarget(t) }
                if let t = capturedPause { center.pauseCommand.removeTarget(t) }
                if let t = capturedToggle { center.togglePlayPauseCommand.removeTarget(t) }
                if let t = capturedStop { center.stopCommand.removeTarget(t) }
                if let t = capturedNext { center.nextTrackCommand.removeTarget(t) }
                if let t = capturedPrev { center.previousTrackCommand.removeTarget(t) }
            }
        }
        #endif
    }

    public func bindCommands(
        onPlay: @escaping @MainActor () -> Void,
        onPause: @escaping @MainActor () -> Void,
        onToggle: @escaping @MainActor () -> Void,
        onNextBand: (@MainActor () -> Void)? = nil,
        onPreviousBand: (@MainActor () -> Void)? = nil
    ) {
        guard enabled else { return }
        #if os(iOS)
        unbindCommands()
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.stopCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = (onNextBand != nil)
        center.previousTrackCommand.isEnabled = (onPreviousBand != nil)

        playTargetToken = center.playCommand.addTarget { _ in
            Task { @MainActor in onPlay() }
            return .success
        }
        pauseTargetToken = center.pauseCommand.addTarget { _ in
            Task { @MainActor in onPause() }
            return .success
        }
        toggleTargetToken = center.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in onToggle() }
            return .success
        }
        stopTargetToken = center.stopCommand.addTarget { _ in
            Task { @MainActor in onPause() }
            return .success
        }
        if let onNextBand {
            nextTargetToken = center.nextTrackCommand.addTarget { _ in
                Task { @MainActor in onNextBand() }
                return .success
            }
        }
        if let onPreviousBand {
            prevTargetToken = center.previousTrackCommand.addTarget { _ in
                Task { @MainActor in onPreviousBand() }
                return .success
            }
        }
        #endif
    }

    public func updateNowPlaying(
        title: String,
        bandLabel: String,
        isPlaying: Bool,
        durationSeconds: Double?,
        elapsedSeconds: Double?,
        accentHex: UInt32,
        isNight: Bool
    ) {
        guard enabled else { return }
        #if os(iOS)
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: String(localized: "brand_full_title", defaultValue: "咩哞 · Mie & Mou"),
            MPMediaItemPropertyAlbumTitle: bandLabel,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: durationSeconds == nil
        ]
        if let durationSeconds, durationSeconds.isFinite, durationSeconds > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = durationSeconds
        }
        if let elapsedSeconds, elapsedSeconds.isFinite, elapsedSeconds >= 0 {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedSeconds
        }

        let key = "\(accentHex)-\(isNight)"
        if key != cachedArtworkKey || cachedArtwork == nil {
            cachedArtworkKey = key
            cachedArtwork = MPMediaItemArtwork(boundsSize: CGSize(width: 240, height: 240)) { size in
                let side = max(64.0, min(512.0, min(size.width, size.height)))
                return Self.renderLockscreenArtwork(
                    size: CGSize(width: side, height: side),
                    accentHex: accentHex,
                    isNight: isNight
                )
            }
        }
        if let artwork = cachedArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused
        #endif
    }

    /// Clears lock-screen banner while preserving bound remote commands so external play still works.
    public func clearNowPlayingInfo() {
        guard enabled else { return }
        #if os(iOS)
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = nil
        center.playbackState = .stopped
        #endif
    }

    public func unbindCommands() {
        #if os(iOS)
        let center = MPRemoteCommandCenter.shared()
        if let t = playTargetToken { center.playCommand.removeTarget(t) }
        if let t = pauseTargetToken { center.pauseCommand.removeTarget(t) }
        if let t = toggleTargetToken { center.togglePlayPauseCommand.removeTarget(t) }
        if let t = stopTargetToken { center.stopCommand.removeTarget(t) }
        if let t = nextTargetToken { center.nextTrackCommand.removeTarget(t) }
        if let t = prevTargetToken { center.previousTrackCommand.removeTarget(t) }
        center.playCommand.isEnabled = false
        center.pauseCommand.isEnabled = false
        center.togglePlayPauseCommand.isEnabled = false
        center.stopCommand.isEnabled = false
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        playTargetToken = nil
        pauseTargetToken = nil
        toggleTargetToken = nil
        stopTargetToken = nil
        nextTargetToken = nil
        prevTargetToken = nil
        #endif
    }

    #if os(iOS)
    nonisolated private static func renderLockscreenArtwork(
        size: CGSize,
        accentHex: UInt32,
        isNight: Bool
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let bgColor = isNight
                ? UIColor(red: 14 / 255.0, green: 19 / 255.0, blue: 38 / 255.0, alpha: 1.0)
                : UIColor(red: 251 / 255.0, green: 247 / 255.0, blue: 240 / 255.0, alpha: 1.0)
            let inkColor = isNight
                ? UIColor(red: 216 / 255.0, green: 223 / 255.0, blue: 244 / 255.0, alpha: 0.72)
                : UIColor(red: 35 / 255.0, green: 27 / 255.0, blue: 21 / 255.0, alpha: 0.78)
            bgColor.setFill()
            ctx.fill(rect)

            let r = CGFloat((accentHex >> 16) & 0xFF) / 255.0
            let g = CGFloat((accentHex >> 8) & 0xFF) / 255.0
            let b = CGFloat(accentHex & 0xFF) / 255.0
            let accent = UIColor(red: r, green: g, blue: b, alpha: 1.0)

            let center = CGPoint(x: rect.midX, y: rect.midY)
            let minSide = min(size.width, size.height)

            // 6-lobe Chladni standing-wave mandala rings matching primary Resonance Field
            for idx in 0..<3 {
                let rad = minSide * (0.28 + CGFloat(idx) * 0.085)
                let amp = minSide * (0.018 - CGFloat(idx) * 0.004)
                let p = UIBezierPath()
                let steps = 72
                for s in 0...steps {
                    let theta = CGFloat(s) / CGFloat(steps) * CGFloat.pi * 2.0
                    let rWave = rad + sin(theta * 6.0 + CGFloat(idx) * 0.6) * amp
                    let pt = CGPoint(x: center.x + cos(theta) * rWave, y: center.y + sin(theta) * rWave)
                    if s == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.close()
                accent.withAlphaComponent(0.38 - CGFloat(idx) * 0.09).setStroke()
                p.lineWidth = max(1.8, minSide * 0.015)
                p.stroke()
            }

            // Sculptural Mie & Mou miniature duo silhouette inside central kiln vessel
            let s = minSide * 0.34
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
            let hornCol = isNight
                ? UIColor(red: 255 / 255.0, green: 196 / 255.0, blue: 92 / 255.0, alpha: 1.0)
                : UIColor(red: 232 / 255.0, green: 162 / 255.0, blue: 28 / 255.0, alpha: 1.0)

            let cowRect = CGRect(x: center.x + s * 0.04, y: center.y - s * 0.30, width: s * 0.62, height: s * 0.58)
            for side in [-1.0, 1.0] {
                let sx = CGFloat(side)
                let horn = UIBezierPath()
                horn.move(to: CGPoint(x: cowRect.midX + sx * s * 0.08, y: cowRect.minY + s * 0.04))
                horn.addQuadCurve(
                    to: CGPoint(x: cowRect.midX + sx * s * 0.25, y: cowRect.minY - s * 0.14),
                    controlPoint: CGPoint(x: cowRect.midX + sx * s * 0.22, y: cowRect.minY)
                )
                hornCol.setStroke()
                horn.lineWidth = max(1.8, minSide * 0.016)
                horn.lineCapStyle = .round
                horn.stroke()
            }
            let cowPath = UIBezierPath(roundedRect: cowRect, cornerRadius: s * 0.24)
            cowFill.setFill()
            cowPath.fill()
            inkColor.setStroke()
            cowPath.lineWidth = max(1.4, minSide * 0.012)
            cowPath.stroke()
            cowSnout.setFill()
            UIBezierPath(ovalIn: CGRect(x: cowRect.minX + s * 0.12, y: cowRect.maxY - s * 0.24, width: s * 0.38, height: s * 0.19)).fill()

            let sheepRect = CGRect(x: center.x - s * 0.66, y: center.y - s * 0.28, width: s * 0.60, height: s * 0.56)
            for side in [-1.0, 1.0] {
                let sx = CGFloat(side)
                let h = UIBezierPath()
                h.move(to: CGPoint(x: sheepRect.midX + sx * s * 0.08, y: sheepRect.minY + s * 0.02))
                h.addQuadCurve(
                    to: CGPoint(x: sheepRect.midX + sx * s * 0.24, y: sheepRect.minY - s * 0.08),
                    controlPoint: CGPoint(x: sheepRect.midX + sx * s * 0.24, y: sheepRect.minY - s * 0.16)
                )
                hornCol.setStroke()
                h.lineWidth = max(2.0, minSide * 0.018)
                h.lineCapStyle = .round
                h.stroke()
            }
            let sheepPath = UIBezierPath(ovalIn: sheepRect)
            sheepWool.setFill()
            sheepPath.fill()
            inkColor.setStroke()
            sheepPath.lineWidth = max(1.4, minSide * 0.012)
            sheepPath.stroke()
            sheepFace.setFill()
            UIBezierPath(ovalIn: CGRect(x: sheepRect.midX - s * 0.17, y: sheepRect.midY - s * 0.13, width: s * 0.34, height: s * 0.26)).fill()

            // Center acoustic resonance seal below duo
            let beadRad = minSide * 0.032
            accent.setFill()
            UIBezierPath(ovalIn: CGRect(x: center.x - beadRad, y: center.y + s * 0.40, width: beadRad * 2, height: beadRad * 2)).fill()
        }
    }
    #endif
}
