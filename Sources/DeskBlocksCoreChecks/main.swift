import DeskBlocksCore
import Foundation

private func check(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    if !condition() {
        fputs("FAIL: \(message) (\(file):\(line))\n", stderr)
        Foundation.exit(1)
    }
}

private func testPrototypeMetricsProduceInitialFourByThreeBlockSize() {
    let metrics = TileGridMetrics.prototype

    let size = metrics.contentSize(columns: 4, rows: 3)

    check(size.width == 408, "expected initial width to be 408")
    check(size.height == 322, "expected initial height to be 322")
}

private func testSnappingUpAddsAWholeColumn() {
    let metrics = TileGridMetrics.prototype
    let fourColumnSize = metrics.contentSize(columns: 4, rows: 3)

    let snapped = metrics.snappedSize(
        for: BlockSize(width: fourColumnSize.width + 49, height: fourColumnSize.height)
    )

    check(snapped.columns == 5, "expected width to snap up to 5 columns")
    check(snapped.rows == 3, "expected rows to remain unchanged")
    check(
        snapped.size.width == metrics.contentSize(columns: 5, rows: 3).width,
        "expected snapped width to be an exact whole-tile width"
    )
}

private func testSnappingDownRemovesOnlyAWholeColumn() {
    let metrics = TileGridMetrics.prototype
    let fourColumnSize = metrics.contentSize(columns: 4, rows: 3)

    let snapped = metrics.snappedSize(
        for: BlockSize(width: fourColumnSize.width - 49, height: fourColumnSize.height)
    )

    check(snapped.columns == 3, "expected width to snap down to 3 columns")
    check(snapped.rows == 3, "expected rows to remain unchanged")
    check(
        snapped.size.width == metrics.contentSize(columns: 3, rows: 3).width,
        "expected snapped width to remove only a whole column"
    )
}

private func testSnappingEnforcesMinimumUsableSize() {
    let metrics = TileGridMetrics.prototype

    let snapped = metrics.snappedSize(for: BlockSize(width: 1, height: 1))

    check(snapped.columns == 1, "expected minimum column count to be 1")
    check(snapped.rows == 1, "expected minimum row count to be 1")
    check(
        snapped.size == metrics.contentSize(columns: 1, rows: 1),
        "expected minimum size to include one tile plus title/frame allowance"
    )
}

private func testTileSizeRemainsUnchangedAcrossSnapping() {
    let metrics = TileGridMetrics.prototype

    let snapped = metrics.snappedSize(for: BlockSize(width: 1000, height: 700))

    check(snapped.tileWidth == metrics.tileWidth, "expected tile width to remain unchanged")
    check(snapped.tileHeight == metrics.tileHeight, "expected tile height to remain unchanged")
}

private func testDeskBlockStateKeepsFutureTileReferencesInTheModel() {
    let state = DeskBlockState.prototypeDefault()

    check(state.title == "DeskBlocks Prototype", "expected prototype title")
    check(state.columns == 4, "expected default columns")
    check(state.rows == 3, "expected default rows")
    check(state.tileReferences.isEmpty, "expected empty tile references for current prototype")
}

private func testDeskBlockStateSnapsProposedSizeAndPreservesReferences() {
    let metrics = TileGridMetrics.prototype
    let state = DeskBlockState(
        title: "Work",
        frame: BlockFrame(
            origin: BlockPoint(x: 10, y: 20),
            size: metrics.contentSize(columns: 4, rows: 3)
        ),
        columns: 4,
        rows: 3,
        tileReferences: [
            TileReference(id: "tile-1", displayName: "Invoices", folderReference: "bookmark-placeholder")
        ]
    )

    let snapped = state.snapped(
        metrics: metrics,
        origin: BlockPoint(x: 30, y: 40),
        proposedSize: BlockSize(width: state.frame.size.width + 49, height: state.frame.size.height)
    )

    check(snapped.frame.origin == BlockPoint(x: 30, y: 40), "expected updated origin")
    check(snapped.columns == 5, "expected snapped columns")
    check(snapped.rows == 3, "expected rows to remain unchanged")
    check(snapped.tileReferences == state.tileReferences, "expected tile references to survive snapping")
}

private func testDeskBlockStateRoundTripsThroughJSON() {
    let state = DeskBlockState.prototypeDefault().snapped(
        metrics: .prototype,
        origin: BlockPoint(x: 111, y: 222),
        proposedSize: BlockSize(width: 510, height: 410)
    )

    do {
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(DeskBlockState.self, from: data)

        check(decoded == state, "expected state to round-trip through JSON")
    } catch {
        fputs("FAIL: expected JSON round-trip, got \(error)\n", stderr)
        Foundation.exit(1)
    }
}

testPrototypeMetricsProduceInitialFourByThreeBlockSize()
testSnappingUpAddsAWholeColumn()
testSnappingDownRemovesOnlyAWholeColumn()
testSnappingEnforcesMinimumUsableSize()
testTileSizeRemainsUnchangedAcrossSnapping()
testDeskBlockStateKeepsFutureTileReferencesInTheModel()
testDeskBlockStateSnapsProposedSizeAndPreservesReferences()
testDeskBlockStateRoundTripsThroughJSON()

print("DeskBlocksCoreChecks passed")
