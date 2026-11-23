import Foundation

/// 名曲「剥洋葱倒拆 + 换种重生」引擎：
/// 反直觉地从 100% 大师成品（圣桑《天鹅》、巴赫、李斯特等）一层层剥回最初的 3 颗火种音，
/// 并允许零基础用户改掉任意 1 颗火种再拉回 100%，瞬间长出属于自己的大师风格变奏！
public enum MasterpieceOnionEngine {

    public enum NoteLayer: Int, Sendable {
        case seed = 0      // 最初 3 颗核心火种
        case skeleton = 1  // 骨干旋律节点
        case ornament = 2  // 灵动过渡与装饰
    }

    public static func layer(forIndex index: Int, totalCount: Int) -> NoteLayer {
        guard totalCount > 0 else { return .seed }
        if index < 3 { return .seed }
        if index == totalCount - 1 { return .skeleton }
        let strideStep = max(2, totalCount / 6)
        return (index % strideStep == 0) ? .skeleton : .ornament
    }

    /// 把用户对最初 3 颗火种音所做的音高微调（seedShifts[0..2]），按分形呼应优雅传播到整首名曲，生成专属变奏！
    public static func applySeedShifts(document: MelodyDocument, shifts: [Int]) -> MelodyDocument {
        guard !shifts.allSatisfy({ $0 == 0 }) else { return document }
        var copy = document
        let s = [
            shifts.indices.contains(0) ? shifts[0] : 0,
            shifts.indices.contains(1) ? shifts[1] : 0,
            shifts.indices.contains(2) ? shifts[2] : 0
        ]

        copy.notes = document.notes.enumerated().map { idx, bead in
            var b = bead
            let shift: Int
            if idx < 3 {
                shift = s[idx]
            } else if idx == document.notes.count - 1 {
                // 保持结尾稳稳归家不漂移
                shift = 0
            } else {
                // 让后续乐句周期性呼应用户的火种变化，听起来既保留原曲气质又长出新旋律！
                shift = s[idx % 3]
            }

            if shift != 0 {
                let linear = b.octaveOffset * 7 + (b.degree - 1) + shift
                let clamped = max(-3, min(8, linear))
                let newOct = Int(floor(Double(clamped) / 7.0))
                let newDeg = clamped - newOct * 7 + 1
                b.degree = max(1, min(7, newDeg))
                b.octaveOffset = max(-1, min(1, newOct))
            }
            return b
        }
        copy.title = "\(document.title) · 我的变奏"
        copy.isSpecimen = false
        return copy
    }
}
