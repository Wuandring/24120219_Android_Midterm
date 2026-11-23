# AGENTS.md — Interactive Concert Seat Map (Flutter)

## 1. Workflow & Agent Rules
- **Role:** You write clean, modular Dart/Flutter code; the user reviews, tests on emulator/device, and commits.
- **Step-by-step:** Implement **ONLY the requested Milestone** (Section 7). Do NOT build multiple milestones at once.
- **Self-Verify:** Before replying, run `flutter analyze` and `flutter test` and fix all warnings/errors.
- **Response Format after each Milestone:**
  1. Files created/modified (bullet list).
  2. Concise explanation of core logic for user review.
  3. Manual verification steps + suggested Git commit message.
  4. Short AI Usage Log entry (task, generated/edited files, caveats/bugs fixed) for `README.md`.
- **Clean Repo:** Keep `.gitignore` clean; no unused code or generated junk.

## 2. Tech Stack & Architecture
- **Stack:** Flutter (Dart, Material 3). **Zero third-party packages** (pure Flutter SDK only to avoid dependency/build issues).
- **Data:** 100% local deterministic Mock Data (no API, no DB).
- **UI Language:** Vietnamese labels + standard concert terms (`Standing`, `VIP`, `Standard`, `Main Stage`).
- **Strict Layer Separation (`lib/`):**
  - `data/`: `seat.dart`, `zone_section.dart`, `concert_mock_data.dart`.
  - `engine/` (pure Dart, zero Flutter UI imports, 100% unit-testable): `camera_transform.dart`, `coordinate_transformer.dart`, `viewport_clamper.dart`, `hit_tester.dart`.
  - `state/`: `filter_state.dart`, `concert_map_controller.dart` (`ChangeNotifier` — single source of truth), `camera_controller.dart` (`ValueNotifier<CameraTransform>`).
  - `ui/canvas/`: `seat_map_paint_cache.dart`, `seat_map_painter.dart` (`CustomPainter`), `interactive_seat_canvas.dart`.
  - `ui/widgets/`: `filter_search_bar.dart`, `legend_panel.dart`, `map_controls.dart`, `seat_bottom_sheet.dart`.
  - `ui/screens/`: `concert_map_screen.dart`.

## 3. Non-Negotiable Guardrails
1. **Single Canvas Only:** Draw the stage, glow, aisles, zone labels, and all **200 seats** in **ONE** `CustomPainter`. NEVER create individual Widgets/Buttons for seats.
2. **No `InteractiveViewer`:** Implement Pan, focal-point Pinch-to-Zoom, boundary clamping, and Tap hit-testing explicitly using `GestureDetector` (`onScaleStart`, `onScaleUpdate`, `onScaleEnd`, `onTapUp` — NEVER mix `onPan*` with `onScale*`) + `engine/` math so coordinate transforms are transparent and unit-tested.
3. **60fps Performance:**
   - Pre-allocate and reuse `Paint` objects, `Rect`/`RRect`/`Path`, and static `TextPainter` instances inside `SeatMapPaintCache` — **NEVER allocate `Paint` or `TextPainter` inside `paint()` loops**.
   - Pass `Listenable.merge([cameraController, mapController])` to `CustomPainter(repaint: ...)` so Pan/Zoom repaints ONLY the Canvas without rebuilding Bottom Sheet or Filter widgets.
   - Apply **viewport culling** (skip seats outside visible world rect) and **LOD** (render seat codes only when `scale >= 1.35 * fitScale`).
4. **Accurate Hit-Testing:** Always transform Screen $\rightarrow$ World first. Must stay accurate after Pan/Zoom and near item borders.
5. **Reset View Rule:** Smoothly animate camera (~300ms `AnimationController`) back to default `fitScale`. **NEVER** clear active filters or selected seats.
6. **Rotation & Orientation:** Preserve all state (`selectedSeatIds`, filters, inspected seat) across screen rotation. Recalculate `fitScale` and clamp camera cleanly when viewport size changes. Work cleanly in both Portrait and Landscape.

## 4. Concert Domain & "Wow" Visual Spec
- **Dark Venue Theme:** Deep navy Canvas (`#0B1120`), subtle arena boundary contour, elevated slate UI surfaces (`#1E293B`), crisp high-contrast text.
- **World Bounds:** $1600 \times 1200$ world units. Entire layout must be clearly readable at default `fitScale`.
- **Stage & Layout:**
  - **T-Shaped Stage:** `MAIN STAGE` across top center + `CATWALK` extending downward, with a soft pre-cached gradient spotlight glow (no per-frame blur filters).
  - Clear dark aisles separating zones + crisp zone headers (`STANDING`, `VIP`, `STANDARD`).
- **200 Interactive Seats** (deterministic mock statuses: ~62% `available`, ~26% `booked`, ~12% `locked`):
  - `STANDING` (40 — circle, `1.800.000 đ`, Cyan `#06B6D4`): `ST-L01..20` ($4 \times 5$ left of catwalk), `ST-R01..20` ($4 \times 5$ right of catwalk).
  - `VIP` (60 — rounded rect + backrest accent bar, `3.500.000 đ`, Amber/Gold `#F59E0B`): `VP-L01..15` ($3 \times 5$), `VP-C01..30` ($3 \times 10$), `VP-R01..15` ($3 \times 5$).
  - `STANDARD` (100 — rounded square, `1.200.000 đ`, Indigo `#818CF8`): `SD-L01..30` ($5 \times 6$), `SD-C01..40` ($5 \times 8$), `SD-R01..30` ($5 \times 6$).
- **4 Visual States** (differentiated by color + border + drawn symbol + opacity):
  - `available`: bright zone fill + crisp subtle border $\rightarrow$ tap selects.
  - `selected`: vibrant emerald (`#10B981`) fill + white highlight border + drawn checkmark $\rightarrow$ tap deselects back to `available` without affecting other seats.
  - `booked`: muted slate (`#334155`) fill + diagonal slash $\rightarrow$ tap inspects info only (not selectable).
  - `locked`: dark crimson (`#450A0A`) fill + muted red border + drawn `X` $\rightarrow$ tap inspects info only (not selectable).
  - *Filtered out:* dim to alpha `0.15`, ignore new selection; if already selected, keep visible with dashed emerald outline at alpha `0.40`.
  - *Spotlight Focus (from Bottom Sheet):* animated pulsing bright ring around the focused seat (~1.2s) after camera centers on it.

## 5. Math & Gesture Engine (`lib/engine/`)
- **Transforms** (scale $s \in [s_{\min}, s_{\max}]$, translation $(t_x, t_y)$):
  - World $\rightarrow$ Screen: $x_s = x_w \cdot s + t_x$, $\; y_s = y_w \cdot s + t_y$.
  - Screen $\rightarrow$ World: $x_w = \dfrac{x_s - t_x}{s}$, $\; y_w = \dfrac{y_s - t_y}{s}$.
- **Pinch-to-Zoom around focal point $(f_x, f_y)$:**
  - $s_{\text{new}} = \text{clamp}(s_{\text{old}} \cdot \text{scaleDelta},\; s_{\min},\; s_{\max})$, where $s_{\min} = 0.9 \cdot s_{\text{fit}}$, $s_{\max} = 4.5 \cdot s_{\text{fit}}$.
  - $t_x' = f_x - (f_x - t_x) \cdot \dfrac{s_{\text{new}}}{s_{\text{old}}}$, $\; t_y' = f_y - (f_y - t_y) \cdot \dfrac{s_{\text{new}}}{s_{\text{old}}}$.
- **Boundary Clamping:** Clamp $(t_x, t_y)$ after every Pan, Zoom, or viewport resize so the map cannot be dragged off-screen.
- **Gesture Disambiguation:** Handle 1-finger Pan and 2-finger Pinch inside `onScaleStart`/`onScaleUpdate`; prevent accidental tap after drag or pinch.
- **Hit-Testing Geometry:** Circle radius check for `STANDING`; exact `Rect` bounds check for `VIP`/`STANDARD` (1:1 match with rendered bounds).

## 6. Supporting UI & Two-Way Sync
- **Top Filter & Search Bar:** Compact dark overlay with search input (seat code), Zone chips, Status chips, active match count badge, "Xóa lọc" (Clear) button, and clear Empty State banner when 0 seats match. Filtering must NOT drop existing `selectedSeatIds`.
- **Legend (`LegendPanel`):** Compact toggleable overlay button/card explaining all 4 states and 3 zones without obstructing the map.
- **Reset View Button:** Floating icon button with tooltip that smoothly animates camera to `fitScale` (preserves filters & selections).
- **Expandable Bottom Sheet (`DraggableScrollableSheet`):**
  - Ticket-stub dark styling. `minChildSize: 0.14`, `initialChildSize: 0.14`, `maxChildSize: 0.50` (keep upper Canvas area interactive).
  - *Collapsed:* Selected count + formatted total price (e.g., `3 ghế • 7.500.000 đ`), or inspected `booked`/`locked` seat details, or helper prompt if none.
  - *Expanded:* Scrollable `ListView` of selected seats (zone color dot, seat code, zone name, price, delete icon).
  - *Two-way sync:* Tap seat on Canvas updates Sheet instantly. Tap a seat row in Sheet smoothly animates camera to center on that seat + triggers Spotlight ring on Canvas. Tap delete icon removes seat and updates Canvas immediately. Store selections in `LinkedHashSet<String>` (zero duplicates).
- **Landscape Mode:** Keep top filter bar single-row/collapsible and Bottom Sheet capped so the Canvas has ample workspace.

## 7. Milestones (1 Milestone = 1 Git Commit)
- **M1 — Setup & Data:** Clean Flutter project scaffold, `.gitignore`, models (`Seat`, `ZoneSection`), `ConcertMockData` (200 seats + T-stage + aisles).
- **M2 — Math Engine & Unit Tests:** `CameraTransform`, `CoordinateTransformer`, `ViewportClamper`, `HitTester` + comprehensive unit tests in `test/engine/` (Pan/Zoom hit-test, border hit-test, focal zoom, clamping).
- **M3 — Dark Concert Canvas Renderer:** `SeatMapPaintCache`, `SeatMapPainter` (T-stage + glow, aisles, zone labels, 200 seats, 4 states, culling, LOD).
- **M4 — Gestures & Selection:** `CameraController`, bounded Pan, focal-point Pinch-to-Zoom, Tap hit-testing, select/deselect state restoration.
- **M5 — State & Two-Way Bottom Sheet:** `ConcertMapController`, ticket-style `DraggableScrollableSheet`, two-way sync, animated focus camera + Spotlight ring.
- **M6 — Tools & Orientation Polish:** Toggleable Legend, Filter/Search + Empty State, animated Reset View, Portrait/Landscape responsiveness, controller unit tests in `test/state/`.
- **M7 — Hardening & Docs:** Fix edge cases (border taps at max zoom, filtered-out selected seats, rotation while sheet expanded); write complete `README.md` (overview, run steps, architecture, data layout, coordinate formulas, hit-testing, state, performance optimizations, demo video link placeholder, AI Usage Log).

## 8. Verification Commands
- Static analysis: `flutter analyze` (0 issues).
- Unit tests: `flutter test` (100% pass).
- Build check: `flutter build apk --debug` (0 errors).