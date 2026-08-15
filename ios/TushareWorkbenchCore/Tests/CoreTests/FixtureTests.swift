import XCTest
@testable import TushareWorkbenchCore

struct FixtureExpected: Decodable {
    struct Sector: Decodable {
        let code: String
        let state: String
    }

    struct Stock: Decodable {
        let code: String
        let type: String
        let subtype: String?
        let atrFlag: String?
    }

    let market: String
    let sector: Sector
    let stock: Stock
}

struct Fixture: Decodable {
    let id: String
    let indices: [SeriesData]
    let sectors: [SectorData]
    let stocks: [StockData]
    let expected: FixtureExpected
    let rules: Rules
}

final class FixtureTests: XCTestCase {
    func loadFixtures() throws -> [Fixture] {
        guard let dir = Bundle.module.url(forResource: "Fixtures", withExtension: nil) else {
            throw SnapshotError.missingFile("Fixtures")
        }
        let files = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }.sorted {
            $0.lastPathComponent < $1.lastPathComponent
        }
        let decoder = JSONDecoder()
        return try files.map { try decoder.decode(Fixture.self, from: Data(contentsOf: $0)) }
    }

    func makeSnapshot(_ fx: Fixture) -> Snapshot {
        Snapshot(
            meta: nil,
            calendar: nil,
            indices: fx.indices,
            sectors: fx.sectors,
            stocks: fx.stocks,
            etfs: []
        )
    }

    func targetStock(_ fx: Fixture) -> StockData {
        fx.stocks.first { $0.code == fx.expected.stock.code } ?? fx.stocks.last!
    }

    func testFixtureCount() throws {
        let fixtures = try loadFixtures()
        XCTAssertGreaterThanOrEqual(fixtures.count, 12)
    }

    func testAllFixtures() throws {
        let fixtures = try loadFixtures()
        for fx in fixtures {
            let snapshot = makeSnapshot(fx)
            let rules = fx.rules

            let market = analyzeMarket(snapshot, rules)
            XCTAssertEqual(market.state, fx.expected.market, fx.id)
            XCTAssertGreaterThanOrEqual(market.reasons.count, 3, fx.id)

            let sectorSrc = snapshot.sectors[0]
            let byCode = Dictionary(uniqueKeysWithValues: snapshot.stocks.map { ($0.code, $0) })
            let sector = analyzeSector(sectorSrc, byCode, rules)
            XCTAssertEqual(sector.state, fx.expected.sector.state, fx.id)
            XCTAssertGreaterThanOrEqual(sector.reasons.count, 5, fx.id)

            let stock = targetStock(fx)
            let classified = classifyStock(stock, rules)
            XCTAssertEqual(classified.type, fx.expected.stock.type, fx.id)
            if let subtype = fx.expected.stock.subtype {
                XCTAssertTrue(classified.subtype?.contains(subtype) == true, "\(fx.id): \(classified.subtype ?? "nil")")
            }
            if let flag = fx.expected.stock.atrFlag {
                XCTAssertTrue(classified.atr.available, fx.id)
                XCTAssertEqual(classified.atr.flag, flag, fx.id)
            }
            XCTAssertGreaterThanOrEqual(classified.reasons.count, 5, fx.id)

            let report = try buildReport(snapshot, stockCode: stock.code, rules)
            XCTAssertEqual(report.currentType, fx.expected.stock.type, fx.id)
            XCTAssertEqual(report.market.state, fx.expected.market, fx.id)
            XCTAssertEqual(report.sector.state, fx.expected.sector.state, fx.id)
            XCTAssertFalse(report.nextSteps.isEmpty, fx.id)
            XCTAssertGreaterThanOrEqual(report.why.count, 3, fx.id)
            let text = ([report.conclusion] + report.why + report.nextSteps).joined(separator: " ")
            for bad in ["买入", "卖出", "目标价", "必涨", "必跌"] {
                XCTAssertFalse(text.contains(bad), "\(fx.id) 出现禁用词 \(bad)")
            }
            let metrics = computeStockMetrics(stock, rules)
            XCTAssertEqual(metrics.days, stock.close.count, fx.id)
        }
    }
}
