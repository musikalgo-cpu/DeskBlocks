import AppKit
import CoreGraphics
import DeskBlocksCore
import Foundation

private enum OverlayWindowConfiguration {
    static let level = NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
    )
    static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .stationary,
        .ignoresCycle,
        .fullScreenAuxiliary
    ]
}

private enum PrototypeGeometry {
    static let metrics = TileGridMetrics.prototype

    static var tileWidth: CGFloat { CGFloat(metrics.tileWidth) }
    static var tileHeight: CGFloat { CGFloat(metrics.tileHeight) }
    static var titleHeight: CGFloat { CGFloat(metrics.titleHeight) }
    static var padding: CGFloat { CGFloat(metrics.padding) }
}

private extension BlockPoint {
    init(_ point: NSPoint) {
        self.init(x: point.x, y: point.y)
    }
}

private extension BlockSize {
    init(_ size: NSSize) {
        self.init(width: size.width, height: size.height)
    }

    var nsSize: NSSize {
        NSSize(width: width, height: height)
    }
}

private extension BlockFrame {
    var contentRect: NSRect {
        NSRect(
            x: origin.x,
            y: origin.y,
            width: size.width,
            height: size.height
        )
    }
}

final class PrototypeStateStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> DeskBlocksState? {
        do {
            let data = try Data(contentsOf: fileURL)
            if let state = try? decoder.decode(DeskBlocksState.self, from: data) {
                return state
            }

            let legacyBlock = try decoder.decode(DeskBlockState.self, from: data)
            return DeskBlocksState(blocks: [legacyBlock])
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        } catch {
            fputs("DeskBlocksPrototype: failed to load state: \(error)\n", stderr)
            return nil
        }
    }

    func save(_ state: DeskBlocksState) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            fputs("DeskBlocksPrototype: failed to save state: \(error)\n", stderr)
        }
    }

    private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("DeskBlocks", isDirectory: true)
            .appendingPathComponent("prototype-state.json")
    }
}

final class DeskBlockView: NSView {
    var state: DeskBlockState {
        didSet {
            needsDisplay = true
        }
    }
    var requestRename: ((DeskBlockID) -> Void)?
    var requestRemove: ((DeskBlockID) -> Void)?

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
        let removeItem = NSMenuItem(
            title: "Remove Block...",
            action: #selector(removeFromContextMenu(_:)),
            keyEquivalent: ""
        )

        renameItem.target = self
        removeItem.target = self
        menu.addItem(renameItem)
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

    private func drawTileGrid() {
        let originX = PrototypeGeometry.padding
        let originY = PrototypeGeometry.padding + PrototypeGeometry.titleHeight

        guard state.columns > 0 else {
            return
        }

        for tileIndex in 0..<state.visibleTileCount {
            let row = tileIndex / state.columns
            let column = tileIndex % state.columns

            drawTile(row: row, column: column, originX: originX, originY: originY)
        }
    }

    private func drawTile(row: Int, column: Int, originX: CGFloat, originY: CGFloat) {
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
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = PrototypeStateStore()
    private var state = DeskBlocksState.prototypeDefault()
    private var windowsByBlockID: [DeskBlockID: NSWindow] = [:]
    private var blockViewsByBlockID: [DeskBlockID: DeskBlockView] = [:]
    private var blockIDsApplyingSnappedFrame: Set<DeskBlockID> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        state = loadInitialState()
        renderAllBlockWindows()
        store.save(state)

        if let newBlockTileCountText = commandLineValue(after: "--new-block-smoke") {
            DispatchQueue.main.async { [weak self] in
                guard let tileCount = Int(newBlockTileCountText), tileCount > 0 else {
                    NSApplication.shared.terminate(nil)
                    return
                }

                let title = self?.commandLineValue(after: "--new-block-title") ?? "Smoke Block"
                self?.createBlock(title: title, tileCount: tileCount)
                NSApplication.shared.terminate(nil)
            }
            return
        }

        if let renameSmokeTitle = commandLineValue(after: "--rename-smoke") {
            DispatchQueue.main.async { [weak self] in
                guard let blockID = self?.state.blocks.first?.id else {
                    NSApplication.shared.terminate(nil)
                    return
                }

                self?.rename(blockID: blockID, to: renameSmokeTitle)
                NSApplication.shared.terminate(nil)
            }
            return
        }

        if CommandLine.arguments.contains("--remove-smoke") {
            DispatchQueue.main.async { [weak self] in
                guard let blockID = self?.state.blocks.first?.id else {
                    NSApplication.shared.terminate(nil)
                    return
                }

                self?.remove(blockID: blockID)
                NSApplication.shared.terminate(nil)
            }
            return
        }

        if CommandLine.arguments.contains("--close-smoke") {
            DispatchQueue.main.async { [weak self] in
                self?.windowsByBlockID.values.first?.close()
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private func commandLineValue(after flag: String) -> String? {
        guard let flagIndex = CommandLine.arguments.firstIndex(of: flag) else {
            return nil
        }

        let valueIndex = CommandLine.arguments.index(after: flagIndex)

        guard valueIndex < CommandLine.arguments.endIndex else {
            return nil
        }

        return CommandLine.arguments[valueIndex]
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateStateFromAllWindows(save: true)
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let proposedFrame = NSRect(origin: sender.frame.origin, size: frameSize)
        let proposedContent = sender.contentRect(forFrameRect: proposedFrame)
        let snapped = PrototypeGeometry.metrics.snappedSize(for: BlockSize(proposedContent.size))
        let snappedFrame = sender.frameRect(
            forContentRect: NSRect(origin: .zero, size: snapped.size.nsSize)
        )

        return snappedFrame.size
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        updateState(from: window, save: false)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        applySnappedFrameIfNeeded(to: window)
        updateState(from: window, save: true)
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        updateState(from: window, save: true)
    }

    func windowWillClose(_ notification: Notification) {
        updateStateFromAllWindows(save: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !state.blocks.isEmpty
    }

    @objc private func createNewBlock(_ sender: Any?) {
        showNewBlockDialog()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        let newBlockItem = NSMenuItem(
            title: "New Block...",
            action: #selector(createNewBlock(_:)),
            keyEquivalent: "n"
        )
        let renameBlockItem = NSMenuItem(
            title: "Rename Block...",
            action: #selector(renameSelectedBlock(_:)),
            keyEquivalent: ""
        )
        let removeBlockItem = NSMenuItem(
            title: "Remove Block...",
            action: #selector(removeSelectedBlock(_:)),
            keyEquivalent: ""
        )

        appMenu.addItem(
            NSMenuItem(
                title: "Quit DeskBlocks",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu

        newBlockItem.target = self
        fileMenu.addItem(newBlockItem)
        fileMenuItem.submenu = fileMenu

        renameBlockItem.target = self
        removeBlockItem.target = self
        editMenu.addItem(renameBlockItem)
        editMenu.addItem(removeBlockItem)
        editMenuItem.submenu = editMenu

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        mainMenu.addItem(editMenuItem)
        NSApplication.shared.mainMenu = mainMenu
    }

    private func loadInitialState() -> DeskBlocksState {
        guard let loadedState = store.load() else {
            return DeskBlocksState.prototypeDefault().snapped(metrics: PrototypeGeometry.metrics)
        }

        return loadedState.snapped(metrics: PrototypeGeometry.metrics)
    }

    private func renderAllBlockWindows() {
        state.blocks.forEach { block in
            renderWindow(for: block)
        }
    }

    private func renderWindow(for block: DeskBlockState) {
        let window = NSWindow(
            contentRect: block.frame.contentRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let minimumContentSize = PrototypeGeometry.metrics.contentSize(columns: 1, rows: 1)
        let minimumFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: minimumContentSize.nsSize)).size
        let blockView = DeskBlockView(state: block)
        blockView.requestRename = { [weak self] blockID in
            self?.showRenameDialog(for: blockID)
        }
        blockView.requestRemove = { [weak self] blockID in
            self?.showRemoveConfirmation(for: blockID)
        }

        window.identifier = NSUserInterfaceItemIdentifier(block.id.rawValue)
        window.title = block.title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.canHide = false
        window.level = OverlayWindowConfiguration.level
        window.collectionBehavior = OverlayWindowConfiguration.collectionBehavior
        window.minSize = minimumFrameSize
        window.delegate = self
        window.contentView = blockView
        window.makeKeyAndOrderFront(nil)

        windowsByBlockID[block.id] = window
        blockViewsByBlockID[block.id] = blockView
    }

    private func showNewBlockDialog() {
        let alert = NSAlert()
        let stackView = NSStackView()
        let titleField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        let tileCountField = NSTextField(frame: NSRect(x: 0, y: 0, width: 80, height: 24))

        alert.messageText = "New Block"
        alert.informativeText = "Enter a title and total tile count."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.frame = NSRect(x: 0, y: 0, width: 330, height: 64)
        stackView.addArrangedSubview(labeledField(label: "Title", field: titleField))
        stackView.addArrangedSubview(labeledField(label: "Tiles", field: tileCountField))

        titleField.stringValue = "Block \(state.blocks.count + 1)"
        tileCountField.stringValue = "12"
        alert.accessoryView = stackView

        let response = alert.runModal()

        guard response == .alertFirstButtonReturn else {
            return
        }

        guard let tileCount = Int(tileCountField.stringValue), tileCount > 0 else {
            NSSound.beep()
            return
        }

        createBlock(title: titleField.stringValue, tileCount: tileCount)
    }

    private func labeledField(label: String, field: NSTextField) -> NSView {
        let stackView = NSStackView()
        let labelView = NSTextField(labelWithString: label)

        stackView.orientation = .horizontal
        stackView.alignment = .firstBaseline
        stackView.spacing = 8
        labelView.frame.size.width = 48
        stackView.addArrangedSubview(labelView)
        stackView.addArrangedSubview(field)

        return stackView
    }

    private func createBlock(title: String, tileCount: Int) {
        let newBlock = makeNewBlock(title: title, tileCount: tileCount)

        state = state.appending(block: newBlock).snapped(metrics: PrototypeGeometry.metrics)
        renderWindow(for: newBlock)
        store.save(state)
    }

    private func makeNewBlock(title: String, tileCount: Int) -> DeskBlockState {
        let offset = Double(state.blocks.count * 28)
        let layout = PrototypeGeometry.metrics.gridLayout(containingTileCount: tileCount)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let blockTitle = trimmedTitle.isEmpty ? "Untitled Block" : trimmedTitle

        return DeskBlockState(
            id: DeskBlockID(UUID().uuidString),
            title: blockTitle,
            frame: BlockFrame(
                origin: BlockPoint(x: 240 + offset, y: 240 + offset),
                size: PrototypeGeometry.metrics.contentSize(columns: layout.columns, rows: layout.rows)
            ),
            columns: layout.columns,
            rows: layout.rows,
            tileCount: layout.requestedTileCount,
            tileReferences: []
        )
    }

    @objc private func renameSelectedBlock(_ sender: Any?) {
        guard
            let keyWindow = NSApplication.shared.keyWindow,
            let blockID = blockID(for: keyWindow)
        else {
            NSSound.beep()
            return
        }

        showRenameDialog(for: blockID)
    }

    @objc private func removeSelectedBlock(_ sender: Any?) {
        guard
            let keyWindow = NSApplication.shared.keyWindow,
            let blockID = blockID(for: keyWindow)
        else {
            NSSound.beep()
            return
        }

        showRemoveConfirmation(for: blockID)
    }

    private func showRenameDialog(for blockID: DeskBlockID) {
        guard
            let block = state.block(id: blockID),
            let window = windowsByBlockID[blockID]
        else {
            return
        }

        let alert = NSAlert()
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))

        alert.messageText = "Rename Block"
        alert.informativeText = "Enter a new block title."
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        input.stringValue = block.title
        input.selectText(nil)
        alert.accessoryView = input

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else {
                return
            }

            self?.rename(blockID: blockID, to: input.stringValue)
        }
    }

    private func rename(blockID: DeskBlockID, to proposedTitle: String) {
        guard let currentBlock = state.block(id: blockID) else {
            return
        }

        let renamedBlock = currentBlock.renamed(to: proposedTitle)

        guard renamedBlock != currentBlock else {
            NSSound.beep()
            return
        }

        state = state.updating(block: renamedBlock)
        blockViewsByBlockID[blockID]?.state = renamedBlock
        windowsByBlockID[blockID]?.title = renamedBlock.title
        store.save(state)
    }

    private func showRemoveConfirmation(for blockID: DeskBlockID) {
        guard
            let block = state.block(id: blockID),
            let window = windowsByBlockID[blockID]
        else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remove Block?"
        alert.informativeText = "Remove \"\(block.title)\" from DeskBlocks. Finder folders and files will not be changed."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else {
                return
            }

            self?.remove(blockID: blockID)
        }
    }

    @discardableResult
    private func remove(blockID: DeskBlockID) -> Bool {
        guard
            state.block(id: blockID) != nil,
            let window = windowsByBlockID[blockID]
        else {
            return false
        }

        updateStateFromAllWindows(save: false)
        state = state.removingBlock(id: blockID)
        blockViewsByBlockID.removeValue(forKey: blockID)
        windowsByBlockID.removeValue(forKey: blockID)
        window.delegate = nil
        window.close()
        store.save(state)

        return true
    }

    private func blockID(for window: NSWindow) -> DeskBlockID? {
        windowsByBlockID.first { _, storedWindow in
            storedWindow === window
        }?.key
    }

    private func updateStateFromAllWindows(save: Bool) {
        windowsByBlockID.values.forEach { window in
            updateState(from: window, save: false)
        }

        if save {
            store.save(state)
        }
    }

    private func updateState(from window: NSWindow, save: Bool) {
        guard
            let blockID = blockID(for: window),
            let currentBlock = state.block(id: blockID)
        else {
            return
        }

        let contentRect = window.contentRect(forFrameRect: window.frame)
        let origin = BlockPoint(contentRect.origin)
        let snapped = PrototypeGeometry.metrics.snappedSize(for: BlockSize(contentRect.size))

        let updatedBlock = currentBlock.snapped(
            metrics: PrototypeGeometry.metrics,
            origin: origin,
            proposedSize: snapped.size
        )

        state = state.updating(block: updatedBlock)
        blockViewsByBlockID[blockID]?.state = updatedBlock
        window.title = updatedBlock.title

        if save {
            store.save(state)
        }
    }

    private func applySnappedFrameIfNeeded(to window: NSWindow) {
        guard
            let blockID = blockID(for: window),
            !blockIDsApplyingSnappedFrame.contains(blockID)
        else {
            return
        }

        let contentRect = window.contentRect(forFrameRect: window.frame)
        let snapped = PrototypeGeometry.metrics.snappedSize(for: BlockSize(contentRect.size))

        guard snapped.size != BlockSize(contentRect.size) else {
            return
        }

        let snappedContentRect = NSRect(origin: contentRect.origin, size: snapped.size.nsSize)
        let snappedFrame = window.frameRect(forContentRect: snappedContentRect)

        blockIDsApplyingSnappedFrame.insert(blockID)
        window.setFrame(snappedFrame, display: true)
        blockIDsApplyingSnappedFrame.remove(blockID)
    }
}

@main
@MainActor
enum DeskBlocksPrototype {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()

        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
