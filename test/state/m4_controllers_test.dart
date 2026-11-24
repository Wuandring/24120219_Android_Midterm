import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/state/camera_controller.dart';
import 'package:concert_seat_map/state/concert_map_controller.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/data/seat.dart';
import 'package:concert_seat_map/engine/coordinate_transformer.dart';

void main() {
  test(
    'fit only once; same-size updates preserve camera without notifications',
    () {
      final c = CameraController();
      addTearDown(c.dispose);
      c.updateViewport(800, 600);
      c.startGesture(const Offset(400, 300), 2);
      c.updateGesture(
        focalPoint: const Offset(400, 300),
        scale: 2,
        pointerCount: 2,
      );
      final before = c.value;
      var notifications = 0;
      c.addListener(() => notifications++);
      expect(c.updateViewport(800, 600), isFalse);
      expect(c.value, before);
      expect(notifications, 0);
    },
  );
  test(
    'cumulative pinch becomes incremental and preserves moving focal point',
    () {
      final c = CameraController();
      addTearDown(c.dispose);
      c.updateViewport(800, 600);
      final initial = c.value.scale;
      final point = CoordinateTransformer.screenToWorld(
        WorldPoint(400, 300),
        c.value,
      );
      c.startGesture(const Offset(400, 300), 2);
      c.updateGesture(
        focalPoint: const Offset(400, 300),
        scale: 1.5,
        pointerCount: 2,
      );
      c.updateGesture(
        focalPoint: const Offset(420, 310),
        scale: 2,
        pointerCount: 2,
      );
      expect(c.value.scale, closeTo(initial * 2, 1e-9));
      final screen = CoordinateTransformer.worldToScreen(point, c.value);
      expect(screen.x, closeTo(420, 1e-9));
      expect(screen.y, closeTo(310, 1e-9));
    },
  );
  test('finger transitions rebase; pan and zoom stay clamped', () {
    final c = CameraController();
    addTearDown(c.dispose);
    c.updateViewport(800, 600);
    c.startGesture(const Offset(400, 300), 2);
    c.updateGesture(
      focalPoint: const Offset(400, 300),
      scale: 2,
      pointerCount: 2,
    );
    final before = c.value;
    c.updateGesture(
      focalPoint: const Offset(100, 100),
      scale: 1,
      pointerCount: 1,
    );
    expect(c.value, before);
    c.updateGesture(
      focalPoint: const Offset(110, 120),
      scale: 1,
      pointerCount: 1,
    );
    expect(c.value.tx, closeTo(before.tx + 10, 1e-9));
    expect(c.value.ty, closeTo(before.ty + 20, 1e-9));
    final panned = c.value;
    c.updateGesture(
      focalPoint: const Offset(500, 400),
      scale: 1,
      pointerCount: 2,
    );
    expect(c.value, panned);
    c.updateGesture(
      focalPoint: const Offset(500, 400),
      scale: 100,
      pointerCount: 2,
    );
    expect(c.value.scale, c.viewport!.maxScale);
    c.updateGesture(
      focalPoint: const Offset(-10000, -10000),
      scale: 100,
      pointerCount: 2,
    );
    expect(c.value, c.viewport!.clamp(c.value));
    c.updateGesture(
      focalPoint: const Offset(500, 400),
      scale: 0.001,
      pointerCount: 2,
    );
    expect(c.value.scale, c.viewport!.minScale);
    c.endGesture();
  });
  test(
    'resize preserves relative zoom and cancels stale gesture baselines',
    () {
      final c = CameraController();
      addTearDown(c.dispose);
      c.updateViewport(400, 800);
      c.startGesture(const Offset(200, 400), 2);
      c.updateGesture(
        focalPoint: const Offset(200, 400),
        scale: 3,
        pointerCount: 2,
      );
      c.updateViewport(800, 400);
      expect(c.value.scale / c.viewport!.fitScale, closeTo(3, 1e-9));
      final before = c.value;
      c.updateGesture(
        focalPoint: const Offset(10, 10),
        scale: 1,
        pointerCount: 1,
      );
      expect(c.value, before);
    },
  );
  test(
    'ordered unique selection toggles available only; snapshots are immutable',
    () {
      final c = ConcertMapController();
      addTearDown(c.dispose);
      final seats = ConcertMockData.seats
          .where((s) => s.status == SeatStatus.available)
          .take(2)
          .toList();
      c.toggleSeat(seats[0].id);
      c.toggleSeat(seats[1].id);
      final snapshot = c.value;
      expect(c.selectedSeatIds.toList(), seats.map((s) => s.id).toList());
      c.toggleSeat(seats[0].id);
      expect(c.selectedSeatIds, {seats[1].id});
      expect(snapshot.selectedSeatIds.length, 2);
      c.toggleSeat(seats[0].id);
      expect(c.selectedSeatIds.length, 2);
      var notifications = 0;
      c.addListener(() => notifications++);
      for (final seat in ConcertMockData.seats.where(
        (s) => s.status != SeatStatus.available,
      )) {
        expect(c.toggleSeat(seat.id), isFalse);
      }
      expect(c.toggleSeat('invalid'), isFalse);
      expect(notifications, 0);
      expect(() => c.selectedSeatIds.clear(), throwsUnsupportedError);
    },
  );
}
