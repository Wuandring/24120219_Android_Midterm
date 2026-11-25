import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/main.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/data/seat.dart';
import 'package:concert_seat_map/state/filter_state.dart';
import 'package:concert_seat_map/engine/coordinate_transformer.dart';
import 'package:concert_seat_map/ui/canvas/interactive_seat_canvas.dart';
import 'package:concert_seat_map/ui/canvas/seat_map_painter.dart';

void main() {
  Finder key(String s) => find.byKey(ValueKey(s));
  InteractiveSeatCanvas canvas(WidgetTester t) =>
      t.widget(find.byType(InteractiveSeatCanvas));
  Future<void> open(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    await t.pumpWidget(const ConcertApp());
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.binding.setSurfaceSize(null);
  }

  Future<void> tapSeat(WidgetTester t, Seat seat) async {
    final p = CoordinateTransformer.worldToScreen(
      WorldPoint(seat.bounds.centerX, seat.bounds.centerY),
      canvas(t).camera.value,
    );
    await t.tapAt(t.getTopLeft(key('seat-canvas-gestures')) + Offset(p.x, p.y));
    await t.pump();
  }

  testWidgets(
    'keyboard leaves canvas size stable; canvas tap and pan dismiss search focus',
    (t) async {
      await open(t);
      addTearDown(t.view.resetViewInsets);
      for (final size in [const Size(390, 844), const Size(844, 390)]) {
        t.view.resetViewInsets();
        await t.binding.setSurfaceSize(size);
        await t.pumpAndSettle();
        expect(
          t.widget<Scaffold>(find.byType(Scaffold)).resizeToAvoidBottomInset,
          isFalse,
        );
        final c = canvas(t).camera;
        final viewport = c.viewport;
        final camera = c.value;
        final canvasSize = t.getSize(key('seat-canvas-gestures'));
        await t.showKeyboard(key('seat-search'));
        final field = t.widget<EditableText>(find.byType(EditableText));
        expect(field.focusNode.hasFocus, isTrue);
        t.view.viewInsets = const FakeViewPadding(bottom: 250);
        await t.pumpAndSettle();
        expect(t.getSize(key('seat-canvas-gestures')), canvasSize);
        expect(c.viewport, same(viewport));
        expect(c.value, camera);
        final origin = t.getTopLeft(key('seat-canvas-gestures'));
        await t.tapAt(origin + const Offset(25, 200));
        await t.pumpAndSettle();
        expect(field.focusNode.hasFocus, isFalse);
        await t.showKeyboard(key('seat-search'));
        await t.dragFrom(origin + const Offset(30, 200), const Offset(50, 0));
        await t.pumpAndSettle();
        expect(field.focusNode.hasFocus, isFalse);
        expect(t.takeException(), isNull);
      }
      t.view.resetViewInsets();
      await close(t);
    },
  );
  testWidgets(
    'zone and status selectors highlight independently and clear to neutral',
    (t) async {
      await open(t);
      final map = canvas(t).mapController;
      BoxDecoration decoration(String name) =>
          t.widget<Container>(key(name)).decoration! as BoxDecoration;
      expect(decoration('zone-filter-style').color, const Color(0xFF141417));
      expect(decoration('status-filter-style').color, const Color(0xFF141417));
      map.setZoneFilter(SeatZone.vip);
      await t.pump();
      expect(decoration('zone-filter-style').color, const Color(0x22C9A96E));
      expect(decoration('status-filter-style').color, const Color(0xFF141417));
      map.setStatusFilter(SeatFilterStatus.selected);
      await t.pump();
      expect(
        decoration('status-filter-style').border,
        Border.all(color: const Color(0xFFC9A96E), width: 0.7),
      );
      map.clearFilters();
      await t.pump();
      expect(decoration('zone-filter-style').color, const Color(0xFF141417));
      expect(decoration('status-filter-style').color, const Color(0xFF141417));
      await close(t);
    },
  );
  testWidgets(
    'search, quick clear, selectors and empty banner clear keep selection',
    (t) async {
      await open(t);
      final map = canvas(t).mapController;
      final seat = ConcertMockData.seats.firstWhere(
        (s) => s.status == SeatStatus.available,
      );
      map.toggleSeat(seat.id);
      await t.enterText(key('seat-search'), 'vp-c');
      await t.pump();
      expect(map.matchedCount, 30);
      await t.tap(key('clear-seat-search'));
      await t.pump();
      expect(map.hasActiveFilters, isFalse);
      await t.tap(key('zone-filter'));
      await t.pumpAndSettle();
      await t.tap(find.text('VIP').last);
      await t.pumpAndSettle();
      expect(map.matchedCount, 60);
      await t.tap(key('status-filter'));
      await t.pumpAndSettle();
      await t.tap(find.text('Đã đặt').last);
      await t.pumpAndSettle();
      expect(map.filters.status, SeatFilterStatus.booked);
      await t.enterText(key('seat-search'), 'missing');
      await t.pump();
      expect(find.text('Không tìm thấy chỗ phù hợp'), findsOneWidget);
      await t.tap(key('empty-clear-filters'));
      await t.pump();
      expect(map.value.matchingSeatIds, isNull);
      expect(t.widget<TextField>(key('seat-search')).controller!.text, '');
      expect(map.selectedSeatIds, {seat.id});
      expect(find.text('Không tìm thấy chỗ phù hợp'), findsNothing);
      await close(t);
    },
  );
  testWidgets(
    'dim unselected taps ignored; dim selected taps deselect without losing other seats',
    (t) async {
      await open(t);
      final map = canvas(t).mapController;
      final seats = ConcertMockData.seats
          .where((s) => s.status == SeatStatus.available)
          .take(3)
          .toList();
      map.toggleSeat(seats[0].id);
      map.toggleSeat(seats[1].id);
      map.setZoneFilter(SeatZone.vip);
      await t.pump();
      final painter = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<SeatMapPainter>()
          .single;
      expect(
        painter.mapState.value.matchingSeatIds!.contains(seats[0].id),
        isFalse,
      );
      expect(painter.visualState(seats[0]), SeatVisualState.selected);
      await tapSeat(t, seats[2]);
      expect(map.selectedCount, 2);
      await tapSeat(t, seats[0]);
      expect(map.selectedSeatIds, {seats[1].id});
      map.clearFilters();
      await t.pump();
      await tapSeat(t, seats[2]);
      expect(map.selectedCount, 2);
      expect(t.takeException(), isNull);
      await close(t);
    },
  );
  testWidgets(
    'legend opens and closes; controls remain stable across rotation',
    (t) async {
      await open(t);
      expect(find.text('Bảng chú thích'), findsNothing);
      await t.tap(key('show-legend'));
      await t.pumpAndSettle();
      expect(find.text('Bảng chú thích'), findsOneWidget);
      expect(find.text('Standing — hình tròn'), findsOneWidget);
      expect(find.textContaining('Đang chọn —'), findsOneWidget);
      await t.tap(find.text('Đóng'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final map = canvas(t).mapController;
      map.setSearchQuery('VP-C');
      map.setZoneFilter(SeatZone.vip);
      await t.pump();
      await t.binding.setSurfaceSize(const Size(844, 390));
      await t.pumpAndSettle();
      expect(map.matchedCount, 30);
      expect(t.takeException(), isNull);
      await t.tap(key('show-legend'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.text('Đóng'));
      await t.pumpAndSettle();
      await close(t);
    },
  );
  testWidgets(
    'animated reset preserves filters, query, focus, selections and sheet totals',
    (t) async {
      await open(t);
      final widget = canvas(t);
      final c = widget.camera;
      final map = widget.mapController;
      final seat = ConcertMockData.seats.firstWhere(
        (s) => s.status == SeatStatus.available,
      );
      map.toggleSeat(seat.id);
      map.focusSeat(seat.id);
      map.setZoneFilter(SeatZone.vip);
      map.setStatusFilter(SeatFilterStatus.available);
      map.setSearchQuery('VP-C');
      await t.pump();
      c.startGesture(const Offset(180, 300), 2);
      c.updateGesture(
        focalPoint: const Offset(180, 300),
        scale: 2,
        pointerCount: 2,
      );
      c.endGesture();
      await t.pump();
      final before = c.value;
      final snapshot = map.value;
      final filters = map.filters;
      await t.tap(key('reset-view'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 150));
      expect(c.value, isNot(before));
      expect(c.value, isNot(c.viewport!.fit()));
      await t.pumpAndSettle();
      expect(c.value, c.viewport!.fit());
      expect(map.filters, same(filters));
      expect(map.value, same(snapshot));
      expect(map.selectedSeatIds, {seat.id});
      expect(map.formattedTotalPrice, '1.800.000 đ');
      expect(map.focusedSeatId, seat.id);
      await t.binding.setSurfaceSize(const Size(844, 390));
      await t.pumpAndSettle();
      expect(map.filters.query, 'VP-C');
      expect(map.selectedCount, 1);
      expect(c.value, c.viewport!.fit());
      expect(t.takeException(), isNull);
      await close(t);
    },
  );
}
