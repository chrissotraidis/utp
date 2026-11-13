import CoreGraphics
import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        FileHandle.standardError.write(Data("display geometry test failed: \(message)\n".utf8))
        exit(1)
    }
}

// A full-screen landscape iPad window supplies its own dimensions.
expect(UT99DisplayGeometry.engineCanvas(windowSize: CGSize(width: 1194, height: 834), backingScale: 2)
       == UT99EngineCanvas(width: 1194, height: 834, backingScale: 2), "landscape window")

// A window measured before its first landscape layout is ordered, not stretched.
expect(UT99DisplayGeometry.engineCanvas(windowSize: CGSize(width: 390, height: 844), backingScale: 3)
       == UT99EngineCanvas(width: 844, height: 390, backingScale: 3), "portrait-measured window")

// A smaller window on another display uses that window and that display's scale,
// not the device's main screen.
expect(UT99DisplayGeometry.engineCanvas(windowSize: CGSize(width: 1920.6, height: 1080.4), backingScale: 1)
       == UT99EngineCanvas(width: 1920, height: 1080, backingScale: 1), "external-display window")

// Without a measured window the configured viewport is left alone.
expect(UT99DisplayGeometry.engineCanvas(windowSize: .zero, backingScale: 2) == nil, "unmeasured window")
expect(UT99DisplayGeometry.engineCanvas(windowSize: CGSize(width: 800, height: 600), backingScale: 0)?.backingScale == 1,
       "invalid scale falls back to 1")

print("display geometry tests passed")
