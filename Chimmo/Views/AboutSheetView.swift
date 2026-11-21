import SwiftUI

/// 应用内「关于与隐私承诺」页（完全离线可查阅，同时提供标准 .mid 导出入口）。
public struct AboutSheetView: View {
    public let palette: ChimmoPalette
    public let currentDocument: MelodyDocument
    public let cradleEnabled: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var exportedMIDIURL: URL?

    public init(palette: ChimmoPalette, currentDocument: MelodyDocument, cradleEnabled: Bool) {
        self.palette = palette
        self.currentDocument = currentDocument
        self.cradleEnabled = cradleEnabled
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 品牌与七小只卡片
                    VStack(alignment: .leading, spacing: 8) {
                        Text("咩哞 · Chimmo")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.primaryInk)
                        Text("把脑海里的旋律唱出来、看得见。七只哑光窑陶小偶（1陶诺、2豆叩、3拍咯、4呜嘟、5壳咯、6钵莫、7叮尖）对应调内七个音级，陪零基础的你捉住脑放旋律、看见编曲家眼中的引力与和声。")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.shelfSurface))

                    // 标准 MIDI 导出（收于二级页面，不打扰零基础首屏）
                    VStack(alignment: .leading, spacing: 10) {
                        Text("导出当前乐思（进阶）")
                            .font(.headline)
                            .foregroundStyle(palette.primaryInk)
                        Text("可将当前画布上的旋律陶珠与水面托底和声导出为标准 MIDI（.mid）文件，直接导入 GarageBand 或 Logic Pro 继续编曲。")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)

                        if let url = exportedMIDIURL {
                            ShareLink(item: url) {
                                Label("分享 \(url.lastPathComponent)", systemImage: "square.and.arrow.up")
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(Capsule().fill(palette.homeAnchor))
                                    .foregroundStyle(palette.isNight ? Color(hex: 0x102026) : .white)
                            }
                        } else {
                            Button {
                                exportedMIDIURL = try? MIDIExporter.writeTemporaryMIDIFile(
                                    document: currentDocument,
                                    includeHarmonyCradle: cradleEnabled
                                )
                            } label: {
                                Label("生成标准 .mid 文件", systemImage: "pianokeys")
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(Capsule().fill(palette.homeAnchor))
                                    .foregroundStyle(palette.isNight ? Color(hex: 0x102026) : .white)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.shelfSurface))

                    // 隐私承诺与开源致谢
                    VStack(alignment: .leading, spacing: 8) {
                        Text("隐私承诺")
                            .font(.headline)
                            .foregroundStyle(palette.primaryInk)
                        Text("咩哞 100% 在本机离线运行：不需要账号、不连接网络、不含广告或任何第三方统计 SDK。你的哼唱音频只在本机内存中实时转换为音珠，从不上传至任何服务器。")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)

                        Divider().overlay(palette.divider).padding(.vertical, 4)

                        Text("开源许可与 100% 版权自洁说明")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.primaryInk)
                        Text("• 动态规划音符切分算法移植自开源项目 SwiftF0 (lars76/swift-f0, MIT License)。\n• 内置 20 首古典名曲（圣桑《天鹅》、李斯特《爱之梦》《安慰曲》《钟》、巴赫《前奏曲》《G弦上的咏叹调》《小步舞曲》《大提琴组曲》、柴可夫斯基《天鹅湖》、德彪西、肖邦、德沃夏克、萨蒂、贝多芬、舒伯特、帕赫贝尔、莫扎特等）均为作者逝世逾百年的全球公有领域乐谱独立编配。\n• 内置 8 首夏日治愈与现代技法曲目均为本项目 100% 原创，不含任何受版权保护的现代影视/流行作品旋律。")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryInk)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.cardSurface))
                }
                .padding(16)
            }
            .background(palette.paper.ignoresSafeArea())
            .navigationTitle("关于咩哞")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
