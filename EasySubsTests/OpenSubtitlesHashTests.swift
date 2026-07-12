import XCTest
@testable import EasySubs

final class OpenSubtitlesHashTests: XCTestCase {
    func testHashUsesSizeAndLittleEndianWordsFromBothEnds() throws {
        let size = OpenSubtitlesHash.chunkSize * 2
        var data = Data(count: size)
        data.replaceSubrange(0..<8, with: withUnsafeBytes(of: UInt64(1).littleEndian, Array.init))
        data.replaceSubrange((size - 8)..<size, with: withUnsafeBytes(of: UInt64(2).littleEndian, Array.init))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try OpenSubtitlesHash.calculate(for: url)
        XCTAssertEqual(result.byteSize, UInt64(size))
        XCTAssertEqual(result.hash, "0000000000020003")
    }

    func testSmallFilesFallBackInsteadOfProducingAnInvalidHash() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data(count: 100).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try OpenSubtitlesHash.calculate(for: url))
    }
}
