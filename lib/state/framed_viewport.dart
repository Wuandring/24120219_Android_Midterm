import 'dart:math' as math;

import '../engine/camera_transform.dart';
import '../engine/viewport_clamper.dart';

/// UI framing adapter: full-canvas gesture coordinates with an unobstructed fit.
class FramedViewport extends ViewportClamper {
  FramedViewport({
    required super.worldBounds,
    required super.viewportWidth,
    required super.viewportHeight,
    this.topInset = 0,
    this.bottomInset = 0,
    this.rightInset = 0,
  }) : super(
         edgePaddingX: viewportWidth / 2,
         edgePaddingY: viewportHeight * 0.8,
       );
  final double topInset, bottomInset, rightInset;
  double get centerX => (viewportWidth - rightInset) / 2;
  double get centerY =>
      topInset + (viewportHeight - topInset - bottomInset) / 2;
  @override
  double get fitScale => math.min(
    (viewportWidth - rightInset) / worldBounds.width,
    (viewportHeight - topInset - bottomInset) / worldBounds.height,
  );
  @override
  CameraTransform fit() => CameraTransform(
    scale: fitScale,
    tx: centerX - worldBounds.centerX * fitScale,
    ty: centerY - worldBounds.centerY * fitScale,
  );
  @override
  CameraTransform resize(CameraTransform camera, ViewportClamper previous) {
    final oldX = previous is FramedViewport
        ? previous.centerX
        : previous.viewportWidth / 2;
    final oldY = previous is FramedViewport
        ? previous.centerY
        : previous.viewportHeight / 2;
    final wx = (oldX - camera.tx) / camera.scale,
        wy = (oldY - camera.ty) / camera.scale;
    final s = (camera.scale / previous.fitScale * fitScale)
        .clamp(minScale, maxScale)
        .toDouble();
    return clamp(
      CameraTransform(scale: s, tx: centerX - wx * s, ty: centerY - wy * s),
    );
  }
}
