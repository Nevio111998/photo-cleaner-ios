import XCTest
@testable import PhotoCleaner

final class PhotoCleanerTests: XCTestCase {
    private func photo(_ id: String, hash: UInt64 = 0, digest: String? = nil, time: TimeInterval = 0) -> PhotoRecord {
        PhotoRecord(id: id, signature: "v1", date: Date(timeIntervalSince1970: time), width: 1000,
                    height: 1000, digest: digest, bytes: 100, fingerprint: hash, quality: 1)
    }
    func testSwipesOnlyChangeDecisionsAndUndoRestoresPreviousChoice() {
        var state = DecisionHistory()
        state.set(.keep, for: "a")
        state.set(.delete, for: "a")
        XCTAssertEqual(state.decisions["a"], .delete)
        XCTAssertEqual(state.undo(), "a")
        XCTAssertEqual(state.decisions["a"], .keep)
        state.undo()
        XCTAssertNil(state.decisions["a"])
        XCTAssertFalse(state.canUndo)
    }
    func testDiscardDoesNotEraseKeptDecisions() {
        var state = DecisionHistory()
        state.set(.keep, for: "a"); state.set(.delete, for: "b")
        state.clearQueue()
        XCTAssertEqual(state.decisions, ["a": .keep])
        XCTAssertFalse(state.canUndo)
    }
    func testMissingResourcesNeverCountAsExactDuplicates() {
        XCTAssertTrue(Grouping.exact([photo("a"), photo("b")]).isEmpty)
        XCTAssertEqual(Grouping.exact([photo("a", digest: "same"), photo("b", digest: "same"), photo("c", digest: "other")]).count, 1)
    }
    func testSimilarGroupsDoNotChainAndRespectTimeWindow() {
        // A differs from B by 2 bits; B from C by 2, but A from C by 4.
        let groups = Grouping.similar([photo("a", hash: 0), photo("b", hash: 3, time: 1),
                                      photo("c", hash: 15, time: 2), photo("d", hash: 0, time: 90_000)], threshold: 2)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].photos.map(\.id), ["a", "b"])
    }
    func testExactCopiesAreNotRepeatedInSimilarGroups() {
        let groups = Grouping.similar([photo("a", digest: "same"), photo("b", digest: "same"), photo("c", hash: 1)], threshold: 2)
        XCTAssertEqual(groups.first?.photos.map(\.id), ["a", "c"])
    }
    func testStateRoundTripAndStaleDecisionRemoval() throws {
        let source = SavedState(records: [photo("a")], decisions: ["a": .delete])
        let restored = try JSONDecoder().decode(SavedState.self, from: JSONEncoder().encode(source))
        XCTAssertEqual(restored.decisions, source.decisions)
        var state = DecisionHistory(decisions: restored.decisions)
        state.retain([])
        XCTAssertTrue(state.decisions.isEmpty)
    }
    func testUniformBlackAndWhiteAreNotSimilar() {
        var black = photo("black"); black.luminance = Array(repeating: 0, count: 64)
        var white = photo("white"); white.luminance = Array(repeating: 255, count: 64)
        XCTAssertTrue(Grouping.similar([black, white], threshold: 6).isEmpty)
    }
    func testFingerprintDistance() {
        XCTAssertEqual(Grouping.distance(0, UInt64.max), 64)
        XCTAssertEqual(Grouping.distance(42, 42), 0)
    }
}
