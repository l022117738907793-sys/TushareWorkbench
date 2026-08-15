import Foundation

public enum AnalyzerError: Error {
    case stockNotFound(String)
}

func findSeries(_ list: [SeriesData], _ code: String) -> SeriesData? {
    list.first { $0.code == code }
}

public func computeStockMetrics(_ stock: StockData, _ rules: Rules) -> StockMetrics {
    let close = stock.close
    let days = valid(close).count
    let last = lastValid(close)
    let ma20v = ma(close, 20)
    let ma60v = ma(close, 60)
    let above20: Bool? = (ma20v == nil || last == nil) ? nil : (last! > ma20v!)
    let above60: Bool? = (ma60v == nil || last == nil) ? nil : (last! > ma60v!)
    let vals = valid(close)
    let high20 = vals.isEmpty ? nil : vals.suffix(20).max()
    let dist20: Double? = (ma20v != nil && last != nil) ? ((last! / ma20v!) - 1) * 100 : nil
    let distHigh: Double? = (last != nil && high20 != nil) ? ((last! / high20!) - 1) * 100 : nil
    return StockMetrics(
        days: days,
        ret5: ret(close, 5),
        ret10: ret(close, 10),
        ret20: ret(close, 20),
        ret60: ret(close, 60),
        above20: above20,
        above60: above60,
        ma20Up: maUp(close, 20),
        ma60Up: maUp(close, 60),
        dist20: dist20,
        distHigh: distHigh,
        pullback: distHigh == nil ? nil : -distHigh!,
        volRatio: volRatio(stock.volume),
        daysAbove20: daysAbove(close, ref: ma20v),
        atr: atrInfo(stock.high, stock.low, close,
                     period: rules.stock.atrPeriod,
                     multiplier: rules.stock.atrMultiplier,
                     minDays: rules.stock.atrMinDays),
        isST: stock.isST
    )
}

public func analyzeMarket(_ snapshot: Snapshot, _ rules: Rules) -> MarketResult {
    guard let main = findSeries(snapshot.indices, rules.market.mainIndex) else {
        return MarketResult(
            state: "数据不足",
            reasons: [reason("main.missing", "沪深300 数据", nil, "存在", false, "缺少主指数数据")],
            implication: "数据不足，无法判断大盘环境。"
        )
    }
    var reasons: [ReasonItem] = []
    let ret20 = ret(main.close, 20)
    let lastMain = lastValid(main.close)
    let ma20m = ma(main.close, 20)
    let above20: Bool? = (ma20m == nil || lastMain == nil) ? nil : (lastMain! > ma20m!)
    let m20 = maUp(main.close, 20)
    let upCount = snapshot.stocks.filter { (ret($0.close, 20) ?? -999) > 0 }.count
    let breadth: Double? = snapshot.stocks.isEmpty ? nil : Double(upCount) / Double(snapshot.stocks.count)

    reasons.append(reason("main.ret20", "沪深300 近20日涨幅", ret20,
                          "≥ \(fmt(rules.market.strong20Pct))%", ge(ret20, rules.market.strong20Pct), ""))
    reasons.append(reason("main.aboveMA20", "价格站上20日线", above20 == nil ? nil : (above20! ? 1 : 0),
                          "是", above20 == true, ""))
    reasons.append(reason("main.ma20Up", "20日线上弯", m20 == nil ? nil : (m20! ? 1 : 0),
                          "是", m20 == true, ""))
    reasons.append(reason("main.breadth", "股票池上涨家数占比", breadth == nil ? nil : breadth! * 100,
                          "≥ \(fmt(rules.market.breadthStrong * 100))%", ge(breadth, rules.market.breadthStrong), ""))

    guard let ret20, let above20, let m20, let breadth else {
        return MarketResult(state: "数据不足", reasons: reasons,
                            implication: "部分市场数据缺失，大盘环境无法判定。")
    }
    let state: String
    if ret20 >= rules.market.strong20Pct && above20 && m20 &&
        breadth >= rules.market.breadthStrong {
        state = "强"
    } else if ret20 <= rules.market.weak20Pct ||
        (!above20 && breadth <= rules.market.breadthWeak) {
        state = "偏弱"
    } else {
        state = "正常"
    }
    let implication: String
    switch state {
    case "强":
        implication = "强环境对趋势交易容错较高，突破与趋势延续更易成立，但仍需逐票确认。"
    case "正常":
        implication = "正常环境需要更严格的量价确认，不追高，等待明确信号。"
    case "偏弱":
        implication = "偏弱环境突破失败概率较高，优先观察与等待，不把小幅走强当作启动。"
    default:
        implication = "数据不足，无法判断大盘环境。"
    }
    return MarketResult(state: state, reasons: reasons, implication: implication)
}

public func analyzeSector(
    _ sector: SectorData,
    _ stocksByCode: [String: StockData],
    _ rules: Rules
) -> SectorResult {
    var reasons: [ReasonItem] = []
    let members = sector.members.compactMap { stocksByCode[$0] }
    let r5 = ret(sector.close, 5)
    let r20 = ret(sector.close, 20)
    let r5Prev = retAt(sector.close, 5, fromEnd: 6)
    let lastSec = lastValid(sector.close)
    let ma20s = ma(sector.close, 20)
    let above20: Bool? = (ma20s == nil || lastSec == nil) ? nil : (lastSec! > ma20s!)
    let vr = volRatio(sector.volume)
    let breadth20: Double? = members.isEmpty
        ? nil
        : Double(members.filter { (ret($0.close, 20) ?? -999) > 0 }.count) / Double(members.count)
    let strongMembers = members.filter { s in
        ge(ret(s.close, 20), rules.sector.strongStock20Pct) &&
        (lastValid(s.close) ?? -Double.infinity) > (ma(s.close, 20) ?? Double.infinity) &&
        gt(ret(s.close, 5), rules.sector.strongStock5Pct)
    }
    let strongCount = strongMembers.count
    let strongestMembers = strongMembers
        .sorted { (ret($0.close, 20) ?? 0) > (ret($1.close, 20) ?? 0) }
        .prefix(3)
        .map(\.name)
    let accel: Double? = (r5 != nil && r5Prev != nil) ? r5! - r5Prev! : nil

    reasons.append(reason("sector.ret20", "板块近20日涨幅", r20, "",
                          ge(r20, rules.sector.strong20Pct), ""))
    reasons.append(reason("sector.ret5", "板块近5日涨幅", r5, "",
                          gt(r5, rules.sector.strong5Pct), ""))
    reasons.append(reason("sector.aboveMA20", "板块站上20日线", above20 == nil ? nil : (above20! ? 1 : 0),
                          "是", above20 == true, ""))
    reasons.append(reason("sector.volumeRatio", "量比(5日/20日)", vr, "",
                          ge(vr, rules.sector.accelVolumeRatio), ""))
    reasons.append(reason("sector.breadth20", "板块内20日上涨家数占比", breadth20 == nil ? nil : breadth20! * 100,
                          "", ge(breadth20, rules.sector.breadthStrong), ""))
    reasons.append(reason("sector.strongCount", "板块内强势股数量", Double(strongCount), "",
                          strongCount >= rules.sector.strongStockMin, ""))
    reasons.append(reason("sector.accel", "5日较前5日加速度(pct)", accel, "",
                          ge(accel, rules.sector.accelAccelPct), ""))

    guard let r5, let r20, let above20, let vr, let breadth20, !members.isEmpty else {
        return SectorResult(code: sector.code, name: sector.name, state: "数据不足",
                            reasons: reasons, breadth20: breadth20,
                            strongCount: strongCount, strongestMembers: strongestMembers)
    }
    var state = "震荡"
    if r20 >= rules.sector.strong20Pct && r5 > rules.sector.strong5Pct && above20 &&
        breadth20 >= rules.sector.breadthStrong && strongCount >= rules.sector.strongStockMin {
        state = "持续强势"
    } else if r20 >= rules.sector.accel20Pct && ge(accel, rules.sector.accelAccelPct) &&
        vr >= rules.sector.accelVolumeRatio && breadth20 >= rules.sector.accelBreadth {
        state = "正在加强"
    } else if r20 < rules.sector.active20PctMax && r5 >= rules.sector.active5Pct &&
        vr >= rules.sector.activeVolumeRatio && strongCount >= rules.sector.activeStrongStockMin {
        state = "开始活跃"
    } else if r20 <= rules.sector.weak20Pct ||
        (!above20 && breadth20 <= rules.sector.weakBreadth) {
        state = "走弱"
    }
    return SectorResult(code: sector.code, name: sector.name, state: state,
                        reasons: reasons, breadth20: breadth20,
                        strongCount: strongCount, strongestMembers: strongestMembers)
}

public func classifyStock(_ stock: StockData, _ rules: Rules) -> StockResult {
    let m = computeStockMetrics(stock, rules)
    var reasons: [ReasonItem] = [
        reason("stock.ret5", "近5日涨跌幅", m.ret5, "", true, ""),
        reason("stock.ret10", "近10日涨跌幅", m.ret10, "", true, ""),
        reason("stock.ret20", "近20日涨跌幅", m.ret20, "", true, ""),
        reason("stock.dist20", "距20日线", m.dist20, "", true, ""),
        reason("stock.distHigh", "距20日高点", m.distHigh, "", true, ""),
        reason("stock.volumeRatio", "量比(5日/20日)", m.volRatio, "", true, ""),
        reason("stock.aboveMA20", "站上20日线", m.above20 == nil ? nil : (m.above20! ? 1 : 0),
               "是", m.above20 == true, ""),
        reason("stock.ma20Up", "20日线上弯", m.ma20Up == nil ? nil : (m.ma20Up! ? 1 : 0),
               "是", m.ma20Up == true, ""),
        reason("stock.daysAbove20", "连续站上20日线天数", Double(m.daysAbove20), "", true, ""),
    ]
    if m.isST {
        reasons.append(reason("stock.isST", "ST/风险警示", 1, "否", false, "ST 不进入观察"))
    }

    func bucket(_ key: String, _ label: String, _ matched: Bool, _ note: String) {
        reasons.append(reason("bucket.\(key)", label, nil, matched ? "命中" : "未命中", matched, note))
    }

    if m.days < rules.stock.minDays {
        bucket("data", "数据充分性", false, "可用交易日 \(m.days) < \(rules.stock.minDays)")
        return StockResult(code: stock.code, name: stock.name, type: "数据不足",
                           reasons: reasons, subtype: nil, atr: m.atr)
    }
    let last5Vol = valid(stock.volume).suffix(5)
    if last5Vol.count == 5 && last5Vol.allSatisfy({ $0 == 0 }) {
        bucket("data", "数据充分性", false, "最近5个交易日无成交")
        return StockResult(code: stock.code, name: stock.name, type: "数据不足",
                           reasons: reasons, subtype: nil, atr: m.atr)
    }

    let exclude =
        le(m.ret20, rules.stock.exclude20Max) ||
        (m.above20 == false && m.above60 == false && m.ma60Up != true) ||
        (le(m.ret5, rules.stock.exclude5Max) && ge(m.volRatio, rules.stock.excludeVolumeRatio))
    bucket("exclude", "排除条件", exclude, exclude ? "命中排除条件" : "未命中")
    if exclude {
        return StockResult(code: stock.code, name: stock.name, type: "排除",
                           reasons: reasons, subtype: nil, atr: m.atr)
    }

    let high =
        ge(m.ret20, rules.stock.high20Min) ||
        (ge(m.distHigh, rules.stock.highDistHighMin) && ge(m.dist20, rules.stock.highDist20Min)) ||
        (ge(m.ret5, rules.stock.high5Min) && ge(m.volRatio, rules.stock.highVolumeRatio)) ||
        (lt(m.ret5, rules.stock.highStall5Max) && ge(m.volRatio, rules.stock.highStallVolumeRatio) &&
         ge(m.ret20, rules.stock.highStall20Min))
    bucket("high", "高位观察条件", high, high ? "命中高位条件" : "未命中")
    if high {
        return StockResult(code: stock.code, name: stock.name, type: "高位观察",
                           reasons: reasons, subtype: nil, atr: m.atr)
    }

    let pullback =
        ge(m.pullback, rules.stock.pullbackMin) &&
        le(m.ret5, rules.stock.pullback5Max) &&
        (m.ma20Up == true || m.above60 == true)
    bucket("pullback", "回调观察条件", pullback, pullback ? "命中回调条件" : "未命中")
    if pullback {
        var subtype = "量能中性"
        if le(m.volRatio, rules.stock.pullbackVolumeLow) { subtype = "缩量回调" }
        if ge(m.volRatio, rules.stock.pullbackVolumeHigh) { subtype = "放量回调" }
        return StockResult(code: stock.code, name: stock.name, type: "回调观察",
                           reasons: reasons, subtype: subtype, atr: m.atr)
    }

    let start =
        ge(m.ret20, rules.stock.start20Min) && le(m.ret20, rules.stock.start20Max) &&
        gt(m.ret5, 0) && m.above20 == true && m.ma20Up == true &&
        ge(m.distHigh, rules.stock.startDistHighMin) &&
        ge(m.volRatio, rules.stock.startVolumeRatio) &&
        m.daysAbove20 <= rules.stock.startDaysAbove20Max
    bucket("start", "启动观察条件", start, start ? "命中启动条件" : "未命中")
    if start {
        return StockResult(code: stock.code, name: stock.name, type: "启动观察",
                           reasons: reasons, subtype: nil, atr: m.atr)
    }

    let trend =
        m.above20 == true &&
        le(m.dist20, rules.stock.trendDist20Max) &&
        ge(m.distHigh, rules.stock.trendDistHighMin) &&
        gt(m.ret5, rules.stock.trend5Min) &&
        ((gt(m.ret20, rules.stock.trend20Min) && le(m.ret20, rules.stock.trend20Max)) ||
         m.daysAbove20 > 10)
    bucket("trend", "趋势观察条件", trend, trend ? "命中趋势条件" : "未命中")
    if trend {
        return StockResult(code: stock.code, name: stock.name, type: "趋势观察",
                           reasons: reasons, subtype: nil, atr: m.atr)
    }

    let fallback = gt(m.ret20, 0) && m.above20 == true
    bucket("fallback", "兜底判断", fallback,
           fallback ? "站上20日线但动量不足，归入趋势观察" : "未站上20日线或动量不足，归入排除")
    return StockResult(code: stock.code, name: stock.name,
                       type: fallback ? "趋势观察" : "排除",
                       reasons: reasons, subtype: nil, atr: m.atr)
}

public let nextSteps: [String: [String]] = [
    "启动观察": ["关注是否持续放量并突破20日高点", "回踩20日线时是否缩量企稳"],
    "趋势观察": ["关注趋势能否保持，20日线是否持续上弯", "关注回调是否健康：缩量回踩20日线后能否再向上"],
    "回调观察": ["判断回调是缩量还是放量", "关注能否重新放量站回20日线"],
    "高位观察": ["重点观察是否出现滞涨、放量滞涨", "警惕跌破20日线的趋势破位"],
    "排除": ["关注能否重新站回关键均线（20日/60日）", "避免把急跌后的反弹直接当作反转"],
    "数据不足": ["补足60个交易日后重新分析"],
]

public func buildReport(
    _ snapshot: Snapshot,
    stockCode: String,
    _ rules: Rules
) throws -> AnalysisReport {
    guard let stock = snapshot.stocks.first(where: { $0.code == stockCode }) else {
        throw AnalyzerError.stockNotFound(stockCode)
    }
    let market = analyzeMarket(snapshot, rules)
    let sectorSrc = snapshot.sectors.first { $0.code == stock.industryCode }
    let stocksByCode = Dictionary(uniqueKeysWithValues: snapshot.stocks.map { ($0.code, $0) })
    let sector: SectorResult
    if let sectorSrc {
        sector = analyzeSector(sectorSrc, stocksByCode, rules)
    } else {
        sector = SectorResult(
            code: stock.industryCode, name: stock.industry, state: "数据不足",
            reasons: [reason("sector.missing", "所属板块数据", nil, "存在", false, "缺少板块数据")],
            breadth20: nil, strongCount: 0, strongestMembers: []
        )
    }
    let stockResult = classifyStock(stock, rules)
    let m = computeStockMetrics(stock, rules)
    let isHigh = stockResult.type == "高位观察"

    var trendReasons: [ReasonItem] = [
        reason("trend.ret20", "近20日涨跌幅", m.ret20, "", true, ""),
        reason("trend.above20", "价格 vs 20日线", m.above20 == nil ? nil : (m.above20! ? 1 : 0), "", m.above20 == true, ""),
        reason("trend.above60", "价格 vs 60日线", m.above60 == nil ? nil : (m.above60! ? 1 : 0), "", m.above60 == true, ""),
        reason("trend.ma20Up", "20日线上弯", m.ma20Up == nil ? nil : (m.ma20Up! ? 1 : 0), "", m.ma20Up == true, ""),
        reason("trend.ma60Up", "60日线上弯", m.ma60Up == nil ? nil : (m.ma60Up! ? 1 : 0), "", m.ma60Up == true, ""),
        reason("trend.daysAbove20", "连续站上20日线天数", Double(m.daysAbove20), "", true, ""),
    ]
    let trendState: String
    if let ret20 = m.ret20, let above20 = m.above20, let above60 = m.above60 {
        if (ret20 <= rules.stock.exclude20Max && above20 == false) ||
            (above60 == false && m.ma60Up != true) {
            trendState = "下跌趋势"
        } else if isHigh {
            trendState = "高位加速"
        } else if above20 == false && m.ma20Up != true &&
            (above60 == false || m.ma60Up != true || gt(m.pullback, 12)) {
            trendState = "涨势走弱"
        } else if above20 == false && above60 == true && m.ma60Up == true &&
            le(m.pullback, 12) {
            trendState = "调整期"
        } else if above20 == true && m.ma20Up == true && m.daysAbove20 <= 10 {
            trendState = "上升趋势初期"
        } else if above20 == true && m.ma20Up == true {
            trendState = "升势中"
        } else {
            trendState = "升势中"
            trendReasons.append(reason("trend.fallback", "兜底", nil, "", true, "依据不足，按升势中处理"))
        }
    } else {
        trendState = "数据不足"
    }

    var priceReasons: [ReasonItem] = [
        reason("price.ret5", "近5日涨跌幅", m.ret5, "", true, ""),
        reason("price.ret10", "近10日涨跌幅", m.ret10, "", true, ""),
        reason("price.ret20", "近20日涨跌幅", m.ret20, "", true, ""),
        reason("price.volRatio", "量比", m.volRatio, "", true, ""),
    ]
    if m.atr.available {
        let flagValue: Double = m.atr.flag == "正常" ? 0 : (m.atr.flag == "偏大" ? 1 : -1)
        priceReasons.append(reason("price.atr", "ATR 波动标记", flagValue, "正常",
                                   m.atr.flag == "正常",
                                   "ATR=\(fmt(m.atr.atr)) 波动带=\(fmt(m.atr.band5))"))
    } else {
        priceReasons.append(reason("price.atr", "ATR 波动标记", nil, "需要≥15日", false,
                                   "数据不足，未计算"))
    }
    let priceState: String
    if m.ret5 == nil || m.ret20 == nil {
        priceState = "数据不足"
    } else if ge(m.ret5, 15) || isHigh {
        priceState = "加速上涨"
    } else if gt(m.ret5, 0) && ge(m.ret20, 3) && le(m.ret20, 15) && ge(m.volRatio, 1.2) {
        priceState = "启动"
    } else if ge(m.pullback, 8) && le(m.ret5, 0) {
        priceState = "回调"
    } else if gt(m.ret20, 0) && m.above20 == true {
        priceState = "趋势延续"
    } else {
        priceState = "走弱"
    }

    var posReasons: [ReasonItem] = [
        reason("pos.distHigh", "距20日高点", m.distHigh, "", true, ""),
        reason("pos.dist20", "距20日线", m.dist20, "", true, ""),
        reason("pos.ret5", "近5日涨跌幅", m.ret5, "", true, ""),
        reason("pos.volRatio", "量比", m.volRatio, "", true, ""),
    ]
    var posState: String
    var trendBroken: Bool? = nil
    var volumeHeavy: Bool? = nil
    if ge(m.distHigh, -3) && gt(m.ret5, 0) && ge(m.volRatio, 1.2) {
        posState = "突破附近"
    } else if isHigh {
        posState = "高位加速后"
    } else if ge(m.pullback, 8) {
        posState = "上涨后回调"
        trendBroken = !(m.above60 == true && m.ma20Up == true)
        volumeHeavy = ge(m.volRatio, 1.5)
        posReasons.append(reason("pos.trendBroken", "回调是否破坏趋势", (trendBroken! ? 1 : 0),
                                 "未破坏", !trendBroken!,
                                 trendBroken! ? "跌破60日线或20日线走平/下弯" : "仍在60日线上方且20日线上弯"))
        posReasons.append(reason("pos.volumeHeavy", "回调量能", (volumeHeavy! ? 1 : 0),
                                 "缩量更健康", !volumeHeavy!,
                                 volumeHeavy! ? "放量回调" : "缩量或量能中性"))
    } else if m.above20 == true && lt(m.pullback, 8) {
        posState = "趋势运行中"
    } else {
        posState = "趋势运行中"
    }

    let steps = nextSteps[stockResult.type] ?? []
    let conclusion = "当前归类为「\(stockResult.type)」"
    let why = buildWhy(market: market, sector: sector, stock: stockResult, m: m)
    var missing: [String] = []
    if m.days < rules.stock.minDays { missing.append("可用交易日仅 \(m.days) 天") }
    if !m.atr.available { missing.append("ATR 数据不足（需≥15日）") }
    if sector.state == "数据不足" { missing.append("所属板块数据不足") }
    if market.state == "数据不足" { missing.append("大盘数据不足") }

    return AnalysisReport(
        market: market,
        sector: sector,
        stockTrend: TrendResult(state: trendState, reasons: trendReasons),
        priceAction: PriceActionResult(state: priceState, reasons: priceReasons),
        position: PositionResult(state: posState, reasons: posReasons,
                                 trendBroken: trendBroken, volumeHeavy: volumeHeavy),
        currentType: stockResult.type,
        nextSteps: steps,
        conclusion: conclusion,
        why: why,
        dataSufficiency: DataSufficiency(enough: missing.isEmpty, missing: missing)
    )
}

private func buildWhy(
    market: MarketResult,
    sector: SectorResult,
    stock: StockResult,
    m: StockMetrics
) -> [String] {
    var items: [String] = [
        "大盘环境为「\(market.state)」，\(market.state == "数据不足" ? "无法作为趋势背景" : "决定趋势交易的容错空间")",
        "所属板块「\(sector.name)」状态为「\(sector.state)」\(sector.state == "数据不足" ? "" : "，板块赚钱效应（上涨占比）约 \(fmt((sector.breadth20 ?? 0) * 100))%")",
        "个股近5日涨幅 \(fmt(m.ret5))%、近20日涨幅 \(fmt(m.ret20))%，量比 \(fmt(m.volRatio))",
        "价格距20日线 \(fmt(m.dist20))%、距20日高点 \(fmt(m.distHigh))%",
    ]
    if m.atr.available {
        let atrText: String
        switch m.atr.flag {
        case "偏大": atrText = "短期涨幅超过正常波动范围"
        case "超跌": atrText = "短期跌幅超过正常波动范围"
        default: atrText = "当前涨跌处于正常波动范围"
        }
        items.append("ATR 波动标记为「\(m.atr.flag)」，\(atrText)")
    } else {
        items.append("ATR 数据不足，未计算正常波动范围")
    }
    return items
}
