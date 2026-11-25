import 'dart:math' as math;

import '../data/seat.dart';
import 'camera_transform.dart';
import 'coordinate_transformer.dart';

/// Viewport dimensions are local canvas pixels, excluding surrounding UI.
class ViewportClamper {
  ViewportClamper({
    required this.worldBounds,
    required this.viewportWidth,
    required this.viewportHeight,
    this.edgePaddingX = 0,
    this.edgePaddingY = 0,
  }) {
    if (!edgePaddingX.isFinite ||
        edgePaddingX < 0 ||
        !edgePaddingY.isFinite ||
        edgePaddingY < 0) {
      throw ArgumentError('Edge clearance must be finite and nonnegative');
    }
    if (!worldBounds.left.isFinite ||
        !worldBounds.top.isFinite ||
        !worldBounds.right.isFinite ||
        !worldBounds.bottom.isFinite ||
        !worldBounds.width.isFinite ||
        worldBounds.width <= 0 ||
        !worldBounds.height.isFinite ||
        worldBounds.height <= 0 ||
        !viewportWidth.isFinite ||
        viewportWidth <= 0 ||
        !viewportHeight.isFinite ||
        viewportHeight <= 0) {
      throw ArgumentError(
        'World and viewport must have finite positive dimensions',
      );
    }
    if (!fitScale.isFinite || fitScale <= 0 || !maxScale.isFinite) {
      throw ArgumentError('World/viewport ratio is not representable');
    }
  }

  final WorldRect worldBounds;
  final double viewportWidth;
  final double viewportHeight;

  /// Optional screen-pixel clearance; fitScale still uses original world bounds.
  final double edgePaddingX;
  final double edgePaddingY;
  double get fitScale => math.min(
    viewportWidth / worldBounds.width,
    viewportHeight / worldBounds.height,
  );
  double get minScale => 0.9 * fitScale;
  double get maxScale => 4.5 * fitScale;

  CameraTransform fit() => CameraTransform(
    scale: fitScale,
    tx: viewportWidth / 2 - worldBounds.centerX * fitScale,
    ty: viewportHeight / 2 - worldBounds.centerY * fitScale,
  );

  CameraTransform clamp(CameraTransform camera) {
    final scale = camera.scale.clamp(minScale, maxScale).toDouble();
    return CameraTransform(
      scale: scale,
      tx: _axis(
        camera.tx,
        worldBounds.left,
        worldBounds.width,
        viewportWidth,
        scale,
        edgePaddingX,
      ),
      ty: _axis(
        camera.ty,
        worldBounds.top,
        worldBounds.height,
        viewportHeight,
        scale,
        edgePaddingY,
      ),
    );
  }

  double _axis(
    double translation,
    double start,
    double length,
    double viewport,
    double scale,
    double padding,
  ) {
    if (length * scale + 2 * padding <= viewport) {
      return (viewport - length * scale) / 2 - start * scale;
    }
    return translation
        .clamp(
          viewport - (start + length) * scale - padding,
          -start * scale + padding,
        )
        .toDouble();
  }

  CameraTransform pan(CameraTransform camera, double dx, double dy) =>
      clamp(camera.pan(dx, dy));

  CameraTransform zoom(
    CameraTransform camera, {
    required double scaleDelta,
    required double focalX,
    required double focalY,
  }) => clamp(
    camera.zoom(
      scaleDelta: scaleDelta,
      focalX: focalX,
      focalY: focalY,
      minScale: minScale,
      maxScale: maxScale,
    ),
  );

  /// Called on the new viewport; preserves relative zoom and world center.
  CameraTransform resize(CameraTransform camera, ViewportClamper previous) {
    final center = CoordinateTransformer.screenToWorld(
      WorldPoint(previous.viewportWidth / 2, previous.viewportHeight / 2),
      camera,
    );
    final scale = (camera.scale / previous.fitScale * fitScale)
        .clamp(minScale, maxScale)
        .toDouble();
    return clamp(
      CameraTransform(
        scale: scale,
        tx: viewportWidth / 2 - center.x * scale,
        ty: viewportHeight / 2 - center.y * scale,
      ),
    );
  }
}
