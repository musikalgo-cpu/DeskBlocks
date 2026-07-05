import AppKit
import DeskBlocksCore
import UniformTypeIdentifiers

private final class FlippedNotePopoverView: NSView {
    override var isFlipped: Bool { true }
}

final class DeskBlockView: NSView, NSDraggingSource {
    private struct TileDragPayload: Codable {
        let blockIDRawValue: String
        let tileIndex: Int
    }

    private struct PendingTileDrag {
        let tileIndex: Int
        let mouseDownLocation: NSPoint
    }

    private static let tileReferenceDragPasteboardType = NSPasteboard.PasteboardType(
        "local.deskblocks.tile-reference"
    )

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
    var requestEditTitleColor: ((DeskBlockID) -> Void)?
    var requestToggleEmptyTiles: ((DeskBlockID) -> Void)?
    var requestToggleLock: ((DeskBlockID) -> Void)?
    var requestChooseFolder: ((DeskBlockID, Int) -> Void)?
    var requestPlaceFolder: ((DeskBlockID, Int, URL) -> Void)?
    var requestOpenFolder: ((DeskBlockID, Int) -> Void)?
    var requestRemoveFolderReference: ((DeskBlockID, Int) -> Void)?
    var requestEditFolderNote: ((DeskBlockID, Int) -> Void)?
    var requestRemoveFolderNote: ((DeskBlockID, Int) -> Void)?
    var requestMoveFolderReference: ((DeskBlockID, Int, Int) -> Void)?

    private var notePopover: NSPopover?
    private var pendingTileDrag: PendingTileDrag?
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
        registerForDraggedTypes([.fileURL, Self.tileReferenceDragPasteboardType])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        let eventLocation = convert(event.locationInWindow, from: nil)
        pendingTileDrag = nil

        if let tileIndex = noteInfoTileIndex(at: eventLocation),
           let tileReference = state.tileReference(at: tileIndex),
           let note = tileReference.note {
            showNotePopover(note, relativeTo: noteInfoIconRect(for: tileIndex))
            return
        }

        if event.clickCount == 2, titleRect.contains(eventLocation) {
            requestRename?(state.id)
            return
        }

        if event.clickCount == 2, let tileIndex = tileIndex(at: eventLocation), state.tileReference(at: tileIndex) != nil {
            requestOpenFolder?(state.id, tileIndex)
            return
        }

        if event.clickCount == 1,
           let tileIndex = tileIndex(at: eventLocation),
           state.tileReference(at: tileIndex) != nil {
            pendingTileDrag = PendingTileDrag(tileIndex: tileIndex, mouseDownLocation: eventLocation)
        }

        if event.clickCount == 1, isWindowDragRegion(at: eventLocation) {
            window?.performDrag(with: event)
            return
        }

        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard
            let pendingTileDrag,
            let tileReference = state.tileReference(at: pendingTileDrag.tileIndex)
        else {
            super.mouseDragged(with: event)
            return
        }

        let eventLocation = convert(event.locationInWindow, from: nil)
        guard distance(from: pendingTileDrag.mouseDownLocation, to: eventLocation) >= 4 else {
            return
        }

        guard
            let dragItem = draggingItem(for: tileReference),
            let tileRect = tileRect(for: pendingTileDrag.tileIndex)
        else {
            self.pendingTileDrag = nil
            return
        }

        dragItem.setDraggingFrame(tileRect, contents: dragImage(for: tileReference))
        beginDraggingSession(with: [dragItem], event: event, source: self)
        self.pendingTileDrag = nil
    }

    override func mouseUp(with event: NSEvent) {
        pendingTileDrag = nil
        super.mouseUp(with: event)
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
        guard canAcceptDrag(from: sender.draggingPasteboard) else {
            return []
        }

        return updateMagneticTarget(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canAcceptDrag(from: sender.draggingPasteboard) else {
            return []
        }

        return updateMagneticTarget(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        magneticTargetTileIndex = nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let eventLocation = convert(sender.draggingLocation, from: nil)

        if let payload = tileReferenceDragPayload(from: sender.draggingPasteboard) {
            guard
                payload.blockIDRawValue == state.id.rawValue,
                let tileIndex = magneticTileIndex(at: eventLocation)
            else {
                magneticTargetTileIndex = nil
                return false
            }

            guard payload.tileIndex != tileIndex else {
                magneticTargetTileIndex = nil
                return false
            }

            requestMoveFolderReference?(state.id, payload.tileIndex, tileIndex)
            magneticTargetTileIndex = nil
            return true
        }

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
        let editFolderNoteItem = NSMenuItem(
            title: clickedTileReference?.note == nil ? "Notiz hinzufügen..." : "Notiz bearbeiten...",
            action: #selector(editFolderNoteFromContextMenu(_:)),
            keyEquivalent: ""
        )
        let removeFolderNoteItem = NSMenuItem(
            title: "Notiz entfernen",
            action: #selector(removeFolderNoteFromContextMenu(_:)),
            keyEquivalent: ""
        )
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
        let titleColorItem = NSMenuItem(
            title: "Title Color...",
            action: #selector(editTitleColorFromContextMenu(_:)),
            keyEquivalent: ""
        )
        let hideEmptyTilesItem = NSMenuItem(
            title: "Hide Empty Tiles",
            action: #selector(toggleEmptyTilesFromContextMenu(_:)),
            keyEquivalent: ""
        )
        let lockItem = NSMenuItem(
            title: "Lock Block",
            action: #selector(toggleLockFromContextMenu(_:)),
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
        titleColorItem.target = self
        hideEmptyTilesItem.target = self
        hideEmptyTilesItem.state = state.hidesEmptyTiles ? .on : .off
        lockItem.target = self
        lockItem.state = state.isLocked ? .on : .off
        chooseFolderItem.target = self
        chooseFolderItem.representedObject = clickedTileIndex
        openFolderItem.target = self
        openFolderItem.representedObject = clickedTileIndex
        removeFolderReferenceItem.target = self
        removeFolderReferenceItem.representedObject = clickedTileIndex
        editFolderNoteItem.target = self
        editFolderNoteItem.representedObject = clickedTileIndex
        removeFolderNoteItem.target = self
        removeFolderNoteItem.representedObject = clickedTileIndex
        addTileItem.target = self
        addTileItem.isEnabled = !state.isLocked
        deleteTileItem.target = self
        deleteTileItem.isEnabled = !state.isLocked
        removeItem.target = self
        menu.addItem(renameItem)
        menu.addItem(titleColorItem)
        menu.addItem(hideEmptyTilesItem)
        menu.addItem(lockItem)
        menu.addItem(.separator())
        if clickedTileIndex != nil {
            if clickedTileReference != nil {
                menu.addItem(openFolderItem)
            }
            menu.addItem(chooseFolderItem)
            if clickedTileReference != nil {
                menu.addItem(editFolderNoteItem)
                if clickedTileReference?.note != nil {
                    menu.addItem(removeFolderNoteItem)
                }
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

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .move
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        pendingTileDrag = nil
        magneticTargetTileIndex = nil
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
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
            .foregroundColor: state.titleColor.nsColor,
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

    @objc private func editTitleColorFromContextMenu(_ sender: Any?) {
        requestEditTitleColor?(state.id)
    }

    @objc private func toggleEmptyTilesFromContextMenu(_ sender: Any?) {
        requestToggleEmptyTiles?(state.id)
    }

    @objc private func toggleLockFromContextMenu(_ sender: Any?) {
        requestToggleLock?(state.id)
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

    @objc private func editFolderNoteFromContextMenu(_ sender: NSMenuItem) {
        guard let tileIndex = sender.representedObject as? Int else {
            return
        }

        requestEditFolderNote?(state.id, tileIndex)
    }

    @objc private func removeFolderNoteFromContextMenu(_ sender: NSMenuItem) {
        guard let tileIndex = sender.representedObject as? Int else {
            return
        }

        requestRemoveFolderNote?(state.id, tileIndex)
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
            let isMagneticTarget = tileIndex == magneticTargetTileIndex

            if state.hidesEmptyTiles, state.tileReference(at: tileIndex) == nil, !isMagneticTarget {
                continue
            }

            drawTile(
                tileIndex: tileIndex,
                row: row,
                column: column,
                originX: originX,
                originY: originY,
                label: label,
                isMagneticTarget: isMagneticTarget
            )
        }
    }

    private func draggingItem(for tileReference: TileReference) -> NSDraggingItem? {
        let payload = TileDragPayload(
            blockIDRawValue: state.id.rawValue,
            tileIndex: tileReference.tileIndex
        )

        guard
            let payloadData = try? JSONEncoder().encode(payload),
            let payloadString = String(data: payloadData, encoding: .utf8)
        else {
            return nil
        }

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(payloadString, forType: Self.tileReferenceDragPasteboardType)
        return NSDraggingItem(pasteboardWriter: pasteboardItem)
    }

    private func dragImage(for tileReference: TileReference) -> NSImage {
        let imageSize = NSSize(
            width: PrototypeGeometry.tileWidth,
            height: PrototypeGeometry.tileHeight
        )
        let image = NSImage(size: imageSize)
        image.lockFocus()

        let tileRect = NSRect(origin: .zero, size: imageSize).insetBy(dx: 5, dy: 5)
        let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: 5, yRadius: 5)
        NSColor(calibratedWhite: 1, alpha: 0.18).setFill()
        tilePath.fill()
        NSColor(calibratedRed: 0.22, green: 0.32, blue: 0.38, alpha: 0.42).setStroke()
        tilePath.lineWidth = 1
        tilePath.stroke()
        drawFolderPlaceholder(in: tileRect)
        drawTileLabel(tileReference.displayName, in: tileRect)

        image.unlockFocus()
        return image
    }

    private func tileLabel(at tileIndex: Int) -> String {
        guard let tileReference = state.tileReference(at: tileIndex) else {
            return "Folder"
        }

        return tileReference.displayName
    }

    private func drawTile(
        tileIndex: Int,
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
        drawNoteInfoIconIfNeeded(for: tileIndex, in: tileRect)
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

    private func drawNoteInfoIconIfNeeded(for tileIndex: Int, in tileRect: NSRect) {
        guard state.tileReference(at: tileIndex)?.note != nil else {
            return
        }

        let iconRect = noteInfoIconRect(in: tileRect)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: noteInfoIconFont(),
            .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.72),
            .paragraphStyle: paragraphStyle
        ]
        "i".draw(in: iconRect.offsetBy(dx: 0, dy: -2), withAttributes: attributes)
    }

    private func noteInfoIconFont() -> NSFont {
        NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 13, weight: .regular),
            toHaveTrait: .italicFontMask
        )
    }

    private func noteInfoTileIndex(at point: NSPoint) -> Int? {
        guard let tileIndex = tileIndex(at: point),
              state.tileReference(at: tileIndex)?.note != nil
        else {
            return nil
        }

        return noteInfoIconRect(for: tileIndex).contains(point) ? tileIndex : nil
    }

    private func noteInfoIconRect(for tileIndex: Int) -> NSRect {
        guard let tileRect = tileRect(for: tileIndex) else {
            return .zero
        }

        return noteInfoIconRect(in: tileRect)
    }

    private func noteInfoIconRect(in tileRect: NSRect) -> NSRect {
        let iconSize: CGFloat = 16
        return NSRect(
            x: tileRect.maxX - iconSize - 7,
            y: tileRect.minY + 7,
            width: iconSize,
            height: iconSize
        )
    }

    private func showNotePopover(_ note: String, relativeTo iconRect: NSRect) {
        notePopover?.close()

        let edgeInset: CGFloat = 22
        let contentSize = notePopoverContentSize(for: note)
        let textFrame = NSRect(
            x: edgeInset,
            y: edgeInset,
            width: contentSize.width - edgeInset * 2,
            height: contentSize.height - edgeInset * 2
        )
        let textView = NSTextView(frame: textFrame)
        textView.string = note
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor(calibratedWhite: 1, alpha: 0.92)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(width: textFrame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        let viewController = NSViewController()
        let container = FlippedNotePopoverView(frame: NSRect(origin: .zero, size: contentSize))
        container.wantsLayer = true
        container.layer?.cornerRadius = 16
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(calibratedRed: 0.18, green: 0.27, blue: 0.34, alpha: 0.85).cgColor
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(textView)
        viewController.view = container

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = contentSize
        popover.contentViewController = viewController
        popover.show(relativeTo: iconRect, of: self, preferredEdge: .minY)
        notePopover = popover
    }

    private func notePopoverContentSize(for note: String) -> NSSize {
        let edgeInset: CGFloat = 22
        let minTextWidth: CGFloat = 120
        let maxContentWidth = min(max((window?.screen ?? NSScreen.main)?.visibleFrame.width ?? 720, 360) * 0.65, 720)
        let maxTextWidth = maxContentWidth - edgeInset * 2
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13)
        ]

        let widths = stride(from: minTextWidth, through: maxTextWidth, by: 20)
        let candidates = widths.map { textWidth -> NSSize in
            let textHeight = noteTextHeight(for: note, width: textWidth, attributes: attributes)
            let contentWidth = ceil(textWidth + edgeInset * 2)
            let contentHeight = ceil(textHeight + edgeInset * 2)
            return NSSize(
                width: contentWidth,
                height: contentHeight
            )
        }

        return candidates.first { size in
            let ratio = size.width / size.height
            return ratio >= 1 && ratio <= 2
        } ?? candidates.last ?? NSSize(width: 260, height: 120)
    }

    private func noteTextHeight(
        for note: String,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any]? = nil
    ) -> CGFloat {
        let resolvedAttributes = attributes ?? [
            .font: NSFont.systemFont(ofSize: 13)
        ]

        return ceil((note as NSString).boundingRect(
            with: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: resolvedAttributes
        ).height)
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

    private func isWindowDragRegion(at point: NSPoint) -> Bool {
        guard !state.isLocked else {
            return false
        }

        if titleRect.contains(point) {
            return true
        }

        return !visibleTileGridRect.contains(point)
    }

    private var visibleTileGridRect: NSRect {
        NSRect(
            x: PrototypeGeometry.padding,
            y: tileGridOriginY,
            width: CGFloat(max(0, state.columns)) * PrototypeGeometry.tileWidth,
            height: CGFloat(max(0, visibleRowCount)) * PrototypeGeometry.tileHeight
        )
    }

    private func updateMagneticTarget(for sender: NSDraggingInfo) -> NSDragOperation {
        let eventLocation = convert(sender.draggingLocation, from: nil)
        magneticTargetTileIndex = magneticTileIndex(at: eventLocation)

        guard magneticTargetTileIndex != nil else {
            return []
        }

        if let payload = tileReferenceDragPayload(from: sender.draggingPasteboard) {
            guard payload.tileIndex != magneticTargetTileIndex else {
                magneticTargetTileIndex = nil
                return []
            }

            return .move
        }

        return dragOperation(for: sender)
    }

    private func tileRect(for tileIndex: Int) -> NSRect? {
        guard let visibleSlot = visibleSlot(forTileIndex: tileIndex) else {
            return nil
        }

        let row = visibleSlot / state.columns
        let column = visibleSlot % state.columns

        return NSRect(
            x: PrototypeGeometry.padding + CGFloat(column) * PrototypeGeometry.tileWidth,
            y: tileGridOriginY + CGFloat(row) * PrototypeGeometry.tileHeight,
            width: PrototypeGeometry.tileWidth,
            height: PrototypeGeometry.tileHeight
        ).insetBy(dx: 5, dy: 5)
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

    private func visibleSlot(forTileIndex targetTileIndex: Int) -> Int? {
        let visibleSlot = targetTileIndex - tileScrollOffset

        guard visibleSlot >= 0, visibleSlot < visibleSlotCount else {
            return nil
        }

        return tileIndex(forVisibleSlot: visibleSlot) == targetTileIndex ? visibleSlot : nil
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

    private func canAcceptDrag(from pasteboard: NSPasteboard) -> Bool {
        if let payload = tileReferenceDragPayload(from: pasteboard) {
            return payload.blockIDRawValue == state.id.rawValue
        }

        return folderURL(from: pasteboard) != nil
    }

    private func tileReferenceDragPayload(from pasteboard: NSPasteboard) -> TileDragPayload? {
        guard
            let payloadString = pasteboard.string(forType: Self.tileReferenceDragPasteboardType),
            let payloadData = payloadString.data(using: .utf8),
            let payload = try? JSONDecoder().decode(TileDragPayload.self, from: payloadData)
        else {
            return nil
        }

        return payload
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

    private func distance(from start: NSPoint, to end: NSPoint) -> CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }
}
