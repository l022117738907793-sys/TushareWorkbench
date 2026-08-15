import SwiftUI
import TushareWorkbenchCore

private let typeOrder = ["启动观察", "趋势观察", "高位观察", "回调观察", "排除", "数据不足"]
private let thesisTypes = ["技术形态", "消息催化", "基本面", "资金流向", "情绪博弈"]

struct AnalysisView: View {
    @EnvironmentObject private var model: AppModel
    @State private var answers: [Int: String] = [:]
    @State private var feedbacks: [Int: LearningFeedback] = [:]
    @State private var saved = false
    @State private var thesis = ThesisInput(types: [], horizon: "波段", text: "")
    @State private var review: ThesisReview?

    private var stock: StockData? {
        model.snapshot?.stocks.first { $0.code == model.selectedStock }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let stock {
                    content(stock)
                } else {
                    VStack(spacing: 12) {
                        Text("先在「工作台」里选择一只股票，然后在这里查看七步分析～")
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                        Button("去工作台") {
                            model.selectedTab = .workbench
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                }
            }
            .background(Palette.bg)
            .navigationTitle("个股分析")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func content(_ stock: StockData) -> some View {
        let report = try? model.report(for: stock.code)
        let metrics = model.rules.map { computeStockMetrics(stock, $0) }
        return ScrollView {
            VStack(spacing: 10) {
                if let report, let m = metrics {
                header(stock, report)
                Sparkline(values: stock.close)
                    .frame(height: 56)
                    .padding(12)
                    .background(Palette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                if !report.dataSufficiency.enough {
                    AppCard {
                        Text("【数据不足，不许编造】\(report.dataSufficiency.missing.joined(separator: "；"))")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                    }
                }

                section("【市场环境】", report.market.state,
                        extra: report.market.implication,
                        reasons: report.market.reasons)
                section("【板块状态】", report.sector.state,
                        extra: "上涨占比 \(Int((report.sector.breadth20 ?? 0) * 100))% · 强势股 \(report.sector.strongCount) 只" +
                            (report.sector.strongestMembers.isEmpty ? "" : " · 代表：\(report.sector.strongestMembers.joined(separator: "、"))"),
                        reasons: report.sector.reasons)
                section("【个股走势阶段】", report.stockTrend.state,
                        reasons: report.stockTrend.reasons)
                section("【近期价格行为】", report.priceAction.state,
                        extra: "ATR：\(m.atr.available ? m.atr.flag : "数据不足") · 量比 \(fmt(m.volRatio)) · 5日 \(fmt(m.ret5))% · 20日 \(fmt(m.ret20))%",
                        reasons: report.priceAction.reasons)
                section("【当前位置】", report.position.state,
                        extra: report.position.trendBroken == nil
                            ? nil
                            : "趋势破坏：\(report.position.trendBroken! ? "已破坏" : "未破坏") · 回调量能：\(report.position.volumeHeavy! ? "放量" : "未明显放量")",
                        reasons: report.position.reasons)

                AppCard(title: "【下一步观察】") {
                    ForEach(Array(report.nextSteps.enumerated()), id: \.offset) { _, s in
                        HStack(alignment: .top) {
                            Text("•").foregroundStyle(Palette.accent)
                            Text(s).font(.system(size: 13))
                        }
                    }
                }

                AppCard(title: "【分析结论】",
                        right: AnyView(Chip(label: report.currentType))) {
                    Text(report.conclusion)
                        .font(.system(size: 15, weight: .bold))
                    Text("为什么").font(.system(size: 13, weight: .semibold))
                    ForEach(Array(report.why.enumerated()), id: \.offset) { _, w in
                        HStack(alignment: .top) {
                            Text("•").foregroundStyle(Palette.accent)
                            Text(w).font(.system(size: 13))
                        }
                    }
                }

                learningCard(report, m)
                thesisCard(report, m)
                } else {
                    Text("分析失败").foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func header(_ stock: StockData, _ report: AnalysisReport) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(stock.name).font(.system(size: 20, weight: .bold))
                Text("\(stock.code) · \(stock.industry) · 数据日期 \(model.snapshot?.meta?.asOf ?? "")")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            Chip(label: report.currentType)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private func section(_ title: String, _ state: String,
                         extra: String? = nil,
                         reasons: [ReasonItem]) -> some View {
        AppCard(title: title, right: AnyView(Chip(label: state))) {
            if let extra, !extra.isEmpty {
                Text(extra).font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .padding(.vertical, 4)
            }
            ReasonList(reasons: reasons)
        }
    }

    private func learningCard(_ report: AnalysisReport, _ m: StockMetrics) -> some View {
        let qList = questions(for: report.currentType)
        return AppCard(title: "学习模式") {
            Text("下面几个问题没有标准答案，目的是练习「市场 → 板块 → 个股趋势 → 涨跌程度 → 当前位置 → 下一步」这套框架。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
            ForEach(Array(qList.enumerated()), id: \.offset) { i, q in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(i + 1). \(q)").font(.system(size: 13))
                    let options = quickOptions(report.currentType, q)
                    if !options.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(options, id: \.self) { o in
                                FilterChip(label: o, isActive: answers[i] == o) {
                                    submit(i, o, report, m)
                                }
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("写下你的判断…", text: Binding(
                            get: { answers[i] ?? "" },
                            set: { answers[i] = $0; feedbacks.removeValue(forKey: i) }
                        ))
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Palette.card2)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button("对照") {
                            submit(i, answers[i] ?? "", report, m)
                        }
                        .disabled((answers[i] ?? "").isEmpty)
                        .font(.system(size: 12))
                        .buttonStyle(.borderedProminent)
                    }
                    if let fb = feedbacks[i] {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("【你的判断】").font(.system(size: 12, weight: .bold))
                            ForEach(fb.doneRight, id: \.self) {
                                Text($0).font(.system(size: 12))
                            }
                            Text("【容易忽略的地方】").font(.system(size: 12, weight: .bold))
                            if fb.easyToMiss.isEmpty {
                                Text("这次你覆盖的因素比较全，很好。").font(.system(size: 12))
                            } else {
                                ForEach(fb.easyToMiss, id: \.self) {
                                    Text($0).font(.system(size: 12))
                                }
                            }
                            Text("【进一步思考】").font(.system(size: 12, weight: .bold))
                            Text(fb.thinkFurther).font(.system(size: 12))
                            Text("（关键词辅助复盘，仅作对照提示）")
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.muted)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.card2.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.vertical, 8)
            }
            Button {
                saveRecord(report)
            } label: {
                Text("保存本次学习记录")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Palette.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if saved {
                Text("已保存到学习记录 ✓").font(.system(size: 13))
                    .foregroundStyle(.green)
            }
        }
    }

    private func submit(_ i: Int, _ text: String, _ report: AnalysisReport, _ m: StockMetrics) {
        guard !text.isEmpty else { return }
        answers[i] = text
        feedbacks[i] = generateLearningFeedback(
            type: report.currentType, answer: text, report: report, m: m
        )
    }

    private func saveRecord(_ report: AnalysisReport) {
        guard let stock else { return }
        let qList = questions(for: report.currentType)
        let record = HistoryRecord(
            id: "\(stock.code)-\(Int(Date().timeIntervalSince1970))",
            stockCode: stock.code,
            stockName: stock.name,
            type: report.currentType,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            answers: qList.enumerated().compactMap { i, q in
                guard let a = answers[i], !a.isEmpty else { return nil }
                return HistoryAnswer(question: q, answer: a)
            },
            report: report
        )
        model.saveHistory(record)
        saved = true
    }

    private func thesisCard(_ report: AnalysisReport, _ m: StockMetrics) -> some View {
        AppCard(title: "我为什么看好这只股票 · 结构化复盘") {
            Text("填一下你看好的理由类型、时间预期和理由描述，系统会用数据逐项对照，不否定你的判断。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(thesisTypes, id: \.self) { t in
                        FilterChip(label: t, isActive: thesis.types.contains(t)) {
                            if thesis.types.contains(t) {
                                thesis.types.removeAll { $0 == t }
                            } else {
                                thesis.types.append(t)
                            }
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                ForEach(["短线", "波段", "中线"], id: \.self) { h in
                    FilterChip(label: h, isActive: thesis.horizon == h) {
                        thesis.horizon = h
                    }
                }
            }
            TextEditor(text: $thesis.text)
                .frame(height: 70)
                .padding(6)
                .background(Palette.card2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .font(.system(size: 13))
            Button {
                review = reviewThesis(thesis, report: report, m: m)
            } label: {
                Text("对照数据复盘")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Palette.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if let review {
                Text("系统依据 vs 你的依据")
                    .font(.system(size: 13, weight: .bold))
                ForEach(review.rows, id: \.reasonType) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(row.reasonType).font(.system(size: 12))
                                .foregroundStyle(Palette.muted)
                            Spacer()
                            Text(row.conclusion).font(.system(size: 12, weight: .semibold))
                        }
                        Text(row.systemEvidence).font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                    }
                    .padding(.vertical, 4)
                    Divider().overlay(Palette.line)
                }
                Text("追问").font(.system(size: 13, weight: .bold))
                Text(review.followUp).font(.system(size: 12))
            }
        }
    }

    private func quickOptions(_ type: String, _ q: String) -> [String] {
        if q.contains("哪个观察类型") { return typeOrder }
        if q.contains("缩量还是放量") { return ["缩量", "放量", "不确定"] }
        if q.contains("什么信号") && type == "高位观察" {
            return ["滞涨", "放量滞涨", "跌破20日线", "缩量整理"]
        }
        if q.contains("哪个指标") { return ["量比", "20日线", "60日线", "ATR"] }
        if q.contains("什么条件") {
            return ["站回20日线", "放量突破", "缩量企稳", "趋势破位"]
        }
        return []
    }
}
