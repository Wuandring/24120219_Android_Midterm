/// Immutable world geometry, independent of Flutter UI types.
class WorldRect {
  const WorldRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;
  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
}

enum SeatZone { standing, vip, standard }

/// Selection belongs to application state; these are the source statuses.
enum SeatStatus { available, booked, locked }

enum SeatShape { circle, roundedRectangle, roundedSquare }

class Seat {
  const Seat({
    required this.id,
    required this.sectionId,
    required this.zone,
    required this.status,
    required this.shape,
    required this.price,
    required this.bounds,
  });

  final String id;
  final String sectionId;
  final SeatZone zone;
  final SeatStatus status;
  final SeatShape shape;

  /// Integer Vietnamese dong, without floating-point rounding.
  final int price;
  final WorldRect bounds;
}
