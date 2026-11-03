import Foundation

/// The tiny HTTP API the app exposes on the local network in appliance mode.
///
///   GET /start?preset=Rain&fade=10&minutes=90&token=XYZ
///   GET /stop?token=XYZ
///   GET /status?token=XYZ
///   GET /presets?token=XYZ
///
/// Anything on the Wi-Fi can call it: a Shortcuts "Get Contents of URL" action on
/// another phone, a Home-hub automation, Home Assistant, or a browser. It is
/// deliberately GET-only with query parameters because that is what the fewest
/// tools struggle with. The token is a shared secret shown in the app.
public enum ControlCommand: Equatable, Sendable {
    case start(preset: String?, fadeSeconds: Double?, minutes: Int?, ignoreWindow: Bool)
    case stop(fadeSeconds: Double?)
    case status
    case presets
}

public struct ControlRequest: Equatable, Sendable {
    public var method: String
    public var path: String
    public var query: [String: String]

    public init(method: String, path: String, query: [String: String]) {
        self.method = method
        self.path = path
        self.query = query
    }

    /// Parses the head of an HTTP/1.x request ("GET /start?x=1 HTTP/1.1\r\n...").
    /// Returns nil if the request line is malformed.
    public init?(rawHTTP: String) {
        guard let firstLine = rawHTTP.split(separator: "\r\n", maxSplits: 1, omittingEmptySubsequences: false).first ??
                rawHTTP.split(separator: "\n", maxSplits: 1).first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0]).uppercased()
        let target = String(parts[1])
        let pathAndQuery = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = String(pathAndQuery[0])
        var query: [String: String] = [:]
        if pathAndQuery.count == 2 {
            for pair in pathAndQuery[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let key = ControlRequest.decode(String(kv[0]))
                let value = kv.count == 2 ? ControlRequest.decode(String(kv[1])) : ""
                query[key] = value
            }
        }
        self.init(method: method, path: path, query: query)
    }

    static func decode(_ s: String) -> String {
        s.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? s
    }

    /// Turns the request into a command, or nil if the path is unknown.
    public var command: ControlCommand? {
        switch path {
        case "/start", "/play", "/on":
            return .start(
                preset: query["preset"],
                fadeSeconds: query["fade"].flatMap(Double.init),
                minutes: query["minutes"].flatMap(Int.init),
                ignoreWindow: ["1", "true", "yes"].contains((query["force"] ?? "").lowercased())
            )
        case "/stop", "/off":
            return .stop(fadeSeconds: query["fade"].flatMap(Double.init))
        case "/status", "/":
            return .status
        case "/presets":
            return .presets
        default:
            return nil
        }
    }

    public var token: String? { query["token"] }
}

/// Builds the raw HTTP response text. JSON body, closes the connection.
public struct ControlResponse: Equatable, Sendable {
    public var status: Int
    public var body: String

    public init(status: Int, body: String) {
        self.status = status
        self.body = body
    }

    public static func json(_ status: Int, _ object: [String: Any]) -> ControlResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
        return ControlResponse(status: status, body: String(decoding: data, as: UTF8.self))
    }

    public static func ok(_ object: [String: Any]) -> ControlResponse { json(200, object) }
    public static func error(_ status: Int, _ message: String) -> ControlResponse {
        json(status, ["ok": false, "error": message])
    }

    public var rawHTTP: String {
        let reason: String
        switch status {
        case 200: reason = "OK"
        case 400: reason = "Bad Request"
        case 401: reason = "Unauthorized"
        case 403: reason = "Forbidden"
        case 404: reason = "Not Found"
        default: reason = "Error"
        }
        let bytes = body.utf8.count
        return "HTTP/1.1 \(status) \(reason)\r\n" +
            "Content-Type: application/json; charset=utf-8\r\n" +
            "Content-Length: \(bytes)\r\n" +
            "Access-Control-Allow-Origin: *\r\n" +
            "Connection: close\r\n" +
            "\r\n" + body
    }
}

/// Generates the shared secret shown in the app. Short enough to type, long
/// enough that nobody on the Wi-Fi guesses it.
public enum ControlToken {
    public static func generate() -> String {
        let alphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")
        var rng = SystemRandomNumberGenerator()
        return String((0..<12).map { _ in alphabet[Int(rng.next() % UInt64(alphabet.count))] })
    }
}
