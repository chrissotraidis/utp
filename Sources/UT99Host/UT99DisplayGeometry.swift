import CoreGraphics

/// The engine's startup canvas, measured from the window that hosts the game
/// rather than from the device's main screen.
struct UT99EngineCanvas: Equatable {
    var width: Int
    var height: Int
    var backingScale: CGFloat
}

enum UT99DisplayGeometry {
    /// UT99 runs landscape-only. The owning window can report portrait bounds
    /// before its first landscape layout, so order the edges. Values stay in
    /// points; Metal applies the backing scale to the drawable.
    static func engineCanvas(windowSize: CGSize, backingScale: CGFloat) -> UT99EngineCanvas? {
        guard windowSize.width.isFinite, windowSize.height.isFinite,
              windowSize.width >= 1, windowSize.height >= 1 else { return nil }
        let shortEdge = floor(min(windowSize.width, windowSize.height))
        let longEdge = max(shortEdge, floor(max(windowSize.width, windowSize.height)))
        return UT99EngineCanvas(
            width: Int(longEdge),
            height: Int(shortEdge),
            backingScale: backingScale.isFinite && backingScale > 0 ? backingScale : 1
        )
    }
}
