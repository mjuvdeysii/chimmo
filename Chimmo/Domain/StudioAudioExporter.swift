import Foundation

/// 零联网工作室级立体声音频（16-bit PCM Stereo WAV）离线导出器。
/// 复刻主舞台所选乐器音色、调式声学空间气候、左手和声织体、巴赫对位与播放速度。
public enum StudioAudioExporter {

    public static func encodePCM16StereoWAV(left: [Float], right: [Float], sampleRate: Int) -> Data {
        let frameCount = min(left.count, right.count)
        let sr = UInt32(max(8_000, min(96_000, sampleRate)))
        let channels: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let blockAlign = channels * (bitsPerSample / 8)
        let byteRate = sr * UInt32(blockAlign)
        let dataBytes = UInt32(clamping: Int64(frameCount) * Int64(blockAlign))
        let riffChunkSize = UInt32(clamping: 36 + Int64(dataBytes))

        var data = Data()
        data.reserveCapacity(44 + Int(dataBytes))

        func appendASCII(_ str: String) {
            data.append(contentsOf: str.utf8)
        }
        func appendUInt32LE(_ v: UInt32) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func appendUInt16LE(_ v: UInt16) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func appendInt16LE(_ v: Int16) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        appendASCII("RIFF")
        appendUInt32LE(riffChunkSize)
        appendASCII("WAVE")
        appendASCII("fmt ")
        appendUInt32LE(16)
        appendUInt16LE(1)
        appendUInt16LE(channels)
        appendUInt32LE(sr)
        appendUInt32LE(byteRate)
        appendUInt16LE(blockAlign)
        appendUInt16LE(bitsPerSample)
        appendASCII("data")
        appendUInt32LE(dataBytes)

        for i in 0..<frameCount {
            let lRaw = left[i]
            let rRaw = right[i]
            let lClamped = lRaw.isFinite ? max(-1.0, min(1.0, lRaw)) : 0.0
            let rClamped = rRaw.isFinite ? max(-1.0, min(1.0, rRaw)) : 0.0
            appendInt16LE(Int16(clamping: Int((lClamped * 32767.0).rounded())))
            appendInt16LE(Int16(clamping: Int((rClamped * 32767.0).rounded())))
        }
        return data
    }

    public static func renderWAVData(
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        accompanimentTexture: AccompanimentTexture = .swanRipple,
        melodyVoice: MelodyVoice? = nil,
        shadowEnabled: Bool = false,
        playbackRate: Double = 1.0,
        visualMode: StageVisualMode = .orbitalDisc,
        sampleRate: Double = 44_100.0
    ) throws -> Data {
        let rendered = try FeltPianoSynth.renderOfflineSongPCM(
            document: document,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides,
            accompanimentTexture: accompanimentTexture,
            melodyVoice: melodyVoice,
            shadowEnabled: shadowEnabled,
            playbackRate: playbackRate,
            visualMode: visualMode,
            sampleRate: sampleRate
        )
        return encodePCM16StereoWAV(left: rendered.left, right: rendered.right, sampleRate: rendered.sampleRate)
    }

    public static func writeTemporaryWAVFile(
        document: MelodyDocument,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:],
        accompanimentTexture: AccompanimentTexture = .swanRipple,
        melodyVoice: MelodyVoice? = nil,
        shadowEnabled: Bool = false,
        playbackRate: Double = 1.0,
        visualMode: StageVisualMode = .orbitalDisc,
        sampleRate: Double = 44_100.0
    ) throws -> URL {
        let wavData = try renderWAVData(
            document: document,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides,
            accompanimentTexture: accompanimentTexture,
            melodyVoice: melodyVoice,
            shadowEnabled: shadowEnabled,
            playbackRate: playbackRate,
            visualMode: visualMode,
            sampleRate: sampleRate
        )
        let safeName = document.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = (safeName.isEmpty ? "ChimmoMelody" : safeName) + ".wav"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try wavData.write(to: url, options: .atomic)
        return url
    }
}
