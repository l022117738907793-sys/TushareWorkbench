import Foundation

public struct Rules: Codable, Equatable, Sendable {
    public var version: Int
    public var market: Market
    public var sector: Sector
    public var stock: Stock

    public struct Market: Codable, Equatable, Sendable {
        public var mainIndex: String
        public var refIndices: [String]
        public var strong20Pct: Double
        public var weak20Pct: Double
        public var breadthStrong: Double
        public var breadthWeak: Double
    }

    public struct Sector: Codable, Equatable, Sendable {
        public var strong20Pct: Double
        public var strong5Pct: Double
        public var strongAboveMA20: Bool
        public var breadthStrong: Double
        public var strongStockMin: Int
        public var strongStock20Pct: Double
        public var strongStock5Pct: Double
        public var accel20Pct: Double
        public var accelAccelPct: Double
        public var accelVolumeRatio: Double
        public var accelBreadth: Double
        public var active20PctMax: Double
        public var active5Pct: Double
        public var activeVolumeRatio: Double
        public var activeStrongStockMin: Int
        public var weak20Pct: Double
        public var weakBreadth: Double
    }

    public struct Stock: Codable, Equatable, Sendable {
        public var minDays: Int
        public var atrMinDays: Int
        public var atrPeriod: Int
        public var atrMultiplier: Double
        public var start20Min: Double
        public var start20Max: Double
        public var startDaysAbove20Max: Int
        public var startDistHighMin: Double
        public var startVolumeRatio: Double
        public var trend20Min: Double
        public var trend20Max: Double
        public var trendDist20Max: Double
        public var trendDistHighMin: Double
        public var trend5Min: Double
        public var high20Min: Double
        public var highDist20Min: Double
        public var highDistHighMin: Double
        public var high5Min: Double
        public var highVolumeRatio: Double
        public var highStallVolumeRatio: Double
        public var highStall5Max: Double
        public var highStall20Min: Double
        public var pullbackMin: Double
        public var pullback5Max: Double
        public var pullbackVolumeLow: Double
        public var pullbackVolumeHigh: Double
        public var exclude20Max: Double
        public var exclude5Max: Double
        public var excludeVolumeRatio: Double
    }
}

public struct SeriesData: Codable, Equatable, Sendable {
    public var code: String
    public var name: String
    public var kind: String?
    public var close: [Double?]
    public var high: [Double?]
    public var low: [Double?]
    public var volume: [Double?]

    public init(
        code: String,
        name: String,
        kind: String? = nil,
        close: [Double?],
        high: [Double?],
        low: [Double?],
        volume: [Double?]
    ) {
        self.code = code
        self.name = name
        self.kind = kind
        self.close = close
        self.high = high
        self.low = low
        self.volume = volume
    }
}

public struct StockData: Codable, Equatable, Sendable {
    public var code: String
    public var name: String
    public var industry: String
    public var industryCode: String
    public var weight: Double
    public var isST: Bool
    public var close: [Double?]
    public var high: [Double?]
    public var low: [Double?]
    public var volume: [Double?]
}

public struct SectorData: Codable, Equatable, Sendable {
    public var code: String
    public var name: String
    public var close: [Double?]
    public var high: [Double?]
    public var low: [Double?]
    public var volume: [Double?]
    public var members: [String]
}

public struct SnapshotMeta: Codable, Equatable, Sendable {
    public var asOf: String
    public var source: String?
    public var poolNote: String?
    public var calendarNote: String?
    public var generatedAt: String?
    public var days: Int?
    public var liveMerged: Bool?

    public init(
        asOf: String,
        source: String? = nil,
        poolNote: String? = nil,
        calendarNote: String? = nil,
        generatedAt: String? = nil,
        days: Int? = nil,
        liveMerged: Bool? = nil
    ) {
        self.asOf = asOf
        self.source = source
        self.poolNote = poolNote
        self.calendarNote = calendarNote
        self.generatedAt = generatedAt
        self.days = days
        self.liveMerged = liveMerged
    }
}

public struct Snapshot: Codable, Equatable, Sendable {
    public var meta: SnapshotMeta?
    public var calendar: [String]?
    public var indices: [SeriesData]
    public var sectors: [SectorData]
    public var stocks: [StockData]
    public var etfs: [SeriesData]

    public init(
        meta: SnapshotMeta? = nil,
        calendar: [String]? = nil,
        indices: [SeriesData],
        sectors: [SectorData],
        stocks: [StockData],
        etfs: [SeriesData]
    ) {
        self.meta = meta
        self.calendar = calendar
        self.indices = indices
        self.sectors = sectors
        self.stocks = stocks
        self.etfs = etfs
    }
}

public struct ReasonItem: Codable, Equatable, Sendable {
    public var key: String
    public var label: String
    public var value: Double?
    public var threshold: String
    public var pass: Bool
    public var note: String
}

public struct ATRInfo: Codable, Equatable, Sendable {
    public var available: Bool
    public var flag: String
    public var atr: Double?
    public var band5: Double?
    public var move5: Double?
}

public struct MarketResult: Codable, Equatable, Sendable {
    public var state: String
    public var reasons: [ReasonItem]
    public var implication: String
}

public struct SectorResult: Codable, Equatable, Sendable {
    public var code: String
    public var name: String
    public var state: String
    public var reasons: [ReasonItem]
    public var breadth20: Double?
    public var strongCount: Int
    public var strongestMembers: [String]
}

public struct StockResult: Codable, Equatable, Sendable {
    public var code: String
    public var name: String
    public var type: String
    public var reasons: [ReasonItem]
    public var subtype: String?
    public var atr: ATRInfo
}

public struct TrendResult: Codable, Equatable, Sendable {
    public var state: String
    public var reasons: [ReasonItem]
}

public struct PriceActionResult: Codable, Equatable, Sendable {
    public var state: String
    public var reasons: [ReasonItem]
}

public struct PositionResult: Codable, Equatable, Sendable {
    public var state: String
    public var reasons: [ReasonItem]
    public var trendBroken: Bool?
    public var volumeHeavy: Bool?
}

public struct DataSufficiency: Codable, Equatable, Sendable {
    public var enough: Bool
    public var missing: [String]
}

public struct AnalysisReport: Codable, Equatable, Sendable {
    public var market: MarketResult
    public var sector: SectorResult
    public var stockTrend: TrendResult
    public var priceAction: PriceActionResult
    public var position: PositionResult
    public var currentType: String
    public var nextSteps: [String]
    public var conclusion: String
    public var why: [String]
    public var dataSufficiency: DataSufficiency
}

public struct StockMetrics: Equatable, Sendable {
    public var days: Int
    public var ret5: Double?
    public var ret10: Double?
    public var ret20: Double?
    public var ret60: Double?
    public var above20: Bool?
    public var above60: Bool?
    public var ma20Up: Bool?
    public var ma60Up: Bool?
    public var dist20: Double?
    public var distHigh: Double?
    public var pullback: Double?
    public var volRatio: Double?
    public var daysAbove20: Int
    public var atr: ATRInfo
    public var isST: Bool
}

public struct ThesisInput: Codable, Equatable, Sendable {
    public var types: [String]
    public var horizon: String
    public var text: String

    public init(types: [String], horizon: String, text: String) {
        self.types = types
        self.horizon = horizon
        self.text = text
    }
}

public struct ThesisRow: Codable, Equatable, Sendable {
    public var reasonType: String
    public var systemEvidence: String
    public var conclusion: String
}

public struct ThesisReview: Codable, Equatable, Sendable {
    public var rows: [ThesisRow]
    public var followUp: String
}

public struct LearningFeedback: Codable, Equatable, Sendable {
    public var doneRight: [String]
    public var easyToMiss: [String]
    public var thinkFurther: String
}
