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

        print("UT99 touch configuration PASS persistence=true clamping=true deadZone=true acceleration=true invertY=true")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        fputs("UT99 touch configuration FAIL: \(message)\n", stderr)
        exit(1)
    }
}
