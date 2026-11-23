import Foundation

/// 纯 Swift 零依赖标准 MIDI 文件（SMF Format 0, 480 TPQN）导出器。
/// 支持将用户哼唱/创作的陶珠旋律与水面托底和声一键导出为 `.mid` 供 GarageBand / Logic Pro 打开。
public enum MIDIExporter {

    private static let ticksPerQuarterNote: UInt16 = 480

    private struct RawMIDIEvent {
        let tick: Int
        let sortPriority: Int // programChange (-1), noteOff (0), noteOn (1)
        let bytes: [UInt8]
    }

    public static func generalMIDIProgram(for voice: MelodyVoice) -> UInt8 {
        switch voice {
        case .concertPiano: return 0   // Acoustic Grand Piano
        case .singingCello: return 42  // Cello
        case .liquidHarp:   return 46  // Orchestral Harp
        case .celestaGlass: return 8   // Celesta
        }
    }

    public static func encodeSMF(
        document: MelodyDocument,
        includeHarmonyCradle: Bool = true,
        melodyVoice: MelodyVoice? = nil,
        includeShadowCounterpoint: Bool = false,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:]
    ) -> Data {
        let bpm = max(40.0, min(240.0, document.estimatedBPM))
        let microsecondsPerBeat = UInt32((60_000_000.0 / bpm).rounded())
        let ticksPerSecond = Double(ticksPerQuarterNote) * (bpm / 60.0)

        let resolvedVoice = melodyVoice ?? document.preferredVoice ?? .concertPiano
        let shadowProgram: UInt8 = (resolvedVoice == .liquidHarp) ? 8 : 46

        var events: [RawMIDIEvent] = [
            RawMIDIEvent(tick: 0, sortPriority: -1, bytes: [0xC0, generalMIDIProgram(for: resolvedVoice)]),
            RawMIDIEvent(tick: 0, sortPriority: -1, bytes: [0xC1, 0]),
            RawMIDIEvent(tick: 0, sortPriority: -1, bytes: [0xC2, shadowProgram])
        ]

        let sortedNotes = document.notes.sorted {
            $0.displayOnset(grooveStrength: document.grooveStrength) < $1.displayOnset(grooveStrength: document.grooveStrength)
        }
        var prevLaneIdx: Int? = nil

        for (idx, bead) in sortedNotes.enumerated() {
            let onsetSec = bead.displayOnset(grooveStrength: document.grooveStrength)
            let durSec = bead.displayDuration(grooveStrength: document.grooveStrength)
            let startTick = max(0, Int((onsetSec * ticksPerSecond).rounded()))
            let endTick = max(startTick + 1, Int(((onsetSec + durSec) * ticksPerSecond).rounded()))

            let laneIdx = XylophoneLane.laneIndex(degree: bead.degree, octaveOffset: bead.octaveOffset)
            let vel: UInt8
            if idx == 0 || idx % 4 == 0 {
                vel = 96
            } else if let prev = prevLaneIdx, laneIdx > prev + 2 {
                vel = 92
            } else {
                vel = 82
            }
            prevLaneIdx = laneIdx

            let melodyMIDI = UInt8(clamping: document.scaleMode.midiNote(
                rootMIDI: document.rootMIDI,
                degree: bead.degree,
                octaveOffset: bead.octaveOffset
            ))
            events.append(RawMIDIEvent(tick: startTick, sortPriority: 1, bytes: [0x90, melodyMIDI, vel]))
            events.append(RawMIDIEvent(tick: endTick, sortPriority: 0, bytes: [0x80, melodyMIDI, 0]))
        }

        let effectivePreset: ChordProgressionPreset = includeHarmonyCradle ? (chordPreset == .off ? .autoMatch : chordPreset) : .off
        let spans = TheoryLensEngine.buildChordSpans(
            document: document,
            preset: effectivePreset,
            overrides: chordOverrides
        )

        if includeHarmonyCradle && effectivePreset != .off {
            for span in spans {
                let startTick = max(0, Int((span.startTime * ticksPerSecond).rounded()))
                let endTick = max(startTick + 1, Int((span.endTime * ticksPerSecond).rounded()))
                let rDeg = span.chord.rootDegree
                let bassMIDI = UInt8(clamping: document.scaleMode.midiNote(
                    rootMIDI: document.rootMIDI,
                    degree: rDeg,
                    octaveOffset: -1
                ))
                events.append(RawMIDIEvent(tick: startTick, sortPriority: 1, bytes: [0x91, bassMIDI, 64]))
                events.append(RawMIDIEvent(tick: endTick, sortPriority: 0, bytes: [0x81, bassMIDI, 0]))

                for (idx, deg) in span.chord.chordToneDegrees.enumerated() {
                    let oct = (idx > 0 && deg < rDeg) ? 0 : (idx == 0 ? -1 : 0)
                    let padMIDI = UInt8(clamping: document.scaleMode.midiNote(
                        rootMIDI: document.rootMIDI,
                        degree: deg,
                        octaveOffset: oct
                    ))
                    events.append(RawMIDIEvent(tick: startTick, sortPriority: 1, bytes: [0x91, padMIDI, 54]))
                    events.append(RawMIDIEvent(tick: endTick, sortPriority: 0, bytes: [0x81, padMIDI, 0]))
                }
            }
        }

        if includeShadowCounterpoint {
            let shadowSpans = TheoryLensEngine.buildChordSpans(document: document, preset: chordPreset, overrides: chordOverrides)
            let shadowNotes = CounterpointShadowEngine.generateShadowVoice(document: document, spans: shadowSpans)
            for s in shadowNotes {
                let startTick = max(0, Int((s.onset * ticksPerSecond).rounded()))
                let endTick = max(startTick + 1, Int(((s.onset + s.duration) * ticksPerSecond).rounded()))
                let sMIDI = UInt8(clamping: document.scaleMode.midiNote(
                    rootMIDI: document.rootMIDI,
                    degree: s.degree,
                    octaveOffset: s.octaveOffset
                ))
                events.append(RawMIDIEvent(tick: startTick, sortPriority: 1, bytes: [0x92, sMIDI, 60]))
                events.append(RawMIDIEvent(tick: endTick, sortPriority: 0, bytes: [0x82, sMIDI, 0]))
            }
        }

        events.sort {
            if $0.tick != $1.tick { return $0.tick < $1.tick }
            return $0.sortPriority < $1.sortPriority
        }

        var trackBytes: [UInt8] = []
        // Track Name meta event (FF 03)
        let titleUTF8 = Array(document.title.utf8.prefix(64))
        trackBytes.append(0x00)
        trackBytes.append(contentsOf: [0xFF, 0x03])
        trackBytes.append(contentsOf: encodeVLQ(titleUTF8.count))
        trackBytes.append(contentsOf: titleUTF8)

        // Set Tempo meta event (FF 51 03 tt tt tt)
        trackBytes.append(0x00)
        trackBytes.append(contentsOf: [
            0xFF, 0x51, 0x03,
            UInt8((microsecondsPerBeat >> 16) & 0xFF),
            UInt8((microsecondsPerBeat >> 8) & 0xFF),
            UInt8(microsecondsPerBeat & 0xFF)
        ])

        var lastTick = 0
        for ev in events {
            let delta = max(0, ev.tick - lastTick)
            trackBytes.append(contentsOf: encodeVLQ(delta))
            trackBytes.append(contentsOf: ev.bytes)
            lastTick = ev.tick
        }

        // End of Track meta event (FF 2F 00)
        trackBytes.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])

        var fileBytes: [UInt8] = []
        // MThd header (Format 0, 1 track, 480 TPQN)
        fileBytes.append(contentsOf: [0x4D, 0x54, 0x68, 0x64]) // "MThd"
        fileBytes.append(contentsOf: [0x00, 0x00, 0x00, 0x06]) // length 6
        fileBytes.append(contentsOf: [0x00, 0x00])             // format 0
        fileBytes.append(contentsOf: [0x00, 0x01])             // 1 track
        fileBytes.append(UInt8((ticksPerQuarterNote >> 8) & 0xFF))
        fileBytes.append(UInt8(ticksPerQuarterNote & 0xFF))

        // MTrk chunk
        fileBytes.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        let tLen = UInt32(trackBytes.count)
        fileBytes.append(contentsOf: [
            UInt8((tLen >> 24) & 0xFF),
            UInt8((tLen >> 16) & 0xFF),
            UInt8((tLen >> 8) & 0xFF),
            UInt8(tLen & 0xFF)
        ])
        fileBytes.append(contentsOf: trackBytes)

        return Data(fileBytes)
    }

    public static func writeTemporaryMIDIFile(
        document: MelodyDocument,
        includeHarmonyCradle: Bool = true,
        melodyVoice: MelodyVoice? = nil,
        includeShadowCounterpoint: Bool = false,
        chordPreset: ChordProgressionPreset = .autoMatch,
        chordOverrides: [Int: DiatonicChord] = [:]
    ) throws -> URL {
        let data = encodeSMF(
            document: document,
            includeHarmonyCradle: includeHarmonyCradle,
            melodyVoice: melodyVoice,
            includeShadowCounterpoint: includeShadowCounterpoint,
            chordPreset: chordPreset,
            chordOverrides: chordOverrides
        )
        let safeName = document.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = (safeName.isEmpty ? "ChimmoMelody" : safeName) + ".mid"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func encodeVLQ(_ value: Int) -> [UInt8] {
        var v = max(0, value)
        var buffer: [UInt8] = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 {
            buffer.insert(UInt8((v & 0x7F) | 0x80), at: 0)
            v >>= 7
        }
        return buffer
    }
}
