import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/main.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/data/seat.dart';
import 'package:concert_seat_map/engine/coordinate_transformer.dart';
import 'package:concert_seat_map/engine/camera_transform.dart';
import 'package:concert_seat_map/ui/canvas/interactive_seat_canvas.dart';
import 'package:concert_seat_map/ui/canvas/seat_map_painter.dart';

void main() {
  Finder key(String id) => find.byKey(ValueKey(id));
  InteractiveSeatCanvas canvas(WidgetTester t) =>
      t.widget(find.byType(InteractiveSeatCanvas));
  final seats = ConcertMockData.seats
      .where((s) => s.status == SeatStatus.available)
      .take(3)
      .toList();
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
    await t.pumpWidget(
      const RepaintBoundary(
        key: ValueKey('polish-preview'),
        child: ConcertApp(),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.binding.setSurfaceSize(null);
  }

  Future<void> capture(WidgetTester t, String name) async {
    if (Platform.environment['M5_PREVIEW_FONT'] == null) return;
    final boundary = t.renderObject<RenderRepaintBoundary>(
      key('polish-preview'),
    );
    await t.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/polish-$name-${image.width}x${image.height}.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'collapsed rows never bleed; clear all is expanded-only and synced',
    (t) async {
      for (final size in [const Size(390, 844), const Size(844, 390)]) {
        await open(t, size);
        final map = canvas(t).mapController;
        for (final seat in seats) {
          map.toggleSeat(seat.id);
        }
        await t.pumpAndSettle();
        final sheet = t.widget<DraggableScrollableSheet>(
          find.byType(DraggableScrollableSheet),
        );
        expect(
          sheet.minChildSize,
          closeTo((68 / size.height).clamp(0.07, 0.24), 1e-8),
        );
        final body = key('ticket-list-visibility');
        expect(t.widget<Opacity>(body).opacity, 0);
        await capture(t, 'collapsed');
        final ignore = find
            .ancestor(of: body, matching: find.byType(IgnorePointer))
            .first;
        expect(t.widget<IgnorePointer>(ignore).ignoring, isTrue);
        expect(key('clear-ticket-selection'), findsNothing);
        sheet.controller!.jumpTo(sheet.minChildSize + 0.014);
        await t.pump();
        expect(t.widget<Opacity>(body).opacity, 0);
        await t.tap(key('toggle-ticket-sheet'));
        await t.pumpAndSettle();
        expect(t.widget<Opacity>(body).opacity, 1);
        expect(key('clear-ticket-selection'), findsOneWidget);
        await capture(t, 'expanded');
        await t.tap(key('seat-row-${seats.first.id}'));
        await t.pumpAndSettle();
        await t.tap(key('clear-ticket-selection'));
        await t.pumpAndSettle();
        expect(map.selectedCount, 0);
        expect(map.focusedSeatId, isNull);
        final painter = t
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<SeatMapPainter>()
            .single;
        expect(painter.visualState(seats.first), SeatVisualState.available);
        expect(key('clear-ticket-selection'), findsNothing);
        map.toggleSeat(seats.first.id);
        await t.pump();
        expect(key('clear-ticket-selection'), findsNothing);
        map.toggleSeat(seats[1].id);
        await t.pump();
        expect(key('clear-ticket-selection'), findsOneWidget);
        expect(t.takeException(), isNull);
        await close(t);
      }
    },
  );

  testWidgets(
    'minimap threshold, navigation, drag clamp and zoom badge stay in sync',
    (t) async {
      await open(t, const Size(844, 390));
      final c = canvas(t).camera;
      final map = canvas(t).mapController;
      map.toggleSeat(seats.first.id);
      final minimap = key('minimap-visibility');
      expect(t.widget<AnimatedOpacity>(minimap).opacity, 0);
      expect(key('zoom-badge'), findsNothing);
      await t.tap(key('zoom-out'));
      await t.pumpAndSettle();
      expect(find.text('0.9×'), findsOneWidget);
      await t.tap(key('reset-view'));
      await t.pumpAndSettle();
      c.value = c.zoomTarget(1.35, const Offset(422, 195));
      await t.pumpAndSettle();
      expect(t.widget<AnimatedOpacity>(minimap).opacity, 0);
      c.value = c.zoomTarget(2 / 1.35, const Offset(422, 195));
      await t.pumpAndSettle();
      expect(t.widget<AnimatedOpacity>(minimap).opacity, 1);
      expect(find.text('2.0×'), findsOneWidget);
      final rect = t.getRect(key('seat-minimap'));
      expect(rect.size, const Size(112, 84));
      final at = rect.topLeft + const Offset(84, 42);
      await t.tapAt(at);
      await t.pumpAndSettle();
      // 4px inset, aspect-preserving 104x78 world overview, centered vertically.
      final wx = (84 - 4) / (104 / 1600);
      final center = CoordinateTransformer.screenToWorld(
        WorldPoint(422, 195),
        c.value,
      );
      expect(center.x, closeTo(wx, 1e-6));
      expect(center.y, closeTo(600, 1e-6));
      await t.dragFrom(rect.center, const Offset(-180, 100));
      await t.pumpAndSettle();
      expect(
        c.value,
        c.viewport!.clamp(
          CameraTransform(
            scale: c.value.scale,
            tx: 422,
            ty: 195 - 1200 * c.value.scale,
          ),
        ),
      );
      expect(map.selectedSeatIds, {seats.first.id});
      await t.tap(key('reset-view'));
      await t.pumpAndSettle();
      expect(t.widget<AnimatedOpacity>(minimap).opacity, 0);
      expect(key('zoom-badge'), findsNothing);
      // Hidden minimap allows a normal canvas gesture through its old bounds.
      final before = c.value;
      await t.dragFrom(rect.center, const Offset(35, -15));
      await t.pumpAndSettle();
      expect(c.value, isNot(before));
      expect(t.takeException(), isNull);
      await close(t);
    },
  );

  testWidgets(
    'minimap interrupts seat focus animation and survives rotation with ticket',
    (t) async {
      await open(t, const Size(390, 844));
      final w = canvas(t);
      w.mapController.toggleSeat(seats.first.id);
      await t.pump();
      await t.tap(key('toggle-ticket-sheet'));
      await t.pumpAndSettle();
      await t.tap(key('seat-row-${seats.first.id}'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 220));
      await capture(t, 'sightline');
      await t.tap(key('seat-minimap'));
      await t.pumpAndSettle();
      final after = w.camera.value;
      final previousViewport = w.camera.viewport!;
      await t.pump(const Duration(seconds: 1));
      expect(w.camera.value, after);
      await capture(t, 'focus');
      await t.binding.setSurfaceSize(const Size(844, 390));
      await t.pumpAndSettle();
      expect(w.mapController.selectedCount, 1);
      expect(w.mapController.focusedSeatId, seats.first.id);
      expect(
        w.camera.value,
        w.camera.viewport!.resize(after, previousViewport),
      );
      await capture(t, 'focus');
      expect(t.takeException(), isNull);
      await close(t);
    },
  );

  testWidgets('canvas and camera controls dispatch SDK haptics', (t) async {
    final calls = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate')
          calls.add(call.arguments as String);
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(t, const Size(390, 844));
    final w = canvas(t);
    Future<void> tapSeat(Seat seat) async {
      final p = CoordinateTransformer.worldToScreen(
        WorldPoint(seat.bounds.centerX, seat.bounds.centerY),
        w.camera.value,
      );
      await t.tapAt(Offset(p.x, p.y));
      await t.pump();
    }

    await tapSeat(seats.first);
    await tapSeat(seats.first);
    await tapSeat(
      ConcertMockData.seats.firstWhere((s) => s.status == SeatStatus.booked),
    );
    await tapSeat(
      ConcertMockData.seats.firstWhere((s) => s.status == SeatStatus.locked),
    );
    await t.tap(key('zoom-in'));
    await t.pumpAndSettle();
    await t.tap(key('zoom-out'));
    await t.pumpAndSettle();
    await t.tap(key('reset-view'));
    await t.pumpAndSettle();
    expect(
      calls.where((s) => s == 'HapticFeedbackType.selectionClick').length,
      5,
    );
    expect(calls.where((s) => s == 'HapticFeedbackType.lightImpact').length, 2);
    await close(t);
  });
}
