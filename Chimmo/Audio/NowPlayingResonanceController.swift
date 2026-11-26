import Foundation
#if os(iOS)
import MediaPlayer
import UIKit
#endif

/// 锁屏与控制中心「正在播放」媒体控制器（100% 离线，支持测试注入 disabled 隔离系统状态）。
@MainActor
public final class NowPlayingResonanceController {
    private let enabled: Bool
    private var playTargetToken: Any?
    private var pauseTargetToken: Any?
    private var toggleTargetToken: Any?
    private var stopTargetToken: Any?

    public init(enabled: Bool = true) {
        self.enabled = enabled
    }

    public func bindCommands(
        onPlay: @escaping @MainActor () -> Void,
        onPause: @escaping @MainActor () -> Void,
        onToggle: @escaping @MainActor () -> Void
    ) {
        guard enabled else { return }
        #if os(iOS)
        clearCommands()
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.stopCommand.isEnabled = true

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
            MPMediaItemPropertyArtist: "咩哞 · Mie & Mou",
            MPMediaItemPropertyAlbumTitle: bandLabel,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: durationSeconds == nil
        ]
        if let durationSeconds, durationSeconds.isFinite && durationSeconds > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = durationSeconds
        }
        if let elapsedSeconds, elapsedSeconds.isFinite && elapsedSeconds >= 0 {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedSeconds
        }

        let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 256, height: 256)) { size in
            Self.renderLockscreenArtwork(size: size, accentHex: accentHex, isNight: isNight)
        }
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #endif
    }

    public func clear() {
        guard enabled else { return }
        #if os(iOS)
        clearCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        #endif
    }

    #if os(iOS)
    private func clearCommands() {
        let center = MPRemoteCommandCenter.shared()
        if let t = playTargetToken { center.playCommand.removeTarget(t) }
        if let t = pauseTargetToken { center.pauseCommand.removeTarget(t) }
        if let t = toggleTargetToken { center.togglePlayPauseCommand.removeTarget(t) }
        if let t = stopTargetToken { center.stopCommand.removeTarget(t) }
        playTargetToken = nil
        pauseTargetToken = nil
        toggleTargetToken = nil
        stopTargetToken = nil
    }

    nonisolated private static func renderLockscreenArtwork(
        size: CGSize,
        accentHex: UInt32,
        isNight: Bool
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let bgColor = isNight
                ? UIColor(red: 14 / 255.0, green: 20 / 255.0, blue: 48 / 255.0, alpha: 1.0)
                : UIColor(red: 251 / 255.0, green: 247 / 255.0, blue: 240 / 255.0, alpha: 1.0)
            bgColor.setFill()
            ctx.fill(rect)

            let r = CGFloat((accentHex >> 16) & 0xFF) / 255.0
            let g = CGFloat((accentHex >> 8) & 0xFF) / 255.0
            let b = CGFloat(accentHex & 0xFF) / 255.0
            let accent = UIColor(red: r, green: g, blue: b, alpha: 1.0)

            let center = CGPoint(x: rect.midX, y: rect.midY)
            for idx in 0..<3 {
                let rad = min(size.width, size.height) * (0.20 + CGFloat(idx) * 0.11)
                let ringRect = CGRect(x: center.x - rad, y: center.y - rad, width: rad * 2, height: rad * 2)
                accent.withAlphaComponent(0.28 - CGFloat(idx) * 0.06).setStroke()
                let p = UIBezierPath(ovalIn: ringRect)
                p.lineWidth = 4.0
                p.stroke()
            }

            let coreRad = min(size.width, size.height) * 0.12
            let coreRect = CGRect(x: center.x - coreRad, y: center.y - coreRad, width: coreRad * 2, height: coreRad * 2)
            accent.setFill()
            UIBezierPath(ovalIn: coreRect).fill()
        }
    }
    #endif
}
