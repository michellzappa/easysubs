import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("EasySubs Setup")
                        .font(.title2.weight(.bold))
                    Text("A one-time connection to OpenSubtitles.com")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(22)

            Form {
                Section("Subtitle") {
                    Picker("Language", selection: $settings.languageCode) {
                        ForEach(SubtitleLanguage.common) { language in
                            Text(language.name).tag(language.code)
                        }
                    }
                    Toggle("Replace an existing .srt", isOn: $settings.overwriteExisting)
                }

                Section("OpenSubtitles.com API") {
                    TextField("Username", text: $settings.username)
                        .textContentType(.username)
                    SecureField("Password", text: $settings.password)
                        .textContentType(.password)
                    SecureField("API key", text: $settings.apiKey)
                    HStack {
                        Text("EasySubs uses the supported OpenSubtitles.com REST API. Searching requires an API key; downloading requires a signed-in OpenSubtitles.com account.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("Open API setup…") {
                            openURL(URL(string: "https://www.opensubtitles.com/en/consumers")!)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: .infinity)

            Divider()
            HStack {
                Label("Your password is stored in macOS Keychain.", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!settings.isConfigured)
            }
            .padding(16)
        }
        .frame(width: 470, height: 460)
    }
}
