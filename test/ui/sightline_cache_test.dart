import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/data/seat.dart';
import 'package:concert_seat_map/state/camera_controller.dart';
import 'package:concert_seat_map/state/concert_map_controller.dart';
import 'package:concert_seat_map/ui/canvas/seat_map_minimap.dart';
import 'package:concert_seat_map/ui/canvas/seat_map_paint_cache.dart';
import 'package:concert_seat_map/ui/canvas/seat_map_painter.dart';
import 'package:concert_seat_map/engine/coordinate_transformer.dart';

void main() {
  test('focus distance, angle and geometry update only with ID; painter reuses text and ink', () {
    final cache = SeatMapPaintCache();
    final camera = CameraController()..updateViewport(844, 390);
    final map = ConcertMapController();
    addTearDown(cache.dispose);
    addTearDown(camera.dispose);
    addTearDown(map.dispose);
    final seat = ConcertMockData.seats.firstWhere(
      (s) =>
          s.id.startsWith('SD-C') &&
          (s.bounds.centerX - 800).abs() < 100 &&
          s.status == SeatStatus.available,
    );
    final text = cache.sightlineText;
    final ink = cache.sightlineInk;
    final path = cache.sightline;
    map.toggleSeat(seat.id);
    map.focusSeat(seat.id);
    cache.updateFocusedSeat(map.focusedSeatId);
    final length = math.sqrt(
      math.pow(seat.bounds.centerX - 800, 2) +
          math.pow(seat.bounds.centerY - 140, 2),
    );
    expect(
      text.text!.toPlainText(),
      '${(length * 0.04).round()}m • Chính diện',
    );
    final span = text.text;
    final tag = cache.sightlineTag;
    cache.updateFocusedSeat(seat.id);
    expect(text.text, same(span));
    expect(cache.sightlineTag, same(tag));
    final painter = SeatMapPainter(
      cache: cache,
      camera: camera,
      mapState: map,
      fitScale: camera.viewport!.fitScale,
    );
    for (var i = 0; i < 5; i++) {
      camera.value = camera.zoomTarget(1.1, const Offset(422, 195));
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(844, 390));
      recorder.endRecording().dispose();
      expect(cache.sightlineText, same(text));
      expect(cache.sightlineText.text, same(span));
      expect(cache.sightlineInk, same(ink));
      expect(cache.sightline, same(path));
    }
    for (final side in ['L', 'R']) {
      final s = ConcertMockData.seats.firstWhere(
        (s) => s.id.startsWith('ST-$side'),
      );
      cache.updateFocusedSeat(s.id);
      expect(
        text.text!.toPlainText(),
        contains(side == 'L' ? 'Cánh trái' : 'Cánh phải'),
      );
    }
    cache.updateFocusedSeat(null);
    expect(cache.focusedSeatId, isNull);
    expect(cache.sightline.getBounds(), Rect.zero);
    expect(cache.sightlineText, same(text));
  });

  test('minimap viewport rectangle is world-clipped and selected dots reflect state', () {
    final cache = SeatMapPaintCache();
    final camera = CameraController()..updateViewport(844, 390);
    final map = ConcertMapController();
    addTearDown(cache.dispose);
    addTearDown(camera.dispose);
    addTearDown(map.dispose);
    final painter = SeatMapMinimapPainter(
      camera: camera,
      mapController: map,
      cache: cache,
    );
    final seats = ConcertMockData.seats
        .where((s) => s.status == SeatStatus.available)
        .take(3);
    for (final s in seats) {
      map.toggleSeat(s.id);
    }
    void paint() {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(112, 84));
      recorder.endRecording().dispose();
    }

    paint();
    expect(painter.lastSelectedDotCount, 3);
    expect(painter.lastVisibleWorldRect, const Rect.fromLTWH(0, 0, 1600, 1200));
    camera.value = camera.zoomTarget(3, const Offset(422, 195));
    camera.value = camera.centerTarget(WorldPoint(0, 0));
    paint();
    final raw = CoordinateTransformer.visibleWorldRect(
      camera.value,
      viewportWidth: 844,
      viewportHeight: 390,
    );
    expect(painter.lastVisibleWorldRect.left, raw.left.clamp(0, 1600));
    expect(painter.lastVisibleWorldRect.right, raw.right.clamp(0, 1600));
    expect(painter.lastVisibleWorldRect.top, greaterThanOrEqualTo(0));
    expect(painter.lastVisibleWorldRect.bottom, lessThanOrEqualTo(1200));
    map.clearSelection();
    paint();
    expect(painter.lastSelectedDotCount, 0);
    final edge = SeatMapMinimap.worldAt(
      const Offset(-100, 1000),
      const Size(112, 84),
    );
    expect(edge.x, 0);
    expect(edge.y, 1200);
  });
}
