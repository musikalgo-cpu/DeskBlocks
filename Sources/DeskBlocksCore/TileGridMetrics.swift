import Foundation

public struct BlockPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct BlockSize: Codable, Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct BlockFrame: Codable, Equatable, Sendable {
    public let origin: BlockPoint
    public let size: BlockSize

    public init(origin: BlockPoint, size: BlockSize) {
        self.origin = origin
        self.size = size
    }
}

public struct BlockColor: Codable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public static let white = BlockColor(red: 1, green: 1, blue: 1, alpha: 1)

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.clamped(red)
        self.green = Self.clamped(green)
        self.blue = Self.clamped(blue)
        self.alpha = Self.clamped(alpha)
    }

    private static func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

public struct DeskBlockID: Codable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public static let prototype = DeskBlockID("prototype-block")

    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "DeskBlockID must not be empty")
        self.rawValue = rawValue
    }
}

public enum FolderReferenceKind: String, Codable, Equatable, Sendable {
    case bookmark
}

public struct FolderReference: Codable, Equatable, Sendable {
    public let kind: FolderReferenceKind
    public let bookmarkDataBase64: String
    public let lastKnownPath: String

    public init(
        kind: FolderReferenceKind = .bookmark,
        bookmarkDataBase64: String,
        lastKnownPath: String
    ) {
        self.kind = kind
        self.bookmarkDataBase64 = bookmarkDataBase64
        self.lastKnownPath = lastKnownPath
    }
}

public struct TileReference: Codable, Equatable, Sendable {
    public let id: String
    public let tileIndex: Int
    public let displayName: String
    public let folderReference: FolderReference
    public let note: String?

    public init(
        id: String,
        tileIndex: Int,
        displayName: String,
        folderReference: FolderReference,
        note: String? = nil
    ) {
        self.id = id
        self.tileIndex = tileIndex
        self.displayName = displayName
        self.folderReference = folderReference
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case tileIndex
        case displayName
        case folderReference
        case note
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        tileIndex = try container.decodeIfPresent(Int.self, forKey: .tileIndex) ?? 0
        displayName = try container.decode(String.self, forKey: .displayName)

        if let decodedReference = try? container.decode(FolderReference.self, forKey: .folderReference) {
            folderReference = decodedReference
        } else {
            let legacyReference = try container.decode(String.self, forKey: .folderReference)
            folderReference = FolderReference(
                bookmarkDataBase64: legacyReference,
                lastKnownPath: ""
            )
        }
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    public func placed(at newTileIndex: Int) -> TileReference {
        TileReference(
            id: id,
            tileIndex: newTileIndex,
            displayName: displayName,
            folderReference: folderReference,
            note: note
        )
    }

    public func withNote(_ proposedNote: String?) -> TileReference {
        let normalizedNote = proposedNote?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        return TileReference(
            id: id,
            tileIndex: tileIndex,
            displayName: displayName,
            folderReference: folderReference,
            note: normalizedNote
        )
    }
}

public struct DeskBlockState: Codable, Equatable, Sendable {
    public let id: DeskBlockID
    public let title: String
    public let titleColor: BlockColor
    public let frame: BlockFrame
    public let columns: Int
    public let rows: Int
    public let tileCount: Int
    public let tileReferences: [TileReference]
    public let hidesEmptyTiles: Bool
    public let isLocked: Bool

    public var tileCapacity: Int {
        max(0, columns * rows)
    }

    public var visibleTileCount: Int {
        min(tileCount, tileCapacity)
    }

    public init(
        id: DeskBlockID = .prototype,
        title: String,
        titleColor: BlockColor = .white,
        frame: BlockFrame,
        columns: Int,
        rows: Int,
        tileCount: Int? = nil,
        tileReferences: [TileReference] = [],
        hidesEmptyTiles: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.titleColor = titleColor
        self.frame = frame
        self.columns = columns
        self.rows = rows
        let safeTileCount = max(1, tileCount ?? max(1, columns * rows))

        self.tileCount = safeTileCount
        self.tileReferences = Self.normalizedTileReferences(tileReferences, tileCount: safeTileCount)
        self.hidesEmptyTiles = hidesEmptyTiles
        self.isLocked = isLocked
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case titleColor
        case frame
        case columns
        case rows
        case tileCount
        case tileReferences
        case hidesEmptyTiles
        case isLocked
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(DeskBlockID.self, forKey: .id) ?? .prototype
        title = try container.decode(String.self, forKey: .title)
        titleColor = try container.decodeIfPresent(BlockColor.self, forKey: .titleColor) ?? .white
        frame = try container.decode(BlockFrame.self, forKey: .frame)
        columns = try container.decode(Int.self, forKey: .columns)
        rows = try container.decode(Int.self, forKey: .rows)
        let decodedTileCount = try container.decodeIfPresent(Int.self, forKey: .tileCount)
        tileCount = max(1, decodedTileCount ?? max(1, columns * rows))
        let decodedReferences = try container.decodeIfPresent([TileReference].self, forKey: .tileReferences) ?? []
        tileReferences = Self.normalizedTileReferences(decodedReferences, tileCount: tileCount)
        hidesEmptyTiles = try container.decodeIfPresent(Bool.self, forKey: .hidesEmptyTiles) ?? false
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(titleColor, forKey: .titleColor)
        try container.encode(frame, forKey: .frame)
        try container.encode(columns, forKey: .columns)
        try container.encode(rows, forKey: .rows)
        try container.encode(tileCount, forKey: .tileCount)
        try container.encode(tileReferences, forKey: .tileReferences)
        try container.encode(hidesEmptyTiles, forKey: .hidesEmptyTiles)
        try container.encode(isLocked, forKey: .isLocked)
    }

    public static func prototypeDefault(
        metrics: TileGridMetrics = .prototype,
        origin: BlockPoint = BlockPoint(x: 240, y: 240)
    ) -> DeskBlockState {
        let columns = 4
        let rows = 3

        return DeskBlockState(
            id: .prototype,
            title: "DeskBlocks Prototype",
            titleColor: .white,
            frame: BlockFrame(
                origin: origin,
                size: metrics.contentSize(columns: columns, rows: rows)
            ),
            columns: columns,
            rows: rows,
            tileCount: columns * rows,
            tileReferences: [],
            hidesEmptyTiles: false,
            isLocked: false
        )
    }

    public func snapped(
        metrics: TileGridMetrics,
        origin: BlockPoint? = nil,
        proposedSize: BlockSize? = nil,
        fittingWithin maximumSize: BlockSize? = nil
    ) -> DeskBlockState {
        let snapped = metrics.snappedSize(
            for: proposedSize ?? frame.size,
            containingAtLeastTileCount: tileCount,
            fittingWithin: maximumSize
        )

        return DeskBlockState(
            id: id,
            title: title,
            titleColor: titleColor,
            frame: BlockFrame(
                origin: origin ?? frame.origin,
                size: snapped.size
            ),
            columns: snapped.columns,
            rows: snapped.rows,
            tileCount: tileCount,
            tileReferences: tileReferences,
            hidesEmptyTiles: hidesEmptyTiles,
            isLocked: isLocked
        )
    }

    public func addingTile(metrics: TileGridMetrics) -> DeskBlockState {
        withTileCount(tileCount + 1, metrics: metrics)
    }

    public func removingTile(metrics: TileGridMetrics) -> DeskBlockState {
        withTileCount(max(1, tileCount - 1), metrics: metrics)
    }

    public func tileReference(at tileIndex: Int) -> TileReference? {
        tileReferences.first { reference in
            reference.tileIndex == tileIndex
        }
    }

    public func placingTileReference(_ tileReference: TileReference, at tileIndex: Int) -> DeskBlockState {
        guard tileIndex >= 0, tileIndex < tileCount else {
            return self
        }

        let placedReference = tileReference.placed(at: tileIndex)
        let nextReferences = tileReferences.filter { reference in
            reference.tileIndex != tileIndex && reference.id != placedReference.id
        } + [placedReference]

        return DeskBlockState(
            id: id,
            title: title,
            titleColor: titleColor,
            frame: frame,
            columns: columns,
            rows: rows,
            tileCount: tileCount,
            tileReferences: nextReferences,
            hidesEmptyTiles: hidesEmptyTiles,
            isLocked: isLocked
        )
    }

    public func removingTileReference(at tileIndex: Int) -> DeskBlockState {
        guard tileReference(at: tileIndex) != nil else {
            return self
        }

        return DeskBlockState(
            id: id,
            title: title,
            titleColor: titleColor,
            frame: frame,
            columns: columns,
            rows: rows,
            tileCount: tileCount,
            tileReferences: tileReferences.filter { reference in
                reference.tileIndex != tileIndex
            },
            hidesEmptyTiles: hidesEmptyTiles,
            isLocked: isLocked
        )
    }

    public func movingTileReference(from sourceTileIndex: Int, to destinationTileIndex: Int) -> DeskBlockState {
        guard
            sourceTileIndex != destinationTileIndex,
            sourceTileIndex >= 0,
            sourceTileIndex < tileCount,
            destinationTileIndex >= 0,
            destinationTileIndex < tileCount,
            let sourceReference = tileReference(at: sourceTileIndex)
        else {
            return self
        }

        let destinationReference = tileReference(at: destinationTileIndex)
        let nextReferences = tileReferences.map { reference in
            if reference.id == sourceReference.id {
                return reference.placed(at: destinationTileIndex)
            }

            if let destinationReference, reference.id == destinationReference.id {
                return reference.placed(at: sourceTileIndex)
            }

            return reference
        }

        return DeskBlockState(
            id: id,
            title: title,
            titleColor: titleColor,
            frame: frame,
            columns: columns,
            rows: rows,
            tileCount: tileCount,
            tileReferences: nextReferences,
            hidesEmptyTiles: hidesEmptyTiles,
            isLocked: isLocked
        )
    }

    public func updatingTileReferenceNote(_ note: String?, at tileIndex: Int) -> DeskBlockState {
        guard let reference = tileReference(at: tileIndex) else {
            return self
        }

        return placingTileReference(reference.withNote(note), at: tileIndex)
    }

    private func withTileCount(_ newTileCount: Int, metrics: TileGridMetrics) -> DeskBlockState {
        let safeTileCount = max(1, newTileCount)
        let currentCapacity = max(1, columns * rows)
        let layout = metrics.gridLayout(containingTileCount: safeTileCount)
        let nextColumns = currentCapacity >= safeTileCount ? columns : layout.columns
        let nextRows = currentCapacity >= safeTileCount ? rows : layout.rows

        return DeskBlockState(
            id: id,
            title: title,
            titleColor: titleColor,
            frame: BlockFrame(
                origin: frame.origin,
                size: metrics.contentSize(columns: nextColumns, rows: nextRows)
            ),
            columns: nextColumns,
            rows: nextRows,
            tileCount: safeTileCount,
            tileReferences: tileReferences,
            hidesEmptyTiles: hidesEmptyTiles,
            isLocked: isLocked
        )
    }

    public func renamed(to proposedTitle: String) -> DeskBlockState {
        let trimmedTitle = proposedTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            return self
        }

        return DeskBlockState(
            id: id,
            title: trimmedTitle,
            titleColor: titleColor,
            frame: frame,
            columns: columns,
            rows: rows,
            tileCount: tileCount,
            tileReferences: tileReferences,
            hidesEmptyTiles: hidesEmptyTiles,
            isLocked: isLocked
        )
    }

    public func withTitleColor(_ proposedTitleColor: BlockColor) -> DeskBlockState {
        guard proposedTitleColor != titleColor else {
            return self
        }

        return DeskBlockState(
            id: id,
            title: title,
            titleColor: proposedTitleColor,
            frame: frame,
            columns: columns,
            rows: rows,
            tileCount: tileCount,
            tileReferences: tileReferences,
            hidesEmptyTiles: hidesEmptyTiles,
            isLocked: isLocked
        )
    }

    public func withEmptyTilesHidden(_ shouldHideEmptyTiles: Bool) -> DeskBlockState {
        guard shouldHideEmptyTiles != hidesEmptyTiles else {
            return self
        }

        return DeskBlockState(
            id: id,
            title: title,
            titleColor: titleColor,
            frame: frame,
            columns: columns,
            rows: rows,
            tileCount: tileCount,
            tileReferences: tileReferences,
            hidesEmptyTiles: shouldHideEmptyTiles,
            isLocked: isLocked
        )
    }

    public func withLocked(_ shouldLock: Bool) -> DeskBlockState {
        guard shouldLock != isLocked else {
            return self
        }

        return DeskBlockState(
            id: id,
            title: title,
            titleColor: titleColor,
            frame: frame,
            columns: columns,
            rows: rows,
            tileCount: tileCount,
            tileReferences: tileReferences,
            hidesEmptyTiles: hidesEmptyTiles,
            isLocked: shouldLock
        )
    }

    private static func normalizedTileReferences(
        _ tileReferences: [TileReference],
        tileCount: Int
    ) -> [TileReference] {
        var seenTileIndexes = Set<Int>()
        var acceptedReferences: [TileReference] = []

        for reference in tileReferences.reversed() {
            guard reference.tileIndex >= 0, reference.tileIndex < tileCount else {
                continue
            }

            guard !seenTileIndexes.contains(reference.tileIndex) else {
                continue
            }

            seenTileIndexes.insert(reference.tileIndex)
            acceptedReferences.append(reference)
        }

        return acceptedReferences
            .reversed()
            .sorted { first, second in
                first.tileIndex < second.tileIndex
            }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

public struct DeskBlocksState: Codable, Equatable, Sendable {
    public let blocks: [DeskBlockState]

    public init(blocks: [DeskBlockState]) {
        let blockIDs = Set(blocks.map(\.id))
        precondition(blockIDs.count == blocks.count, "DeskBlocksState block IDs must be unique")

        self.blocks = blocks
    }

    public static func prototypeDefault(
        metrics: TileGridMetrics = .prototype,
        origin: BlockPoint = BlockPoint(x: 240, y: 240)
    ) -> DeskBlocksState {
        DeskBlocksState(blocks: [
            DeskBlockState.prototypeDefault(metrics: metrics, origin: origin)
        ])
    }

    public func snapped(
        metrics: TileGridMetrics,
        fittingWithin maximumSize: BlockSize? = nil
    ) -> DeskBlocksState {
        DeskBlocksState(blocks: blocks.map { block in
            block.snapped(metrics: metrics, fittingWithin: maximumSize)
        })
    }

    public func block(id: DeskBlockID) -> DeskBlockState? {
        blocks.first { $0.id == id }
    }

    public func appending(block: DeskBlockState) -> DeskBlocksState {
        DeskBlocksState(blocks: blocks + [block])
    }

    public func updating(block updatedBlock: DeskBlockState) -> DeskBlocksState {
        var didUpdate = false
        let updatedBlocks = blocks.map { block in
            guard block.id == updatedBlock.id else {
                return block
            }

            didUpdate = true
            return updatedBlock
        }

        guard didUpdate else {
            return self
        }

        return DeskBlocksState(blocks: updatedBlocks)
    }

    public func removingBlock(id blockID: DeskBlockID) -> DeskBlocksState {
        let remainingBlocks = blocks.filter { block in
            block.id != blockID
        }

        guard remainingBlocks.count != blocks.count else {
            return self
        }

        return DeskBlocksState(blocks: remainingBlocks)
    }
}

public struct SnappedBlockSize: Equatable, Sendable {
    public let size: BlockSize
    public let columns: Int
    public let rows: Int
    public let tileWidth: Double
    public let tileHeight: Double
}

public struct TileGridLayout: Equatable, Sendable {
    public let requestedTileCount: Int
    public let columns: Int
    public let rows: Int

    public var capacity: Int {
        columns * rows
    }
}

public struct TileViewport: Equatable, Sendable {
    public let tileCount: Int
    public let columns: Int
    public let rows: Int

    public init(tileCount: Int, columns: Int, rows: Int) {
        self.tileCount = max(1, tileCount)
        self.columns = max(1, columns)
        self.rows = max(1, rows)
    }

    public var capacity: Int {
        columns * rows
    }

    public var maximumRowAlignedScrollOffset: Int {
        let lastTileRow = (tileCount - 1) / columns
        let maximumFirstVisibleRow = max(0, lastTileRow - rows + 1)

        return maximumFirstVisibleRow * columns
    }
}

public struct TileGridMetrics: Equatable, Sendable {
    public let tileWidth: Double
    public let tileHeight: Double
    public let titleHeight: Double
    public let padding: Double
    public let verticalOverflowIndicatorAllowance: Double
    public let minimumColumns: Int
    public let minimumRows: Int

    public static let prototype = TileGridMetrics(
        tileWidth: 112,
        tileHeight: 104,
        titleHeight: 34,
        padding: 12,
        verticalOverflowIndicatorAllowance: 28,
        minimumColumns: 1,
        minimumRows: 1
    )

    public init(
        tileWidth: Double,
        tileHeight: Double,
        titleHeight: Double,
        padding: Double,
        verticalOverflowIndicatorAllowance: Double,
        minimumColumns: Int,
        minimumRows: Int
    ) {
        precondition(tileWidth > 0, "tileWidth must be positive")
        precondition(tileHeight > 0, "tileHeight must be positive")
        precondition(titleHeight >= 0, "titleHeight must not be negative")
        precondition(padding >= 0, "padding must not be negative")
        precondition(verticalOverflowIndicatorAllowance >= 0, "verticalOverflowIndicatorAllowance must not be negative")
        precondition(minimumColumns > 0, "minimumColumns must be positive")
        precondition(minimumRows > 0, "minimumRows must be positive")

        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.titleHeight = titleHeight
        self.padding = padding
        self.verticalOverflowIndicatorAllowance = verticalOverflowIndicatorAllowance
        self.minimumColumns = minimumColumns
        self.minimumRows = minimumRows
    }

    public func contentSize(columns: Int, rows: Int) -> BlockSize {
        let safeColumns = max(minimumColumns, columns)
        let safeRows = max(minimumRows, rows)

        return BlockSize(
            width: padding * 2 + Double(safeColumns) * tileWidth,
            height: padding * 2 + titleHeight + verticalOverflowIndicatorAllowance + Double(safeRows) * tileHeight
        )
    }

    public func gridLayout(containingTileCount tileCount: Int) -> TileGridLayout {
        let safeTileCount = max(1, tileCount)
        let columns = max(minimumColumns, Int(ceil(sqrt(Double(safeTileCount)))))
        let rows = max(minimumRows, Int(ceil(Double(safeTileCount) / Double(columns))))

        return TileGridLayout(
            requestedTileCount: safeTileCount,
            columns: columns,
            rows: rows
        )
    }

    public func snappedSize(for proposedSize: BlockSize) -> SnappedBlockSize {
        let columns = wholeTileCount(
            proposedLength: proposedSize.width,
            fixedAllowance: padding * 2,
            tileLength: tileWidth,
            minimumCount: minimumColumns
        )
        let rows = wholeTileCount(
            proposedLength: proposedSize.height,
            fixedAllowance: padding * 2 + titleHeight + verticalOverflowIndicatorAllowance,
            tileLength: tileHeight,
            minimumCount: minimumRows
        )

        return SnappedBlockSize(
            size: contentSize(columns: columns, rows: rows),
            columns: columns,
            rows: rows,
            tileWidth: tileWidth,
            tileHeight: tileHeight
        )
    }

    public func snappedSize(
        for proposedSize: BlockSize,
        containingAtLeastTileCount tileCount: Int
    ) -> SnappedBlockSize {
        snappedSize(for: proposedSize, containingAtLeastTileCount: tileCount, fittingWithin: nil)
    }

    public func snappedSize(
        for proposedSize: BlockSize,
        containingAtLeastTileCount tileCount: Int,
        fittingWithin maximumSize: BlockSize?
    ) -> SnappedBlockSize {
        let snapped = snappedSize(for: proposedSize)
        let safeTileCount = max(1, tileCount)
        let maximumColumns = maximumSize.map { maximumSize in
            maximumWholeTileCount(
                proposedLength: maximumSize.width,
                fixedAllowance: padding * 2,
                tileLength: tileWidth,
                minimumCount: minimumColumns
            )
        } ?? Int.max
        let maximumRows = maximumSize.map { maximumSize in
            maximumWholeTileCount(
                proposedLength: maximumSize.height,
                fixedAllowance: padding * 2 + titleHeight + verticalOverflowIndicatorAllowance,
                tileLength: tileHeight,
                minimumCount: minimumRows
            )
        } ?? Int.max
        let columns = min(max(snapped.columns, minimumColumns), maximumColumns)
        let rows = maximumSize == nil
            ? max(
                snapped.rows,
                minimumRows,
                Int(ceil(Double(safeTileCount) / Double(columns)))
            )
            : max(snapped.rows, minimumRows)
        let cappedRows = min(rows, maximumRows)

        return SnappedBlockSize(
            size: contentSize(columns: columns, rows: cappedRows),
            columns: columns,
            rows: cappedRows,
            tileWidth: tileWidth,
            tileHeight: tileHeight
        )
    }

    private func wholeTileCount(
        proposedLength: Double,
        fixedAllowance: Double,
        tileLength: Double,
        minimumCount: Int
    ) -> Int {
        let usableLength = max(0, proposedLength - fixedAllowance)
        let proposedCount = Int((usableLength / tileLength).rounded(.toNearestOrAwayFromZero))

        return max(minimumCount, proposedCount)
    }

    private func maximumWholeTileCount(
        proposedLength: Double,
        fixedAllowance: Double,
        tileLength: Double,
        minimumCount: Int
    ) -> Int {
        let usableLength = max(0, proposedLength - fixedAllowance)
        let proposedCount = Int((usableLength / tileLength).rounded(.down))

        return max(minimumCount, proposedCount)
    }
}
