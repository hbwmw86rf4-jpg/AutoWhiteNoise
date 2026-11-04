import Foundation

/// App-wide settings that are not part of any preset.
public struct AppSettings: Codable, Equatable, Sendable {
    /// Shared secret for the local-network endpoint.
    public var controlToken: String
    public var controlPort: UInt16
    /// Whether the local-network endpoint should run when the app is able to.
    public var controlEnabled: Bool
    /// Whether the app's own scheduler should run (always on Mac; on iPad/iPhone
    /// only while the app is in the foreground).
    public var schedulerEnabled: Bool
    /// Let other apps' audio keep playing underneath ours. Off by default so the
    /// lock screen shows our controls and we take over cleanly.
    public var mixWithOthers: Bool
    /// Appliance mode keeps the screen awake and dim with a clock, for an iPad or
    /// Mac left on the nightstand.
    public var applianceMode: Bool

    public init(controlToken: String = ControlToken.generate(), controlPort: UInt16 = 8787,
                controlEnabled: Bool = false, schedulerEnabled: Bool = true,
                mixWithOthers: Bool = false, applianceMode: Bool = false) {
        self.controlToken = controlToken
        self.controlPort = controlPort
        self.controlEnabled = controlEnabled
        self.schedulerEnabled = schedulerEnabled
        self.mixWithOthers = mixWithOthers
        self.applianceMode = applianceMode
    }
}

/// Reads and writes one Codable value as a JSON file. Writes are atomic so a
/// crash mid-write cannot corrupt the file.
public struct JSONFileStore<Value: Codable> {
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Value.self, from: data)
    }

    public func save(_ value: Value) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

/// All the files the app keeps, in one directory.
public struct Storage {
    public let directory: URL
    public let presets: JSONFileStore<[Preset]>
    public let schedules: JSONFileStore<[ScheduleRule]>
    public let log: JSONFileStore<TriggerLog>
    public let settings: JSONFileStore<AppSettings>

    public init(directory: URL) {
        self.directory = directory
        presets = JSONFileStore(url: directory.appendingPathComponent("presets.json"))
        schedules = JSONFileStore(url: directory.appendingPathComponent("schedules.json"))
        log = JSONFileStore(url: directory.appendingPathComponent("log.json"))
        settings = JSONFileStore(url: directory.appendingPathComponent("settings.json"))
    }

    /// The standard per-user location: Application Support/AutoWhiteNoise.
    public static func standard() -> Storage {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return Storage(directory: base.appendingPathComponent("AutoWhiteNoise", isDirectory: true))
    }

    /// A throwaway location for tests.
    public static func temporary() -> Storage {
        Storage(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoWhiteNoise-\(UUID().uuidString)", isDirectory: true))
    }
}
