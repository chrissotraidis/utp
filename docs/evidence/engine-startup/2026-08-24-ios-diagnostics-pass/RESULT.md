# iOS diagnostics and recovery pass — 2026-08-24

**PASS — host diagnostics path and simulator startup smoke.**

The Diagnostics section now reports host version/build, embedded engine presence, Metal device, audio route, network status, thermal state, display geometry, and persisted touch profile. It provides clipboard copy, a stored ZIP export containing the bounded diagnostics log, host-configuration reset, and safe-texture mode for the next launch.

A fresh iPad Air 11-inch simulator package compiled, passed package verification, installed, and launched with the original engine path and GoldenPad overlay. The raw screenshot records a 4:3 engine surface on the left and the action rail in the reserved right bay. This smoke landed on the original UT title/menu screen; it is not a populated-match or physical-touch result.

Evidence:

- [`ipad-diagnostics-engine.png`](ipad-diagnostics-engine.png)
- [`UT99-engine.stdout`](UT99-engine.stdout)

Physical iPad/iPhone, native touch, performance, and populated-match gates remain open.
