import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/seat.dart';
import '../../engine/camera_transform.dart';
import '../../engine/coordinate_transformer.dart';
import 'seat_map_paint_cache.dart';
import '../../state/seat_map_render_state.dart';
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
  int lastPaintedSeatCount = 0;
  int lastPaintedCodeCount = 0;

  bool get showSeatCodes => camera.value.scale >= 1.35 * fitScale;
  SeatVisualState visualState(Seat seat) {
    if (seat.status == SeatStatus.booked) return SeatVisualState.booked;
    if (seat.status == SeatStatus.locked) return SeatVisualState.locked;
    return mapState.value.selectedSeatIds.contains(seat.id)
        ? SeatVisualState.selected
        : SeatVisualState.available;
  }

  @override
  void paint(Canvas canvas, Size size) {
    lastPaintedSeatCount = 0;
    lastPaintedCodeCount = 0;
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, cache.background);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final c = camera.value;
    canvas.translate(c.tx, c.ty);
    canvas.scale(c.scale);
    canvas.drawRRect(cache.arena, cache.contour);
    canvas.drawRect(cache.glowRect, cache.glow);
    for (final aisle in cache.aisles) {
      canvas.drawRect(aisle, cache.aisle);
    }
    canvas.drawPath(cache.stage, cache.stageFill);
    canvas.drawPath(cache.stage, cache.stageBorder);
    for (final label in cache.labels) {
      label.painter.paint(canvas, label.position);
    }
    final visible = CoordinateTransformer.visibleWorldRect(
      c,
      viewportWidth: size.width,
      viewportHeight: size.height,
    );
    final visibleRect = Rect.fromLTWH(
      visible.left,
      visible.top,
      visible.width,
      visible.height,
    );
    final state = mapState.value;
    final codes = showSeatCodes;
    for (final geometry in cache.seats) {
      if (!geometry.cullBounds.overlaps(visibleRect)) continue;
      lastPaintedSeatCount++;
      final seat = geometry.seat;
      final visual = visualState(seat);
      final matches = state.matchingSeatIds?.contains(seat.id) ?? true;
      final selected = visual == SeatVisualState.selected;
      final opacity = matches
          ? 1.0
          : selected
          ? 0.40
          : 0.15;
      final color = switch (visual) {
        SeatVisualState.available => cache.zoneColors[seat.sectionId]!,
        SeatVisualState.selected => const Color(0xFF10B981),
        SeatVisualState.booked => const Color(0xFF334155),
        SeatVisualState.locked => const Color(0xFF450A0A),
      };
      cache.fill.color = color.withValues(alpha: opacity);
      cache.border.color =
          (selected
                  ? Colors.white
                  : visual == SeatVisualState.locked
                  ? const Color(0xFFB45353)
                  : const Color(0xFFCBD5E1))
              .withValues(alpha: opacity * (selected ? 1 : 0.55));
      cache.symbol.color =
          (visual == SeatVisualState.locked
                  ? const Color(0xFFF87171)
                  : const Color(0xFFF8FAFC))
              .withValues(alpha: opacity * (selected ? 1 : 0.75));
      if (seat.shape == SeatShape.circle) {
        canvas.drawCircle(geometry.center, geometry.radius, cache.fill);
        canvas.drawCircle(geometry.center, geometry.radius, cache.border);
      } else {
        canvas.drawRRect(geometry.rounded, cache.fill);
        canvas.drawRRect(geometry.rounded, cache.border);
      }
      if (seat.shape == SeatShape.roundedRectangle) {
        cache.accent.color = Colors.white.withValues(alpha: 0.4 * opacity);
        canvas.drawRRect(geometry.backrest, cache.accent);
      }
      switch (visual) {
        case SeatVisualState.selected:
          canvas.drawPath(geometry.check, cache.symbol);
        case SeatVisualState.booked:
          canvas.drawPath(geometry.slash, cache.symbol);
        case SeatVisualState.locked:
          canvas.drawPath(geometry.cross, cache.symbol);
        case SeatVisualState.available:
          break;
      }
      if (!matches && selected) {
        cache.border.color = const Color(0xFF10B981).withValues(alpha: 0.4);
        canvas.drawPath(geometry.dashed, cache.border);
      }
      if (state.focusedSeatId == seat.id) {
        final radius =
            geometry.radius + 9 + 3 * math.sin(spotlight.value * math.pi * 6);
        canvas.drawCircle(geometry.center, radius, cache.spotlightGlow);
        canvas.drawCircle(geometry.center, radius, cache.spotlightRing);
      }
      if (codes && matches) {
        geometry.code.paint(canvas, geometry.codePosition);
        lastPaintedCodeCount++;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SeatMapPainter oldDelegate) =>
      oldDelegate.spotlight != spotlight ||
      oldDelegate.cache != cache ||
      oldDelegate.camera != camera ||
      oldDelegate.mapState != mapState ||
      oldDelegate.fitScale != fitScale;
}
