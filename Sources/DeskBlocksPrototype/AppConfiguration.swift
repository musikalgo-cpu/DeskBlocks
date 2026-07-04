import AppKit
import CoreGraphics
import DeskBlocksCore

enum OverlayWindowConfiguration {
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

enum PrototypeGeometry {
    static let metrics = TileGridMetrics.prototype
    static let maximumVisibleColumns = 10
    static let maximumVisibleRows = 10

    static var tileWidth: CGFloat { CGFloat(metrics.tileWidth) }
    static var tileHeight: CGFloat { CGFloat(metrics.tileHeight) }
    static var titleHeight: CGFloat { CGFloat(metrics.titleHeight) }
    static var padding: CGFloat { CGFloat(metrics.padding) }
}

extension BlockPoint {
    init(_ point: NSPoint) {
        self.init(x: point.x, y: point.y)
    }
}

extension BlockSize {
    init(_ size: NSSize) {
        self.init(width: size.width, height: size.height)
    }

    var nsSize: NSSize {
        NSSize(width: width, height: height)
    }
}

extension BlockFrame {
    var contentRect: NSRect {
        NSRect(
            x: origin.x,
            y: origin.y,
            width: size.width,
            height: size.height
        )
    }
}

extension BlockColor {
    init(_ color: NSColor) {
        let resolvedColor = color.usingColorSpace(.deviceRGB) ?? NSColor.white

        self.init(
            red: resolvedColor.redComponent,
            green: resolvedColor.greenComponent,
            blue: resolvedColor.blueComponent,
            alpha: resolvedColor.alphaComponent
        )
    }

    var nsColor: NSColor {
        NSColor(
            calibratedRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
}
