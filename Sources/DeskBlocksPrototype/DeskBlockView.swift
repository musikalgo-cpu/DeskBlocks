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

        super.mouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let renameItem = NSMenuItem(
            title: "Rename Block...",
            action: #selector(renameFromContextMenu(_:)),
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
        addTileItem.target = self
        deleteTileItem.target = self
        removeItem.target = self
        menu.addItem(renameItem)
        menu.addItem(.separator())
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
        guard tileIndex < state.tileReferences.count else {
            return "Folder"
        }

        return state.tileReferences[tileIndex].displayName
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
}
