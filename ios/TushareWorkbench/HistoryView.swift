import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var openId: String?

    var body: some View {
        NavigationStack {
            Group {
                if model.history.isEmpty {
                    VStack(spacing: 10) {
                        Text("还没有学习记录。完成一次个股分析后，记录会保存在这里。")
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(model.history) { rec in
                                recordCard(rec)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
            .background(Palette.bg)
            .navigationTitle("学习记录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func recordCard(_ rec: HistoryRecord) -> some View {
        let open = openId == rec.id
        return AppCard(title: rec.stockName,
                       right: AnyView(Chip(label: rec.type))) {
            Text("\(rec.stockCode) · \(rec.createdAt)")
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
            Button(open ? "收起" : "查看结论依据") {
                withAnimation { openId = open ? nil : rec.id }
            }
            .font(.system(size: 13))
            .foregroundStyle(Palette.accent)
            if open {
                VStack(alignment: .leading, spacing: 4) {
                    Text("大盘：\(rec.report.market.state) · 板块：\(rec.report.sector.state)")
                        .font(.system(size: 12))
                    ForEach(Array(rec.report.why.enumerated()), id: \.offset) { _, w in
                        HStack(alignment: .top) {
                            Text("•").foregroundStyle(Palette.accent)
                            Text(w).font(.system(size: 12))
                        }
                    }
                    if !rec.answers.isEmpty {
                        Text("你的回答").font(.system(size: 12, weight: .bold))
                        ForEach(Array(rec.answers.enumerated()), id: \.offset) { _, a in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.question).font(.system(size: 11, weight: .semibold))
                                Text(a.answer).font(.system(size: 12))
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                    }
                    Button("重新分析") {
                        model.selectStock(rec.stockCode)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
