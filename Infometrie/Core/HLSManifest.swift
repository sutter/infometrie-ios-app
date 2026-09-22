import Foundation

enum HLSManifest {
    /// Route both segment lines and URI attributes (keys, maps, renditions) through the authenticated relay.
    static func rewrite(_ text: String, baseURL: URL, map: (URL) throws -> URL) throws -> String {
        let expression = try NSRegularExpression(pattern: #"URI="([^"]+)""#)
        return try text.components(separatedBy: "\n").map { line in
            let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.isEmpty { return line }
            if !clean.hasPrefix("#") {
                guard let url = URL(string: clean, relativeTo: baseURL)?.absoluteURL else { throw APIError.invalidResponse }
                return try map(url).absoluteString
            }
            var replaced = line
            for match in expression.matches(in: line, range: NSRange(line.startIndex..., in: line)).reversed() {
                guard let valueRange = Range(match.range(at: 1), in: line),
                      let url = URL(string: String(line[valueRange]), relativeTo: baseURL)?.absoluteURL else { continue }
                replaced.replaceSubrange(valueRange, with: try map(url).absoluteString)
            }
            return replaced
        }.joined(separator: "\n")
    }
}

final class SameOriginRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let origin = task.originalRequest?.url, let next = request.url,
              APIClient.sameOrigin(origin, next) else { completionHandler(nil); return }
        var request = request
        if let authorization = task.originalRequest?.value(forHTTPHeaderField: "Authorization") {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        completionHandler(request)
    }
}
