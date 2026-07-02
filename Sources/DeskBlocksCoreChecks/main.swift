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

    check(size.width == 472, "expected initial width to be 472")
    check(size.height == 370, "expected initial height to be 370")
}

private func testSnappingUpAddsAWholeColumn() {
    let metrics = TileGridMetrics.prototype
    let fourColumnSize = metrics.contentSize(columns: 4, rows: 3)

    let snapped = metrics.snappedSize(
        for: BlockSize(width: fourColumnSize.width + 57, height: fourColumnSize.height)
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
        for: BlockSize(width: fourColumnSize.width - 57, height: fourColumnSize.height)
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

private func testTileCountLayoutUsesPerfectSquaresWhenPossible() {
    let metrics = TileGridMetrics.prototype

    check(metrics.gridLayout(containingTileCount: 9).columns == 3, "expected 9 tiles to use 3 columns")
    check(metrics.gridLayout(containingTileCount: 9).rows == 3, "expected 9 tiles to use 3 rows")
    check(metrics.gridLayout(containingTileCount: 16).columns == 4, "expected 16 tiles to use 4 columns")
    check(metrics.gridLayout(containingTileCount: 16).rows == 4, "expected 16 tiles to use 4 rows")
}

private func testTileCountLayoutAddsColumnsBeforeRowsForNonSquares() {
    let metrics = TileGridMetrics.prototype

    let fiveTiles = metrics.gridLayout(containingTileCount: 5)
    let tenTiles = metrics.gridLayout(containingTileCount: 10)
    let seventeenTiles = metrics.gridLayout(containingTileCount: 17)

    check(fiveTiles.columns == 3, "expected 5 tiles to start a third column")
    check(fiveTiles.rows == 2, "expected 5 tiles to fit in 2 rows")
    check(tenTiles.columns == 4, "expected 10 tiles to start a fourth column")
    check(tenTiles.rows == 3, "expected 10 tiles to fit in 3 rows")
    check(tenTiles.requestedTileCount == 10, "expected 10 requested tiles to be preserved")
    check(tenTiles.capacity == 12, "expected 10 requested tiles to use a 12-slot frame capacity")
    check(seventeenTiles.columns == 5, "expected 17 tiles to start a fifth column")
    check(seventeenTiles.rows == 4, "expected 17 tiles to fit in 4 rows")
}

private func testTileCountLayoutEnforcesMinimumOneTile() {
    let metrics = TileGridMetrics.prototype
    let layout = metrics.gridLayout(containingTileCount: 0)

    check(layout.requestedTileCount == 1, "expected non-positive tile count to normalize to 1")
    check(layout.columns == 1, "expected minimum layout to use 1 column")
    check(layout.rows == 1, "expected minimum layout to use 1 row")
}

private func testDeskBlockStateKeepsFutureTileReferencesInTheModel() {
    let state = DeskBlockState.prototypeDefault()

    check(state.id == .prototype, "expected prototype block ID")
    check(state.title == "DeskBlocks Prototype", "expected prototype title")
    check(state.columns == 4, "expected default columns")
    check(state.rows == 3, "expected default rows")
    check(state.tileCount == 12, "expected default tile count")
    check(state.visibleTileCount == 12, "expected default visible tile count")
    check(state.tileReferences.isEmpty, "expected empty tile references for current prototype")
}

private func testDeskBlockStateSeparatesRequestedTilesFromFrameCapacity() {
    let metrics = TileGridMetrics.prototype
    let layout = metrics.gridLayout(containingTileCount: 10)
    let state = DeskBlockState(
        title: "Ten Tiles",
        frame: BlockFrame(
            origin: BlockPoint(x: 10, y: 20),
            size: metrics.contentSize(columns: layout.columns, rows: layout.rows)
        ),
        columns: layout.columns,
        rows: layout.rows,
        tileCount: layout.requestedTileCount
    )

    check(state.columns == 4, "expected 10-tile block to use 4 columns")
    check(state.rows == 3, "expected 10-tile block to use 3 rows")
    check(state.tileCapacity == 12, "expected 10-tile block frame to have 12-slot capacity")
    check(state.tileCount == 10, "expected requested tile count to remain 10")
    check(state.visibleTileCount == 10, "expected renderer-visible tile count to remain 10")
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
        tileCount: 10,
        tileReferences: [
            TileReference(id: "tile-1", displayName: "Invoices", folderReference: "bookmark-placeholder")
        ]
    )

    let snapped = state.snapped(
        metrics: metrics,
        origin: BlockPoint(x: 30, y: 40),
        proposedSize: BlockSize(width: state.frame.size.width + 57, height: state.frame.size.height)
    )

    check(snapped.frame.origin == BlockPoint(x: 30, y: 40), "expected updated origin")
    check(snapped.id == state.id, "expected block ID to survive snapping")
    check(snapped.columns == 5, "expected snapped columns")
    check(snapped.rows == 3, "expected rows to remain unchanged")
    check(snapped.tileCount == 10, "expected requested tile count to survive snapping")
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
        check(decoded.tileCount == 12, "expected legacy state to default tile count from grid capacity")
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

private func testDeskBlocksStateRemovesBlocksByID() {
    let firstBlock = DeskBlockState.prototypeDefault()
    let secondBlock = DeskBlockState(
        id: DeskBlockID("second"),
        title: "Second",
        frame: BlockFrame(
            origin: BlockPoint(x: 520, y: 240),
            size: TileGridMetrics.prototype.contentSize(columns: 2, rows: 2)
        ),
        columns: 2,
        rows: 2,
        tileReferences: [
            TileReference(id: "tile-second", displayName: "Second Folder", folderReference: "bookmark-placeholder")
        ]
    )
    let state = DeskBlocksState(blocks: [firstBlock, secondBlock])

    let removed = state.removingBlock(id: firstBlock.id)

    check(removed.blocks.count == 1, "expected one block to remain after removal")
    check(removed.blocks[0] == secondBlock, "expected non-removed block to remain unchanged")
    check(removed.block(id: firstBlock.id) == nil, "expected removed block to be absent")
}

private func testDeskBlocksStateIgnoresRemovalOfUnknownBlockID() {
    let state = DeskBlocksState(blocks: [DeskBlockState.prototypeDefault()])

    let unchanged = state.removingBlock(id: DeskBlockID("missing"))

    check(unchanged == state, "expected removing an unknown block ID to leave state unchanged")
}

private func testDeskBlocksStateCanRemoveTheLastBlock() {
    let state = DeskBlocksState(blocks: [DeskBlockState.prototypeDefault()])

    let empty = state.removingBlock(id: .prototype)

    check(empty.blocks.isEmpty, "expected removing the last block to produce an empty state")
}

private func testDeskBlockStateRenamesWithTrimmedTitle() {
    let state = DeskBlockState.prototypeDefault()

    let renamed = state.renamed(to: "  Projects  ")

    check(renamed.title == "Projects", "expected title to be trimmed")
    check(renamed.id == state.id, "expected ID to survive title edit")
    check(renamed.frame == state.frame, "expected frame to survive title edit")
    check(renamed.columns == state.columns, "expected columns to survive title edit")
    check(renamed.rows == state.rows, "expected rows to survive title edit")
    check(renamed.tileReferences == state.tileReferences, "expected tile references to survive title edit")
}

private func testDeskBlockStateIgnoresEmptyRenamedTitle() {
    let state = DeskBlockState.prototypeDefault()

    let renamed = state.renamed(to: "   ")

    check(renamed == state, "expected empty title edit to keep existing state")
}

testPrototypeMetricsProduceInitialFourByThreeBlockSize()
testSnappingUpAddsAWholeColumn()
testSnappingDownRemovesOnlyAWholeColumn()
testSnappingEnforcesMinimumUsableSize()
testTileSizeRemainsUnchangedAcrossSnapping()
testTileCountLayoutUsesPerfectSquaresWhenPossible()
testTileCountLayoutAddsColumnsBeforeRowsForNonSquares()
testTileCountLayoutEnforcesMinimumOneTile()
testDeskBlockStateKeepsFutureTileReferencesInTheModel()
testDeskBlockStateSeparatesRequestedTilesFromFrameCapacity()
testDeskBlockStateSnapsProposedSizeAndPreservesReferences()
testDeskBlockStateRoundTripsThroughJSON()
testDeskBlockStateDecodesLegacyJSONWithoutID()
testDeskBlocksStateRepresentsMultipleBlocksWithStableIDs()
testDeskBlocksStateSnapsEveryBlockAndPreservesIDs()
testDeskBlocksStateRoundTripsThroughJSON()
testDeskBlocksStateAppendsAndUpdatesBlocksByID()
testDeskBlocksStateRemovesBlocksByID()
testDeskBlocksStateIgnoresRemovalOfUnknownBlockID()
testDeskBlocksStateCanRemoveTheLastBlock()
testDeskBlockStateRenamesWithTrimmedTitle()
testDeskBlockStateIgnoresEmptyRenamedTitle()

print("DeskBlocksCoreChecks passed")
