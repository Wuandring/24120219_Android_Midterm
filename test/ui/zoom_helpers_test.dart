import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/main.dart';
import 'package:concert_seat_map/ui/canvas/interactive_seat_canvas.dart';
import 'package:concert_seat_map/engine/coordinate_transformer.dart';
import 'package:concert_seat_map/ui/canvas/seat_map_paint_cache.dart';

void main() {
  Finder key(String s) => find.byKey(ValueKey(s));
  InteractiveSeatCanvas canvas(WidgetTester t) =>
      t.widget(find.byType(InteractiveSeatCanvas));
  Future<void> open(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(844, 390));
    await t.pumpWidget(const ConcertApp());
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.binding.setSurfaceSize(null);
  }

  testWidgets(
    'center-mirrored landscape pinch crosses transparent sheet wrapper; corner pans pass HUD',
    (t) async {
      await open(t);
      final c = canvas(t).camera;
      final initial = c.value.scale;
      final hud = t.getRect(key('concert-hud'));
      expect(hud.left, greaterThan(8));
      expect(hud.right, lessThan(836));
      final sheet = t.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      expect(sheet.controller!.size, closeTo(sheet.minChildSize, 1e-6));
      expect(
        t.getRect(key('ticket-drag-handle')).width,
        lessThanOrEqualTo(320),
      );
      expect(c.viewport!.fit().tx + 800 * initial, closeTo(422, 1e-6));
      final a = await t.startGesture(const Offset(342, 195), pointer: 1);
      await a.moveTo(const Offset(330, 195));
      await t.pump();
      final b = await t.startGesture(const Offset(514, 195), pointer: 2);
      await t.pump();
      for (var i = 1; i <= 6; i++) {
        await a.moveTo(Offset(330 - i * 15, 195));
        await b.moveTo(Offset(514 + i * 15, 195));
        await t.pump();
      }
      await b.up();
      await a.moveBy(const Offset(-12, 5));
      await a.up();
      await t.pumpAndSettle();
      expect(c.value.scale, greaterThan(initial * 1.3));
      final before = c.value;
      await t.dragFrom(const Offset(25, 25), const Offset(30, 5));
      await t.pumpAndSettle();
      expect(c.value, isNot(before));
      expect(canvas(t).mapController.selectedCount, 0);
      expect(t.takeException(), isNull);
      await close(t);
    },
  );
  testWidgets(
    'zoom buttons animate and clamp at both limits without changing ticket',
    (t) async {
      await open(t);
      final widget = canvas(t);
      final c = widget.camera;
      widget.mapController.toggleSeat('ST-L01');
      await t.pump();
      final before = c.value;
      await t.tap(key('zoom-in'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 150));
      expect(c.value.scale, greaterThan(before.scale));
      await t.pumpAndSettle();
      for (var i = 0; i < 12; i++) {
        await t.tap(key('zoom-in'));
        await t.pumpAndSettle();
      }
      expect(c.value.scale, closeTo(c.viewport!.maxScale, 1e-8));
      for (var i = 0; i < 20; i++) {
        await t.tap(key('zoom-out'));
        await t.pumpAndSettle();
      }
      expect(c.value.scale, closeTo(c.viewport!.minScale, 1e-8));
      expect(widget.mapController.selectedSeatIds, {'ST-L01'});
      expect(t.takeException(), isNull);
      await close(t);
    },
  );
  testWidgets(
    'empty double tap focal zoom and wheel zoom use local coordinates',
    (t) async {
      await open(t);
      final c = canvas(t).camera;
      const focal = Offset(70, 240);
      final world = CoordinateTransformer.screenToWorld(
        WorldPoint(focal.dx, focal.dy),
        c.value,
      );
      final initial = c.value.scale;
      await t.tapAt(focal);
      await t.pump(const Duration(milliseconds: 60));
      await t.tapAt(focal);
      await t.pumpAndSettle();
      expect(c.value.scale, closeTo(initial * 1.8, 1e-8));
      final screen = CoordinateTransformer.worldToScreen(world, c.value);
      expect(screen.x, closeTo(focal.dx, 1e-6));
      expect(screen.y, closeTo(focal.dy, 1e-6));
      final before = c.value.scale;
      await t.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(422, 220),
          scrollDelta: Offset(0, -80),
        ),
      );
      await t.pumpAndSettle();
      expect(c.value.scale, greaterThan(before));
      c.value = c.zoomTarget(100, focal);
      await t.pump();
      await t.tapAt(focal);
      await t.pump(const Duration(milliseconds: 60));
      await t.tapAt(focal);
      await t.pumpAndSettle();
      final fit = c.viewport!.fit();
      expect(c.value.scale, closeTo(fit.scale, 1e-8));
      expect(c.value.tx, closeTo(fit.tx, 1e-8));
      expect(c.value.ty, closeTo(fit.ty, 1e-8));
      expect(canvas(t).mapController.selectedCount, 0);
      expect(t.takeException(), isNull);
      await close(t);
    },
  );
  testWidgets(
    'landscape rotation starts sheet collapsed and cached architecture leaves FOH label gap',
    (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      await t.pumpWidget(const ConcertApp());
      await t.pumpAndSettle();
      await t.tap(key('toggle-ticket-sheet'));
      await t.pumpAndSettle();
      await t.binding.setSurfaceSize(const Size(844, 390));
      await t.pumpAndSettle();
      final sheet = t.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      expect(sheet.controller!.size, closeTo(sheet.minChildSize, 1e-6));
      final cache = SeatMapPaintCache();
      addTearDown(cache.dispose);
      expect(cache.foh.getBounds(), const Rect.fromLTWH(745, 782, 110, 36));
      expect(cache.stageExtrusions.length, 4);
      expect(cache.deckLips.length, 6);
      expect(cache.labels.first.painter.text!.style!.fontSize, 19);
      expect(
        cache.labels.first.painter.text!.style!.fontWeight,
        FontWeight.w700,
      );
      expect(
        cache.labels[6].anchor.dy - cache.foh.getBounds().bottom,
        greaterThanOrEqualTo(30),
      );
      expect(t.takeException(), isNull);
      await close(t);
    },
  );
}
