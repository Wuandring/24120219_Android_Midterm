import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/data/seat.dart';
import 'package:concert_seat_map/engine/coordinate_transformer.dart';
import 'package:concert_seat_map/ui/canvas/interactive_seat_canvas.dart';
import 'package:concert_seat_map/ui/canvas/seat_map_painter.dart';
import 'package:concert_seat_map/ui/screens/concert_map_screen.dart';

void main() {
  InteractiveSeatCanvas canvas(WidgetTester t) =>
      t.widget(find.byType(InteractiveSeatCanvas));
  Finder key(String value) => find.byKey(ValueKey(value));
  Future<void> open(WidgetTester t, Size size) async {
    await t.binding.setSurfaceSize(size);
    final font = Platform.environment['M5_PREVIEW_FONT'];
    if (font != null) {
      await t.runAsync(() async {
        final loader = FontLoader('Roboto')
          ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
        await loader.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            File('${File(font).parent.path}/materialicons-regular.otf')
                .readAsBytes()
                .then(ByteData.sublistView),
          );
        await icons.load();
      });
    }
    final theme = ThemeData.dark();
    await t.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('m5-preview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: const ConcertMapScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, String name) async {
    if (Platform.environment['M5_PREVIEW_FONT'] == null) return;
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('m5-preview')),
    );
    await t.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/m5-$name-${image.width}x${image.height}.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.binding.setSurfaceSize(null);
  }

  testWidgets(
    'sheet dragging and toggling leave camera untouched after focus and manual pan',
    (t) async {
      await open(t, const Size(390, 844));
      final widget = canvas(t);
      final c = widget.camera;
      final viewport = c.viewport;
      final container = t.getSize(key('seat-canvas-gestures'));
      expect(viewport!.viewportWidth, container.width);
      expect(viewport.viewportHeight, container.height);
      final initial = c.value;
      var notifications = 0;
      c.addListener(() => notifications++);
      // Release before the midpoint: the custom handle must snap back down.
      final sheet = t.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      await t.drag(key('ticket-drag-handle'), const Offset(0, -70));
      await t.pumpAndSettle();
      expect(sheet.controller!.size, closeTo(sheet.minChildSize, 1e-6));
      expect(c.value, initial);
      expect(notifications, 0);
      await t.tap(key('toggle-ticket-sheet'));
      await t.pumpAndSettle();
      expect(c.value, initial);
      expect(c.viewport, same(viewport));
      expect(notifications, 0);
      final seat = ConcertMockData.seats.lastWhere(
        (s) => s.status == SeatStatus.available,
      );
      widget.mapController.toggleSeat(seat.id);
      await t.pump();
      await t.tap(key('seat-row-${seat.id}'));
      await t.pumpAndSettle();
      final focused = c.value;
      notifications = 0;
      await t.tap(key('toggle-ticket-sheet'));
      await t.pumpAndSettle();
      expect(c.value, focused);
      expect(notifications, 0);
      final origin = t.getTopLeft(key('seat-canvas-gestures'));
      await t.dragFrom(origin + const Offset(180, 120), const Offset(30, 25));
      await t.pumpAndSettle();
      final manual = c.value;
      expect(manual, isNot(focused));
      notifications = 0;
      await t.drag(key('ticket-drag-handle'), const Offset(0, -400));
      await t.pumpAndSettle();
      expect(sheet.controller!.size, closeTo(sheet.maxChildSize, 1e-6));
      expect(c.value, manual);
      expect(notifications, 0);
      expect(c.viewport, same(viewport));
      // Rotation may resize the camera, but must preserve the manual world
      // center rather than re-center the still-highlighted selected seat.
      await t.binding.setSurfaceSize(const Size(844, 390));
      await t.pumpAndSettle();
      // Resize may clamp the manual center at the new viewport boundary.
      expect(c.value, c.viewport!.resize(manual, viewport));
      expect(t.takeException(), isNull);
      await close(t);
    },
  );
  testWidgets(
    'selected summary takes priority over inspection and zones use display names',
    (t) async {
      await open(t, const Size(390, 844));
      final map = canvas(t).mapController;
      final seat = ConcertMockData.seats.firstWhere(
        (s) => s.status == SeatStatus.available,
      );
      final booked = ConcertMockData.seats.firstWhere(
        (s) => s.status == SeatStatus.booked,
      );
      map.toggleSeat(seat.id);
      map.inspectSeat(booked.id);
      await t.pump();
      expect(t.widget<Text>(key('ticket-summary')).data, '1 ghế • 1.800.000 đ');
      await t.tap(key('toggle-ticket-sheet'));
      await t.pumpAndSettle();
      expect(find.text('${seat.id} • Standing'), findsOneWidget);
      final geometry = canvas(t).cache.seats
          .firstWhere((g) => g.seat.id == 'VP-C10');
      expect(geometry.code.text!.style!.fontSize, 9.0);
      expect(geometry.code.text!.style!.letterSpacing, 0);
      if (Platform.environment['M5_PREVIEW_FONT'] != null) {
        expect(geometry.code.width, lessThan(50));
      }
      map.removeSeat(seat.id);
      await t.pump();
      expect(
        t.widget<Text>(key('ticket-summary')).data,
        '${booked.id} • Đã đặt',
      );
      await close(t);
    },
  );
  testWidgets(
    'Canvas selection updates sheet; sheet delete restores canvas immediately',
    (t) async {
      await open(t, const Size(390, 844));
      final seat = ConcertMockData.seats.firstWhere(
        (s) => s.status == SeatStatus.available,
      );
      final widget = canvas(t);
      final p = CoordinateTransformer.worldToScreen(
        WorldPoint(seat.bounds.centerX, seat.bounds.centerY),
        widget.camera.value,
      );
      await t.tapAt(
        t.getTopLeft(key('seat-canvas-gestures')) + Offset(p.x, p.y),
      );
      await t.pump();
      expect(find.text('1 ghế • 1.800.000 đ'), findsOneWidget);
      await t.tap(key('toggle-ticket-sheet'));
      await t.pumpAndSettle();
      expect(key('seat-row-${seat.id}'), findsOneWidget);
      await t.tap(key('delete-${seat.id}'));
      await t.pump();
      expect(widget.mapController.selectedCount, 0);
      final painter = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<SeatMapPainter>()
          .single;
      expect(painter.visualState(seat), SeatVisualState.available);
      expect(find.text('Chạm ghế trống để chọn vé'), findsOneWidget);
      expect(t.takeException(), isNull);
      await close(t);
    },
  );
  testWidgets(
    'row focus animates above sheet, pulses, survives rotation and clears on delete',
    (t) async {
      await open(t, const Size(390, 844));
      final widget = canvas(t);
      final seat = ConcertMockData.seats.lastWhere(
        (s) => s.status == SeatStatus.available,
      );
      widget.mapController.toggleSeat(seat.id);
      await t.pump();
      await t.tap(key('toggle-ticket-sheet'));
      await t.pumpAndSettle();
      final before = widget.camera.value;
      await t.tap(key('seat-row-${seat.id}'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 150));
      expect(widget.camera.value, isNot(before));
      expect(widget.mapController.focusedSeatId, seat.id);
      await t.pumpAndSettle();
      void expectCentered() {
        final c = widget.camera;
        final point = CoordinateTransformer.worldToScreen(
          WorldPoint(seat.bounds.centerX, seat.bounds.centerY),
          c.value,
        );
        final origin = t.getTopLeft(key('seat-canvas-gestures'));
        final sheetTop = t.getTopLeft(key('ticket-drag-handle')).dy;
        expect(point.x, closeTo(c.viewport!.viewportWidth / 2, 1e-6));
        expect(point.y, closeTo((sheetTop - origin.dy) / 2, 1e-6));
        expect(origin.dy + point.y + 25, lessThan(sheetTop));
        expect(c.value.scale, greaterThanOrEqualTo(1.6 * c.viewport!.fitScale));
      }

      expectCentered();
      await capture(t, 'focus');
      final painter = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<SeatMapPainter>()
          .single;
      expect(painter.mapState.value.focusedSeatId, seat.id);
      // Repeat focus starts a fresh 1.2-second pulse after the camera transition.
      await t.tap(key('seat-row-${seat.id}'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 350));
      await t.pump(const Duration(milliseconds: 100));
      expect(canvas(t).spotlight.value, inExclusiveRange(0.0, 1.0));
      await t.pumpAndSettle();
      await t.binding.setSurfaceSize(const Size(844, 390));
      await t.pumpAndSettle();
      expect(widget.mapController.focusedSeatId, seat.id);
      expect(widget.mapController.selectedCount, 1);
      await capture(t, 'landscape');
      expectCentered();
      await capture(t, 'focus');
      expect(
        t.getRect(key('toggle-ticket-sheet')).bottom,
        lessThanOrEqualTo(390),
      );
      expect(t.takeException(), isNull);
      await t.tap(key('delete-${seat.id}'));
      await t.pumpAndSettle();
      expect(widget.mapController.focusedSeatId, isNull);
      expect(widget.mapController.selectedCount, 0);
      await close(t);
    },
  );
  testWidgets(
    'long selection list scrolls; drag and toggle controls stay visible in both orientations',
    (t) async {
      await open(t, const Size(390, 844));
      final available = ConcertMockData.seats
          .where((s) => s.status == SeatStatus.available)
          .toList();
      for (final seat in available) {
        canvas(t).mapController.toggleSeat(seat.id);
      }
      await t.pump();
      await t.drag(key('ticket-drag-handle'), const Offset(0, -500));
      await t.pumpAndSettle();
      final list = find.descendant(
        of: key('selected-seats-list'),
        matching: find.byType(Scrollable),
      );
      await t.scrollUntilVisible(
        key('seat-row-${available.last.id}'),
        240,
        scrollable: list,
        maxScrolls: 100,
      );
      await t.pumpAndSettle();
      expect(key('delete-${available.last.id}').hitTestable(), findsOneWidget);
      await t.binding.setSurfaceSize(const Size(844, 390));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(key('toggle-ticket-sheet').hitTestable(), findsOneWidget);
      final sheet = t.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      expect(sheet.maxChildSize, lessThanOrEqualTo(0.42));
      await t.tap(key('toggle-ticket-sheet'));
      await t.pumpAndSettle();
      expect(key('toggle-ticket-sheet').hitTestable(), findsOneWidget);
      expect(canvas(t).mapController.selectedCount, available.length);
      expect(t.takeException(), isNull);
      await close(t);
    },
  );
}
