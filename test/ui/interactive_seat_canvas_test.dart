import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/data/seat.dart';
import 'package:concert_seat_map/engine/coordinate_transformer.dart';
import 'package:concert_seat_map/ui/canvas/interactive_seat_canvas.dart';
import 'package:concert_seat_map/ui/screens/concert_map_screen.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    await tester.pumpWidget(const MaterialApp(home: ConcertMapScreen()));
    await tester.pump();
  }

  InteractiveSeatCanvas canvas(WidgetTester t) =>
      t.widget(find.byType(InteractiveSeatCanvas));
  Offset seatPosition(WidgetTester t, Seat seat) {
    final point = CoordinateTransformer.worldToScreen(
      WorldPoint(seat.bounds.centerX, seat.bounds.centerY),
      canvas(t).camera.value,
    );
    return t.getTopLeft(find.byKey(const ValueKey('seat-canvas-gestures'))) +
        Offset(point.x, point.y);
  }

  Future<void> pinch(WidgetTester t) async {
    final center = t.getCenter(
      find.byKey(const ValueKey('seat-canvas-gestures')),
    );
    final a = await t.startGesture(center - const Offset(60, 0), pointer: 1);
    final b = await t.startGesture(center + const Offset(60, 0), pointer: 2);
    await t.pump();
    for (var i = 1; i <= 5; i++) {
      await a.moveTo(center - Offset(60 + i * 12, 0));
      await b.moveTo(center + Offset(60 + i * 12, 0));
      await t.pump();
    }
    await a.up();
    await b.up();
    await t.pump();
  }

  testWidgets(
    'real pinch/pan clamp; taps use local coordinates after transforms',
    (t) async {
      await open(t);
      final initial = canvas(t).camera.value;
      await pinch(t);
      expect(canvas(t).camera.value.scale, greaterThan(initial.scale));
      await t.drag(
        find.byKey(const ValueKey('seat-canvas-gestures')),
        const Offset(30, 20),
      );
      await t.pump();
      expect(canvas(t).mapController.selectedSeatIds, isEmpty);
      final c = canvas(t).camera;
      expect(c.value, c.viewport!.clamp(c.value));
      final seats = ConcertMockData.seats
          .where(
            (s) => s.status == SeatStatus.available && s.zone == SeatZone.vip,
          )
          .toList();
      final seat = seats.firstWhere((s) {
        final p = seatPosition(t, s);
        return t
            .getRect(find.byKey(const ValueKey('seat-canvas-gestures')))
            .deflate(20)
            .contains(p);
      });
      await t.tapAt(seatPosition(t, seat));
      await t.pump();
      expect(canvas(t).mapController.selectedSeatIds, {seat.id});
      await t.tapAt(seatPosition(t, seat));
      await t.pump();
      expect(canvas(t).mapController.selectedSeatIds, isEmpty);
      await t.drag(
        find.byKey(const ValueKey('seat-canvas-gestures')),
        const Offset(-2500, -2500),
      );
      await t.pump();
      expect(c.value, c.viewport!.clamp(c.value));
      expect(canvas(t).mapController.selectedSeatIds, isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.binding.setSurfaceSize(null);
    },
  );
  testWidgets(
    'selection, camera and source statuses survive rebuild and rotation',
    (t) async {
      await open(t);
      final widget = canvas(t);
      final layoutNotifications = <SchedulerPhase>[];
      widget.camera.addListener(
        () => layoutNotifications.add(SchedulerBinding.instance.schedulerPhase),
      );
      final available = ConcertMockData.seats
          .where((s) => s.status == SeatStatus.available)
          .take(2)
          .toList();
      for (final seat in available) {
        await t.tapAt(seatPosition(t, seat));
        await t.pump();
      }
      expect(widget.mapController.selectedSeatIds.length, 2);
      for (final status in [SeatStatus.booked, SeatStatus.locked]) {
        final seat = ConcertMockData.seats.firstWhere(
          (s) => s.status == status,
        );
        await t.tapAt(seatPosition(t, seat));
        await t.pump();
        expect(widget.mapController.selectedSeatIds.length, 2);
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining(seat.id),
          ),
          findsOneWidget,
        );
      }
      await pinch(t);
      final before = widget.camera.value;
      await t.pumpWidget(
        MaterialApp(theme: ThemeData.dark(), home: const ConcertMapScreen()),
      );
      await t.pump();
      expect(canvas(t).camera, same(widget.camera));
      expect(widget.camera.value, before);
      final relativeZoom = before.scale / widget.camera.viewport!.fitScale;
      layoutNotifications.clear();
      await t.binding.setSurfaceSize(const Size(800, 450));
      await t.pump();
      await t.pump();
      expect(layoutNotifications, [SchedulerPhase.postFrameCallbacks]);
      expect(canvas(t).mapController, same(widget.mapController));
      expect(
        widget.mapController.selectedSeatIds,
        available.map((s) => s.id).toSet(),
      );
      expect(
        widget.camera.value.scale / widget.camera.viewport!.fitScale,
        closeTo(relativeZoom, 1e-8),
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.binding.setSurfaceSize(null);
    },
  );
}
