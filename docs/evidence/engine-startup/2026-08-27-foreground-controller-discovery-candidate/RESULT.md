# Foreground controller discovery candidate — 2026-08-27

## Outcome

This follow-up is **accepted locally** and requires one focused physical-iPad
hot-connect check. It follows the physically rejected `d10f613` candidate and
does not change controller mappings, touch mappings, pointer transforms, or the
physically accepted keyboard event recipe.

## Physical rejection that defines the change

With `d10f613` installed, the user launched UTP without the Xbox controller,
chose **Try Normal Start**, connected the controller through Bluetooth Settings,
and returned to an unusable controller at the original menu. Ending and
reopening UTP with the controller already connected restored correct menu
control and correct Oblivion gameplay after switching to Gameplay controls.

The restart erased the failed process's session-scoped engine stdout. The
replacement log proves controller-at-launch remains healthy but cannot classify
the preceding hot-connect profile.

## Narrow implementation

The shipped GameController interface states that wireless discovery is a
finite asynchronous operation. UTP previously started it only during initial
integration. A user who entered Bluetooth Settings later could return after
that discovery window had expired.

The candidate now:

- restarts wireless discovery when UTP becomes active with no extended
  controller;
- retries controller enumeration on the main run loop at bounded delays through
  six seconds, using the same configuration path that works at cold launch;
- restarts discovery from the first responder-only controller event and after
  a full disconnect;
- cancels remaining retries immediately after adopting an extended profile;
- retains touch gameplay when only responder presses exist; and
- copies the last 512 KiB of `UT99-engine.stdout` to
  `UT99-engine.previous.stdout` before each engine launch and includes that file
  in diagnostics exports.

## Local proof

The real-engine Simulator lifecycle creates an external virtual controller only
after Unreal enters its main loop. The final run records:

- discovery restarted after engine entry;
- extended profile connection and configuration;
- main-run-loop retry 1 finding two extended profiles;
- discovery adoption;
- menu stick/A input;
- Menu → Gameplay switching;
- movement, look, right-trigger press and release;
- Gameplay → Menu switching; and
- disconnect cleanup.

Launching the Player Name regression afterward preserved all of those markers
in `UT99-engine.previous.stdout`. The current log and visible stock field both
show the unchanged `Ab 9` keyboard regression with KeyDown, TextInput, KeyUp
ordering.

## Verification

- focused host/input source guards: passed;
- real-engine Simulator build: passed;
- discovery-aware controller lifecycle: passed;
- previous-session log rotation: passed;
- visible Player Name `Ab 9` regression: passed;
- complete `make test`: passed;
- signed iPhoneOS build: passed;
- deep iOS package verification: passed;
- `git diff --check`: passed.

## Installed product identity

- Bundle identifier: `com.ut99apple.client`
- Host UUID: `F97BE745-DD6D-3F98-AD4A-A3996D7F42C5`
- Host SHA-256:
  `bdce45653bef78e54ef82957ef5e1d3025a5f0422e8912173d1b38230d23803b`
- Embedded SDL SHA-256:
  `1830d33b185c66e75ea4cc0e96cb8b361fd32c3010b31f54db680a6eb5af4277`
- SDL patch SHA-256 remains:
  `68a1ce30d1e8808e7a928269bfc2133c2ea17e6e8ac75b22fb3f07dace2244e2`

The candidate was installed in place on the attached iPad. Pre/post copies of
the current preferences plist, `User.ini`, and `UnrealTournament.ini` are
byte-identical. Their SHA-256 values are, respectively:

- `f9ec692e41aefa5ffbb38050094e932c8734f9200be744ef619c401ae886d294`;
- `7f5539979bbe67a0471faaf04ba7d454db13b21e7dc80477f4cf95368d1945aa`;
  and
- `43a8ae5c33d00d4d572eb4852e462d567b612b08c45db2888e7f75bbe80b2809`.

## Remaining boundary

Simulator discovery/adoption proves UTP's state machine, not whether iPadOS
will publish the physical Xbox profile after returning from Settings. Perform
only the failed sequence: launch with Xbox off, connect through Settings, return
to the original menu, wait up to six seconds, then move the left stick and press
A/B. If it fails, stop without restarting UTP; the retained current log will
classify every retry and profile count. A later restart will preserve that log
as the previous session instead of erasing it.
