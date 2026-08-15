import Foundation

public struct TushareResponseData: Decodable, Sendable {
    public let fields: [String]
    public let items: [[JSONValue]]
}

public enum JSONValue: Decodable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else {
            throw DecodingError.dataCorruptedError(
                in: c,
                debugDescription: "不支持的 JSON 值"
            )
        }
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        if case .number(let n) = self { return String(n) }
        return nil
    }

    public var doubleValue: Double? {
        if case .number(let n) = self { return n }
        if case .string(let s) = self { return Double(s) }
        return nil
    }
}

public actor TushareClient {
    private let token: String
    private var lastCall = Date.distantPast
    private var cache: [String: (Date, TushareResponseData)] = [:]

    public init(token: String) {
        self.token = token
    }

    public func call(
        apiName: String,
        params: [String: String],
        fields: String = ""
    ) async throws -> TushareResponseData {
        let key = "\(apiName)|\(params.sorted { $0.key < $1.key })"
        if let hit = cache[key], Date().timeIntervalSince(hit.0) < 30 * 60 {
            return hit.1
        }
        let wait = 1.1 - Date().timeIntervalSince(lastCall)
        if wait > 0 {
            try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
        lastCall = Date()
        var body: [String: Any] = [
            "api_name": apiName,
            "token": token,
            "params": params,
        ]
        if !fields.isEmpty {
            body["fields"] = fields
        }
        var request = URLRequest(url: URL(string: "https://api.tushare.pro")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        struct Envelope: Decodable {
            let code: Int
            let msg: String?
            let data: TushareResponseData?
        }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.code == 0, let payload = envelope.data else {
            throw TushareClientError.api(envelope.msg ?? "未知错误")
        }
        cache[key] = (Date(), payload)
        return payload
    }
}

public enum TushareClientError: Error, LocalizedError {
    case api(String)
    public var errorDescription: String? {
        switch self {
        case .api(let msg): return msg
        }
    }
}
