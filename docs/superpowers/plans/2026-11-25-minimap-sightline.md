# Minimap, Sightline and Ticket Polish Implementation Plan

**Goal:** Fix collapsed ticket bleed and add SDK-only minimap navigation, cached focus sightline, haptics and zoom feedback.

**Architecture:** Keep Data/Engine and seat hit-testing unchanged. Reuse CameraController bounds for minimap navigation. Main Canvas uses cached sightline segments and one reusable TextPainter updated on focus changes. A separate lightweight minimap painter listens to camera/map state directly.

**Tech Stack:** Flutter SDK only.

**Spec:** User request in this chat, 25/11/2026. Implementation stays in this session.

## Constraints and review focus

- No changes to 200 seat coordinates, hit-test math, dependencies or existing selection/filter persistence.
- No Paint/TextPainter construction inside either paint method.
- Transparent/hidden overlays must not intercept Canvas taps.
- Compact headers must fit landscape and safe areas; sheet drag must never mutate camera.
- Minimap navigation cancels running camera animation/auto-refocus; selection/focus/filter state persists.

## Tasks

- [x] Add widget tests for collapsed opacity/IgnorePointer, clear-all visibility and synchronization, minimap visibility/navigation/clamping, zoom badge and landscape stability. Add cache tests for sightline focus reuse and clearing.
- [x] Run tests to confirm the new behavior is absent (four new widget tests failed before implementation).
- [x] In concert_map_screen.dart use `(68 / size.height).clamp(0.07, 0.24)`; in seat_bottom_sheet.dart hide rows at `minSize + 0.015`, show expanded clear-all for >=2 selections.
- [x] Add CameraController.centerTarget(WorldPoint) through existing clamp; add seat_map_minimap.dart with cached paints, silhouettes, selected dots and clamped visibleWorldRect; connect tap animation and direct drag navigation.
- [x] Cache sightline geometry, distance/angle text and tag in SeatMapPaintCache on focused ID changes; render dashed line and pill without per-frame Paint/TextPainter allocations.
- [x] Add selection/unavailable/control haptics and a camera-listening relative zoom badge. Update README AI log.
- [x] Run flutter analyze, flutter test and debug APK build; inspect portrait/landscape previews and confirm protected files unchanged.

Verification: analyzer 0 issues (4.1s), all 66 tests passed (20s), debug APK built (17.1s). Data/Engine and their tests plus pubspec/lock unchanged. Paint/TextPainter constructors remain outside paint. Font for the compact clear action was made explicit after preview inspection.
