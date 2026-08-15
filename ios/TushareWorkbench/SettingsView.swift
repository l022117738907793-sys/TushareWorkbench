import SwiftUI
import TushareWorkbenchCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private let groups: [(String, [(String, String, Double)])] = [
        ("大盘环境", [
            ("market.strong20Pct", "强势 20 日涨幅阈值(%)", 1),
            ("market.weak20Pct", "偏弱 20 日涨幅阈值(%)", 1),
            ("market.breadthStrong", "强势上涨家数占比", 0.05),
            ("market.breadthWeak", "偏弱上涨家数占比", 0.05),
        ]),
        ("板块强弱", [
            ("sector.strong20Pct", "持续强势 20 日涨幅(%)", 1),
            ("sector.accelAccelPct", "正在加强加速度(pct)", 0.5),
            ("sector.accelVolumeRatio", "加强量比", 0.1),
            ("sector.active5Pct", "开始活跃 5 日涨幅(%)", 0.5),
            ("sector.strongStockMin", "强势股数量下限", 1),
        ]),
        ("个股分类", [
            ("stock.start20Min", "启动观察 20 日涨幅下限(%)", 0.5),
            ("stock.start20Max", "启动观察 20 日涨幅上限(%)", 0.5),
            ("stock.startVolumeRatio", "启动观察量比", 0.1),
            ("stock.trend20Min", "趋势观察 20 日涨幅下限(%)", 0.5),
            ("stock.trend20Max", "趋势观察 20 日涨幅上限(%)", 0.5),
            ("stock.high20Min", "高位观察 20 日涨幅(%)", 0.5),
            ("stock.pullbackMin", "回调观察回撤(%)", 0.5),
            ("stock.exclude20Max", "排除 20 日跌幅(%)", 0.5),
        ]),
        ("ATR 波动", [
            ("stock.atrMultiplier", "ATR 倍数", 0.1),
            ("stock.atrPeriod", "ATR 周期", 1),
        ]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    dataSourceCard
                    snapshotServiceCard
                    ForEach(groups, id: \.0) { name, items in
                        AppCard(title: "阈值 · \(name)") {
                            ForEach(items, id: \.0) { path, label, step in
                                HStack {
                                    Text(label).font(.system(size: 13))
                                        .foregroundStyle(Palette.muted)
                                    Spacer()
                                    TextField("", value: Binding(
                                        get: {
                                            model.overrides[path] ?? baseValue(path)
                                        },
                                        set: { model.setOverride(path, $0) }
                                    ), format: .number.precision(.fractionLength(1)))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .padding(6)
                                    .background(Palette.card2)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                    Button("恢复默认阈值") {
                        model.resetRules()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Palette.bg)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var dataSourceCard: some View {
        AppCard(title: "数据源") {
            Picker("", selection: Binding(
                get: { model.dataSource },
                set: { model.setDataSource($0) }
            )) {
                Text("演示快照").tag(DataSource.demo)
                Text("Tushare 实时").tag(DataSource.tushare)
            }
            .pickerStyle(.segmented)
            if model.dataSource == .tushare {
                SecureField("tushare token", text: Binding(
                    get: { model.token },
                    set: { model.setToken($0) }
                ))
                .textFieldStyle(.roundedBorder)
                Button("拉取并合并最新指数") {
                    Task { await model.refreshLive() }
                }
                .buttonStyle(.borderedProminent)
                if let liveError = model.liveError {
                    Text(liveError).font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
                Text("实时模式只刷新沪深300（该账号接口限频 1 次/分钟）；板块与个股仍用演示快照。接口失败时明确显示原因，不编造。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    private var snapshotServiceCard: some View {
        AppCard(title: "快照服务") {
            Text("填写快照服务地址后，应用启动时会自动下载最新快照；服务不可用时回退到内置快照。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
            TextField("https://l022117738907793-sys.github.io/TushareWorkbench/data", text: Binding(
                get: { model.remoteUrl },
                set: { model.setRemoteUrl($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .keyboardType(.URL)
            .autocapitalization(.none)
            Button("检查并下载最新快照") {
                model.reloadRemote()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.remoteBusy)
            Button("通知服务重新抓取") {
                model.triggerRemoteFetch()
            }
            .buttonStyle(.bordered)
            .disabled(model.remoteBusy || model.remoteUrl.isEmpty)
            if let status = model.remoteStatus {
                Text(status).font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func baseValue(_ path: String) -> Double {
        guard let rules = model.rules else { return 0 }
        switch path {
        case "market.strong20Pct": return rules.market.strong20Pct
        case "market.weak20Pct": return rules.market.weak20Pct
        case "market.breadthStrong": return rules.market.breadthStrong
        case "market.breadthWeak": return rules.market.breadthWeak
        case "sector.strong20Pct": return rules.sector.strong20Pct
        case "sector.accelAccelPct": return rules.sector.accelAccelPct
        case "sector.accelVolumeRatio": return rules.sector.accelVolumeRatio
        case "sector.active5Pct": return rules.sector.active5Pct
        case "sector.strongStockMin": return Double(rules.sector.strongStockMin)
        case "stock.start20Min": return rules.stock.start20Min
        case "stock.start20Max": return rules.stock.start20Max
        case "stock.startVolumeRatio": return rules.stock.startVolumeRatio
        case "stock.trend20Min": return rules.stock.trend20Min
        case "stock.trend20Max": return rules.stock.trend20Max
        case "stock.high20Min": return rules.stock.high20Min
        case "stock.pullbackMin": return rules.stock.pullbackMin
        case "stock.exclude20Max": return rules.stock.exclude20Max
        case "stock.atrMultiplier": return rules.stock.atrMultiplier
        case "stock.atrPeriod": return Double(rules.stock.atrPeriod)
        default: return 0
        }
    }
}
