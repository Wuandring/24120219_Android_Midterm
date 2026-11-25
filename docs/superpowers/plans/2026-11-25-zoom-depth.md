# Reliable Zoom and Architectural Depth Plan

**Scope:** user-requested gesture reliability, empty-space double tap, +/- and wheel helpers, compact touch bounds, FOH/readability and cached 2.5D decoration. No data/hit-test math changes.

- [x] Incremental scale independent of pointer count, transition rebasing and bounded zoom target helper.
- [x] Content-hugging landscape HUD, collapsed 320px right sheet on orientation entry, full-width centered fit.
- [x] Animated helper zoom/double tap; local pointer-wheel zoom; preserve immediate single-seat taps.
- [x] Cache extrusion/shadow paths, tier lips/steps, subtle warm light shaders; FOH 745/782/110/36; bold ivory section labels.
- [x] Test emulator-style mirrored touch/pointer transitions, corner/sheet hit-through, helpers, clamping and unchanged geometry. Analyze/test/build and README.

Final verification: analyze 0 issues; all 60 tests passed; debug APK built successfully (18.3s). Portrait and landscape render previews inspected. Data/engine sources and tests, pubspec and lock unchanged.
