import Foundation

@main
private enum TouchConfigurationTests {
    static func main() {
        let suiteName = "UT99TouchConfigurationTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fail("defaults suite unavailable")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        require(UT99TouchConfiguration.load(from: defaults) == .standard, "standard configuration missing")
        var legacy = UT99TouchConfiguration.standard
        legacy.movementDeadZone = 0.28
        legacy.save(to: defaults)
        require(UT99TouchConfiguration.load(from: defaults).movementDeadZone == 0.04,
                "legacy movement response was not migrated")
        var legacyLook = UT99TouchConfiguration.standard
        legacyLook.lookDeadZone = 0.0025
        legacyLook.save(to: defaults)
        require(UT99TouchConfiguration.load(from: defaults).lookDeadZone == UT99TouchConfiguration.standard.lookDeadZone,
                "legacy floating-look dead zone was not migrated")
        var stored = UT99TouchConfiguration.standard
        stored.leftHanded = true
        stored.hiddenActions = ["scoreboard", "crouch"]
        stored.lookAcceleration = 0.8
        stored.lookDeadZone = 0.006
        stored.movementDeadZone = 0.22
        stored.autoHideForController = false
        stored.save(to: defaults)
        require(UT99TouchConfiguration.load(from: defaults) == stored, "configuration did not persist")

        var unsafe = stored
        unsafe.lookAcceleration = 99
        unsafe.lookDeadZone = -1
        unsafe.movementDeadZone = 2
        let clamped = unsafe.sanitized()
        require(clamped.lookAcceleration == 1.5, "acceleration upper bound missing")
        require(clamped.lookDeadZone == 0, "look dead-zone lower bound missing")
        require(clamped.movementDeadZone == 0.45, "movement dead-zone upper bound missing")

        let dead = UT99TouchInputTuning.transformedLook(
            CGPoint(x: 0.001, y: 0.001), sensitivity: 1,
            configuration: stored, invertY: false
        )
        require(dead.x == 0 && dead.y == 0, "look dead zone did not suppress drift")
        let slow = UT99TouchInputTuning.transformedLook(
            CGPoint(x: 0.02, y: 0.01), sensitivity: 1,
            configuration: stored, invertY: false
        )
        let fast = UT99TouchInputTuning.transformedLook(
            CGPoint(x: 0.20, y: 0.10), sensitivity: 1,
            configuration: stored, invertY: false
        )
        require(fast.x / 10 > slow.x, "acceleration did not increase fast-swipe gain")
        let inverted = UT99TouchInputTuning.transformedLook(
            CGPoint(x: 0.02, y: 0.01), sensitivity: 1,
            configuration: stored, invertY: true
        )
        require(inverted.x == slow.x && inverted.y == -slow.y, "invert Y changed the wrong axis")

        let stickDead = UT99TouchInputTuning.floatingStickLook(CGPoint(x: 0.02, y: 0))
        let stickFine = UT99TouchInputTuning.floatingStickLook(CGPoint(x: 0.10, y: 0))
        let stickFull = UT99TouchInputTuning.floatingStickLook(CGPoint(x: 1, y: 0))
        require(stickDead.x == 0 && stickDead.y == 0, "floating stick did not reject resting noise")
        require(stickFine.x > 0.0005, "floating stick did not respond early")
        require(abs(stickFull.x - 0.0065) < 0.00001, "floating stick maximum was not bounded")

        let forward = UT99TouchInputTuning.controllerMovement(CGPoint(x: 0.11, y: 0.92))
        let diagonal = UT99TouchInputTuning.controllerMovement(CGPoint(x: 0.55, y: 0.82))
        let drift = UT99TouchInputTuning.controllerMovement(CGPoint(x: 0.08, y: -0.07))
        let menuDrift = UT99TouchInputTuning.controllerMenuCursor(CGPoint(x: 0.09, y: -0.08))
        let menuMove = UT99TouchInputTuning.controllerMenuCursor(CGPoint(x: 0.20, y: 0.03))
        require(forward.x == 0 && forward.y == 0.92, "controller forward wobble was not suppressed")
        require(diagonal.x == 0.55 && diagonal.y == 0.82, "deliberate controller diagonal was changed")
        require(drift.x == 0 && drift.y == 0, "controller resting drift was not suppressed")
        require(menuDrift.x == 0 && menuDrift.y == 0, "menu cursor resting drift was not suppressed")
        require(menuMove.x == 0.20 && menuMove.y == 0.03, "menu cursor deliberate movement changed")

        print("UT99 touch configuration PASS persistence=true migration=true clamping=true deadZone=true acceleration=true invertY=true floatingCurve=true controllerCardinal=true")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        fputs("UT99 touch configuration FAIL: \(message)\n", stderr)
        exit(1)
    }
}
