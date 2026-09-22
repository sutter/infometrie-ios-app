#if DEBUG
import Foundation

/// Exercises the real login UI, API client and Keychain without using a remote account.
/// This transport exists only in Debug and requires both explicit UI-test switches.
final class LoginTestProtocol: URLProtocol, @unchecked Sendable {
    @MainActor static func appModel() -> AppModel? {
        let process = ProcessInfo.processInfo
        guard process.arguments.contains("--uitesting"),
              let namespace = process.environment["INFOMETRIE_LOGIN_TEST_ID"],
              UUID(uuidString: namespace) != nil else { return nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LoginTestProtocol.self]
        return AppModel(api: APIClient(session: URLSession(configuration: configuration)),
                        sessionStore: SessionStore(service: "fr.yacast.infometrie.ios.login-tests.\(namespace)"),
                        remembersEmail: false)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() { }

    override func startLoading() {
        guard let url = request.url, APIClient.sameOrigin(url, APIClient.baseURL) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        if url.path == "/rest/v1/auth/login" {
            let body = bodyData().flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            guard request.httpMethod == "POST",
                  request.value(forHTTPHeaderField: "Content-Type") == "application/json",
                  request.value(forHTTPHeaderField: "Authorization") == nil,
                  body?["email"] as? String == "connexion@example.invalid",
                  let uid = body?["device_uid"] as? String, UUID(uuidString: uid) != nil,
                  let name = body?["device_name"] as? String, !name.isEmpty,
                  let model = body?["device_model"] as? String, !model.isEmpty else {
                respond(422); return
            }
            switch body?["password"] as? String {
            case "invalide": respond(401)
            case "inactif": respond(403)
            case "hors-ligne": client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            case "quota" where body?["replace_device_id"] as? Int != 37:
                respond(409, ["error": true, "reason": "device quota reached", "max_devices": 1,
                              "devices": [["id": 37, "name": "Ancien iPhone", "model": "iPhone"]]])
            case "valide", "quota":
                respond(201, ["token": "login-ui-fixture", "expires": 3600, "device_id": 38,
                              "email": "connexion@example.invalid", "fullname": "Compte de test API", "organisation": "Validation locale"])
            default: respond(401)
            }
            return
        }
        guard request.httpMethod == "GET", request.value(forHTTPHeaderField: "Authorization") == "Bearer login-ui-fixture" else {
            respond(401); return
        }
        switch url.path {
        case "/rest/v1/feed":
            respond(200, ["last_seq": 901, "items": [["id": 901, "seq": 901, "at": APIDate.string(Date()),
                "kind": "intervention", "media": "radio", "channel": "Canal de test", "person": "Compte API",
                "party": "TEST", "title": "Fil chargé après authentification"]]])
        case "/rest/v1/persons", "/rest/v1/parties": respond(200, [])
        default: respond(404)
        }
    }

    private func bodyData() -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }

    private func respond(_ status: Int, _ body: Any = [:]) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: (try? JSONSerialization.data(withJSONObject: body)) ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }
}
#endif
