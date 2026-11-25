import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/main.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/engine/coordinate_transformer.dart';
import 'package:concert_seat_map/ui/canvas/interactive_seat_canvas.dart';
import 'package:concert_seat_map/ui/canvas/seat_map_paint_cache.dart';

void main() {
  testWidgets(
    'portrait fit keeps all seat bounds above ticket; render review previews',
    (t) async {
      final font = Platform.environment['M5_PREVIEW_FONT'];
      if (font != null)
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
      for (final size in [const Size(390, 844), const Size(844, 390)]) {
        await t.binding.setSurfaceSize(size);
        await t.pumpWidget(
          const RepaintBoundary(
            key: ValueKey('matte-preview'),
            child: ConcertApp(),
          ),
        );
        await t.pumpAndSettle();
        final widget = t.widget<InteractiveSeatCanvas>(
          find.byType(InteractiveSeatCanvas),
        );
        final hud = t.getRect(find.byKey(const ValueKey('concert-hud')));
        final sheet = t.getRect(
          find.byKey(const ValueKey('ticket-drag-handle')),
        );
        for (final seat in ConcertMockData.seats) {
          final b = seat.bounds;
          final top = CoordinateTransformer.worldToScreen(
            WorldPoint(b.left, b.top),
            widget.camera.value,
          );
          final bottom = CoordinateTransformer.worldToScreen(
            WorldPoint(b.right, b.bottom),
            widget.camera.value,
          );
          expect(top.y, greaterThan(hud.bottom));
          if (size.width < size.height)
            expect(bottom.y, lessThan(sheet.top));
          else
            expect(bottom.y, lessThan(sheet.top));
        }
        if (font != null) {
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('matte-preview')),
          );
          await t.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'build/matte-preview-${size.width.toInt()}x${size.height.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
      await t.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'landscape clear left canvas accepts two-finger pinch and fits last Standard row',
    (t) async {
      await t.binding.setSurfaceSize(const Size(844, 390));
      await t.pumpWidget(const ConcertApp());
      await t.pumpAndSettle();
      final finder = find.byKey(const ValueKey('seat-canvas-gestures'));
      final widget = t.widget<InteractiveSeatCanvas>(
        find.byType(InteractiveSeatCanvas),
      );
      expect(t.getRect(finder), const Rect.fromLTWH(0, 0, 844, 390));
      final dock = t.getRect(find.byKey(const ValueKey('ticket-drag-handle')));
      expect(dock.left, greaterThanOrEqualTo(504));
      expect(dock.width, lessThanOrEqualTo(340));
      final hud = t.getRect(find.byKey(const ValueKey('concert-hud')));
      expect(hud.height, lessThanOrEqualTo(46));
      final bottom = ConcertMockData.seats.last.bounds;
      final point = CoordinateTransformer.worldToScreen(
        WorldPoint(bottom.centerX, bottom.bottom),
        widget.camera.value,
      );
      // Full-width centered fit still clears the collapsed right-hand ticket.
      expect(
        widget.camera.viewport!.fit().tx + 800 * widget.camera.value.scale,
        closeTo(422, 1e-6),
      );
      expect(point.y, lessThan(dock.top));
      expect(point.y, greaterThan(hud.bottom));
      final initial = widget.camera.value.scale;
      final a = await t.startGesture(const Offset(180, 190), pointer: 1);
      final b = await t.startGesture(const Offset(280, 190), pointer: 2);
      await t.pump();
      var previous = initial;
      for (var i = 1; i <= 6; i++) {
        await a.moveTo(Offset(180 - i * 10, 190));
        await b.moveTo(Offset(280 + i * 10, 190));
        await t.pump();
        expect(widget.camera.value.scale, greaterThanOrEqualTo(previous));
        previous = widget.camera.value.scale;
      }
      await a.up();
      await b.up();
      await t.pumpAndSettle();
      expect(widget.camera.value.scale, greaterThan(initial * 1.3));
      expect(widget.mapController.selectedCount, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.binding.setSurfaceSize(null);
    },
  );
  testWidgets(
    'architectural decoration avoids every existing seat and cache has deterministic dust',
    (t) async {
      final cache = SeatMapPaintCache();
      addTearDown(cache.dispose);
      final shapes = [cache.mainStage, cache.catwalk, cache.bStage, cache.foh];
      for (final g in cache.seats) {
        final rect = Path()..addRect(g.rect);
        for (final shape in shapes) {
          expect(
            Path.combine(
              ui.PathOperation.intersect,
              shape,
              rect,
            ).getBounds().isEmpty,
            isTrue,
            reason: g.seat.id,
          );
        }
      }
      expect(cache.stardust.length, 65);
      for (final dot in cache.stardust) {
        expect(dot.paint.color.a, inInclusiveRange(0.115, 0.325));
        expect(dot.position.dx < 100 || dot.position.dx > 1500, isTrue);
      }
      expect(cache.seats.first.inks[5].fill.color.a, closeTo(0.45, 0.005));
      expect(
        cache.labels
            .take(8)
            .map((l) => (l.painter.text! as TextSpan).text)
            .toList(),
        [
          'STANDING L',
          'STANDING R',
          'VIP L',
          'VIP C',
          'VIP R',
          'STANDARD L',
          'STANDARD C',
          'STANDARD R',
        ],
      );
    },
  );
}
