#if canImport(Network)
import Foundation
import Network

/// A very small HTTP/1.1 listener on the local network, advertised over
/// Bonjour as `_autowhitenoise._tcp` so other devices can find it as
/// `<device-name>.local`. Each connection: read the request head, hand it to
/// the controller on the main actor, write one JSON response, close.
///
/// Only runs while the app process is alive and allowed to run: always on
/// Mac, while foregrounded or already playing on iPhone/iPad.
public final class LocalControlServer {
    public typealias Handler = @MainActor (ControlRequest) -> ControlResponse

    private var listener: NWListener?
    private let handler: Handler
    private let queue = DispatchQueue(label: "AutoWhiteNoise.control", qos: .userInitiated)
    public private(set) var port: UInt16 = 0
    public var onStateChange: ((String) -> Void)?

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public var isRunning: Bool { listener != nil }

    public func start(port: UInt16) throws {
        stop()
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { throw ServerError.badPort }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let l = try NWListener(using: params, on: nwPort)
        l.service = NWListener.Service(type: "_autowhitenoise._tcp")
        l.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.port = l.port?.rawValue ?? port
                self?.onStateChange?("Listening on port \(l.port?.rawValue ?? port)")
            case .failed(let error):
                self?.onStateChange?("Failed: \(error.localizedDescription)")
                self?.stop()
            case .cancelled:
                self?.onStateChange?("Stopped")
            default:
                break
            }
        }
        l.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        l.start(queue: queue)
        listener = l
        self.port = port
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        var buffer = Data()
        func receiveMore() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, isComplete, error in
                guard let self else { connection.cancel(); return }
                if let data { buffer.append(data) }
                let headComplete = buffer.range(of: Data("\r\n\r\n".utf8)) != nil
                if headComplete || isComplete || error != nil || buffer.count > 65_536 {
                    let text = String(decoding: buffer, as: UTF8.self)
                    self.respond(to: text, on: connection)
                } else {
                    receiveMore()
                }
            }
        }
        receiveMore()
    }

    private func respond(to rawRequest: String, on connection: NWConnection) {
        guard let request = ControlRequest(rawHTTP: rawRequest) else {
            send(ControlResponse.error(400, "Malformed request."), on: connection)
            return
        }
        let handler = self.handler
        Task { @MainActor in
            let response = handler(request)
            self.send(response, on: connection)
        }
    }

    private func send(_ response: ControlResponse, on connection: NWConnection) {
        let data = Data(response.rawHTTP.utf8)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    public enum ServerError: Error, LocalizedError {
        case badPort
        public var errorDescription: String? { "Port must be between 1 and 65535." }
    }
}
#endif
