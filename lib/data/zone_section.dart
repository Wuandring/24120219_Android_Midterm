import 'seat.dart';

class ZoneSection {
  const ZoneSection({
    required this.id,
    required this.label,
    required this.zone,
    required this.bounds,
    required this.rows,
    required this.columns,
    required this.price,
    required this.colorArgb,
    required this.shape,
  });

  final String id;
  final String label;
  final SeatZone zone;
  final WorldRect bounds;
  final int rows;
  final int columns;
  final int price;
  final int colorArgb;
  final SeatShape shape;
}
