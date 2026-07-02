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

    check(state.id == .prototype, "expected prototype block ID")
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
    check(snapped.id == state.id, "expected block ID to survive snapping")
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

private func testDeskBlockStateDecodesLegacyJSONWithoutID() {
    let legacyJSON = """
    {
      "title": "Legacy Prototype",
      "frame": {
        "origin": { "x": 11, "y": 22 },
        "size": { "width": 408, "height": 322 }
      },
      "columns": 4,
      "rows": 3,
      "tileReferences": []
    }
    """

    do {
        let decoded = try JSONDecoder().decode(DeskBlockState.self, from: Data(legacyJSON.utf8))

        check(decoded.id == .prototype, "expected legacy state to default to prototype block ID")
        check(decoded.title == "Legacy Prototype", "expected legacy title to decode")
        check(decoded.columns == 4, "expected legacy columns to decode")
        check(decoded.rows == 3, "expected legacy rows to decode")
    } catch {
        fputs("FAIL: expected legacy JSON without ID to decode, got \(error)\n", stderr)
        Foundation.exit(1)
    }
}

private func testDeskBlocksStateRepresentsMultipleBlocksWithStableIDs() {
    let metrics = TileGridMetrics.prototype
    let state = DeskBlocksState(blocks: [
        DeskBlockState(
            id: DeskBlockID("block-a"),
            title: "Work",
            frame: BlockFrame(
                origin: BlockPoint(x: 10, y: 20),
                size: metrics.contentSize(columns: 2, rows: 2)
            ),
            columns: 2,
            rows: 2
        ),
        DeskBlockState(
            id: DeskBlockID("block-b"),
            title: "Personal",
            frame: BlockFrame(
                origin: BlockPoint(x: 300, y: 200),
                size: metrics.contentSize(columns: 3, rows: 1)
            ),
            columns: 3,
            rows: 1
        )
    ])

    check(state.blocks.count == 2, "expected two blocks")
    check(state.blocks[0].id == DeskBlockID("block-a"), "expected first stable ID")
    check(state.blocks[1].id == DeskBlockID("block-b"), "expected second stable ID")
}

private func testDeskBlocksStateSnapsEveryBlockAndPreservesIDs() {
    let metrics = TileGridMetrics.prototype
    let state = DeskBlocksState(blocks: [
        DeskBlockState(
            id: DeskBlockID("wide"),
            title: "Wide",
            frame: BlockFrame(
                origin: BlockPoint(x: 10, y: 20),
                size: BlockSize(width: 1000, height: metrics.contentSize(columns: 1, rows: 1).height)
            ),
            columns: 1,
            rows: 1
        ),
        DeskBlockState(
            id: DeskBlockID("small"),
            title: "Small",
            frame: BlockFrame(
                origin: BlockPoint(x: 30, y: 40),
                size: BlockSize(width: 1, height: 1)
            ),
            columns: 0,
            rows: 0
        )
    ])

    let snapped = state.snapped(metrics: metrics)

    check(snapped.blocks[0].id == DeskBlockID("wide"), "expected first ID to survive snapping")
    check(snapped.blocks[0].columns > 1, "expected first block to snap to multiple columns")
    check(snapped.blocks[1].id == DeskBlockID("small"), "expected second ID to survive snapping")
    check(snapped.blocks[1].columns == 1, "expected second block to normalize to minimum columns")
    check(snapped.blocks[1].rows == 1, "expected second block to normalize to minimum rows")
}

private func testDeskBlocksStateRoundTripsThroughJSON() {
    let state = DeskBlocksState(blocks: [
        DeskBlockState.prototypeDefault(),
        DeskBlockState(
            id: DeskBlockID("archive"),
            title: "Archive",
            frame: BlockFrame(
                origin: BlockPoint(x: 500, y: 120),
                size: TileGridMetrics.prototype.contentSize(columns: 2, rows: 4)
            ),
            columns: 2,
            rows: 4,
            tileReferences: [
                TileReference(id: "tile-archive", displayName: "Archive", folderReference: "bookmark-placeholder")
            ]
        )
    ])

    do {
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(DeskBlocksState.self, from: data)

        check(decoded == state, "expected multiple-block state to round-trip through JSON")
    } catch {
        fputs("FAIL: expected multiple-block JSON round-trip, got \(error)\n", stderr)
        Foundation.exit(1)
    }
}

private func testDeskBlocksStateAppendsAndUpdatesBlocksByID() {
    let metrics = TileGridMetrics.prototype
    let initialBlock = DeskBlockState.prototypeDefault()
    let addedBlock = DeskBlockState(
        id: DeskBlockID("added"),
        title: "Added",
        frame: BlockFrame(
            origin: BlockPoint(x: 520, y: 240),
            size: metrics.contentSize(columns: 2, rows: 2)
        ),
        columns: 2,
        rows: 2
    )
    let initialState = DeskBlocksState(blocks: [initialBlock])

    let appended = initialState.appending(block: addedBlock)
    let updatedBlock = addedBlock.snapped(
        metrics: metrics,
        origin: BlockPoint(x: 640, y: 260),
        proposedSize: metrics.contentSize(columns: 3, rows: 2)
    )
    let updated = appended.updating(block: updatedBlock)

    check(appended.blocks.count == 2, "expected appended state to contain two blocks")
    check(updated.blocks.count == 2, "expected update to preserve block count")
    check(updated.block(id: initialBlock.id) == initialBlock, "expected first block to remain unchanged")
    check(updated.block(id: addedBlock.id) == updatedBlock, "expected matching block to update by ID")
}

testPrototypeMetricsProduceInitialFourByThreeBlockSize()
testSnappingUpAddsAWholeColumn()
testSnappingDownRemovesOnlyAWholeColumn()
testSnappingEnforcesMinimumUsableSize()
testTileSizeRemainsUnchangedAcrossSnapping()
testDeskBlockStateKeepsFutureTileReferencesInTheModel()
testDeskBlockStateSnapsProposedSizeAndPreservesReferences()
testDeskBlockStateRoundTripsThroughJSON()
testDeskBlockStateDecodesLegacyJSONWithoutID()
testDeskBlocksStateRepresentsMultipleBlocksWithStableIDs()
testDeskBlocksStateSnapsEveryBlockAndPreservesIDs()
testDeskBlocksStateRoundTripsThroughJSON()
testDeskBlocksStateAppendsAndUpdatesBlocksByID()

print("DeskBlocksCoreChecks passed")
