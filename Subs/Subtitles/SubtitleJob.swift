import Foundation


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

extension SubtitleJob {
    /// One line of status, for the drop window and the status menu.
    var detail: String {
        switch stage {
        case .queued: "Waiting"
        case .hashing: "Reading video fingerprint…"
        case .searching: "Searching OpenSubtitles…"
        case .downloading: matchDescription ?? "Downloading…"
        case .saved: "Saved beside the video"
        case .skipped: "Subtitle already exists"
        case let .failed(message): message
        }
    }

    /// The `.srt` on disk, when there is one.
    var subtitleURL: URL? {
        switch stage {
        case let .saved(url), let .skipped(url): url
        default: nil
        }
    }
}
