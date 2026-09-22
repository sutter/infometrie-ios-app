import Foundation

/// Offline fixture transport. Requests still traverse the real HLS relay and must carry its Bearer header.
final class DemoMediaProtocol: URLProtocol, @unchecked Sendable {
    static let origin = URL(string: "https://demo.infometrie.invalid")!
    static let token = "local-offline-demonstration"
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == origin.host }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let name = url.lastPathComponent
        let authorized = request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.token)"
        let allowed = name == "demo.m3u8" || (0...6).contains { name == String(format: "demo-segment-%02d.ts", $0) }
        let file = allowed ? Bundle.main.url(forResource: (name as NSString).deletingPathExtension, withExtension: (name as NSString).pathExtension) : nil
        let data = file.flatMap { try? Data(contentsOf: $0) }
        let status = !authorized ? 401 : data == nil ? 404 : 200
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": name.hasSuffix("m3u8") ? "application/vnd.apple.mpegurl" : "video/mp2t"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if authorized, let data { client?.urlProtocol(self, didLoad: data) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
