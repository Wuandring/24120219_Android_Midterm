# Interactive Concert Seat Map

Flutter / Dart / Material 3; Android. M1: setup and local data; M2: pure Dart math engine; M3: dark concert canvas renderer; M4: pan, pinch and selection; M5: expandable ticket sheet and spotlight; M6: filters, legend and camera reset.

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

The app displays the 200-seat concert canvas with bounded pan, pinch-to-zoom and persistent tap selection. The ticket sheet supports two-way selection and animated focus; filter/search controls and camera-only Reset View are available in M6.

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

## M4 gestures and selection

`CameraController` owns camera and viewport. Initial dimensions call fit once; unchanged dimensions do nothing; changed dimensions preserve relative zoom/center via the M2 resize math. `ConcertMapScreen` coalesces layout measurements and applies them in a mounted post-frame callback, never mutating camera notifiers during build.

`InteractiveSeatCanvas` handles one-finger pan and two-finger pinch through onScaleStart/Update/End only. The controller computes incremental zoom as current cumulative scale / previous cumulative scale. Finger count changes rebase focal point and scale, avoiding centroid jumps. Translation follows local focal movement; zoom and translation are clamped together. Resize cancels old gesture baselines. Taps use localPosition, convert screen to world and use exact M2 geometry. Drag/pinch suppresses selection.

`ConcertMapController` stores ordered unique IDs in LinkedHashSet and emits immutable render snapshots from the state layer. Available taps toggle only that seat. Booked/locked seats show a Vietnamese snackbar without changing selection or source status. Controllers live for the screen lifetime, preserving selection on rebuild and rotation. The painter listens directly to camera/map controllers; pan and selection repaint the canvas without rebuilding the screen.

### M4 manual verification

1. Run `flutter run`. Tap two available seats: both become emerald with checkmarks; tap one again: only that seat restores its zone color.
2. Tap booked/locked seats: feedback appears and existing selections stay intact.
3. Pinch to zoom, drag, then tap a seat: the visible seat should toggle. Drag far beyond each edge and pinch to both limits: the map remains clamped.
4. Add/remove a second finger while moving: the camera should not jump to a new focal origin. Finish dragging/pinching: no seat should be accidentally selected.
5. Rotate while zoomed with seats selected: selection persists and camera adapts to the new viewport; normal rebuilds keep the same view.

Suggested commit: `feat: add bounded map gestures and persistent seat selection (M4)`

### AI Usage Log — M4

- 2026-11-24 — Added CameraController, ConcertMapController, state-layer render snapshot, InteractiveSeatCanvas, controller and gesture widget tests; updated painter, screen, README and plan. Removed build-time camera reset; added post-frame dimension reconciliation, incremental pinch deltas and finger-count rebasing. Tests cover focal anchoring, clamps, local transformed taps, independent selection, blocked seats, same-size rebuilds and rotation persistence. Removed a redundant test import reported by analyzer. No third-party packages added; bottom sheet/filter/reset tools remain later milestones. Physical-device gesture feel and frame-rate profiling remain manual checks.

M4 verification: flutter analyze — 0 issues; flutter test — 32/32 passed; flutter build apk --debug — passed. Rotation test confirms camera layout notifications run in postFrameCallbacks. Gradle native-access warning is non-fatal.

## M5 expandable tickets and spotlight

`ConcertMapController` exposes ordered immutable `selectedSeats`, `selectedCount`, integer `totalPrice`, `formattedTotalPrice`, `removeSeat`, `clearSelection`, inspection and `focusedSeatId`. VND formatting uses SDK-only digit grouping; totals are simulated local mock prices. Canvas toggles and sheet deletes publish the same immutable render snapshot, so source statuses remain unchanged and selections have no duplicates. Removing a focused seat clears its spotlight.

`SeatBottomSheet` is a persistent dark ticket-style `DraggableScrollableSheet` with a drag handle, expand/collapse button and scrollable selected-seat rows. The initial/minimum extent is 0.14 or enough for the 64px controls; maximum extent is 0.50 in portrait and 0.42 in landscape at normal phone sizes. The collapsed bar prioritizes selected count/total whenever seats are selected; otherwise it shows inspection information or an empty hint. Handle release animates to the nearest endpoint; zone names display Standing, VIP and Standard. List rows appear on expansion and show code, zone color, formatted price and delete action.

The screen updates the full canvas camera viewport post-frame only on initialization or actual resize/rotation. Sheet dragging and toggling never change the viewport, camera transform or fitScale. Explicit focus requests pass the current sheet pixel height as bottomInset, centering at (viewportHeight - bottomInset) / 2. Optional screen-space edge padding in `ViewportClamper` allows edge seats to reach the visible-area center without changing fitScale; unpadded engine behavior stays unchanged. CameraController enables fixed half-width horizontal and 0.8-height vertical clearance, keeping part of the venue onscreen while allowing bottom-row focus above the largest supported sheet. These bounds do not vary during sheet dragging.

Tapping a row animates the camera for 300ms to that visible-area center. Focus zoom targets at least 2.4×fitScale and a 1.0 world-to-screen scale where possible, clamped to the valid 0.9–4.5×fitScale range. After centering, a 1.2s pulse runs on cached spotlight Paint objects; a steady ring then remains until focus is removed. Manual map gestures cancel camera animation and disable automatic refocusing. Sheet changes never re-center the camera; rotation adapts the full viewport and only re-centers an explicitly focused seat if manual interaction has not taken control. All eight section headers include L/C/R suffixes. Seat codes use 9.0 world-unit text with explicit zero letter spacing; other labels retain their own spacing.

### M5 manual verification

1. Select several available seats on Canvas. Expand the ticket bar and compare rows, count and simulated VND total. Deselect on Canvas or delete a row: both surfaces update immediately.
2. Tap a row, including a bottom-most Standard seat. Check the smooth camera transition, readable seat code and pulsing ring above the sheet. Delete the focused row: its selection and ring disappear.
3. Drag/toggle the sheet, scroll a long list, then rotate with it expanded. Controls should stay visible, the map above should remain interactive, and selections/focus should persist.
4. Tap a booked/locked seat: inspection appears in the ticket bar without altering selection. Start a pan during focus animation: manual movement takes control.
5. Run `flutter test test/state/m5_sheet_state_test.dart test/ui/seat_bottom_sheet_test.dart`. Optional `M5_PREVIEW_FONT` may point to SDK `bin/cache/artifacts/material_fonts/roboto-regular.ttf` to export portrait/landscape screenshots under ignored build/ for visual review.

Suggested commit: `feat: add expandable ticket sheet and animated seat spotlight (M5)`

### AI Usage Log — M5

- 2026-11-24 — Added persistent ticket sheet, M5 state/widget tests and implementation plan; extended map/render state, camera/viewport math, screen, interactive canvas and cached painter. Added ordered seat totals, immutable focus, two-way delete/select sync, visible-area focus animation, cached spotlight pulse, L/C/R labels and orientation-safe extents. Adjusted occupied-seat regression assertion for the new inspection summary; fixed a missing Size import in new tests. Visually reviewed rendered focus states and increased focus/code readability. No dependencies added. Physical-device gesture feel, accessibility text scaling and frame-rate profiling remain manual checks.

M5 verification: flutter analyze — 0 issues; flutter test — 38/38 passed; flutter build apk --debug — passed. Portrait 390×844 and landscape 844×390 focus screenshots reviewed; no RenderFlex overflow in widget tests. Gradle native-access warning is non-fatal.

- 2026-11-25 — M5 fixes: decoupled full-canvas viewport from sheet movement; added bottomInset focus targeting and manual-pan auto-refocus suppression. Added fixed vertical focus clearance, 9.0/zero-spacing seat codes, handle snap on release, capitalized zone names and selection-first summaries. Regression tests cover unchanged camera notifications/viewport during sheet dragging/toggling, manual-view persistence, inset focus, typography and summary priority. SDK-only; no M6 features.

M5 fix verification (2026-11-25): flutter analyze — 0 issues; flutter test — 40/40 passed; flutter build apk --debug — passed. Tests confirm zero camera notifications during sheet dragging/toggling and correct clamped resize after manual pan.

## M6 legend, filters, search and camera reset

`FilterState` combines zone, visual status and trimmed case-insensitive seat-code substring predicates. `ConcertMapController` exposes filters, hasActiveFilters, matchedCount, activeFilterDescription and clearFilters. Matching IDs are null when no condition is active and an immutable empty set for zero matches. Every selection/remove/clear operation recomputes status matches; Available excludes selected seats. Filtering never drops selections, totals, inspection or focus.

Canvas hit-testing uses the same eligibility rule as the controller: dimmed unselected seats cannot be selected; existing dimmed selected seats may still be deselected. The existing painter renders nonmatches at 0.15 alpha and retained selections at 0.40 with dashed emerald outlines. The bottom sheet always shows the complete selected ticket, independent of filters.

`FilterSearchBar` provides code input, quick clear, zone/status popup selectors, match count with filter-description tooltip and Xóa lọc. Narrow layouts use two compact rows; wide layouts use a single horizontally scrollable row. A small map banner offers Xóa bộ lọc for zero matches. The AppBar legend opens a scrollable dark dialog explaining three zone colors/shapes, four states and filtered-seat behavior.

Reset View animates the camera to viewport.fit() over 300ms without publishing any map-state change. It preserves query, filters, selection, totals, focus and inspection, and disables automatic focus recentering. Manual gestures or actual viewport resize cancel the current camera animation. Camera-only repainting remains independent of filter/sheet widget rebuilds.

### M6 manual verification

1. Select seats, then combine a zone, status and mixed-case query such as vp-c. Compare the match count, dimmed seats and retained ticket list.
2. Tap a dimmed unselected seat: no selection should be added. Deselect an existing dimmed selected seat: only that seat leaves the ticket. Delete from the sheet while filtering Selected: match count updates immediately.
3. Enter a nonexistent code, check the empty banner and use Xóa bộ lọc. Try the search X button separately: it clears only the query.
4. Open Bảng chú thích, inspect zone/state explanations, and close it. Rotate in both orientations; controls should scroll horizontally without overflow.
5. Pan/zoom with selections and filters active, press Reset View and verify that only the camera returns to fit scale. Query, selected IDs and simulated total must stay intact.

Suggested commit: `feat: add concert filters, legend and animated camera reset (M6)`

### AI Usage Log — M6

- 2026-11-25 — Added FilterState, FilterSearchBar, LegendPanel and M6 unit/widget tests; updated map controller, Canvas eligibility, screen and plan. Added combined matching/null-versus-empty semantics, dynamic visual-status filtering, selection-safe dim tap behavior, zero-match clear banner and camera-only animated reset. No third-party packages added. Tests cover matching counts, search normalization, immutable snapshots, selection persistence, blocked dim taps, clear controls, legend, reset preservation and portrait/landscape layout. Physical-device accessibility/text scaling and FPS profiling remain manual checks.

M6 verification: flutter analyze — 0 issues; flutter test — 49/49 passed; flutter build apk --debug — passed. Portrait/landscape widget tests reported no RenderFlex overflow. Gradle native-access warning is non-fatal.

- 2026-11-25 — M6 UX fixes: disabled Scaffold keyboard-driven resizing, dismissed search focus on Canvas tap and pan/pinch start, and added independent cyan tint/border highlights for active zone/status selectors. Widget tests simulate keyboard insets in both orientations, verify stable canvas/camera dimensions, focus dismissal and selector highlight clearing. flutter analyze: 0 issues; flutter test: 51/51 passed.
