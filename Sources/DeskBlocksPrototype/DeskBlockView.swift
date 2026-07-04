import AppKit
import DeskBlocksCore
import UniformTypeIdentifiers

final class DeskBlockView: NSView {
    var state: DeskBlockState {
        didSet {
            clampTileScrollOffset()
            needsDisplay = true
        }
    }
    var requestRename: ((DeskBlockID) -> Void)?
    var requestRemove: ((DeskBlockID) -> Void)?
    var requestAddTile: ((DeskBlockID) -> Void)?
    var requestDeleteTile: ((DeskBlockID) -> Void)?
    var requestChooseFolder: ((DeskBlockID, Int) -> Void)?
    var requestPlaceFolder: ((DeskBlockID, Int, URL) -> Void)?
    var requestOpenFolder: ((DeskBlockID, Int) -> Void)?
    var requestRemoveFolderReference: ((DeskBlockID, Int) -> Void)?

    private var magneticTargetTileIndex: Int? {
        didSet {
            if magneticTargetTileIndex != oldValue {
                needsDisplay = true
            }
        }
    }
    private let magneticTargetMargin: CGFloat = 18
    private var tileScrollOffset = 0 {
        didSet {
            if tileScrollOffset != oldValue {
                magneticTargetTileIndex = nil
                needsDisplay = true
            }
        }
    }

    private var titleRect: NSRect {
        NSRect(
            x: PrototypeGeometry.padding,
            y: PrototypeGeometry.padding,
            width: bounds.width - PrototypeGeometry.padding * 2,
            height: PrototypeGeometry.titleHeight
        )
    }

    init(state: DeskBlockState) {
        self.state = state
        super.init(frame: NSRect(origin: .zero, size: state.frame.size.nsSize))
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let eventLocation = convert(event.locationInWindow, from: nil)

        if event.clickCount == 2, titleRect.contains(eventLocation) {
            requestRename?(state.id)
            return
        }

        if event.clickCount == 2, let tileIndex = tileIndex(at: eventLocation), state.tileReference(at: tileIndex) != nil {
            requestOpenFolder?(state.id, tileIndex)
            return
        }

        super.mouseDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard maxTileScrollOffset > 0 else {
            super.scrollWheel(with: event)
            return
        }

        let horizontalIntent = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
        let step = horizontalIntent ? 1 : max(1, state.columns)
        let delta = horizontalIntent ? event.scrollingDeltaX : -event.scrollingDeltaY

        guard delta != 0 else {
            super.scrollWheel(with: event)
            return
        }

        scrollTiles(by: delta > 0 ? step : -step, alignToRows: !horizontalIntent)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard folderURL(from: sender.draggingPasteboard) != nil else {
            return []
        }

        return updateMagneticTarget(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard folderURL(from: sender.draggingPasteboard) != nil else {
            return []
        }

        return updateMagneticTarget(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        magneticTargetTileIndex = nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let eventLocation = convert(sender.draggingLocation, from: nil)

        guard
            let tileIndex = magneticTileIndex(at: eventLocation),
            let folderURL = folderURL(from: sender.draggingPasteboard)
        else {
            magneticTargetTileIndex = nil
            return false
        }

        requestPlaceFolder?(state.id, tileIndex, folderURL)
        magneticTargetTileIndex = nil
        return true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let eventLocation = convert(event.locationInWindow, from: nil)
        let clickedTileIndex = tileIndex(at: eventLocation)
        let clickedTileReference = clickedTileIndex.flatMap { state.tileReference(at: $0) }
        let renameItem = NSMenuItem(
            title: "Rename Block...",
            action: #selector(renameFromContextMenu(_:)),
            keyEquivalent: ""
        )
        let chooseFolderItem = NSMenuItem(
            title: clickedTileReference == nil ? "Choose Folder..." : "Replace Folder...",
            action: #selector(chooseFolderFromContextMenu(_:)),
            keyEquivalent: ""
        )
        let openFolderItem = NSMenuItem(
            title: "Open Folder",
            action: #selector(openFolderFromContextMenu(_:)),
            keyEquivalent: ""
        )
        let removeFolderReferenceItem = NSMenuItem(
            title: "Remove Folder Reference",
            action: #selector(removeFolderReferenceFromContextMenu(_:)),
            keyEquivalent: ""
        )
        let addTileItem = NSMenuItem(
            title: "Add Tile",
            action: #selector(addTileFromContextMenu(_:)),
            keyEquivalent: ""
        )
        let deleteTileItem = NSMenuItem(
            title: "Delete Tile",
            action: #selector(deleteTileFromContextMenu(_:)),
            keyEquivalent: ""
        )
        let removeItem = NSMenuItem(
            title: "Remove Block...",
            action: #selector(removeFromContextMenu(_:)),
            keyEquivalent: ""
        )

        renameItem.target = self
        chooseFolderItem.target = self
        chooseFolderItem.representedObject = clickedTileIndex
        openFolderItem.target = self
        openFolderItem.representedObject = clickedTileIndex
        removeFolderReferenceItem.target = self
        removeFolderReferenceItem.representedObject = clickedTileIndex
        addTileItem.target = self
        deleteTileItem.target = self
        removeItem.target = self
        menu.addItem(renameItem)
        menu.addItem(.separator())
        if clickedTileIndex != nil {
            if clickedTileReference != nil {
                menu.addItem(openFolderItem)
            }
            menu.addItem(chooseFolderItem)
            if clickedTileReference != nil {
                menu.addItem(removeFolderReferenceItem)
            }
            menu.addItem(.separator())
        }
        menu.addItem(addTileItem)
        menu.addItem(deleteTileItem)
        menu.addItem(.separator())
        menu.addItem(removeItem)

        return menu
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds.insetBy(dx: 0.5, dy: 0.5)
        let blockPath = NSBezierPath(
            roundedRect: bounds,
            xRadius: 8,
            yRadius: 8
        )

        NSColor(calibratedRed: 0.18, green: 0.27, blue: 0.34, alpha: 0.85).setStroke()
        blockPath.lineWidth = 1
        blockPath.stroke()

        drawTitle()
        drawTileGrid()
        drawOverflowIndicators()
    }

    private func drawTitle() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]

        state.title.draw(
            in: titleRect.insetBy(dx: 2, dy: 7),
            withAttributes: attributes
        )
    }

    @objc private func renameFromContextMenu(_ sender: Any?) {
        requestRename?(state.id)
    }

    @objc private func removeFromContextMenu(_ sender: Any?) {
        requestRemove?(state.id)
    }

    @objc private func addTileFromContextMenu(_ sender: Any?) {
        requestAddTile?(state.id)
    }

    @objc private func deleteTileFromContextMenu(_ sender: Any?) {
        requestDeleteTile?(state.id)
    }

    @objc private func chooseFolderFromContextMenu(_ sender: NSMenuItem) {
        guard let tileIndex = sender.representedObject as? Int else {
            return
        }

        requestChooseFolder?(state.id, tileIndex)
    }

    @objc private func openFolderFromContextMenu(_ sender: NSMenuItem) {
        guard let tileIndex = sender.representedObject as? Int else {
            return
        }

        requestOpenFolder?(state.id, tileIndex)
    }

    @objc private func removeFolderReferenceFromContextMenu(_ sender: NSMenuItem) {
        guard let tileIndex = sender.representedObject as? Int else {
            return
        }

        requestRemoveFolderReference?(state.id, tileIndex)
    }

    private func drawTileGrid() {
        let originX = PrototypeGeometry.padding
        let originY = tileGridOriginY

        guard state.columns > 0 else {
            return
        }

        for visibleSlot in 0..<visibleSlotCount {
            guard let tileIndex = tileIndex(forVisibleSlot: visibleSlot) else {
                continue
            }

            let row = visibleSlot / state.columns
            let column = visibleSlot % state.columns

            let label = tileLabel(at: tileIndex)

            drawTile(
                row: row,
                column: column,
                originX: originX,
                originY: originY,
                label: label,
                isMagneticTarget: tileIndex == magneticTargetTileIndex
            )
        }
    }

    private func tileLabel(at tileIndex: Int) -> String {
        guard let tileReference = state.tileReference(at: tileIndex) else {
            return "Folder"
        }

        return tileReference.displayName
    }

    private func drawTile(
        row: Int,
        column: Int,
        originX: CGFloat,
        originY: CGFloat,
        label: String,
        isMagneticTarget: Bool
    ) {
        let tileInset: CGFloat = isMagneticTarget ? 3 : 5
        let tileRect = NSRect(
            x: originX + CGFloat(column) * PrototypeGeometry.tileWidth,
            y: originY + CGFloat(row) * PrototypeGeometry.tileHeight,
            width: PrototypeGeometry.tileWidth,
            height: PrototypeGeometry.tileHeight
        ).insetBy(dx: tileInset, dy: tileInset)

        let tilePath = NSBezierPath(
            roundedRect: tileRect,
            xRadius: 5,
            yRadius: 5
        )

        if isMagneticTarget {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            shadow.shadowBlurRadius = 5
            shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.18)
            shadow.set()
            NSColor(calibratedWhite: 1, alpha: 0.22).setFill()
            tilePath.fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        if isMagneticTarget {
            NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.26, alpha: 0.42).setStroke()
            tilePath.lineWidth = 1.5
        } else {
            NSColor(calibratedRed: 0.22, green: 0.32, blue: 0.38, alpha: 0.28).setStroke()
            tilePath.lineWidth = 1
        }
        tilePath.stroke()

        drawFolderPlaceholder(in: tileRect)
        drawTileLabel(label, in: tileRect)
    }

    private func drawFolderPlaceholder(in tileRect: NSRect) {
        let iconWidth: CGFloat = 60
        let iconHeight: CGFloat = 52
        let iconRect = NSRect(
            x: tileRect.midX - iconWidth / 2,
            y: tileRect.minY + 8,
            width: iconWidth,
            height: iconHeight
        )

        let folderIcon = NSWorkspace.shared.icon(for: .folder)
        folderIcon.size = iconRect.size
        folderIcon.draw(in: iconRect)
    }

    private func drawTileLabel(_ label: String, in tileRect: NSRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        let labelRect = NSRect(
            x: tileRect.minX + 6,
            y: tileRect.maxY - 26,
            width: tileRect.width - 12,
            height: 18
        )

        label.draw(in: labelRect, withAttributes: attributes)
    }

    private func tileIndex(at point: NSPoint) -> Int? {
        tileIndex(at: point, margin: 0)
    }

    private func magneticTileIndex(at point: NSPoint) -> Int? {
        tileIndex(at: point, margin: magneticTargetMargin)
    }

    private func tileIndex(at point: NSPoint, margin: CGFloat) -> Int? {
        let originX = PrototypeGeometry.padding
        let originY = tileGridOriginY
        let relativeX = point.x - originX
        let relativeY = point.y - originY

        guard state.columns > 0, state.visibleTileCount > 0 else {
            return nil
        }

        let rowCount = visibleRowCount
        let gridWidth = CGFloat(state.columns) * PrototypeGeometry.tileWidth
        let gridHeight = CGFloat(rowCount) * PrototypeGeometry.tileHeight

        guard
            relativeX >= -margin,
            relativeY >= -margin,
            relativeX < gridWidth + margin,
            relativeY < gridHeight + margin
        else {
            return nil
        }

        let clampedX = min(
            max(relativeX, 0),
            CGFloat(state.columns) * PrototypeGeometry.tileWidth - 1
        )
        let clampedY = min(
            max(relativeY, 0),
            CGFloat(rowCount) * PrototypeGeometry.tileHeight - 1
        )
        let column = Int(clampedX / PrototypeGeometry.tileWidth)
        let row = Int(clampedY / PrototypeGeometry.tileHeight)
        let visibleSlot = row * state.columns + column

        guard
            column >= 0,
            column < state.columns,
            visibleSlot >= 0,
            visibleSlot < visibleSlotCount
        else {
            return nil
        }

        return tileIndex(forVisibleSlot: visibleSlot)
    }

    private func updateMagneticTarget(for sender: NSDraggingInfo) -> NSDragOperation {
        let eventLocation = convert(sender.draggingLocation, from: nil)
        magneticTargetTileIndex = magneticTileIndex(at: eventLocation)

        guard magneticTargetTileIndex != nil else {
            return []
        }

        return dragOperation(for: sender)
    }

    private var visibleSlotCount: Int {
        max(0, min(state.tileCapacity, state.tileCount - tileScrollOffset))
    }

    private var visibleRowCount: Int {
        guard state.columns > 0 else {
            return 0
        }

        return Int(ceil(Double(visibleSlotCount) / Double(state.columns)))
    }

    private var maxTileScrollOffset: Int {
        TileViewport(
            tileCount: state.tileCount,
            columns: state.columns,
            rows: state.rows
        ).maximumRowAlignedScrollOffset
    }

    private var canScrollBackward: Bool {
        tileScrollOffset > 0
    }

    private var canScrollForward: Bool {
        tileScrollOffset < maxTileScrollOffset
    }

    private func tileIndex(forVisibleSlot visibleSlot: Int) -> Int? {
        let tileIndex = tileScrollOffset + visibleSlot

        guard visibleSlot >= 0, tileIndex >= 0, tileIndex < state.tileCount else {
            return nil
        }

        return tileIndex
    }

    private func scrollTiles(by delta: Int, alignToRows: Bool) {
        let nextOffset = min(max(tileScrollOffset + delta, 0), maxTileScrollOffset)
        let alignedOffset = alignToRows ? rowAlignedTileScrollOffset(nextOffset) : nextOffset

        guard alignedOffset != tileScrollOffset else {
            return
        }

        tileScrollOffset = alignedOffset
    }

    private func clampTileScrollOffset() {
        tileScrollOffset = rowAlignedTileScrollOffset(min(tileScrollOffset, maxTileScrollOffset))
    }

    private func rowAlignedTileScrollOffset(_ proposedOffset: Int) -> Int {
        guard state.columns > 0 else {
            return 0
        }

        let cappedOffset = min(max(proposedOffset, 0), maxTileScrollOffset)
        return min((cappedOffset / state.columns) * state.columns, maxTileScrollOffset)
    }

    private func drawOverflowIndicators() {
        guard state.tileCapacity < state.tileCount else {
            return
        }

        let gridMinX = PrototypeGeometry.padding
        let gridMinY = tileGridOriginY
        let gridWidth = CGFloat(state.columns) * PrototypeGeometry.tileWidth
        let gridHeight = CGFloat(max(1, state.rows)) * PrototypeGeometry.tileHeight

        if canScrollForward {
            drawBottomOverflowHint(
                x: gridMinX,
                y: gridMinY + gridHeight,
                width: gridWidth
            )
        }

        if canScrollBackward {
            drawTopOverflowHint(
                x: gridMinX,
                y: gridMinY,
                width: gridWidth
            )
        }
    }

    private func drawBottomOverflowHint(x: CGFloat, y: CGFloat, width: CGFloat) {
        drawChevron(
            center: NSPoint(x: x + width / 2, y: y + 10),
            pointsDown: true,
            alpha: 0.42
        )
    }

    private func drawTopOverflowHint(x: CGFloat, y: CGFloat, width: CGFloat) {
        drawChevron(
            center: NSPoint(x: x + width / 2, y: y - 12),
            pointsDown: false,
            alpha: 0.28
        )
    }

    private func drawChevron(center: NSPoint, pointsDown: Bool, alpha: CGFloat) {
        let path = NSBezierPath()
        let halfWidth: CGFloat = 7
        let halfHeight: CGFloat = 3

        if pointsDown {
            path.move(to: NSPoint(x: center.x - halfWidth, y: center.y - halfHeight))
            path.line(to: NSPoint(x: center.x, y: center.y + halfHeight))
            path.line(to: NSPoint(x: center.x + halfWidth, y: center.y - halfHeight))
        } else {
            path.move(to: NSPoint(x: center.x - halfWidth, y: center.y + halfHeight))
            path.line(to: NSPoint(x: center.x, y: center.y - halfHeight))
            path.line(to: NSPoint(x: center.x + halfWidth, y: center.y + halfHeight))
        }

        NSColor(calibratedRed: 0.11, green: 0.15, blue: 0.18, alpha: alpha).setStroke()
        path.lineWidth = 1.4
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private var tileGridOriginY: CGFloat {
        PrototypeGeometry.padding + PrototypeGeometry.titleHeight + overflowIndicatorGutter
    }

    private var overflowIndicatorGutter: CGFloat {
        CGFloat(PrototypeGeometry.metrics.verticalOverflowIndicatorAllowance / 2)
    }

    private func folderURL(from pasteboard: NSPasteboard) -> URL? {
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], let folderURL = urls.first(where: isFolderURL) {
            return folderURL
        }

        let filenamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        guard let paths = pasteboard.propertyList(forType: filenamesPasteboardType) as? [String] else {
            return nil
        }

        return paths
            .map { URL(fileURLWithPath: $0) }
            .first(where: isFolderURL)
    }

    private func isFolderURL(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func dragOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        let sourceMask = sender.draggingSourceOperationMask

        if sourceMask.contains(.copy) {
            return .copy
        }

        if sourceMask.contains(.generic) {
            return .generic
        }

        if sourceMask.contains(.link) {
            return .link
        }

        return []
    }
}
