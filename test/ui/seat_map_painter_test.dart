import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/data/seat.dart';
import 'package:concert_seat_map/engine/camera_transform.dart';
import 'package:concert_seat_map/engine/viewport_clamper.dart';
import 'package:concert_seat_map/main.dart';
import 'package:concert_seat_map/ui/canvas/seat_map_paint_cache.dart';
import 'package:concert_seat_map/ui/canvas/seat_map_painter.dart';

void main() {
  late SeatMapPaintCache cache;
  late ValueNotifier<CameraTransform> camera;
  late ValueNotifier<SeatMapRenderState> state;
  setUp(() {
    cache = SeatMapPaintCache();
    camera = ValueNotifier(CameraTransform(scale: 1));
    state = ValueNotifier(SeatMapRenderState());
  });
  tearDown(() {
    cache.dispose();
    camera.dispose();
    state.dispose();
  });
  SeatMapPainter painter() => SeatMapPainter(
    cache: cache,
    camera: camera,
    mapState: state,
    fitScale: 1,
  );
  void draw(SeatMapPainter p, Size size) {
    final recorder = ui.PictureRecorder();
    p.paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
  }

  testWidgets('full world paints all seats; LOD uses exact threshold', (
    tester,
  ) async {
    final p = painter();
    draw(p, const Size(1600, 1200));
    expect(p.lastPaintedSeatCount, 200);
    expect(p.lastPaintedCodeCount, 0);
    camera.value = CameraTransform(scale: 1.35 - 1e-8);
    expect(p.showSeatCodes, isFalse);
    camera.value = CameraTransform(scale: 1.35);
    draw(p, const Size(2400, 1800));
    expect(p.lastPaintedSeatCount, 200);
    expect(p.lastPaintedCodeCount, 200);
  });
  testWidgets('culling skips offscreen seats and keeps intersecting seats', (
    tester,
  ) async {
    final p = painter();
    draw(p, const Size(500, 400));
    expect(p.lastPaintedSeatCount, inExclusiveRange(0, 200));
    camera.value = CameraTransform(scale: 1, tx: -5000, ty: -5000);
    draw(p, const Size(500, 400));
    expect(p.lastPaintedSeatCount, 0);
    final seat = cache.seats.first;
    camera.value = CameraTransform(
      scale: 1,
      tx: -seat.rect.right + 1,
      ty: -seat.rect.top,
    );
    draw(p, const Size(10, 40));
    expect(p.lastPaintedSeatCount, greaterThan(0));
  });
  testWidgets(
    'all visual states and filtered selection render without mutation',
    (tester) async {
      final available = ConcertMockData.seats.firstWhere(
        (s) => s.status == SeatStatus.available,
      );
      state.value = SeatMapRenderState(
        selectedSeatIds: {available.id},
        matchingSeatIds: {},
      );
      final p = painter();
      expect(p.visualState(available), SeatVisualState.selected);
      for (final seat in ConcertMockData.seats.where(
        (s) => s.status != SeatStatus.available,
      )) {
        expect(p.visualState(seat).name, seat.status.name);
      }
      draw(p, const Size(1600, 1200));
      expect(state.value.selectedSeatIds, {available.id});
      expect(() => state.value.selectedSeatIds.clear(), throwsUnsupportedError);
    },
  );
  testWidgets('merged notifications repaint without rebuilding host', (
    tester,
  ) async {
    var builds = 0;
    final p = painter();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (_) {
            builds++;
            return CustomPaint(painter: p, size: const Size(1600, 1200));
          },
        ),
      ),
    );
    final before = builds;
    camera.value = CameraTransform(scale: 2);
    await tester.pump();
    state.value = SeatMapRenderState(selectedSeatIds: {'ST-L01'});
    await tester.pump();
    expect(builds, before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('screen fits portrait and landscape with one seat painter', (
    tester,
  ) async {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const ConcertApp());
      await tester.pump();
      final paints = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter is SeatMapPainter);
      expect(paints.length, 1);
      expect(
        (paints.single.painter! as SeatMapPainter).lastPaintedSeatCount,
        200,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });
  testWidgets('export fit and state previews for visual review', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final fontPath = Platform.environment['M3_PREVIEW_FONT'];
      if (fontPath != null) {
        final loader = FontLoader('Roboto')
          ..addFont(
            File(fontPath)
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
        cache.dispose();
        cache = SeatMapPaintCache();
      }
      final selected = ConcertMockData.seats
          .firstWhere((s) => s.status == SeatStatus.available)
          .id;
      for (final zoomed in [false, true]) {
        final viewport = ViewportClamper(
          worldBounds: ConcertMockData.worldBounds,
          viewportWidth: 1200,
          viewportHeight: 900,
        );
        camera.value = zoomed
            ? CameraTransform(scale: 1.6, tx: -350, ty: -330)
            : viewport.fit();
        state.value = SeatMapRenderState(
          selectedSeatIds: {selected, 'ST-L04'},
          matchingSeatIds: zoomed
              ? ConcertMockData.seats
                    .where((s) => s.id != selected)
                    .map((s) => s.id)
                    .toSet()
              : null,
        );
        final p = SeatMapPainter(
          cache: cache,
          camera: camera,
          mapState: state,
          fitScale: viewport.fitScale,
        );
        final recorder = ui.PictureRecorder();
        p.paint(Canvas(recorder), const Size(1200, 900));
        final picture = recorder.endRecording();
        final image = await picture.toImage(1200, 900);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        {
          final file = File('build/m3-preview-${zoomed ? 'zoom' : 'fit'}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        }
        image.dispose();
        picture.dispose();
      }
    });
  });
}
