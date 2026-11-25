# Matte Concert Redesign Plan

**Spec:** attached Pasted text.txt, 2026-11-25. User overrides earlier neon palette/layout.
**Design:** matte #0D0D0F world, architectural slate facets, periwinkle/terracotta/teal seats and champagne hairlines. System Roboto, tracked section headers, compact legible code text. Portrait HUD above edge-to-edge ticket; landscape one-row HUD and 340px right-docked ticket. Fit/reset frame only the unobstructed region.
**Architecture:** retain data and pure engine unchanged. Add framed viewport adapter in state; precompute all geometry, text and state-specific paints in cache. Painter uses scalar culling and cached objects without app-level allocations. Preserve all interactions/state.

- [x] Rebuild cache/painter, legend and UI palette.
- [x] Full-screen canvas, responsive HUD and docked sheet.
- [x] Framed fit/reset/focus with stable viewport and landscape pinch.
- [x] Update UI expectations; add landscape multi-touch, fit visibility and decorative no-overlap tests.
- [x] Verify unchanged Data/Engine files, analyze/test/build, screenshots and README.
