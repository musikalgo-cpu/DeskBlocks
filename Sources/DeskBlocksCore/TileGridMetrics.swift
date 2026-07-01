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
    public let title: String
    public let frame: BlockFrame
    public let columns: Int
    public let rows: Int
    public let tileReferences: [TileReference]

    public init(
        title: String,
        frame: BlockFrame,
        columns: Int,
        rows: Int,
        tileReferences: [TileReference] = []
    ) {
        self.title = title
        self.frame = frame
        self.columns = columns
        self.rows = rows
        self.tileReferences = tileReferences
    }

    public static func prototypeDefault(
        metrics: TileGridMetrics = .prototype,
        origin: BlockPoint = BlockPoint(x: 240, y: 240)
    ) -> DeskBlockState {
        let columns = 4
        let rows = 3

        return DeskBlockState(
            title: "DeskBlocks Prototype",
            frame: BlockFrame(
                origin: origin,
                size: metrics.contentSize(columns: columns, rows: rows)
            ),
            columns: columns,
            rows: rows,
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
            title: title,
            frame: BlockFrame(
                origin: origin ?? frame.origin,
                size: snapped.size
            ),
            columns: snapped.columns,
            rows: snapped.rows,
            tileReferences: tileReferences
        )
    }
}

public struct SnappedBlockSize: Equatable, Sendable {
    public let size: BlockSize
    public let columns: Int
    public let rows: Int
    public let tileWidth: Double
    public let tileHeight: Double
}

public struct TileGridMetrics: Equatable, Sendable {
    public let tileWidth: Double
    public let tileHeight: Double
    public let titleHeight: Double
    public let padding: Double
    public let minimumColumns: Int
    public let minimumRows: Int

    public static let prototype = TileGridMetrics(
        tileWidth: 96,
        tileHeight: 88,
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
