import AppKit
import DeskBlocksCore
import UniformTypeIdentifiers

final class DeskBlockView: NSView {
    var state: DeskBlockState {
        didSet {
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

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard folderURL(from: sender.draggingPasteboard) != nil, tileIndex(at: convert(sender.draggingLocation, from: nil)) != nil else {
            return []
        }

        return dragOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard folderURL(from: sender.draggingPasteboard) != nil, tileIndex(at: convert(sender.draggingLocation, from: nil)) != nil else {
            return []
        }

        return dragOperation(for: sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let eventLocation = convert(sender.draggingLocation, from: nil)

        guard
            let tileIndex = tileIndex(at: eventLocation),
            let folderURL = folderURL(from: sender.draggingPasteboard)
        else {
            return false
        }

        requestPlaceFolder?(state.id, tileIndex, folderURL)
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

        NSColor(calibratedWhite: 0.98, alpha: 0.88).setFill()
        blockPath.fill()

        NSColor(calibratedRed: 0.18, green: 0.27, blue: 0.34, alpha: 0.85).setStroke()
        blockPath.lineWidth = 1
        blockPath.stroke()

        drawTitle()
        drawTileGrid()
    }

    private func drawTitle() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.11, green: 0.16, blue: 0.2, alpha: 1),
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
        let originY = PrototypeGeometry.padding + PrototypeGeometry.titleHeight

        guard state.columns > 0 else {
            return
        }

        for tileIndex in 0..<state.visibleTileCount {
            let row = tileIndex / state.columns
            let column = tileIndex % state.columns

            let label = tileLabel(at: tileIndex)

            drawTile(row: row, column: column, originX: originX, originY: originY, label: label)
        }
    }

    private func tileLabel(at tileIndex: Int) -> String {
        guard let tileReference = state.tileReference(at: tileIndex) else {
            return "Folder"
        }

        return tileReference.displayName
    }

    private func drawTile(row: Int, column: Int, originX: CGFloat, originY: CGFloat, label: String) {
        let tileRect = NSRect(
            x: originX + CGFloat(column) * PrototypeGeometry.tileWidth,
            y: originY + CGFloat(row) * PrototypeGeometry.tileHeight,
            width: PrototypeGeometry.tileWidth,
            height: PrototypeGeometry.tileHeight
        ).insetBy(dx: 5, dy: 5)

        let tilePath = NSBezierPath(
            roundedRect: tileRect,
            xRadius: 5,
            yRadius: 5
        )
        NSColor(calibratedWhite: 1, alpha: 0.62).setFill()
        tilePath.fill()

        NSColor(calibratedRed: 0.22, green: 0.32, blue: 0.38, alpha: 0.28).setStroke()
        tilePath.lineWidth = 1
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
            .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.19, alpha: 1),
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
        let originX = PrototypeGeometry.padding
        let originY = PrototypeGeometry.padding + PrototypeGeometry.titleHeight
        let relativeX = point.x - originX
        let relativeY = point.y - originY

        guard relativeX >= 0, relativeY >= 0, state.columns > 0 else {
            return nil
        }

        let column = Int(relativeX / PrototypeGeometry.tileWidth)
        let row = Int(relativeY / PrototypeGeometry.tileHeight)
        let tileIndex = row * state.columns + column

        guard column >= 0, column < state.columns, tileIndex >= 0, tileIndex < state.visibleTileCount else {
            return nil
        }

        return tileIndex
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
