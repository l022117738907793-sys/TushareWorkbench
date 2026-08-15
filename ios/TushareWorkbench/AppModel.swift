import Foundation
import TushareWorkbenchCore

enum DataSource: String {
    case demo
    case tushare
}

enum AppTab: String {
    case workbench = "工作台"
    case analysis = "个股分析"
    case history = "学习记录"
    case settings = "设置"
}

struct HistoryAnswer: Codable, Equatable {
    let question: String
    let answer: String
}

struct HistoryRecord: Codable, Equatable, Identifiable {
    let id: String
    let stockCode: String
    let stockName: String
    let type: String
    let createdAt: String
    let answers: [HistoryAnswer]
    let report: AnalysisReport
}

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var loading = true
    @Published var errorText: String?
    @Published var liveError: String?
    @Published var remoteUrl = "http://127.0.0.1:8787"
    @Published var remoteStatus: String?
    @Published var remoteBusy = false
    @Published var dataSource: DataSource = .demo
    @Published var token = ""
    @Published var overrides: [String: Double] = [:]
    @Published private(set) var rules: Rules?
    @Published var marketResult: MarketResult?
    @Published var sectorResults: [String: SectorResult] = [:]
    @Published var stockResults: [String: StockResult] = [:]
    @Published var selectedStock: String?
    @Published var selectedTab: AppTab = .workbench
    @Published var history: [HistoryRecord] = []
    @Published var expandedSectors: Set<String> = []
    @Published var sectorFilter = "全部"

    private let defaults = UserDefaults.standard

    init() {
        if let raw = defaults.string(forKey: "dataSource"), raw == "tushare" {
            dataSource = .tushare
        }
        token = defaults.string(forKey: "token") ?? ""
        remoteUrl = defaults.string(forKey: "remoteUrl") ?? "http://127.0.0.1:8787"
        overrides = (defaults.dictionary(forKey: "overrides") as? [String: Double]) ?? [:]
        if let data = defaults.data(forKey: "history"),
           let records = try? JSONDecoder().decode([HistoryRecord].self, from: data) {
            history = records
        }
    }

    func load() {
        Task {
            do {
                var snapshot: Snapshot?
                if let remote = try await loadRemoteSnapshot() {
                    snapshot = remote
                }
                if snapshot == nil {
                    snapshot = try SnapshotLoader.loadBundled(
                        resourceDirectory: "demo-data"
                    )
                    if remoteStatus == nil {
                        remoteStatus = "使用内置快照"
                    }
                }
                guard let snapshot else {
                    throw SnapshotError.missingFile("snapshot")
                }
                self.snapshot = snapshot
                let baseRules = try Self.bundledRules()
                self.rules = Self.apply(overrides, to: baseRules)
                recompute()
                let args = ProcessInfo.processInfo.arguments
                if let idx = args.firstIndex(of: "-selectedStock"),
                   args.indices.contains(idx + 1) {
                    selectedStock = args[idx + 1]
                    selectedTab = .analysis
                } else if let hit = args.first(where: { $0.hasPrefix("-selectedStock=") }) {
                    selectedStock = String(hit.dropFirst("-selectedStock=".count))
                    selectedTab = .analysis
                }
                loading = false
            } catch {
                errorText = "加载失败：\(error.localizedDescription)"
                loading = false
            }
        }
    }

    private func loadRemoteSnapshot() async throws -> Snapshot? {
        guard !remoteUrl.isEmpty else { return nil }
        remoteStatus = "正在下载最新快照…"
        let base = remoteUrl
        struct Latest: Decodable {
            let snapshot: String
        }
        do {
            let latestData = try await fetchData(url: URL(string: "\(base)/latest")!)
            let latest = try JSONDecoder().decode(Latest.self, from: latestData)
            let dir = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("remote-snapshot", isDirectory: true)
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
            for file in ["meta.json", "calendar.json", "indices.json",
                         "sectors.json", "stocks.json", "etfs.json"] {
                let data = try await fetchData(
                    url: URL(string: "\(base)/snapshots/\(latest.snapshot)/\(file)")!
                )
                try data.write(to: dir.appendingPathComponent(file))
            }
            remoteStatus = "已使用远程快照（\(latest.snapshot)）"
            return try SnapshotLoader().load(from: dir)
        } catch {
            remoteStatus = "远程快照不可用（\(error.localizedDescription)），使用内置快照"
            return nil
        }
    }

    private func fetchData(url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    func setRemoteUrl(_ value: String) {
        remoteUrl = value
        defaults.set(value, forKey: "remoteUrl")
    }

    func reloadRemote() {
        remoteBusy = true
        load()
        remoteBusy = false
    }

    func triggerRemoteFetch() {
        guard !remoteUrl.isEmpty else { return }
        remoteBusy = true
        Task {
            do {
                var request = URLRequest(
                    url: URL(string: "\(remoteUrl)/refresh")!
                )
                request.httpMethod = "POST"
                _ = try await URLSession.shared.data(for: request)
                remoteStatus = "已通知服务重新抓取，稍后自动刷新"
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                load()
            } catch {
                remoteStatus = "通知失败：\(error.localizedDescription)"
            }
            remoteBusy = false
        }
    }

    private static func bundledRules() throws -> Rules {
        guard let url = Bundle.main.url(forResource: "rules", withExtension: "json") else {
            throw SnapshotError.missingFile("rules.json")
        }
        return try JSONDecoder().decode(Rules.self, from: Data(contentsOf: url))
    }

    static func apply(_ overrides: [String: Double], to base: Rules) -> Rules {
        var rules = base
        for (path, value) in overrides {
            switch path {
            case "market.strong20Pct": rules.market.strong20Pct = value
            case "market.weak20Pct": rules.market.weak20Pct = value
            case "market.breadthStrong": rules.market.breadthStrong = value
            case "market.breadthWeak": rules.market.breadthWeak = value
            case "sector.strong20Pct": rules.sector.strong20Pct = value
            case "sector.accelAccelPct": rules.sector.accelAccelPct = value
            case "sector.accelVolumeRatio": rules.sector.accelVolumeRatio = value
            case "sector.active5Pct": rules.sector.active5Pct = value
            case "sector.strongStockMin": rules.sector.strongStockMin = Int(value)
            case "stock.start20Min": rules.stock.start20Min = value
            case "stock.start20Max": rules.stock.start20Max = value
            case "stock.startVolumeRatio": rules.stock.startVolumeRatio = value
            case "stock.trend20Min": rules.stock.trend20Min = value
            case "stock.trend20Max": rules.stock.trend20Max = value
            case "stock.high20Min": rules.stock.high20Min = value
            case "stock.pullbackMin": rules.stock.pullbackMin = value
            case "stock.exclude20Max": rules.stock.exclude20Max = value
            case "stock.atrMultiplier": rules.stock.atrMultiplier = value
            case "stock.atrPeriod": rules.stock.atrPeriod = Int(value)
            default: break
            }
        }
        return rules
    }

    func recompute() {
        guard let snapshot, let rules else { return }
        marketResult = analyzeMarket(snapshot, rules)
        let byCode = Dictionary(uniqueKeysWithValues: snapshot.stocks.map { ($0.code, $0) })
        sectorResults = Dictionary(
            uniqueKeysWithValues: snapshot.sectors.map {
                ($0.code, analyzeSector($0, byCode, rules))
            }
        )
        stockResults = Dictionary(
            uniqueKeysWithValues: snapshot.stocks.map {
                ($0.code, classifyStock($0, rules))
            }
        )
    }

    func setOverride(_ path: String, _ value: Double) {
        overrides[path] = value
        defaults.set(overrides, forKey: "overrides")
        if let base = try? Self.bundledRules() {
            rules = Self.apply(overrides, to: base)
            recompute()
        }
    }

    func resetRules() {
        overrides = [:]
        defaults.removeObject(forKey: "overrides")
        if let base = try? Self.bundledRules() {
            rules = base
            recompute()
        }
    }

    func report(for code: String) throws -> AnalysisReport {
        guard let snapshot, let rules else {
            throw AnalyzerError.stockNotFound(code)
        }
        return try buildReport(snapshot, stockCode: code, rules)
    }

    func selectStock(_ code: String) {
        selectedStock = code
        selectedTab = .analysis
    }

    func toggleSector(_ code: String) {
        if expandedSectors.contains(code) {
            expandedSectors.remove(code)
        } else {
            expandedSectors.insert(code)
        }
    }

    func saveHistory(_ record: HistoryRecord) {
        history.insert(record, at: 0)
        if history.count > 100 { history = Array(history.prefix(100)) }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: "history")
        }
    }

    func setDataSource(_ ds: DataSource) {
        dataSource = ds
        defaults.set(ds.rawValue, forKey: "dataSource")
    }

    func setToken(_ value: String) {
        token = value
        defaults.set(value, forKey: "token")
    }

    func refreshLive() async {
        guard !token.isEmpty else {
            liveError = "请先在设置里填写 Tushare Token"
            return
        }
        let client = TushareClient(token: token)
        do {
            let responses = try await withThrowingTaskGroup(of: TushareResponseData.self) { group in
                for code in ["000300.SH", "000001.SH", "399006.SZ"] {
                    group.addTask {
                        try await client.call(
                            apiName: "index_daily",
                            params: [
                                "ts_code": code,
                                "start_date": "20260801",
                                "end_date": "20260815",
                            ]
                        )
                    }
                }
                var out: [TushareResponseData] = []
                for try await r in group { out.append(r) }
                return out
            }
            guard let snapshot else { return }
            let latest = responses.compactMap { resp -> [String: Any]? in
                let sorted = resp.items.sorted { a, b in
                    (a[1].stringValue ?? "") < (b[1].stringValue ?? "")
                }
                guard let row = sorted.last else { return nil }
                var dict: [String: Any] = [:]
                for (i, field) in resp.fields.enumerated() {
                    dict[field] = row[i]
                }
                return dict
            }
            guard let first = latest.first,
                  let newDate = (first["trade_date"] as? JSONValue)?.stringValue,
                  newDate > (snapshot.meta?.asOf ?? "") else {
                liveError = "实时数据日期未超过快照日期，继续使用快照"
                return
            }
            let updated = snapshot.indices.map { idx -> SeriesData in
                guard let row = latest.first(where: {
                    ($0["ts_code"] as? JSONValue)?.stringValue == idx.code
                }) else { return idx }
                let close = row["close"] as? JSONValue
                let high = row["high"] as? JSONValue
                let low = row["low"] as? JSONValue
                let volume = row["vol"] as? JSONValue
                guard let close, let high, let low, let volume,
                      let c = close.doubleValue, let h = high.doubleValue,
                      let l = low.doubleValue, let v = volume.doubleValue else {
                    return idx
                }
                return SeriesData(
                    code: idx.code, name: idx.name, kind: idx.kind,
                    close: idx.close + [c], high: idx.high + [h],
                    low: idx.low + [l], volume: idx.volume + [v]
                )
            }
            self.snapshot = Snapshot(
                meta: SnapshotMeta(
                    asOf: newDate, source: snapshot.meta?.source,
                    poolNote: snapshot.meta?.poolNote,
                    calendarNote: snapshot.meta?.calendarNote,
                    generatedAt: snapshot.meta?.generatedAt,
                    days: snapshot.meta?.days, liveMerged: true
                ),
                calendar: (snapshot.calendar ?? []) + [newDate],
                indices: updated,
                sectors: snapshot.sectors,
                stocks: snapshot.stocks,
                etfs: snapshot.etfs
            )
            recompute()
            liveError = "已合并实时指数数据（板块与个股仍为演示快照）"
        } catch {
            liveError = "实时拉取失败：\(error.localizedDescription)（继续使用演示数据，不编造）"
        }
    }
}
