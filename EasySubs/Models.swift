import Foundation
import EasySubsKit

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

