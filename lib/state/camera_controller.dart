import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../data/concert_mock_data.dart';
import '../data/seat.dart';

import 'dart:math' as math;

import '../engine/camera_transform.dart';
import '../engine/coordinate_transformer.dart';
import '../engine/viewport_clamper.dart';
import 'framed_viewport.dart';

class CameraController extends ValueNotifier<CameraTransform> {
  CameraController() : super(CameraTransform(scale: 1));
  ViewportClamper? _viewport;
  ViewportClamper? get viewport => _viewport;
  Offset? _lastFocalPoint;
  double _lastScale = 1;
  int _pointerCount = 0;

  /// Call outside build. The initial fit occurs only once.
  bool updateViewport(
    double width,
    double height, {
    double topInset = 0,
    double bottomInset = 0,
    double rightInset = 0,
  }) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0)
      return false;
    final previous = _viewport;
    if (previous is FramedViewport &&
        previous.viewportWidth == width &&
        previous.viewportHeight == height &&
        previous.topInset == topInset &&
        previous.bottomInset == bottomInset &&
        previous.rightInset == rightInset)
      return false;
    final next = FramedViewport(
      worldBounds: ConcertMockData.worldBounds,
      viewportWidth: width,
      viewportHeight: height,
      topInset: topInset,
      bottomInset: bottomInset,
      rightInset: rightInset,
    );
    _viewport = next;
    endGesture();
    value = previous == null ? next.fit() : next.resize(value, previous);
    return true;
  }

  CameraTransform focusTarget(Seat seat, {double bottomInset = 0}) {
    final v = _viewport!;
    if (!bottomInset.isFinite || bottomInset < 0) {
      throw ArgumentError.value(bottomInset, 'bottomInset');
    }
    final topInset = v is FramedViewport ? v.topInset : 0.0;
    final visibleHeight = (v.viewportHeight - topInset - bottomInset).clamp(
      0.0,
      v.viewportHeight,
    );
    final scale = math
        .max(value.scale, math.max(1.0, 2.4 * v.fitScale))
        .clamp(v.minScale, v.maxScale)
        .toDouble();
    return v.clamp(
      CameraTransform(
        scale: scale,
        tx:
            (v is FramedViewport ? v.centerX : v.viewportWidth / 2) -
            seat.bounds.centerX * scale,
        ty: topInset + visibleHeight / 2 - seat.bounds.centerY * scale,
      ),
    );
  }

  void startGesture(Offset focalPoint, int pointerCount) {
    _lastFocalPoint = focalPoint;
    _lastScale = 1;
    _pointerCount = pointerCount;
  }

  CameraTransform zoomTarget(double factor, Offset focalPoint) {
    final viewport = _viewport;
    if (viewport == null) return value;
    return viewport.zoom(
      value,
      scaleDelta: factor,
      focalX: focalPoint.dx,
      focalY: focalPoint.dy,
    );
  }

  CameraTransform centerTarget(WorldPoint point) {
    final v = _viewport;
    if (v == null) return value;
    return v.clamp(
      CameraTransform(
        scale: value.scale,
        tx: v.viewportWidth / 2 - point.x * value.scale,
        ty: v.viewportHeight / 2 - point.y * value.scale,
      ),
    );
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
    // Emulator/trackpad recognizers can report scaling with pointerCount == 1.
    // A normal pan has scale == lastScale == 1; returning a pinch to 1 must
    // also undo the previous scale increment rather than leaving zoom stuck.
    final ratio = _lastScale > 0 ? scale / _lastScale : 1.0;
    final scaleDelta = ratio.isFinite && ratio > 0 ? ratio : 1.0;
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
