import Foundation

public enum SnapshotError: Error {
    case missingFile(String)
    case decodeFailed(String, Error)
}

public struct SnapshotLoader {
    public init() {}

    public func load(from directory: URL) throws -> Snapshot {
        func read<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            let url = directory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw SnapshotError.missingFile(name)
            }
            let data = try Data(contentsOf: url)
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw SnapshotError.decodeFailed(name, error)
            }
        }
        return Snapshot(
            meta: try? read("meta.json", as: SnapshotMeta.self),
            calendar: try? read("calendar.json", as: [String].self),
            indices: try read("indices.json", as: [SeriesData].self),
            sectors: try read("sectors.json", as: [SectorData].self),
            stocks: try read("stocks.json", as: [StockData].self),
            etfs: try read("etfs.json", as: [SeriesData].self)
        )
    }

    public static func loadBundled(
        resourceDirectory: String = "demo-data",
        bundle: Bundle = .main
    ) throws -> Snapshot {
        guard let base = bundle.resourceURL else {
            throw SnapshotError.missingFile("bundle resources")
        }
        let sub = base.appendingPathComponent(resourceDirectory, isDirectory: true)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: sub.path, isDirectory: &isDir), isDir.boolValue {
            return try SnapshotLoader().load(from: sub)
        }
        // XcodeGen 可能把文件夹资源平铺到 bundle 根目录
        return try SnapshotLoader().load(from: base)
    }
}
