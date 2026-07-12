import Foundation

enum OpenSubtitlesHashError: LocalizedError {
    case fileTooSmall
    case unreadable

    var errorDescription: String? {
        switch self {
        case .fileTooSmall: "The video is too small for hash matching."
        case .unreadable: "The video could not be read."
        }
    }
}

enum OpenSubtitlesHash {
    static let chunkSize = 64 * 1024

    static func calculate(for url: URL) throws -> (hash: String, byteSize: UInt64) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let size = try handle.seekToEnd()
        guard size >= UInt64(chunkSize * 2) else { throw OpenSubtitlesHashError.fileTooSmall }

        try handle.seek(toOffset: 0)
        guard let first = try handle.read(upToCount: chunkSize), first.count == chunkSize else {
            throw OpenSubtitlesHashError.unreadable
        }
        try handle.seek(toOffset: size - UInt64(chunkSize))
        guard let last = try handle.read(upToCount: chunkSize), last.count == chunkSize else {
            throw OpenSubtitlesHashError.unreadable
        }

        var value = size
        value = sum(first, into: value)
        value = sum(last, into: value)
        return (String(format: "%016llx", value), size)
    }

    private static func sum(_ data: Data, into initial: UInt64) -> UInt64 {
        var result = initial
        data.withUnsafeBytes { bytes in
            for offset in stride(from: 0, to: data.count, by: MemoryLayout<UInt64>.size) {
                result = result &+ UInt64(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
            }
        }
        return result
    }
}

