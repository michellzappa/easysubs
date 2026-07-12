import Foundation

struct SubtitleLanguage: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let common: [SubtitleLanguage] = [
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

struct OpenSubtitlesCredentials: Equatable {
    let apiKey: String
    let username: String
    let password: String

    var isComplete: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }
}

struct SubtitleMatch {
    let fileID: Int
    let releaseName: String?
    let matchedByHash: Bool
}

enum JobStage: Equatable {
    case queued
    case hashing
    case searching
    case downloading
    case saved(URL)
    case skipped(URL)
    case failed(String)

    var isActive: Bool {
        switch self {
        case .hashing, .searching, .downloading: true
        default: false
        }
    }
}

struct SubtitleJob: Identifiable {
    let id = UUID()
    let videoURL: URL
    var stage: JobStage = .queued
    var matchDescription: String?
}

