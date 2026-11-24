# Interactive Concert Seat Map

Flutter / Dart / Material 3; Android. M1: setup and local data; M2: pure Dart math engine; M3: dark concert canvas renderer.

## Run

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --debug
```

## M1 data

`lib/data/seat.dart`: immutable seats, source statuses and pure Dart world geometry.
`lib/data/zone_section.dart`: block metadata, grid, color, shape and price.
`lib/data/concert_mock_data.dart`: immutable lists, world 1600×1200, T-stage, aisles, 8 blocks. Codes are row-major: ST-L/R (20 each), VP-L/C/R (15/30/15), SD-L/C/R (30/40/30). Prices: Standing 1.800.000 đ, VIP 3.500.000 đ, Standard 1.200.000 đ. Status permutation produces exactly 124 available, 52 booked, 24 locked. Selected status belongs to later controller state.

The app now displays the fitted 200-seat concert canvas. Gestures, selection behavior and filter controls are later milestones.

## Manual verification

1. Run on an Android emulator/device: dark Vietnamese startup screen shows 200 seats.
2. Rotate the device: text remains visible without overflow.
3. Run data tests to verify counts, codes, prices and geometry.

Suggested commit: `feat: scaffold Flutter app and deterministic concert data (M1)`

## AI Usage Log

- 2026-11-24 — M1: generated Android scaffold; edited pubspec, analysis options and main screen; created Seat, ZoneSection, ConcertMockData, data/widget tests and implementation plan. Removed scaffold flutter_lints to keep SDK-only dependencies. No canvas or interaction implemented in this milestone. Verification results are reported in the delivery message.

Verification: flutter analyze — 0 issues; flutter test — 4/4 passed; flutter build apk --debug — passed. Android Gradle emitted a Java native-access warning; it did not prevent the build. Manual emulator/device verification remains for the reviewer.

## M2 math engine

- `lib/engine/camera_transform.dart`: immutable scale/translation, pixel pan and focal zoom. Zoom deltas are incremental; limits are 0.9–4.5 times fitScale.
- `lib/engine/coordinate_transformer.dart`: `WorldPoint`, world/screen conversion and visible world bounds for later culling. Formula: screen = world × scale + translation; inverse = (screen − translation) / scale.
- `lib/engine/viewport_clamper.dart`: fit, per-axis clamp, bounded pan/zoom and resize. Small maps center on each axis; large maps keep viewport covered. Resize preserves relative zoom and the previous center world point where boundaries permit.
- `lib/engine/hit_tester.dart`: converts screen to world, uses circle radius or inclusive rectangle edges. Tiny world-coordinate tolerance covers floating-point roundoff. Returns booked/locked geometry hits for later inspection; optional eligibility predicate supports filtering. It does not modify selections.

All engine files are pure Dart, with no Flutter/UI imports. Viewport sizes are local canvas pixels. Zero-size layouts must wait until the canvas has a positive size before creating a clamper. Focal zoom preserves the world point under the fingers until boundary clamping requires repositioning.

### M2 review steps

1. Run `flutter test test/engine/` for the 15 math/geometry tests.
2. Run `flutter analyze` and `flutter test` (19 total tests including M1).
3. Run `flutter run` to confirm the M1 startup screen still works. M2 adds no canvas or gestures; those belong to M3/M4.

Suggested commit: `feat: add pure Dart camera math and hit-testing engine (M2)`

### AI Usage Log — M2

- 2026-11-24 — Created four engine files, `test/engine/math_engine_test.dart` and M2 implementation plan; updated README. Added coordinate round trips, focal zoom limits, axis clamping, resize and hit-test checks for all 200 seats and shape borders. Fixed an import name collision with flutter_test's HitTester by hiding the test-library symbol. No third-party dependency added. `flutter analyze`: 0 issues; `flutter test`: 19/19 passed. APK build result recorded below.


M2 debug APK build: passed (flutter build apk --debug). Gradle emitted a non-fatal Java native-access warning. Device/emulator interaction remains a manual check.

## M3 canvas renderer

`SeatMapPaintCache` owns the T-stage path, arena contour, gradient shader, aisles, static labels, 200 seat shapes, VIP backrests, status symbols, dashed outlines and seat-code TextPainters. Dispose the cache when leaving the screen. `SeatMapPainter` draws the entire venue in one canvas and reads camera/render snapshots through `Listenable.merge`; no per-seat widgets and no Paint/TextPainter allocation in painting loops.

Viewport culling uses cached seat bounds including outlines/code space. Seat codes appear only at `scale >= 1.35 * fitScale`. Source booking status remains intact; selected IDs are a rendering overlay for available seats. Filtered seats dim to 0.15 alpha; filtered selections remain at 0.40 with a dashed emerald outline. `ConcertMapScreen` displays the full venue at fit scale and recalculates it on layout changes. M3 adds no gesture or selection behavior.

### M3 manual verification

1. Run `flutter run` on Android. Check the navy arena, cyan T-stage glow, clear aisles and Standing/VIP/Standard blocks.
2. Check circle Standing seats, VIP backrests and Standard squares; booked seats have a slash, locked seats have an X.
3. Rotate the device: all 200 seats should remain within the fitted map. Code labels are hidden at fit scale.
4. Run `flutter test test/ui/seat_map_painter_test.dart`. Tests cover selected/filtered rendering, LOD threshold, culling, notifier repaint and both orientations. Preview PNGs are generated under ignored `build/m3-preview-{fit,zoom}.png`. For readable preview fonts, set `M3_PREVIEW_FONT` to the Flutter SDK's `bin/cache/artifacts/material_fonts/roboto-regular.ttf` before running the test; otherwise Flutter test's box font is expected.
5. Gesture-driven zoom/selection will be wired in M4. Device frame-rate profiling remains for integration with gestures.

Suggested commit: `feat: render dark concert canvas with cached geometry and LOD (M3)`

### AI Usage Log — M3

- 2026-11-24 — Added paint cache, single-canvas painter, fit-view screen and renderer tests; updated main entry, startup test, plan and README. Verified fit/zoom PNGs visually with SDK Roboto. Fixed preview export async handling and explicitly selected Roboto to avoid test placeholder glyphs. No dependencies added; no state/gesture controller implemented. Selected/filtered visual samples are test inputs, not preselected seats in the app.

M3 verification: flutter analyze — 0 issues; flutter test — 25/25 passed; flutter build apk --debug — passed. Fit/zoom previews reviewed visually. Gradle native-access warning is non-fatal; 60fps profiling on device remains for gesture integration.
