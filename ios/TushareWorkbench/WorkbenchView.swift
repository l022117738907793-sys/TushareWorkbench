import SwiftUI
import TushareWorkbenchCore

private let sectorOrder = ["持续强势", "正在加强", "开始活跃", "震荡", "走弱", "数据不足"]
private let stockOrder = ["启动观察", "趋势观察", "高位观察", "回调观察", "排除", "数据不足"]

struct WorkbenchView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showMarketReasons = false

    private var sortedSectors: [SectorData] {
        guard let snapshot = model.snapshot else { return [] }
        return snapshot.sectors.sorted { a, b in
            let sa = model.sectorResults[a.code]?.state ?? "数据不足"
            let sb = model.sectorResults[b.code]?.state ?? "数据不足"
            let ia = sectorOrder.firstIndex(of: sa) ?? 5
            let ib = sectorOrder.firstIndex(of: sb) ?? 5
            return ia < ib
        }
    }

    private var filteredSectors: [SectorData] {
        if model.sectorFilter == "全部" { return sortedSectors }
        return sortedSectors.filter {
            model.sectorResults[$0.code]?.state == model.sectorFilter
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    header
                    marketCard
                    sectorCard
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Palette.bg)
            .navigationTitle("趋势筛选工作台")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.snapshot?.meta?.poolNote ?? "")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
            Text("数据日期：\(model.snapshot?.meta?.asOf ?? "")")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var marketCard: some View {
        AppCard(title: "第一层 · 大盘环境",
                right: AnyView(Chip(label: model.marketResult?.state ?? "数据不足"))) {
            Text(model.marketResult?.implication ?? "")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
            Button(showMarketReasons ? "收起判断依据" : "展开判断依据") {
                withAnimation { showMarketReasons.toggle() }
            }
            .font(.system(size: 13))
            .foregroundStyle(Palette.accent)
            if showMarketReasons, let reasons = model.marketResult?.reasons {
                ReasonList(reasons: reasons)
            }
        }
    }

    private var sectorCard: some View {
        AppCard(title: "第二层 · 板块强弱") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(["全部"] + sectorOrder, id: \.self) { f in
                        FilterChip(label: f, isActive: model.sectorFilter == f) {
                            model.sectorFilter = f
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            VStack(spacing: 6) {
                ForEach(filteredSectors, id: \.code) { sec in
                    sectorRow(sec)
                }
            }
        }
    }

    private func sectorRow(_ sec: SectorData) -> some View {
        let res = model.sectorResults[sec.code]
        let open = model.expandedSectors.contains(sec.code)
        return VStack(spacing: 0) {
            Button {
                model.toggleSector(sec.code)
            } label: {
                HStack(spacing: 8) {
                    Text(sec.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Chip(label: res?.state ?? "数据不足")
                    Spacer()
                    Text("20日 \(fmt1(res?.reasons.first(where: { $0.key == "sector.ret20" })?.value))%")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                    Text("强势 \(res?.strongCount ?? 0)")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                }
                .padding(10)
                .background(Palette.card2)
            }
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("上涨占比 \(Int((res?.breadth20 ?? 0) * 100))%")
                        Text("强势股 \(res?.strongCount ?? 0) 只")
                        if let tops = res?.strongestMembers, !tops.isEmpty {
                            Text("代表：\(tops.joined(separator: "、"))")
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)

                    ForEach(stockOrder, id: \.self) { type in
                        let list = stocks(in: sec, of: type)
                        if !list.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Chip(label: type)
                                    Text("\(list.count) 只")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Palette.muted)
                                }
                                ForEach(list, id: \.code) { st in
                                    stockRow(st)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.card2.opacity(0.5))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
    }

    private func stocks(in sec: SectorData, of type: String) -> [StockData] {
        guard let snapshot = model.snapshot else { return [] }
        return sec.members.compactMap { code in
            guard model.stockResults[code]?.type == type else { return nil }
            return snapshot.stocks.first { $0.code == code }
        }
    }

    private func stockRow(_ st: StockData) -> some View {
        let res = model.stockResults[st.code]
        return Button {
            model.selectStock(st.code)
        } label: {
            HStack(spacing: 8) {
                Sparkline(values: st.close)
                    .frame(width: 56, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(st.name).font(.system(size: 12, weight: .semibold))
                    Text(st.code).font(.system(size: 10))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Text("\(fmt1(res?.reasons.first(where: { $0.key == "stock.ret20" })?.value))%")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                Text("量比 \(fmt1(res?.reasons.first(where: { $0.key == "stock.volumeRatio" })?.value))")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
