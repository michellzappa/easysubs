import EasySubsKit
import HouseKit
import SwiftUI

extension HouseSettingsWindowController {
    static let openSubtitlesPaneID = "opensubtitles"

    /// General · Subtitles · OpenSubtitles · About, the house order.
    static func subs(settings: SettingsStore) -> HouseSettingsWindowController {
        HouseSettingsWindowController(appName: "Subs", panes: [
            .general { GeneralSettingsPane() },
            SettingsPane(id: "subtitles", title: "Subtitles", symbol: "captions.bubble") {
                SubtitlesPane(settings: settings)
            },
            SettingsPane(id: openSubtitlesPaneID, title: "OpenSubtitles", symbol: "key") {
                OpenSubtitlesPane(settings: settings)
            },
            .about {
                AboutSettingsPane(
                    appName: "Subs",
                    tagline: "Drop a video. Get its subtitles.",
                    repository: "michellzappa/easysubs"
                )
            }
        ])
    }
}

private struct SubtitlesPane: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $settings.languageCode) {
                    ForEach(SubtitleLanguage.common) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                Toggle("Replace an existing .srt", isOn: $settings.overwriteExisting)
            } footer: {
                Text("Subs saves the subtitle beside the video, with the same name and an .srt extension. It tries an exact match on the video's fingerprint first, then the file name.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct OpenSubtitlesPane: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $settings.username)
                    .textContentType(.username)
                SecureField("Password", text: $settings.password)
                    .textContentType(.password)
                SecureField("API key", text: $settings.apiKey)
            } header: {
                Text("Account")
            } footer: {
                Text("Searching needs an API key. Downloading needs a signed-in OpenSubtitles.com account. The password is stored in macOS Keychain.")
            }

            Section {
                LabeledContent("Status") {
                    Label(
                        settings.isConfigured ? "Ready" : "Setup required",
                        systemImage: settings.isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(settings.isConfigured ? .green : .orange)
                }
                Button("Create an account…") {
                    openURL(URL(string: "https://www.opensubtitles.com/en/users/sign_up")!)
                }
                Button("Get an API key…") {
                    openURL(URL(string: "https://www.opensubtitles.com/en/consumers")!)
                }
            }
        }
        .formStyle(.grouped)
    }
}
