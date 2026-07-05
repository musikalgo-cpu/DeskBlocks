import AppKit
import DeskBlocksCore
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = PrototypeStateStore()
    private var state = DeskBlocksState.prototypeDefault()
    private var windowsByBlockID: [DeskBlockID: NSWindow] = [:]
    private var blockViewsByBlockID: [DeskBlockID: DeskBlockView] = [:]
    private var blockIDsApplyingSnappedFrame: Set<DeskBlockID> = []
    private let titleColorPanel = NSColorPanel.shared
    private var titleColorEditingBlockID: DeskBlockID?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        configureTitleColorPanel()

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

        if let titleColorSmokeValue = commandLineValue(after: "--title-color-smoke") {
            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    let blockID = self.state.blocks.first?.id,
                    let color = self.blockColor(from: titleColorSmokeValue)
                else {
                    NSApplication.shared.terminate(nil)
                    return
                }

                self.updateTitleColor(for: blockID, to: color)
                NSApplication.shared.terminate(nil)
            }
            return
        }

        if CommandLine.arguments.contains("--hide-empty-tiles-smoke") {
            DispatchQueue.main.async { [weak self] in
                guard let blockID = self?.state.blocks.first?.id else {
                    NSApplication.shared.terminate(nil)
                    return
                }

                self?.toggleEmptyTiles(for: blockID)
                NSApplication.shared.terminate(nil)
            }
            return
        }

        if CommandLine.arguments.contains("--lock-block-smoke") {
            DispatchQueue.main.async { [weak self] in
                guard let blockID = self?.state.blocks.first?.id else {
                    NSApplication.shared.terminate(nil)
                    return
                }

                self?.toggleLock(for: blockID)
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

        if CommandLine.arguments.contains("--add-tile-smoke") {
            DispatchQueue.main.async { [weak self] in
                guard let blockID = self?.state.blocks.first?.id else {
                    NSApplication.shared.terminate(nil)
                    return
                }

                self?.addTile(to: blockID)
                NSApplication.shared.terminate(nil)
            }
            return
        }

        if CommandLine.arguments.contains("--delete-tile-smoke") {
            DispatchQueue.main.async { [weak self] in
                guard let blockID = self?.state.blocks.first?.id else {
                    NSApplication.shared.terminate(nil)
                    return
                }

                self?.deleteTile(from: blockID)
                NSApplication.shared.terminate(nil)
            }
            return
        }

        if let folderPath = commandLineValue(after: "--add-folder-smoke") {
            DispatchQueue.main.async { [weak self] in
                guard let blockID = self?.state.blocks.first?.id else {
                    NSApplication.shared.terminate(nil)
                    return
                }

                let tileIndex = self?.commandLineInt(after: "--tile-index") ?? 0
                self?.placeFolderReference(
                    folderURL: URL(fileURLWithPath: folderPath, isDirectory: true),
                    in: blockID,
                    at: tileIndex
                )
                NSApplication.shared.terminate(nil)
            }
            return
        }

        if CommandLine.arguments.contains("--remove-folder-smoke") {
            DispatchQueue.main.async { [weak self] in
                guard let blockID = self?.state.blocks.first?.id else {
                    NSApplication.shared.terminate(nil)
                    return
                }

                let tileIndex = self?.commandLineInt(after: "--tile-index") ?? 0
                self?.removeFolderReference(from: blockID, at: tileIndex)
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

    func applicationWillTerminate(_ notification: Notification) {
        updateStateFromAllWindows(save: true)
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard
            let blockID = blockID(for: sender),
            let currentBlock = state.block(id: blockID)
        else {
            return frameSize
        }

        guard !currentBlock.isLocked else {
            return sender.frame.size
        }

        let proposedFrame = NSRect(origin: sender.frame.origin, size: frameSize)
        let proposedContent = sender.contentRect(forFrameRect: proposedFrame)
        let snapped = PrototypeGeometry.metrics.snappedSize(
            for: BlockSize(proposedContent.size),
            containingAtLeastTileCount: currentBlock.tileCount,
            fittingWithin: maximumContentSize(for: sender)
        )
        let snappedFrame = sender.frameRect(
            forContentRect: NSRect(origin: .zero, size: snapped.size.nsSize)
        )

        return snappedFrame.size
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        guard !isLocked(window: window) else {
            enforceLockedFrame(for: window)
            return
        }

        updateState(from: window, save: false)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        guard !isLocked(window: window) else {
            enforceLockedFrame(for: window)
            return
        }

        applySnappedFrameIfNeeded(to: window)
        keepWindowInsideVisibleScreen(window)
        updateState(from: window, save: true)
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        guard !isLocked(window: window) else {
            enforceLockedFrame(for: window)
            return
        }

        keepWindowInsideVisibleScreen(window)
        updateState(from: window, save: true)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return true
        }

        guard
            let blockID = selectedBlockID(),
            let block = state.block(id: blockID)
        else {
            return action == #selector(createNewBlock(_:))
        }

        switch action {
        case #selector(toggleSelectedBlockEmptyTiles(_:)):
            menuItem.state = block.hidesEmptyTiles ? .on : .off
            return true
        case #selector(toggleSelectedBlockLock(_:)):
            menuItem.state = block.isLocked ? .on : .off
            return true
        case #selector(addTileToSelectedBlock(_:)), #selector(deleteTileFromSelectedBlock(_:)):
            return !block.isLocked
        default:
            return true
        }
    }

    func windowWillClose(_ notification: Notification) {
        updateStateFromAllWindows(save: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !state.blocks.isEmpty
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

    private func commandLineInt(after flag: String) -> Int? {
        commandLineValue(after: flag).flatMap(Int.init)
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
        let titleColorItem = NSMenuItem(
            title: "Title Color...",
            action: #selector(editSelectedBlockTitleColor(_:)),
            keyEquivalent: ""
        )
        let hideEmptyTilesItem = NSMenuItem(
            title: "Hide Empty Tiles",
            action: #selector(toggleSelectedBlockEmptyTiles(_:)),
            keyEquivalent: ""
        )
        let lockBlockItem = NSMenuItem(
            title: "Lock Block",
            action: #selector(toggleSelectedBlockLock(_:)),
            keyEquivalent: ""
        )
        let addTileItem = NSMenuItem(
            title: "Add Tile",
            action: #selector(addTileToSelectedBlock(_:)),
            keyEquivalent: ""
        )
        let deleteTileItem = NSMenuItem(
            title: "Delete Tile",
            action: #selector(deleteTileFromSelectedBlock(_:)),
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
        titleColorItem.target = self
        hideEmptyTilesItem.target = self
        lockBlockItem.target = self
        addTileItem.target = self
        deleteTileItem.target = self
        removeBlockItem.target = self
        editMenu.addItem(renameBlockItem)
        editMenu.addItem(titleColorItem)
        editMenu.addItem(hideEmptyTilesItem)
        editMenu.addItem(lockBlockItem)
        editMenu.addItem(.separator())
        editMenu.addItem(addTileItem)
        editMenu.addItem(deleteTileItem)
        editMenu.addItem(.separator())
        editMenu.addItem(removeBlockItem)
        editMenuItem.submenu = editMenu

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        mainMenu.addItem(editMenuItem)
        NSApplication.shared.mainMenu = mainMenu
    }

    private func loadInitialState() -> DeskBlocksState {
        let maximumViewportSize = maximumTileViewportContentSize()

        guard let loadedState = store.load() else {
            return DeskBlocksState.prototypeDefault()
                .snapped(metrics: PrototypeGeometry.metrics, fittingWithin: maximumViewportSize)
        }

        return loadedState.snapped(metrics: PrototypeGeometry.metrics, fittingWithin: maximumViewportSize)
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
        let blockView = DeskBlockView(state: block)
        blockView.requestRename = { [weak self] blockID in
            self?.showRenameDialog(for: blockID)
        }
        blockView.requestRemove = { [weak self] blockID in
            self?.showRemoveConfirmation(for: blockID)
        }
        blockView.requestEditTitleColor = { [weak self] blockID in
            self?.showTitleColorPanel(for: blockID)
        }
        blockView.requestToggleEmptyTiles = { [weak self] blockID in
            self?.toggleEmptyTiles(for: blockID)
        }
        blockView.requestToggleLock = { [weak self] blockID in
            self?.toggleLock(for: blockID)
        }
        blockView.requestAddTile = { [weak self] blockID in
            self?.addTile(to: blockID)
        }
        blockView.requestDeleteTile = { [weak self] blockID in
            self?.deleteTile(from: blockID)
        }
        blockView.requestChooseFolder = { [weak self] blockID, tileIndex in
            self?.showChooseFolderPanel(for: blockID, tileIndex: tileIndex)
        }
        blockView.requestPlaceFolder = { [weak self] blockID, tileIndex, folderURL in
            self?.placeFolderReference(folderURL: folderURL, in: blockID, at: tileIndex)
        }
        blockView.requestOpenFolder = { [weak self] blockID, tileIndex in
            self?.openFolderReference(in: blockID, at: tileIndex)
        }
        blockView.requestRemoveFolderReference = { [weak self] blockID, tileIndex in
            self?.removeFolderReference(from: blockID, at: tileIndex)
        }
        blockView.requestEditFolderNote = { [weak self] blockID, tileIndex in
            self?.showFolderNoteDialog(for: blockID, tileIndex: tileIndex)
        }
        blockView.requestRemoveFolderNote = { [weak self] blockID, tileIndex in
            self?.updateFolderNote(nil, in: blockID, at: tileIndex)
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
        window.minSize = minimumFrameSize(for: block, in: window)
        window.delegate = self
        window.contentView = blockView
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        applyWindowInteraction(for: block, to: window)
        window.makeKeyAndOrderFront(nil)

        windowsByBlockID[block.id] = window
        blockViewsByBlockID[block.id] = blockView
    }

    private func minimumFrameSize(for block: DeskBlockState, in window: NSWindow) -> NSSize {
        let minimumContentSize = PrototypeGeometry.metrics.contentSize(
            columns: PrototypeGeometry.metrics.minimumColumns,
            rows: PrototypeGeometry.metrics.minimumRows
        )

        return window.frameRect(forContentRect: NSRect(origin: .zero, size: minimumContentSize.nsSize)).size
    }

    private func maximumContentSize(for window: NSWindow) -> BlockSize? {
        guard let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame else {
            return maximumTileViewportContentSize()
        }

        let maximumViewportSize = maximumTileViewportContentSize()
        let maxFrameSize = screenFrame.size
        let maxContentRect = window.contentRect(
            forFrameRect: NSRect(origin: .zero, size: maxFrameSize)
        )

        return BlockSize(
            width: min(maxContentRect.width, maximumViewportSize.width),
            height: min(maxContentRect.height, maximumViewportSize.height)
        )
    }

    private func maximumTileViewportContentSize() -> BlockSize {
        PrototypeGeometry.metrics.contentSize(
            columns: PrototypeGeometry.maximumVisibleColumns,
            rows: PrototypeGeometry.maximumVisibleRows
        )
    }

    private func keepWindowInsideVisibleScreen(_ window: NSWindow) {
        guard let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame else {
            return
        }

        var frame = window.frame

        if frame.width > visibleFrame.width {
            frame.size.width = visibleFrame.width
        }
        if frame.height > visibleFrame.height {
            frame.size.height = visibleFrame.height
        }

        if frame.minX < visibleFrame.minX {
            frame.origin.x = visibleFrame.minX
        }
        if frame.maxX > visibleFrame.maxX {
            frame.origin.x = visibleFrame.maxX - frame.width
        }
        if frame.minY < visibleFrame.minY {
            frame.origin.y = visibleFrame.minY
        }
        if frame.maxY > visibleFrame.maxY {
            frame.origin.y = visibleFrame.maxY - frame.height
        }

        guard frame != window.frame else {
            return
        }

        window.setFrame(frame, display: true)
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

        state = state
            .appending(block: newBlock)
            .snapped(
                metrics: PrototypeGeometry.metrics,
                fittingWithin: maximumTileViewportContentSize()
            )
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
                size: PrototypeGeometry.metrics.contentSize(
                    columns: min(layout.columns, PrototypeGeometry.maximumVisibleColumns),
                    rows: min(layout.rows, PrototypeGeometry.maximumVisibleRows)
                )
            ),
            columns: min(layout.columns, PrototypeGeometry.maximumVisibleColumns),
            rows: min(layout.rows, PrototypeGeometry.maximumVisibleRows),
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

    @objc private func editSelectedBlockTitleColor(_ sender: Any?) {
        guard let blockID = selectedBlockID() else {
            NSSound.beep()
            return
        }

        showTitleColorPanel(for: blockID)
    }

    @objc private func toggleSelectedBlockEmptyTiles(_ sender: Any?) {
        guard let blockID = selectedBlockID() else {
            NSSound.beep()
            return
        }

        toggleEmptyTiles(for: blockID)
    }

    @objc private func toggleSelectedBlockLock(_ sender: Any?) {
        guard let blockID = selectedBlockID() else {
            NSSound.beep()
            return
        }

        toggleLock(for: blockID)
    }

    @objc private func addTileToSelectedBlock(_ sender: Any?) {
        guard let blockID = selectedBlockID() else {
            NSSound.beep()
            return
        }

        addTile(to: blockID)
    }

    @objc private func deleteTileFromSelectedBlock(_ sender: Any?) {
        guard let blockID = selectedBlockID() else {
            NSSound.beep()
            return
        }

        deleteTile(from: blockID)
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

    private func configureTitleColorPanel() {
        titleColorPanel.setTarget(self)
        titleColorPanel.setAction(#selector(titleColorPanelChanged(_:)))
        titleColorPanel.isContinuous = true
        titleColorPanel.showsAlpha = true
    }

    private func showTitleColorPanel(for blockID: DeskBlockID) {
        guard let block = state.block(id: blockID) else {
            return
        }

        titleColorEditingBlockID = blockID
        titleColorPanel.color = block.titleColor.nsColor
        titleColorPanel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func titleColorPanelChanged(_ sender: NSColorPanel) {
        guard let blockID = titleColorEditingBlockID else {
            return
        }

        updateTitleColor(for: blockID, to: BlockColor(sender.color))
    }

    private func updateTitleColor(for blockID: DeskBlockID, to proposedColor: BlockColor) {
        guard let currentBlock = state.block(id: blockID) else {
            return
        }

        let updatedBlock = currentBlock.withTitleColor(proposedColor)

        guard updatedBlock != currentBlock else {
            return
        }

        update(block: updatedBlock)
    }

    private func toggleEmptyTiles(for blockID: DeskBlockID) {
        guard let currentBlock = state.block(id: blockID) else {
            return
        }

        update(block: currentBlock.withEmptyTilesHidden(!currentBlock.hidesEmptyTiles))
    }

    private func toggleLock(for blockID: DeskBlockID) {
        guard let currentBlock = state.block(id: blockID) else {
            return
        }

        update(block: currentBlock.withLocked(!currentBlock.isLocked))
    }

    private func addTile(to blockID: DeskBlockID) {
        guard let currentBlock = state.block(id: blockID) else {
            return
        }

        guard !currentBlock.isLocked else {
            NSSound.beep()
            return
        }

        update(block: currentBlock.addingTile(metrics: PrototypeGeometry.metrics))
    }

    private func deleteTile(from blockID: DeskBlockID) {
        guard let currentBlock = state.block(id: blockID) else {
            return
        }

        guard !currentBlock.isLocked else {
            NSSound.beep()
            return
        }

        let updatedBlock = currentBlock.removingTile(metrics: PrototypeGeometry.metrics)

        guard updatedBlock != currentBlock else {
            NSSound.beep()
            return
        }

        update(block: updatedBlock)
    }

    private func showChooseFolderPanel(for blockID: DeskBlockID, tileIndex: Int) {
        guard
            state.block(id: blockID) != nil,
            let window = windowsByBlockID[blockID]
        else {
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Choose"
        panel.message = "Choose a folder for this DeskBlocks tile."
        panel.directoryURL = FileManager.default.urls(
            for: .desktopDirectory,
            in: .userDomainMask
        ).first

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let folderURL = panel.url else {
                return
            }

            self?.placeFolderReference(folderURL: folderURL, in: blockID, at: tileIndex)
        }
    }

    private func placeFolderReference(folderURL: URL, in blockID: DeskBlockID, at tileIndex: Int) {
        guard let currentBlock = state.block(id: blockID) else {
            return
        }

        do {
            let bookmarkData = try folderURL.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let displayName = FileManager.default.displayName(atPath: folderURL.path)
            let reference = TileReference(
                id: UUID().uuidString,
                tileIndex: tileIndex,
                displayName: displayName.isEmpty ? folderURL.lastPathComponent : displayName,
                folderReference: FolderReference(
                    bookmarkDataBase64: bookmarkData.base64EncodedString(),
                    lastKnownPath: folderURL.path
                )
            )

            let updatedBlock = currentBlock.placingTileReference(reference, at: tileIndex)

            guard updatedBlock != currentBlock else {
                NSSound.beep()
                return
            }

            update(block: updatedBlock)
        } catch {
            fputs("DeskBlocksPrototype: failed to create folder bookmark: \(error)\n", stderr)
            NSSound.beep()
        }
    }

    private func openFolderReference(in blockID: DeskBlockID, at tileIndex: Int) {
        guard
            let tileReference = state.block(id: blockID)?.tileReference(at: tileIndex),
            let folderURL = resolvedFolderURL(for: tileReference)
        else {
            NSSound.beep()
            return
        }

        NSWorkspace.shared.open(folderURL)
    }

    private func removeFolderReference(from blockID: DeskBlockID, at tileIndex: Int) {
        guard let currentBlock = state.block(id: blockID) else {
            return
        }

        let updatedBlock = currentBlock.removingTileReference(at: tileIndex)

        guard updatedBlock != currentBlock else {
            NSSound.beep()
            return
        }

        update(block: updatedBlock)
    }

    private func showFolderNoteDialog(for blockID: DeskBlockID, tileIndex: Int) {
        guard
            let block = state.block(id: blockID),
            let tileReference = block.tileReference(at: tileIndex),
            let window = windowsByBlockID[blockID]
        else {
            return
        }

        let alert = NSAlert()
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 140))
        let textView = NSTextView(frame: scrollView.bounds)

        alert.messageText = tileReference.note == nil ? "Notiz hinzufügen" : "Notiz bearbeiten"
        alert.informativeText = "Beschreibung für \"\(tileReference.displayName)\"."
        alert.addButton(withTitle: "Speichern")
        alert.addButton(withTitle: "Abbrechen")

        textView.string = tileReference.note ?? ""
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true

        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        alert.accessoryView = scrollView
        window.makeFirstResponder(textView)

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else {
                return
            }

            self?.updateFolderNote(textView.string, in: blockID, at: tileIndex)
        }
    }

    private func updateFolderNote(_ note: String?, in blockID: DeskBlockID, at tileIndex: Int) {
        guard let currentBlock = state.block(id: blockID) else {
            return
        }

        let updatedBlock = currentBlock.updatingTileReferenceNote(note, at: tileIndex)

        guard updatedBlock != currentBlock else {
            return
        }

        update(block: updatedBlock)
    }

    private func resolvedFolderURL(for tileReference: TileReference) -> URL? {
        guard let bookmarkData = Data(base64Encoded: tileReference.folderReference.bookmarkDataBase64) else {
            return fallbackFolderURL(for: tileReference)
        }

        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            return resolvedURL
        } catch {
            fputs("DeskBlocksPrototype: failed to resolve folder bookmark: \(error)\n", stderr)
            return fallbackFolderURL(for: tileReference)
        }
    }

    private func fallbackFolderURL(for tileReference: TileReference) -> URL? {
        let path = tileReference.folderReference.lastKnownPath

        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func update(block updatedBlock: DeskBlockState) {
        guard let window = windowsByBlockID[updatedBlock.id] else {
            return
        }

        let maximumSize = maximumContentSize(for: window)
        let normalizedBlock = updatedBlock.snapped(
            metrics: PrototypeGeometry.metrics,
            proposedSize: updatedBlock.frame.size,
            fittingWithin: maximumSize
        )

        state = state.updating(block: normalizedBlock)
        blockViewsByBlockID[normalizedBlock.id]?.state = normalizedBlock
        window.title = normalizedBlock.title
        window.minSize = minimumFrameSize(for: normalizedBlock, in: window)
        applyWindowInteraction(for: normalizedBlock, to: window)

        let contentRect = window.contentRect(forFrameRect: window.frame)
        let minimumContentSize = PrototypeGeometry.metrics.snappedSize(
            for: BlockSize(contentRect.size),
            containingAtLeastTileCount: normalizedBlock.tileCount,
            fittingWithin: maximumSize
        ).size

        if BlockSize(contentRect.size) != minimumContentSize {
            let nextFrame = window.frameRect(
                forContentRect: NSRect(origin: contentRect.origin, size: minimumContentSize.nsSize)
            )
            window.setFrame(nextFrame, display: true)
        }

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
        if titleColorEditingBlockID == blockID {
            titleColorEditingBlockID = nil
        }
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

    private func selectedBlockID() -> DeskBlockID? {
        guard let keyWindow = NSApplication.shared.keyWindow else {
            return nil
        }

        return blockID(for: keyWindow)
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

        guard !currentBlock.isLocked else {
            enforceLockedFrame(for: window)
            return
        }

        let contentRect = window.contentRect(forFrameRect: window.frame)
        let origin = BlockPoint(contentRect.origin)
        let snapped = PrototypeGeometry.metrics.snappedSize(
            for: BlockSize(contentRect.size),
            containingAtLeastTileCount: currentBlock.tileCount,
            fittingWithin: maximumContentSize(for: window)
        )

        let updatedBlock = currentBlock.snapped(
            metrics: PrototypeGeometry.metrics,
            origin: origin,
            proposedSize: snapped.size,
            fittingWithin: maximumContentSize(for: window)
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
        guard let currentBlock = state.block(id: blockID) else {
            return
        }

        let snapped = PrototypeGeometry.metrics.snappedSize(
            for: BlockSize(contentRect.size),
            containingAtLeastTileCount: currentBlock.tileCount,
            fittingWithin: maximumContentSize(for: window)
        )

        guard snapped.size != BlockSize(contentRect.size) else {
            return
        }

        let snappedContentRect = NSRect(origin: contentRect.origin, size: snapped.size.nsSize)
        let snappedFrame = window.frameRect(forContentRect: snappedContentRect)

        blockIDsApplyingSnappedFrame.insert(blockID)
        window.setFrame(snappedFrame, display: true)
        blockIDsApplyingSnappedFrame.remove(blockID)
    }

    private func applyWindowInteraction(for block: DeskBlockState, to window: NSWindow) {
        if block.isLocked {
            window.styleMask.remove(.resizable)
        } else {
            window.styleMask.insert(.resizable)
        }

        window.isMovableByWindowBackground = !block.isLocked
        window.minSize = minimumFrameSize(for: block, in: window)
    }

    private func isLocked(window: NSWindow) -> Bool {
        guard let blockID = blockID(for: window) else {
            return false
        }

        return state.block(id: blockID)?.isLocked == true
    }

    private func enforceLockedFrame(for window: NSWindow) {
        guard
            let blockID = blockID(for: window),
            let block = state.block(id: blockID)
        else {
            return
        }

        let storedFrame = window.frameRect(forContentRect: block.frame.contentRect)

        guard window.frame != storedFrame else {
            return
        }

        window.setFrame(storedFrame, display: true)
    }

    private func blockColor(from argument: String) -> BlockColor? {
        let components = argument
            .split(separator: ",")
            .map { substring in
                Double(substring.trimmingCharacters(in: .whitespaces))
            }

        guard components.count == 4, components.allSatisfy({ $0 != nil }) else {
            return nil
        }

        return BlockColor(
            red: components[0] ?? 1,
            green: components[1] ?? 1,
            blue: components[2] ?? 1,
            alpha: components[3] ?? 1
        )
    }
}
