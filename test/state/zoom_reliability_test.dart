import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/state/camera_controller.dart';

void main() {
  test(
    'scaling works with one reported pointer and reverses to cumulative one',
    () {
      final c = CameraController();
      addTearDown(c.dispose);
      c.updateViewport(844, 390);
      final initial = c.value.scale;
      c.startGesture(const Offset(422, 195), 1);
      c.updateGesture(
        focalPoint: const Offset(422, 195),
        scale: 1.3,
        pointerCount: 1,
      );
      c.updateGesture(
        focalPoint: const Offset(422, 195),
        scale: 1.8,
        pointerCount: 1,
      );
      expect(c.value.scale, closeTo(initial * 1.8, 1e-9));
      c.updateGesture(
        focalPoint: const Offset(422, 195),
        scale: 1,
        pointerCount: 1,
      );
      expect(c.value.scale, closeTo(initial, 1e-9));
    },
  );
  test(
    'one-to-two pointer transition rebases exactly once then zoom continues',
    () {
      final c = CameraController();
      addTearDown(c.dispose);
      c.updateViewport(844, 390);
      c.startGesture(const Offset(350, 195), 1);
      c.updateGesture(
        focalPoint: const Offset(360, 195),
        scale: 1,
        pointerCount: 1,
      );
      final before = c.value;
      c.updateGesture(
        focalPoint: const Offset(422, 195),
        scale: 1.1,
        pointerCount: 2,
      );
      expect(c.value, before);
      c.updateGesture(
        focalPoint: const Offset(422, 195),
        scale: 1.65,
        pointerCount: 2,
      );
      expect(c.value.scale, closeTo(before.scale * 1.5, 1e-9));
    },
  );
}
