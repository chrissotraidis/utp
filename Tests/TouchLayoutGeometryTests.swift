import Foundation
import CoreGraphics

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("UT99 touch geometry FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func near(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.02) -> Bool {
    abs(lhs - rhs) <= tolerance
}

private let actionIDs: Set<String> = [
    "primaryFire", "alternateFire", "jump", "crouch", "use",
    "nextWeapon", "previousWeapon", "scoreboard", "pause",
]

private func verifyContained(_ frames: [String: CGRect], in safe: CGRect, name: String) {
    require(Set(frames.keys) == actionIDs.union(["move", "look"]), "\(name) semantic controls changed")
    for (id, frame) in frames {
        // EctoPad's phone D-pad uses a 36pt reference scaled to the safe
        // 800x380 canvas; the 874x402 notched reference resolves to 34.02pt.
        require(frame.width >= 34 && frame.height >= 34, "\(name) \(id) target is too small: \(frame)")
        require(safe.contains(frame), "\(name) \(id) leaves safe bounds: \(frame)")
    }
}

private func verifyMirror(
    right: [String: CGRect],
    left: [String: CGRect],
    safe: CGRect,
    name: String
) {
    for id in right.keys {
        guard let rightFrame = right[id], let leftFrame = left[id] else {
            require(false, "\(name) mirror lost \(id)")
            continue
        }
        require(near(rightFrame.midX + leftFrame.midX, safe.minX + safe.maxX),
                "\(name) \(id) did not mirror horizontally")
        require(near(rightFrame.midY, leftFrame.midY), "\(name) \(id) changed vertical placement")
        require(rightFrame.size == leftFrame.size, "\(name) \(id) changed size when mirrored")
    }
}

let tabletSafe = CGRect(x: 0, y: 20, width: 1180, height: 780)
let tablet = UT99EctoPadReferenceLayout.tabletFrames(
    safeRect: tabletSafe,
    scale: 1,
    leftHanded: false
)
let tabletLeft = UT99EctoPadReferenceLayout.tabletFrames(
    safeRect: tabletSafe,
    scale: 1,
    leftHanded: true
)
verifyContained(tablet, in: tabletSafe, name: "iPad")
verifyContained(tabletLeft, in: tabletSafe, name: "iPad southpaw")
verifyMirror(right: tablet, left: tabletLeft, safe: tabletSafe, name: "iPad")

require(near(tablet["move"]!.midX / tabletSafe.width, 0.1310395315), "iPad move X drifted from EctoPad")
require(near((tablet["move"]!.midY - tabletSafe.minY) / tabletSafe.height, 0.7905894519), "iPad move Y drifted")
require(tablet["move"]!.width == 172, "iPad movement stick size drifted")
require(tablet["look"]!.width == 112, "iPad aim stick size drifted")
require(tablet["primaryFire"]!.width == 104, "iPad FIRE hierarchy drifted")
require(tablet["alternateFire"]!.width == 76, "iPad ALT hierarchy drifted")
require(tablet["jump"]!.width == 62 && tablet["crouch"]!.width == 62,
        "iPad utility button hierarchy drifted")
require(tablet["pause"]!.width == 116 && tablet["pause"]!.height == 62,
        "iPad MENU pill drifted")

// EctoPad's A/B/X/Y face cluster intentionally overlaps like a physical
// GameCube face. Guard the exact hierarchy instead of flattening it through the
// generic imported-profile collision solver.
require(tablet["primaryFire"]!.intersects(tablet["alternateFire"]!),
        "iPad face cluster drifted away from EctoPad")
require(tablet["primaryFire"]!.midY < tablet["look"]!.midY,
        "iPad FIRE must remain above the aim stick")
require(tablet["alternateFire"]!.midX < tablet["primaryFire"]!.midX,
        "iPad ALT must remain left of FIRE")

let d = tablet["scoreboard"]!.width
require(near(tablet["scoreboard"]!.midX, tablet["use"]!.midX), "D-pad vertical axis split")
require(near(tablet["use"]!.midY - tablet["scoreboard"]!.midY, d * 2), "D-pad vertical spacing drifted")
require(near(tablet["nextWeapon"]!.midX - tablet["previousWeapon"]!.midX, d * 2),
        "D-pad weapon-cycle spacing drifted")
require(near(tablet["nextWeapon"]!.midY, tablet["previousWeapon"]!.midY),
        "D-pad weapon-cycle axis split")
require(tablet["nextWeapon"]!.width == d && tablet["previousWeapon"]!.width == d,
        "D-pad weapon controls lost their compact hierarchy")

let phoneSafe = CGRect(x: 59, y: 0, width: 756, height: 381)
let phone = UT99EctoPadReferenceLayout.phoneFrames(
    safeRect: phoneSafe,
    profileScale: 1,
    leftHanded: false
)
let phoneLeft = UT99EctoPadReferenceLayout.phoneFrames(
    safeRect: phoneSafe,
    profileScale: 1,
    leftHanded: true
)
verifyContained(phone, in: phoneSafe, name: "iPhone")
verifyContained(phoneLeft, in: phoneSafe, name: "iPhone southpaw")
verifyMirror(right: phone, left: phoneLeft, safe: phoneSafe, name: "iPhone")
require(phone["move"]!.width > phone["look"]!.width, "phone stick hierarchy collapsed")
require(phone["primaryFire"]!.width > phone["alternateFire"]!.width, "phone fire hierarchy collapsed")

// Preserve coverage for the generic custom-placement collision solver used by
// imported profiles and editor scaling.
let customControls = [
    UT99TouchControlGeometry(id: "a", center: CGPoint(x: 80, y: 80), baseDiameter: 60),
    UT99TouchControlGeometry(id: "b", center: CGPoint(x: 180, y: 80), baseDiameter: 60),
]
let fitted = UT99TouchLayoutGeometry.fittedScale(
    desiredScale: 1.5,
    canvasSize: CGSize(width: 260, height: 160),
    safeInsets: .zero,
    controls: customControls
)
let customFrames = UT99TouchLayoutGeometry.frames(scale: fitted, controls: customControls)
require(UT99TouchLayoutGeometry.collisionPairs(in: customFrames).isEmpty, "custom placement solver regressed")

print("UT99 reference touch geometry PASS controls=11 tablet=true phone=true southpaw=true")
