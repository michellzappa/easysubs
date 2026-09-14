import Foundation

public struct SubtitleLanguage: Identifiable, Hashable, Sendable {
    public let code: String
    public let name: String
    public var id: String { code }

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }

    public static let common: [SubtitleLanguage] = [
        .init(code: "en", name: "English"),
        .init(code: "nl", name: "Dutch"),
        .init(code: "es", name: "Spanish"),
        .init(code: "fr", name: "French"),
        .init(code: "de", name: "German"),
        .init(code: "it", name: "Italian"),
        .init(code: "pt-pt", name: "Portuguese"),
        .init(code: "pt-br", name: "Portuguese (Brazil)"),
        .init(code: "pl", name: "Polish"),
        .init(code: "ru", name: "Russian"),
        .init(code: "uk", name: "Ukrainian"),
        .init(code: "tr", name: "Turkish"),
        .init(code: "sv", name: "Swedish"),
        .init(code: "da", name: "Danish"),
        .init(code: "no", name: "Norwegian"),
        .init(code: "fi", name: "Finnish"),
        .init(code: "cs", name: "Czech"),
        .init(code: "hu", name: "Hungarian"),
        .init(code: "ro", name: "Romanian"),
        .init(code: "el", name: "Greek"),
        .init(code: "he", name: "Hebrew"),
        .init(code: "ar", name: "Arabic"),
        .init(code: "ja", name: "Japanese"),
        .init(code: "ko", name: "Korean"),
        .init(code: "zh-cn", name: "Chinese (Simplified)"),
        .init(code: "zh-tw", name: "Chinese (Traditional)"),
        .init(code: "id", name: "Indonesian"),
        .init(code: "vi", name: "Vietnamese"),
        .init(code: "th", name: "Thai")
    ]
}

public struct OpenSubtitlesCredentials: Equatable, Sendable {
    public let apiKey: String
    public let username: String
    public let password: String

    public init(apiKey: String, username: String, password: String) {
        self.apiKey = apiKey
        self.username = username
        self.password = password
    }

    public var isComplete: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }
}

public struct SubtitleMatch: Sendable {
    public let fileID: Int
    public let releaseName: String?
    public let matchedByHash: Bool
}

