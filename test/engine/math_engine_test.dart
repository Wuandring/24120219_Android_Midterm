import 'package:flutter_test/flutter_test.dart' hide HitTester;
import 'package:concert_seat_map/data/seat.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/engine/camera_transform.dart';
import 'package:concert_seat_map/engine/coordinate_transformer.dart';
import 'package:concert_seat_map/engine/viewport_clamper.dart';
import 'package:concert_seat_map/engine/hit_tester.dart';

void samePoint(WorldPoint actual, WorldPoint expected) {
  expect(actual.x, closeTo(expected.x, 1e-8));
  expect(actual.y, closeTo(expected.y, 1e-8));
}

ViewportClamper viewport(double w, double h) => ViewportClamper(
  worldBounds: ConcertMockData.worldBounds,
  viewportWidth: w,
  viewportHeight: h,
);

void main() {
  group('camera and coordinates', () {
    test(
      'round trip works across scales, translations and negative coordinates',
      () {
        for (final scale in [0.01, 0.9, 1.0, 4.5, 100.0]) {
          final camera = CameraTransform(scale: scale, tx: -327, ty: 819);
          for (final p in [
            WorldPoint(0, 0),
            WorldPoint(1600, 1200),
            WorldPoint(-41, 57),
          ]) {
            samePoint(
              CoordinateTransformer.screenToWorld(
                CoordinateTransformer.worldToScreen(p, camera),
                camera,
              ),
              p,
            );
          }
        }
      },
    );
    test('pan changes screen position by the pixel delta', () {
      final c = CameraTransform(scale: 2, tx: 10, ty: -20).pan(30, -40);
      expect(c, CameraTransform(scale: 2, tx: 40, ty: -60));
      expect(c.hashCode, CameraTransform(scale: 2, tx: 40, ty: -60).hashCode);
    });
    test('focal world point stays fixed even when zoom hits limits', () {
      final camera = CameraTransform(scale: 1, tx: -83, ty: 51);
      final focal = WorldPoint(123, 456);
      final world = CoordinateTransformer.screenToWorld(focal, camera);
      for (final delta in [0.001, 0.7, 1.8, 1000.0]) {
        final next = camera.zoom(
          scaleDelta: delta,
          focalX: focal.x,
          focalY: focal.y,
          minScale: 0.9,
          maxScale: 4.5,
        );
        samePoint(CoordinateTransformer.worldToScreen(world, next), focal);
        expect(next.scale, inInclusiveRange(0.9, 4.5));
      }
    });
    test('visible world rectangle uses inverse transform', () {
      final rect = CoordinateTransformer.visibleWorldRect(
        CameraTransform(scale: 2, tx: -100, ty: 20),
        viewportWidth: 800,
        viewportHeight: 600,
      );
      expect(
        [rect.left, rect.top, rect.width, rect.height],
        [50, -10, 400, 300],
      );
    });
    test('invalid math inputs are rejected', () {
      for (final value in [0.0, -1.0, double.nan, double.infinity]) {
        expect(() => CameraTransform(scale: value), throwsArgumentError);
        expect(() => viewport(value, 600), throwsArgumentError);
        expect(
          () => CameraTransform(scale: 1).zoom(
            scaleDelta: value,
            focalX: 0,
            focalY: 0,
            minScale: 0.9,
            maxScale: 4.5,
          ),
          throwsArgumentError,
        );
      }
      expect(() => WorldPoint(double.nan, 0), throwsArgumentError);
      expect(
        () => CameraTransform(scale: 1, tx: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => CameraTransform(
          scale: 1,
        ).zoom(scaleDelta: 2, focalX: 0, focalY: 0, minScale: 2, maxScale: 1),
        throwsArgumentError,
      );
    });
  });
  group('viewport clamping', () {
    test('fit centers complete world in portrait and landscape', () {
      for (final v in [viewport(400, 800), viewport(800, 400)]) {
        final c = v.fit();
        samePoint(
          CoordinateTransformer.worldToScreen(WorldPoint(800, 600), c),
          WorldPoint(v.viewportWidth / 2, v.viewportHeight / 2),
        );
        expect(c.scale, v.fitScale);
        expect(1600 * c.scale, lessThanOrEqualTo(v.viewportWidth));
        expect(1200 * c.scale, lessThanOrEqualTo(v.viewportHeight));
      }
    });
    test('large map clamps at both edges after pan and zoom', () {
      final v = viewport(800, 600);
      final camera = CameraTransform(scale: 1, tx: -300, ty: -200);
      final top = v.pan(camera, 10000, 10000);
      final bottom = v.pan(camera, -10000, -10000);
      expect([top.tx, top.ty], [0, 0]);
      expect([bottom.tx, bottom.ty], [-800, -600]);
      for (final delta in [0.001, 1000.0]) {
        final c = v.zoom(camera, scaleDelta: delta, focalX: 400, focalY: 300);
        expect(c.scale, inInclusiveRange(v.minScale, v.maxScale));
        expect(v.clamp(c), c);
      }
    });
    test('smaller map centers each axis independently', () {
      final v = viewport(800, 1200);
      final c = v.clamp(CameraTransform(scale: 0.45, tx: 999, ty: -999));
      expect(c.tx, closeTo(40, 1e-9));
      expect(c.ty, closeTo(330, 1e-9));
      final mixed = v.clamp(CameraTransform(scale: 0.6, tx: 999, ty: -999));
      expect(mixed.tx, 0);
      expect(mixed.ty, 240);
    });
    test('clamps nonzero world origins correctly', () {
      final v = ViewportClamper(
        worldBounds: const WorldRect(-100, 50, 1600, 1200),
        viewportWidth: 800,
        viewportHeight: 600,
      );
      final c = v.clamp(CameraTransform(scale: 1, tx: 9999, ty: -9999));
      expect([c.tx, c.ty], [100, -650]);
    });
    test('rotation preserves relative zoom and center when bounds allow', () {
      final old = viewport(400, 800);
      final next = viewport(800, 400);
      final camera = old.clamp(
        CameraTransform(
          scale: old.fitScale * 4,
          tx: 200 - 800 * old.fitScale * 4,
          ty: 400 - 600 * old.fitScale * 4,
        ),
      );
      final resized = next.resize(camera, old);
      expect(resized.scale / next.fitScale, closeTo(4, 1e-9));
      samePoint(
        CoordinateTransformer.screenToWorld(WorldPoint(400, 200), resized),
        WorldPoint(800, 600),
      );
      expect(old.resize(resized, next).scale, closeTo(camera.scale, 1e-9));
    });
    test('resize clamps a camera near a world edge', () {
      final old = viewport(800, 600);
      final next = viewport(300, 900);
      final c = next.resize(old.pan(old.fit(), -9999, 9999), old);
      expect(next.clamp(c), c);
    });
  });
  group('hit testing', () {
    test('all 200 centers hit correctly after pan and zoom', () {
      for (final scale in [0.225, 0.5, 2.25]) {
        final c = CameraTransform(scale: scale, tx: -317, ty: 123);
        for (final seat in ConcertMockData.seats) {
          final p = CoordinateTransformer.worldToScreen(
            WorldPoint(seat.bounds.centerX, seat.bounds.centerY),
            c,
          );
          expect(
            HitTester.hitTest(
              seats: ConcertMockData.seats,
              screenPoint: p,
              camera: c,
            ),
            same(seat),
          );
        }
      }
    });
    test('circle includes circumference, excludes bounding-box corners', () {
      final seat = ConcertMockData.seats.first;
      final b = seat.bounds;
      expect(HitTester.contains(seat, WorldPoint(b.right, b.centerY)), isTrue);
      expect(HitTester.contains(seat, WorldPoint(b.left, b.top)), isFalse);
      expect(
        HitTester.contains(seat, WorldPoint(b.right + 0.001, b.centerY)),
        isFalse,
      );
    });
    test('all shape borders remain accurate at maximum zoom', () {
      final c = CameraTransform(
        scale: viewport(800, 600).maxScale,
        tx: -317.3,
        ty: 19.7,
      );
      for (final shape in SeatShape.values) {
        final seat = ConcertMockData.seats.firstWhere((s) => s.shape == shape);
        final b = seat.bounds;
        for (final p in [
          WorldPoint(b.left, b.centerY),
          WorldPoint(b.right, b.centerY),
          WorldPoint(b.centerX, b.top),
          WorldPoint(b.centerX, b.bottom),
        ]) {
          expect(
            HitTester.hitTest(
              seats: [seat],
              camera: c,
              screenPoint: CoordinateTransformer.worldToScreen(p, c),
            ),
            same(seat),
          );
        }
        if (shape != SeatShape.circle) {
          for (final p in [
            WorldPoint(b.left, b.top),
            WorldPoint(b.right, b.bottom),
          ]) {
            expect(HitTester.contains(seat, p), isTrue);
          }
        }
        for (final p in [
          WorldPoint(b.left - 0.001, b.centerY),
          WorldPoint(b.right + 0.001, b.centerY),
          WorldPoint(b.centerX, b.top - 0.001),
          WorldPoint(b.centerX, b.bottom + 0.001),
        ]) {
          expect(HitTester.contains(seat, p), isFalse);
        }
      }
    });
    test('empty space, excluded seats and booked/locked inspection', () {
      final c = CameraTransform(scale: 1);
      expect(
        HitTester.hitTest(
          seats: ConcertMockData.seats,
          screenPoint: WorldPoint(800, 100),
          camera: c,
        ),
        isNull,
      );
      for (final status in SeatStatus.values) {
        final seat = ConcertMockData.seats.firstWhere(
          (s) => s.status == status,
        );
        final point = WorldPoint(seat.bounds.centerX, seat.bounds.centerY);
        expect(
          HitTester.hitTest(seats: [seat], screenPoint: point, camera: c),
          same(seat),
        );
        expect(
          HitTester.hitTest(
            seats: [seat],
            screenPoint: point,
            camera: c,
            isEligible: (_) => false,
          ),
          isNull,
        );
      }
    });
  });
}

