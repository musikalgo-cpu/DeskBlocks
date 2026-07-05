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
    check(size.height == 398, "expected initial height to include overflow indicator allowance")
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

private func testSnappingCanEnforceMinimumCapacityForTileCount() {
    let metrics = TileGridMetrics.prototype
    let proposedSize = metrics.contentSize(columns: 1, rows: 1)
    let snapped = metrics.snappedSize(for: proposedSize, containingAtLeastTileCount: 10)

    check(snapped.columns == 1, "expected proposed 1-column width to stay at 1 column")
    check(snapped.rows == 10, "expected 10 tiles in 1 column to require 10 rows")
    check(snapped.size == metrics.contentSize(columns: 1, rows: 10), "expected minimum size to fit 10 tiles")
}

private func testSnappingCanReduceRowsWhenProposedWidthFitsTiles() {
    let metrics = TileGridMetrics.prototype
    let proposedSize = metrics.contentSize(columns: 6, rows: 1)
    let snapped = metrics.snappedSize(for: proposedSize, containingAtLeastTileCount: 12)

    check(snapped.columns == 6, "expected proposed 6-column width to be preserved")
    check(snapped.rows == 2, "expected 12 tiles in 6 columns to require only 2 rows")
    check(snapped.size == metrics.contentSize(columns: 6, rows: 2), "expected empty third row to be removable")
}

private func testSnappingCanCapToMaximumContentSize() {
    let metrics = TileGridMetrics.prototype
    let maximumSize = metrics.contentSize(columns: 3, rows: 2)
    let proposedSize = metrics.contentSize(columns: 8, rows: 8)

    let snapped = metrics.snappedSize(
        for: proposedSize,
        containingAtLeastTileCount: 100,
        fittingWithin: maximumSize
    )

    check(snapped.columns == 3, "expected columns to cap at maximum content width")
    check(snapped.rows == 2, "expected rows to cap at maximum content height")
    check(snapped.size == maximumSize, "expected snapped size to stay within maximum content size")
}

private func testSnappingAllowsViewportSmallerThanTileCountWhenMaximumContentSizeExists() {
    let metrics = TileGridMetrics.prototype
    let maximumSize = metrics.contentSize(columns: 10, rows: 10)
    let proposedSize = metrics.contentSize(columns: 1, rows: 1)

    let snapped = metrics.snappedSize(
        for: proposedSize,
        containingAtLeastTileCount: 30,
        fittingWithin: maximumSize
    )

    check(snapped.columns == 1, "expected viewport width to follow proposed 1-column size")
    check(snapped.rows == 1, "expected viewport height to allow scrolling instead of forcing all rows visible")
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

private func testTileViewportRowAlignedScrollOffsetReachesPartialLastRow() {
    let viewport = TileViewport(tileCount: 23, columns: 5, rows: 4)

    check(viewport.capacity == 20, "expected viewport capacity")
    check(viewport.maximumRowAlignedScrollOffset == 5, "expected scroll offset to reach partial last row")
}

private func testTileViewportRowAlignedScrollOffsetIsZeroWhenAllTilesFit() {
    let viewport = TileViewport(tileCount: 11, columns: 10, rows: 2)

    check(viewport.capacity == 20, "expected viewport capacity to fit all tiles")
    check(viewport.maximumRowAlignedScrollOffset == 0, "expected no scroll offset when all tiles fit")
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

private func testDeskBlockStateSnappingDoesNotHideRequestedTiles() {
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

    let snapped = state.snapped(
        metrics: metrics,
        proposedSize: metrics.contentSize(columns: 1, rows: 1)
    )

    check(snapped.columns == 1, "expected proposed 1-column width to be preserved")
    check(snapped.rows == 10, "expected snapped block to grow rows enough for 10 tiles")
    check(snapped.tileCapacity >= snapped.tileCount, "expected snapped capacity to fit requested tiles")
    check(snapped.visibleTileCount == 10, "expected all requested tiles to remain visible after resize")
}

private func testDeskBlockStateAddsTileAndExpandsOnlyWhenNeeded() {
    let metrics = TileGridMetrics.prototype
    let state = DeskBlockState(
        title: "Twelve Tiles",
        frame: BlockFrame(
            origin: BlockPoint(x: 10, y: 20),
            size: metrics.contentSize(columns: 4, rows: 3)
        ),
        columns: 4,
        rows: 3,
        tileCount: 12
    )

    let expanded = state.addingTile(metrics: metrics)

    check(expanded.tileCount == 13, "expected add tile to increase tile count")
    check(expanded.columns == 4, "expected 13 tiles to keep 4 columns")
    check(expanded.rows == 4, "expected 13 tiles to expand to 4 rows")
    check(expanded.tileCapacity >= expanded.tileCount, "expected expanded block to fit added tile")
}

private func testDeskBlockStateRemovesTileWithoutDeletingLastTile() {
    let metrics = TileGridMetrics.prototype
    let state = DeskBlockState(
        title: "One Tile",
        frame: BlockFrame(
            origin: BlockPoint(x: 10, y: 20),
            size: metrics.contentSize(columns: 1, rows: 1)
        ),
        columns: 1,
        rows: 1,
        tileCount: 1
    )

    let removed = state.removingTile(metrics: metrics)

    check(removed.tileCount == 1, "expected remove tile to keep at least one tile")
    check(removed.visibleTileCount == 1, "expected last tile to remain visible")
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
            TileReference(
                id: "tile-1",
                tileIndex: 2,
                displayName: "Invoices",
                folderReference: FolderReference(
                    bookmarkDataBase64: "bookmark-placeholder",
                    lastKnownPath: "/Users/example/Desktop/Invoices"
                )
            )
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

private func testDeskBlockStatePlacesFolderReferenceAtTileIndex() {
    let state = DeskBlockState.prototypeDefault()
    let reference = TileReference(
        id: "tile-projects",
        tileIndex: 0,
        displayName: "Projects",
        folderReference: FolderReference(
            bookmarkDataBase64: "bookmark-projects",
            lastKnownPath: "/Users/example/Desktop/Projects"
        )
    )

    let updated = state.placingTileReference(reference, at: 5)

    check(updated.tileReference(at: 5)?.displayName == "Projects", "expected reference at requested tile index")
    check(updated.tileReference(at: 0) == nil, "expected original reference tile index to be replaced")
    check(updated.tileReferences.count == 1, "expected one stored tile reference")
}

private func testDeskBlockStateRejectsFolderReferenceOutsideVisibleTileCount() {
    let state = DeskBlockState.prototypeDefault()
    let reference = TileReference(
        id: "tile-projects",
        tileIndex: 0,
        displayName: "Projects",
        folderReference: FolderReference(
            bookmarkDataBase64: "bookmark-projects",
            lastKnownPath: "/Users/example/Desktop/Projects"
        )
    )

    let updated = state.placingTileReference(reference, at: state.tileCount)

    check(updated == state, "expected out-of-range tile placement to leave state unchanged")
}

private func testDeskBlockStateKeepsOnlyOneReferencePerTileIndex() {
    let state = DeskBlockState(
        title: "Work",
        frame: BlockFrame(
            origin: BlockPoint(x: 10, y: 20),
            size: TileGridMetrics.prototype.contentSize(columns: 2, rows: 2)
        ),
        columns: 2,
        rows: 2,
        tileReferences: [
            TileReference(
                id: "first",
                tileIndex: 1,
                displayName: "First",
                folderReference: FolderReference(bookmarkDataBase64: "first-bookmark", lastKnownPath: "/first")
            ),
            TileReference(
                id: "second",
                tileIndex: 1,
                displayName: "Second",
                folderReference: FolderReference(bookmarkDataBase64: "second-bookmark", lastKnownPath: "/second")
            )
        ]
    )

    check(state.tileReferences.count == 1, "expected duplicate tile references to normalize to one reference")
    check(state.tileReference(at: 1)?.id == "second", "expected later duplicate reference to win")
}

private func testDeskBlockStateDropsReferencesWhenTileIsRemoved() {
    let metrics = TileGridMetrics.prototype
    let state = DeskBlockState(
        title: "Two Tiles",
        frame: BlockFrame(
            origin: BlockPoint(x: 10, y: 20),
            size: metrics.contentSize(columns: 2, rows: 1)
        ),
        columns: 2,
        rows: 1,
        tileCount: 2,
        tileReferences: [
            TileReference(
                id: "last-tile",
                tileIndex: 1,
                displayName: "Last",
                folderReference: FolderReference(bookmarkDataBase64: "last-bookmark", lastKnownPath: "/last")
            )
        ]
    )

    let updated = state.removingTile(metrics: metrics)

    check(updated.tileCount == 1, "expected tile count to shrink")
    check(updated.tileReferences.isEmpty, "expected reference in removed tile slot to be dropped")
}

private func testDeskBlockStateRemovesFolderReferenceWithoutRemovingTile() {
    let state = DeskBlockState(
        title: "Work",
        frame: BlockFrame(
            origin: BlockPoint(x: 10, y: 20),
            size: TileGridMetrics.prototype.contentSize(columns: 2, rows: 2)
        ),
        columns: 2,
        rows: 2,
        tileReferences: [
            TileReference(
                id: "projects",
                tileIndex: 2,
                displayName: "Projects",
                folderReference: FolderReference(bookmarkDataBase64: "projects-bookmark", lastKnownPath: "/projects")
            )
        ]
    )

    let updated = state.removingTileReference(at: 2)

    check(updated.tileCount == state.tileCount, "expected removing reference to preserve tile count")
    check(updated.visibleTileCount == state.visibleTileCount, "expected removing reference to preserve visible tiles")
    check(updated.tileReferences.isEmpty, "expected reference to be removed")
}

private func testDeskBlockStateIgnoresRemovingMissingFolderReference() {
    let state = DeskBlockState.prototypeDefault()

    let updated = state.removingTileReference(at: 2)

    check(updated == state, "expected missing reference removal to leave state unchanged")
}

private func testDeskBlockStateRoundTripsThroughJSON() {
    let state = DeskBlockState.prototypeDefault().snapped(
        metrics: .prototype,
        origin: BlockPoint(x: 111, y: 222),
        proposedSize: BlockSize(width: 510, height: 410)
    ).withTitleColor(
        BlockColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
    )
    .withEmptyTilesHidden(true)
    .withLocked(true)

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
        check(decoded.titleColor == .white, "expected legacy title color to default to white")
        check(decoded.hidesEmptyTiles == false, "expected legacy empty tile visibility to default to showing empty tiles")
        check(decoded.isLocked == false, "expected legacy lock state to default to unlocked")
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

private func testDeskBlocksStateSnapsEveryBlockWithinMaximumViewport() {
    let metrics = TileGridMetrics.prototype
    let maximumSize = metrics.contentSize(columns: 2, rows: 2)
    let state = DeskBlocksState(blocks: [
        DeskBlockState(
            id: DeskBlockID("many"),
            title: "Many",
            frame: BlockFrame(
                origin: BlockPoint(x: 10, y: 20),
                size: metrics.contentSize(columns: 1, rows: 30)
            ),
            columns: 1,
            rows: 30,
            tileCount: 30
        )
    ])

    let snapped = state.snapped(metrics: metrics, fittingWithin: maximumSize)

    check(snapped.blocks[0].columns <= 2, "expected snapped block to fit maximum columns")
    check(snapped.blocks[0].rows <= 2, "expected snapped block to fit maximum rows")
    check(snapped.blocks[0].tileCount == 30, "expected requested tile count to survive viewport snapping")
}

private func testDeskBlockStateSnapsWithinMaximumViewport() {
    let metrics = TileGridMetrics.prototype
    let maximumSize = metrics.contentSize(columns: 2, rows: 2)
    let state = DeskBlockState(
        title: "Many",
        frame: BlockFrame(
            origin: BlockPoint(x: 10, y: 20),
            size: metrics.contentSize(columns: 1, rows: 30)
        ),
        columns: 1,
        rows: 30,
        tileCount: 30
    )

    let snapped = state.snapped(metrics: metrics, fittingWithin: maximumSize)

    check(snapped.columns <= 2, "expected block to fit maximum columns")
    check(snapped.rows <= 2, "expected block to fit maximum rows")
    check(snapped.tileCount == 30, "expected requested tile count to survive viewport snapping")
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
                TileReference(
                    id: "tile-archive",
                    tileIndex: 3,
                    displayName: "Archive",
                    folderReference: FolderReference(
                        bookmarkDataBase64: "bookmark-placeholder",
                        lastKnownPath: "/Users/example/Desktop/Archive"
                    )
                )
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
            TileReference(
                id: "tile-second",
                tileIndex: 0,
                displayName: "Second Folder",
                folderReference: FolderReference(
                    bookmarkDataBase64: "bookmark-placeholder",
                    lastKnownPath: "/Users/example/Desktop/Second Folder"
                )
            )
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
        .withTitleColor(BlockColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1))

    let renamed = state.renamed(to: "  Projects  ")

    check(renamed.title == "Projects", "expected title to be trimmed")
    check(renamed.id == state.id, "expected ID to survive title edit")
    check(renamed.titleColor == state.titleColor, "expected title color to survive title edit")
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

private func testDeskBlockStateUpdatesTitleColorWithoutChangingGeometryOrReferences() {
    let state = DeskBlockState(
        title: "Color Test",
        frame: BlockFrame(
            origin: BlockPoint(x: 90, y: 120),
            size: TileGridMetrics.prototype.contentSize(columns: 3, rows: 2)
        ),
        columns: 3,
        rows: 2,
        tileCount: 5,
        tileReferences: [
            TileReference(
                id: "tile-a",
                tileIndex: 1,
                displayName: "Folder A",
                folderReference: FolderReference(
                    bookmarkDataBase64: "bookmark-a",
                    lastKnownPath: "/tmp/a"
                )
            )
        ]
    )

    let updated = state.withTitleColor(BlockColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4))

    check(updated.titleColor == BlockColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4), "expected title color to update")
    check(updated.id == state.id, "expected ID to survive title color edit")
    check(updated.title == state.title, "expected title text to survive title color edit")
    check(updated.frame == state.frame, "expected frame to survive title color edit")
    check(updated.columns == state.columns, "expected columns to survive title color edit")
    check(updated.rows == state.rows, "expected rows to survive title color edit")
    check(updated.tileCount == state.tileCount, "expected tile count to survive title color edit")
    check(updated.tileReferences == state.tileReferences, "expected tile references to survive title color edit")
}

private func testDeskBlockStateTogglesEmptyTileVisibilityWithoutChangingGeometryOrReferences() {
    let state = DeskBlockState(
        title: "Visibility Test",
        titleColor: BlockColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 1),
        frame: BlockFrame(
            origin: BlockPoint(x: 90, y: 120),
            size: TileGridMetrics.prototype.contentSize(columns: 3, rows: 2)
        ),
        columns: 3,
        rows: 2,
        tileCount: 5,
        tileReferences: [
            TileReference(
                id: "tile-a",
                tileIndex: 1,
                displayName: "Folder A",
                folderReference: FolderReference(
                    bookmarkDataBase64: "bookmark-a",
                    lastKnownPath: "/tmp/a"
                )
            )
        ]
    )

    let updated = state.withEmptyTilesHidden(true)

    check(updated.hidesEmptyTiles, "expected empty tiles to become hidden")
    check(updated.id == state.id, "expected ID to survive empty tile visibility edit")
    check(updated.title == state.title, "expected title to survive empty tile visibility edit")
    check(updated.titleColor == state.titleColor, "expected title color to survive empty tile visibility edit")
    check(updated.frame == state.frame, "expected frame to survive empty tile visibility edit")
    check(updated.columns == state.columns, "expected columns to survive empty tile visibility edit")
    check(updated.rows == state.rows, "expected rows to survive empty tile visibility edit")
    check(updated.tileCount == state.tileCount, "expected tile count to survive empty tile visibility edit")
    check(updated.tileReferences == state.tileReferences, "expected tile references to survive empty tile visibility edit")
}

private func testDeskBlockStateTogglesLockWithoutChangingGeometryOrReferences() {
    let state = DeskBlockState(
        title: "Lock Test",
        titleColor: BlockColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 1),
        frame: BlockFrame(
            origin: BlockPoint(x: 90, y: 120),
            size: TileGridMetrics.prototype.contentSize(columns: 3, rows: 2)
        ),
        columns: 3,
        rows: 2,
        tileCount: 5,
        tileReferences: [
            TileReference(
                id: "tile-a",
                tileIndex: 1,
                displayName: "Folder A",
                folderReference: FolderReference(
                    bookmarkDataBase64: "bookmark-a",
                    lastKnownPath: "/tmp/a"
                )
            )
        ],
        hidesEmptyTiles: true
    )

    let updated = state.withLocked(true)

    check(updated.isLocked, "expected block to become locked")
    check(updated.id == state.id, "expected ID to survive lock edit")
    check(updated.title == state.title, "expected title to survive lock edit")
    check(updated.titleColor == state.titleColor, "expected title color to survive lock edit")
    check(updated.frame == state.frame, "expected frame to survive lock edit")
    check(updated.columns == state.columns, "expected columns to survive lock edit")
    check(updated.rows == state.rows, "expected rows to survive lock edit")
    check(updated.tileCount == state.tileCount, "expected tile count to survive lock edit")
    check(updated.tileReferences == state.tileReferences, "expected tile references to survive lock edit")
    check(updated.hidesEmptyTiles == state.hidesEmptyTiles, "expected empty tile visibility to survive lock edit")
}

private func testTileReferenceDecodesLegacyStringFolderReference() {
    let legacyJSON = """
    {
      "id": "legacy-tile",
      "displayName": "Legacy Folder",
      "folderReference": "legacy-bookmark"
    }
    """

    do {
        let decoded = try JSONDecoder().decode(TileReference.self, from: Data(legacyJSON.utf8))

        check(decoded.id == "legacy-tile", "expected legacy tile ID")
        check(decoded.tileIndex == 0, "expected legacy tile index to default to zero")
        check(decoded.folderReference.kind == .bookmark, "expected legacy reference to become a bookmark reference")
        check(decoded.folderReference.bookmarkDataBase64 == "legacy-bookmark", "expected legacy string to be preserved")
    } catch {
        fputs("FAIL: expected legacy tile reference to decode, got \(error)\n", stderr)
        Foundation.exit(1)
    }
}

testPrototypeMetricsProduceInitialFourByThreeBlockSize()
testSnappingUpAddsAWholeColumn()
testSnappingDownRemovesOnlyAWholeColumn()
testSnappingEnforcesMinimumUsableSize()
testSnappingCanEnforceMinimumCapacityForTileCount()
testSnappingCanReduceRowsWhenProposedWidthFitsTiles()
testSnappingCanCapToMaximumContentSize()
testSnappingAllowsViewportSmallerThanTileCountWhenMaximumContentSizeExists()
testTileSizeRemainsUnchangedAcrossSnapping()
testTileCountLayoutUsesPerfectSquaresWhenPossible()
testTileCountLayoutAddsColumnsBeforeRowsForNonSquares()
testTileCountLayoutEnforcesMinimumOneTile()
testTileViewportRowAlignedScrollOffsetReachesPartialLastRow()
testTileViewportRowAlignedScrollOffsetIsZeroWhenAllTilesFit()
testDeskBlockStateKeepsFutureTileReferencesInTheModel()
testDeskBlockStateSeparatesRequestedTilesFromFrameCapacity()
testDeskBlockStateSnappingDoesNotHideRequestedTiles()
testDeskBlockStateAddsTileAndExpandsOnlyWhenNeeded()
testDeskBlockStateRemovesTileWithoutDeletingLastTile()
testDeskBlockStateSnapsProposedSizeAndPreservesReferences()
testDeskBlockStatePlacesFolderReferenceAtTileIndex()
testDeskBlockStateRejectsFolderReferenceOutsideVisibleTileCount()
testDeskBlockStateKeepsOnlyOneReferencePerTileIndex()
testDeskBlockStateDropsReferencesWhenTileIsRemoved()
testDeskBlockStateRemovesFolderReferenceWithoutRemovingTile()
testDeskBlockStateIgnoresRemovingMissingFolderReference()
testDeskBlockStateRoundTripsThroughJSON()
testDeskBlockStateDecodesLegacyJSONWithoutID()
testDeskBlocksStateRepresentsMultipleBlocksWithStableIDs()
testDeskBlocksStateSnapsEveryBlockAndPreservesIDs()
testDeskBlocksStateSnapsEveryBlockWithinMaximumViewport()
testDeskBlockStateSnapsWithinMaximumViewport()
testDeskBlocksStateRoundTripsThroughJSON()
testDeskBlocksStateAppendsAndUpdatesBlocksByID()
testDeskBlocksStateRemovesBlocksByID()
testDeskBlocksStateIgnoresRemovalOfUnknownBlockID()
testDeskBlocksStateCanRemoveTheLastBlock()
testDeskBlockStateRenamesWithTrimmedTitle()
testDeskBlockStateIgnoresEmptyRenamedTitle()
testDeskBlockStateUpdatesTitleColorWithoutChangingGeometryOrReferences()
testDeskBlockStateTogglesEmptyTileVisibilityWithoutChangingGeometryOrReferences()
testDeskBlockStateTogglesLockWithoutChangingGeometryOrReferences()
testTileReferenceDecodesLegacyStringFolderReference()

print("DeskBlocksCoreChecks passed")
