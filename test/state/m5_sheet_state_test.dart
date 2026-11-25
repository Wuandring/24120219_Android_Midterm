import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/state/concert_map_controller.dart';
import 'package:concert_seat_map/state/camera_controller.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/data/seat.dart';
import 'package:concert_seat_map/engine/coordinate_transformer.dart';

void main() {
  test('ordered seat totals, remove, clear, focus and immutable snapshots', () {
    final c = ConcertMapController();
    addTearDown(c.dispose);
    final seats = [
      for (final zone in SeatZone.values)
        ConcertMockData.seats.firstWhere(
          (s) => s.zone == zone && s.status == SeatStatus.available,
        ),
    ];
    for (final seat in seats) {
      c.toggleSeat(seat.id);
    }
    expect(c.selectedSeats, seats);
    expect(c.selectedCount, 3);
    expect(c.totalPrice, 6500000);
    expect(c.formattedTotalPrice, '6.500.000 đ');
    expect(ConcertMapController.formatVnd(0), '0 đ');
    expect(c.focusSeat(seats.first.id), isTrue);
    final snapshot = c.value;
    expect(snapshot.focusedSeatId, seats.first.id);
    c.removeSeat(seats.first.id);
    expect(c.focusedSeatId, isNull);
    expect(snapshot.selectedSeatIds.length, 3);
    expect(snapshot.focusedSeatId, seats.first.id);
    expect(c.focusSeat(seats.first.id), isFalse);
    expect(() => c.selectedSeats.clear(), throwsUnsupportedError);
    c.clearSelection();
    expect(c.selectedCount, 0);
    expect(c.formattedTotalPrice, '0 đ');
    expect(c.focusedSeatId, isNull);
  });
  test('inspection preserves selections; removing focused seat restores source state', () {
    final c = ConcertMapController();
    addTearDown(c.dispose);
    final available = ConcertMockData.seats.firstWhere(
      (s) => s.status == SeatStatus.available,
    );
    final booked = ConcertMockData.seats.firstWhere(
      (s) => s.status == SeatStatus.booked,
    );
    c.toggleSeat(available.id);
    c.focusSeat(available.id);
    c.inspectSeat(booked.id);
    expect(c.selectedCount, 1);
    expect(c.inspectedSeat, booked);
    c.toggleSeat(available.id);
    expect(c.focusedSeatId, isNull);
    expect(c.selectedCount, 0);
    expect(available.status, SeatStatus.available);
  });
  test('edge clearance centers last Standard row and remains bounded', () {
    final c = CameraController();
    addTearDown(c.dispose);
    final seat = ConcertMockData.seats.lastWhere(
      (s) => s.zone == SeatZone.standard,
    );
    for (final size in [const Size(390, 360), const Size(800, 160)]) {
      c.updateViewport(size.width, size.height);
      c.value = c.focusTarget(seat);
      final p = CoordinateTransformer.worldToScreen(
        WorldPoint(seat.bounds.centerX, seat.bounds.centerY),
        c.value,
      );
      expect(p.x, closeTo(size.width / 2, 1e-8));
      expect(p.y, closeTo(size.height / 2, 1e-8));
      final inset = size.height * 0.42;
      final target = c.focusTarget(seat, bottomInset: inset);
      final visiblePoint = CoordinateTransformer.worldToScreen(
        WorldPoint(seat.bounds.centerX, seat.bounds.centerY),
        target,
      );
      expect(visiblePoint.y, closeTo((size.height - inset) / 2, 1e-8));
      expect(c.viewport!.viewportHeight, size.height);
      expect(c.value.scale, greaterThanOrEqualTo(1.6 * c.viewport!.fitScale));
      expect(
        c.viewport!.clamp(c.value.pan(-100000, -100000)).ty,
        closeTo(
          size.height - 1200 * c.value.scale - c.viewport!.edgePaddingY,
          1e-8,
        ),
      );
    }
  });
}
