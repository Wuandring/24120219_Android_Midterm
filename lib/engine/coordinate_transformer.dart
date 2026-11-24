import '../data/seat.dart';
import 'camera_transform.dart';

class WorldPoint {
  WorldPoint(this.x, this.y) {
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('Coordinates must be finite');
    }
  }
  final double x;
  final double y;
}

abstract final class CoordinateTransformer {
  static WorldPoint worldToScreen(WorldPoint point, CameraTransform camera) =>
      WorldPoint(
        point.x * camera.scale + camera.tx,
        point.y * camera.scale + camera.ty,
      );

  static WorldPoint screenToWorld(WorldPoint point, CameraTransform camera) =>
      WorldPoint(
        (point.x - camera.tx) / camera.scale,
        (point.y - camera.ty) / camera.scale,
      );

  /// Unclipped world rectangle for culling, including any letterboxed area.
  static WorldRect visibleWorldRect(
    CameraTransform camera, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    if (!viewportWidth.isFinite ||
        viewportWidth <= 0 ||
        !viewportHeight.isFinite ||
        viewportHeight <= 0) {
      throw ArgumentError('Viewport dimensions must be positive and finite');
    }
    final topLeft = screenToWorld(WorldPoint(0, 0), camera);
    return WorldRect(
      topLeft.x,
      topLeft.y,
      viewportWidth / camera.scale,
      viewportHeight / camera.scale,
    );
  }
}
