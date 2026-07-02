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

    func load() -> DeskBlockState? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(DeskBlockState.self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        } catch {
            fputs("DeskBlocksPrototype: failed to load state: \(error)\n", stderr)
            return nil
        }
    }

    func save(_ state: DeskBlockState) {
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

    init(state: DeskBlockState) {
        self.state = state
        super.init(frame: NSRect(origin: .zero, size: state.frame.size.nsSize))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

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
        let titleRect = NSRect(
            x: PrototypeGeometry.padding,
            y: PrototypeGeometry.padding,
            width: bounds.width - PrototypeGeometry.padding * 2,
            height: PrototypeGeometry.titleHeight
        )

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

    private func drawTileGrid() {
        let originX = PrototypeGeometry.padding
        let originY = PrototypeGeometry.padding + PrototypeGeometry.titleHeight

        for row in 0..<state.rows {
            for column in 0..<state.columns {
                drawTile(row: row, column: column, originX: originX, originY: originY)
            }
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
    private var state = DeskBlockState.prototypeDefault()
    private var window: NSWindow?
    private var blockView: DeskBlockView?
    private var isApplyingSnappedFrame = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        state = store.load() ?? DeskBlockState.prototypeDefault()
        state = state.snapped(metrics: PrototypeGeometry.metrics)

        let window = NSWindow(
            contentRect: state.frame.contentRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let minimumContentSize = PrototypeGeometry.metrics.contentSize(columns: 1, rows: 1)
        let minimumFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: minimumContentSize.nsSize)).size
        let blockView = DeskBlockView(state: state)

        window.title = state.title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.canHide = false
        window.level = OverlayWindowConfiguration.level
        window.collectionBehavior = OverlayWindowConfiguration.collectionBehavior
        window.minSize = minimumFrameSize
        window.delegate = self
        window.contentView = blockView
        window.makeKeyAndOrderFront(nil)

        self.window = window
        self.blockView = blockView
        store.save(state)
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateStateFromWindow(save: true)
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
        updateStateFromWindow(save: false)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        applySnappedFrameIfNeeded()
        updateStateFromWindow(save: true)
    }

    func windowDidMove(_ notification: Notification) {
        updateStateFromWindow(save: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func updateStateFromWindow(save: Bool) {
        guard let window else {
            return
        }

        let contentRect = window.contentRect(forFrameRect: window.frame)
        let origin = BlockPoint(contentRect.origin)
        let snapped = PrototypeGeometry.metrics.snappedSize(for: BlockSize(contentRect.size))

        state = state.snapped(
            metrics: PrototypeGeometry.metrics,
            origin: origin,
            proposedSize: snapped.size
        )
        blockView?.state = state

        if save {
            store.save(state)
        }
    }

    private func applySnappedFrameIfNeeded() {
        guard let window, !isApplyingSnappedFrame else {
            return
        }

        let contentRect = window.contentRect(forFrameRect: window.frame)
        let snapped = PrototypeGeometry.metrics.snappedSize(for: BlockSize(contentRect.size))

        guard snapped.size != BlockSize(contentRect.size) else {
            return
        }

        let snappedContentRect = NSRect(origin: contentRect.origin, size: snapped.size.nsSize)
        let snappedFrame = window.frameRect(forContentRect: snappedContentRect)

        isApplyingSnappedFrame = true
        window.setFrame(snappedFrame, display: true)
        isApplyingSnappedFrame = false
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
