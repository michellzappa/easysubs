import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var jobs: [SubtitleJob] = []
    @Published private(set) var isProcessing = false
    @Published var wantsSetup = false

    private let settings: SettingsStore
    private let client = OpenSubtitlesClient()
    private let videoExtensions: Set<String> = [
        "3gp", "avi", "flv", "m2ts", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "mts", "ogm", "ts", "webm", "wmv"
    ]

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func accept(_ urls: [URL]) -> Bool {
        let videos = urls.filter { videoExtensions.contains($0.pathExtension.lowercased()) }
        guard !videos.isEmpty else { return false }
        guard settings.isConfigured else {
            wantsSetup = true
            return true
        }

        let additions = videos.map { SubtitleJob(videoURL: $0) }
        jobs.insert(contentsOf: additions, at: 0)
        processQueueIfNeeded()
        return true
    }

    func chooseVideos() {
        let panel = NSOpenPanel()
        panel.title = "Choose video files"
        panel.prompt = "Find Subtitles"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = videoExtensions.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK { _ = accept(panel.urls) }
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func clearFinished() {
        jobs.removeAll { !$0.stage.isActive && $0.stage != .queued }
    }

    private func processQueueIfNeeded() {
        guard !isProcessing else { return }
        isProcessing = true
        Task {
            while let index = jobs.lastIndex(where: { $0.stage == .queued }) {
                await process(jobID: jobs[index].id)
            }
            isProcessing = false
        }
    }

    private func process(jobID: UUID) async {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        let videoURL = jobs[index].videoURL
        let outputURL = videoURL.deletingPathExtension().appendingPathExtension("srt")

        if FileManager.default.fileExists(atPath: outputURL.path), !settings.overwriteExisting {
            update(jobID) { $0.stage = .skipped(outputURL) }
            return
        }

        let hasAccess = videoURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { videoURL.stopAccessingSecurityScopedResource() } }

        do {
            update(jobID) { $0.stage = .hashing }
            let match = try await client.findBestSubtitle(
                for: videoURL,
                language: settings.languageCode,
                credentials: settings.credentials
            ) { [weak self] in
                await self?.setSearching(jobID)
            }
            update(jobID) {
                $0.stage = .downloading
                let method = match.matchedByHash ? "Exact video match" : "Filename match"
                $0.matchDescription = match.releaseName.map { "\(method) · \($0)" } ?? method
            }
            let data = try await client.download(match: match, credentials: settings.credentials)
            try data.write(to: outputURL, options: .atomic)
            update(jobID) { $0.stage = .saved(outputURL) }
        } catch {
            update(jobID) { $0.stage = .failed(error.localizedDescription) }
        }
    }

    private func setSearching(_ jobID: UUID) {
        update(jobID) { $0.stage = .searching }
    }

    private func update(_ id: UUID, change: (inout SubtitleJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        change(&jobs[index])
    }
}
