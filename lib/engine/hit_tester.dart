import 'dart:math' as math;

import '../data/seat.dart';
import 'camera_transform.dart';
import 'coordinate_transformer.dart';

abstract final class HitTester {
  /// Returns geometry hits regardless of booking status. Caller decides actions.
  /// Optional eligibility supports future filtering without changing geometry.
  static Seat? hitTest({
    required Iterable<Seat> seats,
    required WorldPoint screenPoint,
    required CameraTransform camera,
    bool Function(Seat)? isEligible,
  }) {
    final point = CoordinateTransformer.screenToWorld(screenPoint, camera);
    for (final seat in seats) {
      if ((isEligible == null || isEligible(seat)) && contains(seat, point)) {
        return seat;
      }
    }
    return null;
  }

  static bool contains(Seat seat, WorldPoint point) {
    final b = seat.bounds;
    // World-unit tolerance only for conversion roundoff, not a touch target halo.
    final epsilon =
        1e-12 *
        math.max(1.0, math.max(b.left.abs() + b.width, b.top.abs() + b.height));
    if (seat.shape == SeatShape.circle) {
      final radius = math.min(b.width, b.height) / 2;
      final dx = point.x - b.centerX;
      final dy = point.y - b.centerY;
      return dx * dx + dy * dy <= (radius + epsilon) * (radius + epsilon);
    }
    // The spec deliberately uses exact rectangular bounds for VIP/Standard.
    return point.x >= b.left - epsilon &&
        point.x <= b.right + epsilon &&
        point.y >= b.top - epsilon &&
        point.y <= b.bottom + epsilon;
  }
}
