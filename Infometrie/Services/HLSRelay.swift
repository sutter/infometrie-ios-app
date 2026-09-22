import Foundation
import Network

/// Loopback-only relay: AVPlayer uses documented HTTP playback while URLSession supplies Bearer authentication.
/// No media is written to disk and the random route is renewed for each playback session.
final class HLSRelay: @unchecked Sendable {
    private let queue = DispatchQueue(label: "fr.yacast.infometrie.hls")
    private let nonce = UUID().uuidString
    private let origin: URL
    private let token: String
    private var listener: NWListener?
    private var port: NWEndpoint.Port?
    // Listener state and this continuation are confined to queue.
    private var startup: CheckedContinuation<Void, Error>?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private let session: URLSession
    var onUnauthorized: (@Sendable () -> Void)?

    init(origin: URL, token: String, configuration: URLSessionConfiguration = .ephemeral) {
        self.origin = origin; self.token = token
        let config = configuration
        config.urlCache = nil; config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config, delegate: SameOriginRedirectDelegate(), delegateQueue: nil)
    }
    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                self.startup = continuation
                do {
                    let parameters = NWParameters.tcp
                    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
                    let listener = try NWListener(using: parameters)
                    self.listener = listener
                    listener.stateUpdateHandler = { [weak self] state in
                        guard let self, let continuation = self.startup else { return }
                        switch state {
                        case .ready:
                            self.port = self.listener?.port; self.startup = nil; continuation.resume()
                        case .failed(let error):
                            self.startup = nil; continuation.resume(throwing: error)
                        case .cancelled:
                            self.startup = nil; continuation.resume(throwing: CancellationError())
                        default: break
                        }
                    }
                    listener.newConnectionHandler = { [weak self] connection in
                        guard let self else { connection.cancel(); return }
                        self.connections[ObjectIdentifier(connection)] = connection
                        connection.start(queue: self.queue)
                        self.receive(connection, buffer: Data())
                    }
                    listener.start(queue: self.queue)
                } catch { self.startup = nil; continuation.resume(throwing: error) }
            }
        }
    }
    func localURL(for remote: URL) throws -> URL {
        guard APIClient.sameOrigin(remote, origin), let port else { throw APIError.untrustedMedia }
        let encoded = Data(remote.absoluteString.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        // Retain the suffix so AVFoundation can determine the playlist/container format.
        return URL(string: "http://127.0.0.1:\(port.rawValue)/\(nonce)/\(encoded)/media.\(remote.pathExtension.isEmpty ? "bin" : remote.pathExtension)")!
    }
    func stop() {
        session.invalidateAndCancel()
        queue.async {
            self.listener?.cancel(); self.listener = nil
            for connection in self.connections.values { connection.cancel() }
            self.connections.removeAll()
        }
    }
    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var buffer = buffer
            if let data { buffer.append(data) }
            guard buffer.count <= 32_768 else { self.respond(connection, status: 400); return }
            if let text = String(data: buffer, encoding: .utf8), text.contains("\r\n\r\n") {
                self.handle(text, connection: connection)
            } else if complete || error != nil { self.close(connection) }
            else { self.receive(connection, buffer: buffer) }
        }
    }
    private func handle(_ header: String, connection: NWConnection) {
        let lines = header.components(separatedBy: "\r\n")
        let first = (lines.first ?? "").split(separator: " ")
        guard first.count == 3, first[0] == "GET" || first[0] == "HEAD" else { respond(connection, status: 405); return }
        let path = first[1].split(separator: "/")
        guard path.count == 3, path[0] == Substring(nonce) else { respond(connection, status: 403); return }
        var encoded = String(path[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let bytes = Data(base64Encoded: encoded), let address = String(data: bytes, encoding: .utf8),
              let remote = URL(string: address), APIClient.sameOrigin(remote, origin) else { respond(connection, status: 403); return }
        var request = URLRequest(url: remote)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let isHead = first[0] == "HEAD"
        for line in lines.dropFirst() where line.lowercased().hasPrefix("range:") {
            request.setValue(String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces), forHTTPHeaderField: "Range")
        }
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { connection.cancel(); return }
            self.queue.async {
                guard error == nil, let response = response as? HTTPURLResponse, var data else {
                    self.respond(connection, status: 502); return
                }
                if response.statusCode == 401 || response.statusCode == 403 { self.onUnauthorized?() }
                guard (200..<300).contains(response.statusCode) else { self.respond(connection, status: response.statusCode); return }
                var contentType = response.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"
                var extra: [String: String] = [:]
                let manifest = data.starts(with: Data("#EXTM3U".utf8))
                if manifest, let text = String(data: data, encoding: .utf8) {
                    do {
                        let rewritten = try HLSManifest.rewrite(text, baseURL: response.url ?? remote) { try self.localURL(for: $0) }
                        data = Data(rewritten.utf8); contentType = "application/vnd.apple.mpegurl"
                    } catch { self.respond(connection, status: 502); return }
                } else {
                    for key in ["Content-Range", "Accept-Ranges"] {
                        if let value = response.value(forHTTPHeaderField: key) { extra[key] = value }
                    }
                }
                self.respond(connection, status: response.statusCode, data: data, type: contentType, head: isHead, headers: extra)
            }
        }.resume()
    }
    private func respond(_ connection: NWConnection, status: Int, data: Data = Data(), type: String = "text/plain", head: Bool = false, headers: [String: String] = [:]) {
        var header = "HTTP/1.1 \(status) \(HTTPURLResponse.localizedString(forStatusCode: status))\r\nContent-Type: \(type)\r\nContent-Length: \(data.count)\r\nCache-Control: no-store\r\nConnection: close\r\n"
        for (key, value) in headers { header += "\(key): \(value)\r\n" }
        var response = Data((header + "\r\n").utf8)
        if !head { response.append(data) }
        connection.send(content: response, completion: .contentProcessed { [weak self] _ in
            self?.close(connection)
        })
    }
    private func close(_ connection: NWConnection) {
        connection.cancel(); connections.removeValue(forKey: ObjectIdentifier(connection))
    }
}
