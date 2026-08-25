import Foundation
import CoreGraphics

struct UT99TouchInsets: Equatable {
    var top: CGFloat
    var left: CGFloat
    var bottom: CGFloat
    var right: CGFloat

    static let zero = UT99TouchInsets(top: 0, left: 0, bottom: 0, right: 0)
}

struct UT99TouchControlGeometry {
    let id: String
    let center: CGPoint
    let baseDiameter: CGFloat
}

/// Pure geometry shared by UIKit and the host-side regression test. The editor
/// permits both a profile scale and a user scale; fitting those independently
/// against fixed centers can make valid settings overlap. This solver finds the
/// largest uniform multiplier that keeps every circular action target inside
/// the safe region with a measurable visual gap.
enum UT99TouchLayoutGeometry {
    static let minimumVisualGap: CGFloat = 12
    static let edgeMargin: CGFloat = 8

    static func mirroredCenter(
        _ center: CGPoint,
        canvasWidth: CGFloat,
        leftHanded: Bool
    ) -> CGPoint {
        guard leftHanded else { return center }
        return CGPoint(x: canvasWidth - center.x, y: center.y)
    }

    static func fittedScale(
        desiredScale: CGFloat,
        canvasSize: CGSize,
        safeInsets: UT99TouchInsets,
        controls: [UT99TouchControlGeometry]
    ) -> CGFloat {
        guard desiredScale > 0, canvasSize.width > 0, canvasSize.height > 0 else { return 0 }
        var maximum = desiredScale

        for control in controls where control.baseDiameter > 0 {
            let availableRadius = min(
                control.center.x - safeInsets.left - edgeMargin,
                canvasSize.width - safeInsets.right - edgeMargin - control.center.x,
                control.center.y - safeInsets.top - edgeMargin,
                canvasSize.height - safeInsets.bottom - edgeMargin - control.center.y
            )
            maximum = min(maximum, max(0, availableRadius * 2 / control.baseDiameter))
        }

        for firstIndex in controls.indices {
            for secondIndex in controls.indices where secondIndex > firstIndex {
                let first = controls[firstIndex]
                let second = controls[secondIndex]
                let distance = hypot(first.center.x - second.center.x, first.center.y - second.center.y)
                let combinedDiameter = first.baseDiameter + second.baseDiameter
                guard combinedDiameter > 0 else { continue }
                let pairLimit = max(0, (distance - minimumVisualGap) * 2 / combinedDiameter)
                maximum = min(maximum, pairLimit)
            }
        }

        return max(0, maximum)
    }

    static func frames(
        scale: CGFloat,
        controls: [UT99TouchControlGeometry]
    ) -> [String: CGRect] {
        var result: [String: CGRect] = [:]
        for control in controls {
            let diameter = control.baseDiameter * scale
            let radius = diameter / 2
            let originX = control.center.x - radius
            let originY = control.center.y - radius
            let origin = CGPoint(x: originX, y: originY)
            let size = CGSize(width: diameter, height: diameter)
            result[control.id] = CGRect(origin: origin, size: size)
        }
        return result
    }

    static func collisionPairs(in frames: [String: CGRect]) -> [(String, String)] {
        let entries = frames.sorted { $0.key < $1.key }
        var collisions: [(String, String)] = []
        for firstIndex in entries.indices {
            for secondIndex in entries.indices where secondIndex > firstIndex {
                let first = entries[firstIndex]
                let second = entries[secondIndex]
                let firstCenter = CGPoint(
                    x: first.value.origin.x + first.value.size.width / 2,
                    y: first.value.origin.y + first.value.size.height / 2
                )
                let secondCenter = CGPoint(
                    x: second.value.origin.x + second.value.size.width / 2,
                    y: second.value.origin.y + second.value.size.height / 2
                )
                let distance = hypot(firstCenter.x - secondCenter.x, firstCenter.y - secondCenter.y)
                let required = first.value.size.width / 2 + second.value.size.width / 2 + minimumVisualGap
                if distance + 0.001 < required {
                    collisions.append((first.key, second.key))
                }
            }
        }
        return collisions
    }
}

/// Tablet adaptation of EctoPad's `SunPadGameOverlay.mm` at commit
/// 461de17f549d98742bc3b2d031156f79ab3eaa9d. The control sizes and thumb arc
/// retain the reference hierarchy, but UT's independent gameplay actions use
/// non-overlapping hit targets instead of the reference's physical-button
/// overlap.
enum UT99EctoPadReferenceLayout {
    static func tabletFrames(
        safeRect: CGRect,
        scale: CGFloat,
        leftHanded: Bool
    ) -> [String: CGRect] {
        func frame(_ id: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> (String, CGRect) {
            let center = CGPoint(x: safeRect.origin.x + x * safeRect.size.width,
                                 y: safeRect.origin.y + y * safeRect.size.height)
            // EctoPad's 280pt R trigger was authored against its wider iPad
            // reference. Preserve that size when possible and symmetrically
            // fit it on narrower split-view/simulator safe areas.
            let horizontalRoom = 2 * min(center.x - safeRect.minX, safeRect.maxX - center.x)
            let verticalRoom = 2 * min(center.y - safeRect.minY, safeRect.maxY - center.y)
            let size = CGSize(width: min(width * scale, horizontalRoom),
                              height: min(height * scale, verticalRoom))
            return (id, CGRect(x: center.x - size.width / 2,
                               y: center.y - size.height / 2,
                               width: size.width,
                               height: size.height))
        }

        let d = 48 * scale
        let dCenter = CGPoint(x: safeRect.origin.x + 0.2686676428 * safeRect.size.width,
                              y: safeRect.origin.y + 0.7947259566 * safeRect.size.height)
        var result = Dictionary(uniqueKeysWithValues: [
            frame("move", 0.1310395315, 0.7905894519, 172, 172),
            frame("look", 0.9152542373, 0.9038461538, 112, 112),
            frame("primaryFire", 0.8898305085, 0.7307692308, 104, 104),
            frame("alternateFire", 0.8093220339, 0.8076923077, 76, 76),
            frame("jump", 0.9661016949, 0.6858974359, 62, 62),
            frame("crouch", 0.9661016949, 0.7820512821, 62, 62),
            frame("pause", 0.8967789165, 0.5780765253, 116, 62),
            // UT has four low-frequency utility actions that map cleanly to
            // EctoPad's four-direction pad. Weapon cycling belongs on left /
            // right—not on the reference controller's giant analog trigger.
            ("previousWeapon", CGRect(x: dCenter.x - d * 1.5, y: dCenter.y - d / 2, width: d, height: d)),
            ("nextWeapon", CGRect(x: dCenter.x + d * 0.5, y: dCenter.y - d / 2, width: d, height: d)),
            ("scoreboard", CGRect(x: dCenter.x - d / 2, y: dCenter.y - d * 1.5, width: d, height: d)),
            ("use", CGRect(x: dCenter.x - d / 2, y: dCenter.y + d * 0.5, width: d, height: d)),
        ])
        if leftHanded { result = mirrored(result, in: safeRect) }
        return result
    }

    static func phoneFrames(
        safeRect: CGRect,
        profileScale: CGFloat,
        leftHanded: Bool
    ) -> [String: CGRect] {
        let minX = safeRect.origin.x
        let minY = safeRect.origin.y
        let maxX = safeRect.origin.x + safeRect.size.width
        let maxY = safeRect.origin.y + safeRect.size.height
        let midX = safeRect.origin.x + safeRect.size.width / 2
        let baseScale = min(1, min(safeRect.size.width / 800, safeRect.size.height / 380))
        let scale = baseScale * profileScale
        let margin = max(8, 18 * baseScale)
        let stick = 126 * scale
        let camera = 86 * scale
        let small = 46 * scale
        let medium = 58 * scale
        let large = 78 * scale

        let move = CGRect(x: minX + margin,
                          y: maxY - margin - stick,
                          width: stick, height: stick)
        let look = CGRect(x: maxX - margin - camera,
                          y: maxY - margin - camera,
                          width: camera, height: camera)
        let fire = CGRect(x: maxX - margin - large,
                          y: maxY - margin - camera - large - 18 * scale,
                          width: large, height: large)
        let alt = CGRect(x: fire.minX - medium - 12 * scale,
                         y: fire.midY + 8 - medium / 2,
                         width: medium, height: medium)
        let jump = CGRect(x: fire.midX - small / 2,
                          y: fire.minY - small - 10 * scale,
                          width: small, height: small)
        let crouch = CGRect(x: fire.minX - small - 8 * scale,
                            y: fire.minY - small + 8,
                            width: small, height: small)
        let d = 36 * scale
        let dCenter = CGPoint(x: move.maxX + 18 * scale + 1.5 * d, y: move.midY)
        let startWidth = 92 * scale
        var result: [String: CGRect] = [
            "move": move,
            "look": look,
            "primaryFire": fire,
            "alternateFire": alt,
            "jump": jump,
            "crouch": crouch,
            "pause": CGRect(x: midX - startWidth / 2,
                              y: minY + margin,
                              width: startWidth, height: small),
            "scoreboard": CGRect(x: dCenter.x - d / 2, y: dCenter.y - d * 1.5, width: d, height: d),
            "use": CGRect(x: dCenter.x - d / 2, y: dCenter.y + d * 0.5, width: d, height: d),
            "previousWeapon": CGRect(x: dCenter.x - d * 1.5, y: dCenter.y - d / 2, width: d, height: d),
            "nextWeapon": CGRect(x: dCenter.x + d * 0.5, y: dCenter.y - d / 2, width: d, height: d),
        ]
        if leftHanded { result = mirrored(result, in: safeRect) }
        return result
    }

    private static func mirrored(_ source: [String: CGRect], in safeRect: CGRect) -> [String: CGRect] {
        source.mapValues { frame in
            CGRect(x: safeRect.origin.x * 2 + safeRect.size.width - frame.origin.x - frame.size.width,
                   y: frame.origin.y,
                   width: frame.size.width,
                   height: frame.size.height)
        }
    }
}
