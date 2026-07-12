import XCTest
@testable import EasySubs

final class OpenSubtitlesCodingTests: XCTestCase {
    func testLoginResponseDecodesSnakeCaseBaseURL() throws {
        let data = Data(#"{"token":"abc","base_url":"vip-api.opensubtitles.com"}"#.utf8)
        let response = try JSONDecoder.openSubtitles.decode(LoginResponse.self, from: data)
        XCTAssertEqual(response.token, "abc")
        XCTAssertEqual(response.baseURL, "vip-api.opensubtitles.com")
    }

    func testSubtitleFileDecodesSnakeCaseIdentifiers() throws {
        let data = Data(#"{"file_id":42,"file_name":"release.srt"}"#.utf8)
        let file = try JSONDecoder.openSubtitles.decode(SubtitleFile.self, from: data)
        XCTAssertEqual(file.fileID, 42)
        XCTAssertEqual(file.fileName, "release.srt")
    }

    func testDownloadRequestEncodesAPIFieldNames() throws {
        let data = try JSONEncoder().encode(DownloadRequest(fileID: 42, subFormat: "srt"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["sub_format"] as? String, "srt")
        XCTAssertNil(object["subFormat"])
        XCTAssertEqual(object["file_id"] as? Int, 42)
        XCTAssertNil(object["fileID"])
    }
}
