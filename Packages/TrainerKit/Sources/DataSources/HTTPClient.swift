import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let body: Data
    public let etag: String?

    public init(statusCode: Int, body: Data, etag: String?) {
        self.statusCode = statusCode
        self.body = body
        self.etag = etag
    }
}

public protocol HTTPClient: Sendable {
    /// GET `url`. When `etag` is given it is sent as If-None-Match, so an unchanged file
    /// comes back as a cheap 304 Not Modified.
    func get(_ url: URL, ifNoneMatch etag: String?) async throws -> HTTPResponse
}

public struct URLSessionHTTPClient: HTTPClient {
    public init() {}

    public func get(_ url: URL, ifNoneMatch etag: String?) async throws -> HTTPResponse {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        // Generic client name only: no personal or device details.
        request.setValue("TrainerToolkit/1.0 (personal iOS app)", forHTTPHeaderField: "User-Agent")
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return HTTPResponse(statusCode: http.statusCode, body: data, etag: http.value(forHTTPHeaderField: "ETag"))
    }
}
