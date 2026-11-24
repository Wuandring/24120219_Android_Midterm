/// Immutable camera: screen = world * scale + translation.
class CameraTransform {
  CameraTransform({required this.scale, this.tx = 0, this.ty = 0}) {
    if (!scale.isFinite || scale <= 0 || !tx.isFinite || !ty.isFinite) {
      throw ArgumentError(
        'Camera requires positive finite scale and finite translation',
      );
    }
  }

  final double scale;
  final double tx;
  final double ty;

  CameraTransform pan(double dx, double dy) =>
      CameraTransform(scale: scale, tx: tx + dx, ty: ty + dy);

  /// scaleDelta is incremental, not cumulative since gesture start.
  /// Boundary clamping is a separate step and can move the focal point.
  CameraTransform zoom({
    required double scaleDelta,
    required double focalX,
    required double focalY,
    required double minScale,
    required double maxScale,
  }) {
    if (!scaleDelta.isFinite ||
        scaleDelta <= 0 ||
        !focalX.isFinite ||
        !focalY.isFinite ||
        !minScale.isFinite ||
        minScale <= 0 ||
        !maxScale.isFinite ||
        maxScale < minScale) {
      throw ArgumentError('Invalid focal zoom parameters');
    }
    final next = (scale * scaleDelta).clamp(minScale, maxScale).toDouble();
    final ratio = next / scale;
    return CameraTransform(
      scale: next,
      tx: focalX - (focalX - tx) * ratio,
      ty: focalY - (focalY - ty) * ratio,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CameraTransform &&
      scale == other.scale &&
      tx == other.tx &&
      ty == other.ty;
  @override
  int get hashCode => Object.hash(scale, tx, ty);
}
