import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import '../../data/seat.dart';
import '../../engine/camera_transform.dart';
import '../../state/seat_map_render_state.dart';
import 'seat_map_paint_cache.dart';
export '../../state/seat_map_render_state.dart';

enum SeatVisualState { available, selected, booked, locked }

class SeatMapPainter extends CustomPainter {
  SeatMapPainter({
    required this.cache,
    required this.camera,
    required this.mapState,
    required this.fitScale,
    this.spotlight = kAlwaysCompleteAnimation,
  }) : super(repaint: Listenable.merge([camera, mapState, spotlight]));
  final SeatMapPaintCache cache;
  final ValueListenable<CameraTransform> camera;
  final ValueListenable<SeatMapRenderState> mapState;
  final double fitScale;
  final Animation<double> spotlight;
  int lastPaintedSeatCount = 0, lastPaintedCodeCount = 0;
  bool get showSeatCodes => camera.value.scale >= 1.35 * fitScale;
  SeatVisualState visualState(Seat s) {
    if (s.status == SeatStatus.booked) return SeatVisualState.booked;
    if (s.status == SeatStatus.locked) return SeatVisualState.locked;
    return mapState.value.selectedSeatIds.contains(s.id)
        ? SeatVisualState.selected
        : SeatVisualState.available;
  }

  @override
  void paint(Canvas canvas, Size size) {
    lastPaintedSeatCount = 0;
    lastPaintedCodeCount = 0;
    if (size.isEmpty) return;
    canvas.drawPaint(cache.background);
    canvas.save();
    final c = camera.value;
    canvas.translate(c.tx, c.ty);
    canvas.scale(c.scale);
    for (var i = 0; i < cache.stardust.length; i++) {
      final dot = cache.stardust[i];
      canvas.drawCircle(dot.position, dot.radius, dot.paint);
    }
    for (var i = 0; i < cache.pads.length; i++) {
      final pad = cache.pads[i];
      // Deck shadows/lips are cached, and drawn before the deck tops.
      if (i == 0) {
        for (var j = 0; j < cache.deckShadows.length; j++) {
          canvas.drawPath(cache.deckShadows[j], cache.groundShadow);
          canvas.drawPath(cache.deckLips[j], cache.extrusion);
        }
      }
      canvas.drawPath(pad, cache.padFill);
      canvas.drawPath(pad, cache.padBorder);
    }
    canvas.drawPath(cache.tierSteps, cache.stepPaint);
    canvas.drawPath(cache.leftCone, cache.leftLight);
    canvas.drawPath(cache.rightCone, cache.rightLight);
    for (var i = 0; i < cache.stageShadows.length; i++) {
      canvas.drawPath(cache.stageShadows[i], cache.groundShadow);
      canvas.drawPath(cache.stageExtrusions[i], cache.extrusion);
    }
    canvas.drawPath(cache.mainStage, cache.stageFill);
    canvas.drawPath(cache.mainStage, cache.stageBorder);
    canvas.drawPath(cache.catwalk, cache.stageFill);
    canvas.drawPath(cache.catwalk, cache.stageBorder);
    canvas.drawPath(cache.bStage, cache.stageFill);
    canvas.drawPath(cache.bStage, cache.stageBorder);
    canvas.drawPath(cache.innerBStage, cache.innerBorder);
    canvas.drawPath(cache.bevel, cache.bevelFill);
    canvas.drawPath(cache.foh, cache.stageFill);
    canvas.drawPath(cache.foh, cache.stageBorder);
    for (var i = 0; i < cache.labels.length; i++) {
      final l = cache.labels[i];
      if (l.readableSection) {
        // Preserve anchored 2D geometry; only text gets a legibility floor.
        canvas.save();
        canvas.translate(l.anchor.dx, l.anchor.dy);
        canvas.scale(math.max(1.0, 0.45 / c.scale));
        l.painter.paint(canvas, l.centeredPosition);
        canvas.restore();
      } else {
        l.painter.paint(canvas, l.position);
      }
    }
    // Scalar culling avoids creating inverse-transform Rect/point objects per frame.
    final left = -c.tx / c.scale, top = -c.ty / c.scale;
    final right = (size.width - c.tx) / c.scale,
        bottom = (size.height - c.ty) / c.scale;
    final state = mapState.value;
    final codes = showSeatCodes;
    for (var i = 0; i < cache.seats.length; i++) {
      final g = cache.seats[i];
      final b = g.cullBounds;
      if (b.right <= left ||
          b.left >= right ||
          b.bottom <= top ||
          b.top >= bottom)
        continue;
      lastPaintedSeatCount++;
      final visual = visualState(g.seat);
      final matches = state.matchingSeatIds?.contains(g.seat.id) ?? true;
      final ink = g.inks[visual.index + (matches ? 0 : 4)];
      if (g.seat.shape == SeatShape.circle) {
        canvas.drawCircle(g.center, g.radius, ink.fill);
        if (visual == SeatVisualState.selected ||
            visual == SeatVisualState.locked)
          canvas.drawCircle(g.center, g.radius, ink.border);
      } else {
        canvas.drawRRect(g.rounded, ink.fill);
        if (visual == SeatVisualState.selected ||
            visual == SeatVisualState.locked)
          canvas.drawRRect(g.rounded, ink.border);
      }
      if (g.seat.shape == SeatShape.roundedRectangle)
        canvas.drawRRect(g.backrest, ink.backrest);
      switch (visual) {
        case SeatVisualState.selected:
          canvas.drawPath(g.check, ink.symbol);
        case SeatVisualState.booked:
          canvas.drawPath(g.slash, ink.symbol);
        case SeatVisualState.locked:
          canvas.drawPath(g.cross, ink.symbol);
        case SeatVisualState.available:
          break;
      }
      if (!matches && visual == SeatVisualState.selected)
        canvas.drawPath(g.dashed, cache.dashedBorder);
      if (state.focusedSeatId == g.seat.id) {
        final radius =
            g.radius + 9 + 3 * math.sin(spotlight.value * math.pi * 6);
        canvas.drawCircle(g.center, radius, cache.spotlightGlow);
        canvas.drawCircle(g.center, radius, cache.spotlightRing);
      }
      if (codes && matches) {
        g.code.paint(canvas, g.codePosition);
        lastPaintedCodeCount++;
      }
    }
    if (state.focusedSeatId != null &&
        state.selectedSeatIds.contains(state.focusedSeatId) &&
        cache.focusedSeatId == state.focusedSeatId) {
      cache.sightlineInk.strokeWidth = 1.5 / c.scale;
      canvas.drawPath(cache.sightline, cache.sightlineInk);
      canvas.save();
      canvas.translate(
        cache.sightlineTagAnchor.dx,
        cache.sightlineTagAnchor.dy,
      );
      // Keep the distance tag readable in screen pixels at any map zoom.
      canvas.scale(1 / c.scale);
      canvas.translate(0, -38);
      canvas.drawRRect(cache.sightlineTag, cache.sightlineTagInk);
      canvas.drawRRect(cache.sightlineTag, cache.sightlineTagBorder);
      cache.sightlineText.paint(canvas, cache.sightlineTextPosition);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SeatMapPainter oldDelegate) =>
      oldDelegate.cache != cache ||
      oldDelegate.camera != camera ||
      oldDelegate.mapState != mapState ||
      oldDelegate.fitScale != fitScale ||
      oldDelegate.spotlight != spotlight;
}
