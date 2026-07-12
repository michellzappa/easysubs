import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let apiKey = "apiKey"
        static let username = "username"
        static let language = "language"
        static let overwriteExisting = "overwriteExisting"
    }

    private let defaults: UserDefaults

    @Published var apiKey: String {
        didSet { defaults.set(apiKey, forKey: Key.apiKey) }
    }
    @Published var username: String {
        didSet { defaults.set(username, forKey: Key.username) }
    }
    @Published var password: String {
        didSet { KeychainStore.write(password, account: "password") }
    }
    @Published var languageCode: String {
        didSet { defaults.set(languageCode, forKey: Key.language) }
    }
    @Published var overwriteExisting: Bool {
        didSet { defaults.set(overwriteExisting, forKey: Key.overwriteExisting) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        apiKey = defaults.string(forKey: Key.apiKey) ?? ""
        username = defaults.string(forKey: Key.username) ?? ""
        password = KeychainStore.read(account: "password")
        languageCode = defaults.string(forKey: Key.language) ?? "en"
        overwriteExisting = defaults.bool(forKey: Key.overwriteExisting)
    }

    var credentials: OpenSubtitlesCredentials {
        OpenSubtitlesCredentials(
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
    }

    var isConfigured: Bool { credentials.isComplete }

    var languageName: String {
        SubtitleLanguage.common.first(where: { $0.code == languageCode })?.name ?? languageCode
    }
}

