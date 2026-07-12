import Foundation

enum OpenSubtitlesError: LocalizedError {
    case invalidResponse
    case decoding(stage: String, detail: String)
    case api(status: Int, message: String)
    case noMatch
    case invalidDownload

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "OpenSubtitles returned an unreadable response."
        case let .decoding(stage, detail):
            "OpenSubtitles returned an unreadable \(stage) response (\(detail))."
        case let .api(status, message):
            status == 401 ? "OpenSubtitles rejected the username or password." : message
        case .noMatch:
            "No subtitle was found in the selected language."
        case .invalidDownload:
            "OpenSubtitles did not provide a valid download."
        }
    }
}

actor OpenSubtitlesClient {
    private let defaultBaseURL = URL(string: "https://api.opensubtitles.com/api/v1")!
    private let userAgent = "EasySubs v1.0"
    private var sessionToken: String?
    private var sessionBaseURL: URL?
    private var authenticatedCredentials: OpenSubtitlesCredentials?

    func findBestSubtitle(
        for videoURL: URL,
        language: String,
        credentials: OpenSubtitlesCredentials,
        onHashComplete: @Sendable () async -> Void
    ) async throws -> SubtitleMatch {
        let auth = try await authenticate(credentials)

        if let hash = try? OpenSubtitlesHash.calculate(for: videoURL) {
            await onHashComplete()
            let hashResults = try await search(
                parameters: [
                    URLQueryItem(name: "languages", value: language),
                    URLQueryItem(name: "moviehash", value: hash.hash),
                    URLQueryItem(name: "moviebytesize", value: String(hash.byteSize)),
                    URLQueryItem(name: "order_by", value: "download_count"),
                    URLQueryItem(name: "order_direction", value: "desc")
                ],
                auth: auth,
                apiKey: credentials.apiKey
            )
            if let result = bestMatch(in: hashResults, matchedByHash: true) { return result }
        } else {
            await onHashComplete()
        }

        let filename = videoURL.deletingPathExtension().lastPathComponent
        let nameResults = try await search(
            parameters: [
                URLQueryItem(name: "languages", value: language),
                URLQueryItem(name: "query", value: filename),
                URLQueryItem(name: "order_by", value: "download_count"),
                URLQueryItem(name: "order_direction", value: "desc")
            ],
            auth: auth,
            apiKey: credentials.apiKey
        )
        guard let result = bestMatch(in: nameResults, matchedByHash: false) else {
            throw OpenSubtitlesError.noMatch
        }
        return result
    }

    func download(
        match: SubtitleMatch,
        credentials: OpenSubtitlesCredentials
    ) async throws -> Data {
        let auth = try await authenticate(credentials)
        let endpoint = auth.baseURL.appending(path: "download")
        var linkRequest = request(url: endpoint, apiKey: credentials.apiKey, token: auth.token)
        linkRequest.httpMethod = "POST"
        linkRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        linkRequest.httpBody = try JSONEncoder().encode(DownloadRequest(fileID: match.fileID, subFormat: "srt"))

        let (responseData, response) = try await URLSession.shared.data(for: linkRequest)
        try validate(response, data: responseData)
        let result = try decode(DownloadResponse.self, from: responseData, stage: "download")
        guard let url = URL(string: result.link) else { throw OpenSubtitlesError.invalidDownload }

        // The temporary URL can use a different OpenSubtitles host. Do not send
        // the account bearer token across hosts; the API key and user agent are enough.
        var downloadRequest = request(url: url, apiKey: credentials.apiKey)
        downloadRequest.setValue("text/plain, application/octet-stream", forHTTPHeaderField: "Accept")
        let (subtitleData, downloadResponse) = try await URLSession.shared.data(for: downloadRequest)
        try validate(downloadResponse, data: subtitleData)
        guard !subtitleData.isEmpty else { throw OpenSubtitlesError.invalidDownload }
        return subtitleData
    }

    private func authenticate(_ credentials: OpenSubtitlesCredentials) async throws -> Authentication {
        if authenticatedCredentials == credentials,
           let sessionToken,
           let sessionBaseURL {
            return Authentication(token: sessionToken, baseURL: sessionBaseURL)
        }

        var request = request(url: defaultBaseURL.appending(path: "login"), apiKey: credentials.apiKey)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(LoginRequest(username: credentials.username, password: credentials.password))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        let login = try decode(LoginResponse.self, from: data, stage: "login")

        let baseURL = normalizedBaseURL(login.baseURL)
        sessionToken = login.token
        sessionBaseURL = baseURL
        authenticatedCredentials = credentials
        return Authentication(token: login.token, baseURL: baseURL)
    }

    private func search(parameters: [URLQueryItem], auth: Authentication, apiKey: String) async throws -> [SubtitleResult] {
        var components = URLComponents(url: auth.baseURL.appending(path: "subtitles"), resolvingAgainstBaseURL: false)!
        components.queryItems = parameters
        guard let url = components.url else { throw OpenSubtitlesError.invalidResponse }
        let (data, response) = try await URLSession.shared.data(for: request(url: url, apiKey: apiKey, token: auth.token))
        try validate(response, data: data)
        return try decode(SearchResponse.self, from: data, stage: "search").data
    }

    private func bestMatch(in results: [SubtitleResult], matchedByHash: Bool) -> SubtitleMatch? {
        for result in results {
            guard let file = result.attributes.files.first else { continue }
            return SubtitleMatch(
                fileID: file.fileID,
                releaseName: result.attributes.release ?? file.fileName,
                matchedByHash: matchedByHash
            )
        }
        return nil
    }

    private func request(url: URL, apiKey: String, token: String? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw OpenSubtitlesError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let decoded = try? JSONDecoder.openSubtitles.decode(APIErrorResponse.self, from: data)
            let fallback = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw OpenSubtitlesError.api(status: http.statusCode, message: decoded?.message ?? fallback)
        }
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        stage: String
    ) throws -> Value {
        do {
            return try JSONDecoder.openSubtitles.decode(type, from: data)
        } catch let error as DecodingError {
            throw OpenSubtitlesError.decoding(stage: stage, detail: Self.describe(error))
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case let .keyNotFound(key, _):
            "missing ‘\(key.stringValue)’"
        case let .valueNotFound(_, context),
             let .typeMismatch(_, context),
             let .dataCorrupted(context):
            context.debugDescription
        @unknown default:
            "unexpected JSON format"
        }
    }

    private func normalizedBaseURL(_ value: String) -> URL {
        var text = value
        if !text.contains("://") { text = "https://" + text }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !text.hasSuffix("/api/v1") { text += "/api/v1" }
        return URL(string: text) ?? defaultBaseURL
    }
}

private struct Authentication {
    let token: String
    let baseURL: URL
}

private struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct LoginResponse: Decodable {
    let token: String
    let baseURL: String

    enum CodingKeys: String, CodingKey {
        case token
        case baseURL = "base_url"
    }
}

private struct SearchResponse: Decodable {
    let data: [SubtitleResult]
}

private struct SubtitleResult: Decodable {
    let attributes: SubtitleAttributes
}

private struct SubtitleAttributes: Decodable {
    let release: String?
    let files: [SubtitleFile]
}

struct SubtitleFile: Decodable {
    let fileID: Int
    let fileName: String?

    enum CodingKeys: String, CodingKey {
        case fileID = "file_id"
        case fileName = "file_name"
    }
}

struct DownloadRequest: Encodable {
    let fileID: Int
    let subFormat: String

    enum CodingKeys: String, CodingKey {
        case fileID = "file_id"
        case subFormat = "sub_format"
    }
}

private struct DownloadResponse: Decodable {
    let link: String
}

private struct APIErrorResponse: Decodable {
    let message: String
}

extension JSONDecoder {
    static var openSubtitles: JSONDecoder {
        // Fields that need snake-case conversion use explicit CodingKeys above.
        // Combining those keys with .convertFromSnakeCase transforms `base_url`
        // and `file_id` before matching and makes valid API responses fail to decode.
        JSONDecoder()
    }
}
