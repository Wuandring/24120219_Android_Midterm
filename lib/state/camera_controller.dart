import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../data/concert_mock_data.dart';
import '../engine/camera_transform.dart';
import '../engine/viewport_clamper.dart';

class CameraController extends ValueNotifier<CameraTransform> {
  CameraController() : super(CameraTransform(scale: 1));
  ViewportClamper? _viewport;
  ViewportClamper? get viewport => _viewport;
  Offset? _lastFocalPoint;
  double _lastScale = 1;
  int _pointerCount = 0;

  /// Call outside build. The initial fit occurs only once.
  bool updateViewport(double width, double height) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0)
      return false;
    final previous = _viewport;
    if (previous?.viewportWidth == width && previous?.viewportHeight == height)
      return false;
    final next = ViewportClamper(
      worldBounds: ConcertMockData.worldBounds,
      viewportWidth: width,
      viewportHeight: height,
    );
    _viewport = next;
    endGesture();
    value = previous == null ? next.fit() : next.resize(value, previous);
    return true;
  }

  void startGesture(Offset focalPoint, int pointerCount) {
    _lastFocalPoint = focalPoint;
    _lastScale = 1;
    _pointerCount = pointerCount;
  }

  void updateGesture({
    required Offset focalPoint,
    required double scale,
    required int pointerCount,
  }) {
    final viewport = _viewport;
    if (viewport == null ||
        !scale.isFinite ||
        scale <= 0 ||
        !focalPoint.dx.isFinite ||
        !focalPoint.dy.isFinite)
      return;
    final previousFocal = _lastFocalPoint;
    if (previousFocal == null || pointerCount != _pointerCount) {
      // Recognizer scale/focal origin can reset when a finger joins/leaves.
      _lastFocalPoint = focalPoint;
      _lastScale = scale;
      _pointerCount = pointerCount;
      return;
    }
    final delta = focalPoint - previousFocal;
    final scaleDelta = pointerCount > 1 ? scale / _lastScale : 1.0;
    // Translate the old focal point to the new one, then zoom about the new
    // focal point. Clamp once so intermediate edge clamps do not add drift.
    value = viewport.zoom(
      value.pan(delta.dx, delta.dy),
      scaleDelta: scaleDelta,
      focalX: focalPoint.dx,
      focalY: focalPoint.dy,
    );
    _lastFocalPoint = focalPoint;
    _lastScale = scale;
    _pointerCount = pointerCount;
  }

  void endGesture() {
    _lastFocalPoint = null;
    _lastScale = 1;
    _pointerCount = 0;
  }
}
