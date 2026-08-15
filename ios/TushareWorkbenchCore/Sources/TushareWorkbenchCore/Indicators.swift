import Foundation

func valid(_ arr: [Double?]) -> [Double] {
    arr.compactMap { $0 }
}

func lastValid(_ arr: [Double?]) -> Double? {
    valid(arr).last
}

func avg(_ arr: [Double]) -> Double {
    arr.reduce(0, +) / Double(arr.count)
}

public func ret(_ close: [Double?], _ k: Int) -> Double? {
    let v = valid(close)
    guard v.count > k, v[v.count - 1 - k] != 0 else { return nil }
    return (v[v.count - 1] / v[v.count - 1 - k] - 1) * 100
}

public func ma(_ close: [Double?], _ x: Int) -> Double? {
    let v = valid(close)
    guard v.count >= x else { return nil }
    return avg(Array(v.suffix(x)))
}

public func maPrev(_ close: [Double?], _ x: Int, lookback: Int = 5) -> Double? {
    let v = valid(close)
    guard v.count >= x + lookback else { return nil }
    return avg(Array(v[(v.count - x - lookback)..<(v.count - lookback)]))
}

public func maUp(_ close: [Double?], _ x: Int) -> Bool? {
    guard let now = ma(close, x), let prev = maPrev(close, x) else { return nil }
    return now > prev
}

public func daysAbove(_ close: [Double?], ref: Double?) -> Int {
    guard let ref else { return 0 }
    var count = 0
    for v in valid(close).reversed() {
        if v > ref {
            count += 1
        } else {
            break
        }
    }
    return count
}

public func volRatio(_ volume: [Double?]) -> Double? {
    let v = valid(volume)
    guard v.count >= 20 else { return nil }
    return avg(Array(v.suffix(5))) / avg(Array(v.suffix(20)))
}

public func atrInfo(
    _ high: [Double?],
    _ low: [Double?],
    _ close: [Double?],
    period: Int = 14,
    multiplier: Double = 1.5,
    minDays: Int = 15
) -> ATRInfo {
    let hv = valid(high)
    let lv = valid(low)
    let cv = valid(close)
    let n = min(hv.count, lv.count, cv.count)
    guard n >= period + 1, cv.count >= minDays else {
        return ATRInfo(available: false, flag: "", atr: nil, band5: nil, move5: nil)
    }
    var trs: [Double] = []
    for i in 1..<n {
        let h = hv[i], l = lv[i], pc = cv[i - 1]
        trs.append(max(h - l, abs(h - pc), abs(l - pc)))
    }
    let atrV = avg(Array(trs.suffix(period)))
    let band5 = atrV * sqrt(5) * multiplier
    let last = cv[cv.count - 1]
    let prev5 = cv[cv.count - 6]
    let move5 = last - prev5
    var flag = "正常"
    if move5 > band5 { flag = "偏大" }
    if move5 < -band5 { flag = "超跌" }
    return ATRInfo(available: true, flag: flag, atr: atrV, band5: band5, move5: move5)
}

func reason(
    _ key: String,
    _ label: String,
    _ value: Double?,
    _ threshold: String,
    _ pass: Bool,
    _ note: String
) -> ReasonItem {
    ReasonItem(key: key, label: label, value: value, threshold: threshold, pass: pass, note: note)
}

func fmt(_ v: Double?) -> String {
    guard let v else { return "—" }
    return String(format: "%.2f", v)
}

func retAt(_ close: [Double?], _ k: Int, fromEnd: Int) -> Double? {
    let v = valid(close)
    let end = v.count - fromEnd
    guard end - k >= 0 else { return nil }
    let base = v[end - k]
    guard base != 0 else { return nil }
    return (v[end] / base - 1) * 100
}

func ge(_ a: Double?, _ b: Double) -> Bool {
    (a ?? -Double.infinity) >= b
}

func le(_ a: Double?, _ b: Double) -> Bool {
    (a ?? Double.infinity) <= b
}

func gt(_ a: Double?, _ b: Double) -> Bool {
    (a ?? -Double.infinity) > b
}

func lt(_ a: Double?, _ b: Double) -> Bool {
    (a ?? Double.infinity) < b
}
