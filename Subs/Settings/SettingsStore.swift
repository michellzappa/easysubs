import EasySubsKit
import Foundation

/// OpenSubtitles credentials and subtitle preferences. The password is in
/// Keychain; everything else is in the app's preferences. Controls save on change.
@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let apiKey = "apiKey"
        static let username = "username"
        static let language = "language"
        static let overwriteExisting = "overwriteExisting"
        static let migratedFromEasySubs = "migratedFromEasySubs"
    }

    /// EasySubs, the window app before the rename. Its preferences and
    /// Keychain item are copied over once.
    private static let easySubsDomain = "app.easysubs.mac"

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
        Self.migrateFromEasySubs(into: defaults)
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

    /// Copies EasySubs settings once, only when Subs has none of its own.
    private static func migrateFromEasySubs(into defaults: UserDefaults) {
        guard !defaults.bool(forKey: Key.migratedFromEasySubs) else { return }
        defaults.set(true, forKey: Key.migratedFromEasySubs)
        guard defaults.string(forKey: Key.apiKey) == nil,
              let old = UserDefaults(suiteName: easySubsDomain)
        else { return }
        for key in [Key.apiKey, Key.username, Key.language, Key.overwriteExisting] {
            if let value = old.object(forKey: key) { defaults.set(value, forKey: key) }
        }
        if KeychainStore.read(account: "password").isEmpty {
            let password = KeychainStore.read(account: "password", service: easySubsDomain)
            if !password.isEmpty { KeychainStore.write(password, account: "password") }
        }
    }
}
