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

public struct DeskBlockID: Codable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public static let prototype = DeskBlockID("prototype-block")

    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "DeskBlockID must not be empty")
        self.rawValue = rawValue
    }
}

public struct TileReference: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let folderReference: String

    public init(id: String, displayName: String, folderReference: String) {
        self.id = id
        self.displayName = displayName
        self.folderReference = folderReference
    }
}

public struct DeskBlockState: Codable, Equatable, Sendable {
    public let id: DeskBlockID
    public let title: String
    public let frame: BlockFrame
    public let columns: Int
    public let rows: Int
    public let tileCount: Int
    public let tileReferences: [TileReference]

    public var tileCapacity: Int {
        max(0, columns * rows)
    }

    public var visibleTileCount: Int {
        min(tileCount, tileCapacity)
    }

    public init(
        id: DeskBlockID = .prototype,
        title: String,
        frame: BlockFrame,
        columns: Int,
        rows: Int,
        tileCount: Int? = nil,
        tileReferences: [TileReference] = []
    ) {
        self.id = id
        self.title = title
        self.frame = frame
        self.columns = columns
        self.rows = rows
        self.tileCount = max(1, tileCount ?? max(1, columns * rows))
        self.tileReferences = tileReferences
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case frame
        case columns
        case rows
        case tileCount
        case tileReferences
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(DeskBlockID.self, forKey: .id) ?? .prototype
        title = try container.decode(String.self, forKey: .title)
        frame = try container.decode(BlockFrame.self, forKey: .frame)
        columns = try container.decode(Int.self, forKey: .columns)
        rows = try container.decode(Int.self, forKey: .rows)
        let decodedTileCount = try container.decodeIfPresent(Int.self, forKey: .tileCount)
        tileCount = max(1, decodedTileCount ?? max(1, columns * rows))
        tileReferences = try container.decodeIfPresent([TileReference].self, forKey: .tileReferences) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(frame, forKey: .frame)
        try container.encode(columns, forKey: .columns)
        try container.encode(rows, forKey: .rows)
        try container.encode(tileCount, forKey: .tileCount)
        try container.encode(tileReferences, forKey: .tileReferences)
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
            frame: BlockFrame(
                origin: origin,
                size: metrics.contentSize(columns: columns, rows: rows)
            ),
            columns: columns,
            rows: rows,
            tileCount: columns * rows,
            tileReferences: []
        )
    }

    public func snapped(
        metrics: TileGridMetrics,
        origin: BlockPoint? = nil,
        proposedSize: BlockSize? = nil
    ) -> DeskBlockState {
        let snapped = metrics.snappedSize(for: proposedSize ?? frame.size)

        return DeskBlockState(
            id: id,
            title: title,
            frame: BlockFrame(
                origin: origin ?? frame.origin,
                size: snapped.size
            ),
            columns: snapped.columns,
            rows: snapped.rows,
            tileCount: tileCount,
            tileReferences: tileReferences
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
            frame: frame,
            columns: columns,
            rows: rows,
            tileCount: tileCount,
            tileReferences: tileReferences
        )
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

    public func snapped(metrics: TileGridMetrics) -> DeskBlocksState {
        DeskBlocksState(blocks: blocks.map { block in
            block.snapped(metrics: metrics)
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

public struct TileGridMetrics: Equatable, Sendable {
    public let tileWidth: Double
    public let tileHeight: Double
    public let titleHeight: Double
    public let padding: Double
    public let minimumColumns: Int
    public let minimumRows: Int

    public static let prototype = TileGridMetrics(
        tileWidth: 112,
        tileHeight: 104,
        titleHeight: 34,
        padding: 12,
        minimumColumns: 1,
        minimumRows: 1
    )

    public init(
        tileWidth: Double,
        tileHeight: Double,
        titleHeight: Double,
        padding: Double,
        minimumColumns: Int,
        minimumRows: Int
    ) {
        precondition(tileWidth > 0, "tileWidth must be positive")
        precondition(tileHeight > 0, "tileHeight must be positive")
        precondition(titleHeight >= 0, "titleHeight must not be negative")
        precondition(padding >= 0, "padding must not be negative")
        precondition(minimumColumns > 0, "minimumColumns must be positive")
        precondition(minimumRows > 0, "minimumRows must be positive")

        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.titleHeight = titleHeight
        self.padding = padding
        self.minimumColumns = minimumColumns
        self.minimumRows = minimumRows
    }

    public func contentSize(columns: Int, rows: Int) -> BlockSize {
        let safeColumns = max(minimumColumns, columns)
        let safeRows = max(minimumRows, rows)

        return BlockSize(
            width: padding * 2 + Double(safeColumns) * tileWidth,
            height: padding * 2 + titleHeight + Double(safeRows) * tileHeight
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
            fixedAllowance: padding * 2 + titleHeight,
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
}
