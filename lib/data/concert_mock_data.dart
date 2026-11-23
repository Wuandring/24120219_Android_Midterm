import 'seat.dart';
import 'zone_section.dart';

/// Deterministic, read-only layout in a 1600 x 1200 world.
abstract final class ConcertMockData {
  static const worldBounds = WorldRect(0, 0, 1600, 1200);
  static const mainStage = WorldRect(400, 70, 800, 140);
  static const catwalk = WorldRect(740, 210, 120, 310);
  static const stageParts = [mainStage, catwalk];

  // Clear strips between blocks; these do not intersect any seat.
  static const aisles = [
    WorldRect(80, 530, 1440, 60),
    WorldRect(80, 790, 1440, 60),
    WorldRect(480, 590, 70, 570),
    WorldRect(1050, 590, 70, 570),
    WorldRect(700, 240, 40, 290),
    WorldRect(860, 240, 40, 290),
  ];

  static const sections = <ZoneSection>[
    ZoneSection(
      id: 'ST-L',
      label: 'STANDING',
      zone: SeatZone.standing,
      bounds: WorldRect(300, 260, 400, 250),
      rows: 4,
      columns: 5,
      price: 1800000,
      colorArgb: 0xFF06B6D4,
      shape: SeatShape.circle,
    ),
    ZoneSection(
      id: 'ST-R',
      label: 'STANDING',
      zone: SeatZone.standing,
      bounds: WorldRect(900, 260, 400, 250),
      rows: 4,
      columns: 5,
      price: 1800000,
      colorArgb: 0xFF06B6D4,
      shape: SeatShape.circle,
    ),
    ZoneSection(
      id: 'VP-L',
      label: 'VIP',
      zone: SeatZone.vip,
      bounds: WorldRect(100, 610, 380, 160),
      rows: 3,
      columns: 5,
      price: 3500000,
      colorArgb: 0xFFF59E0B,
      shape: SeatShape.roundedRectangle,
    ),
    ZoneSection(
      id: 'VP-C',
      label: 'VIP',
      zone: SeatZone.vip,
      bounds: WorldRect(550, 610, 500, 160),
      rows: 3,
      columns: 10,
      price: 3500000,
      colorArgb: 0xFFF59E0B,
      shape: SeatShape.roundedRectangle,
    ),
    ZoneSection(
      id: 'VP-R',
      label: 'VIP',
      zone: SeatZone.vip,
      bounds: WorldRect(1120, 610, 380, 160),
      rows: 3,
      columns: 5,
      price: 3500000,
      colorArgb: 0xFFF59E0B,
      shape: SeatShape.roundedRectangle,
    ),
    ZoneSection(
      id: 'SD-L',
      label: 'STANDARD',
      zone: SeatZone.standard,
      bounds: WorldRect(100, 870, 380, 290),
      rows: 5,
      columns: 6,
      price: 1200000,
      colorArgb: 0xFF818CF8,
      shape: SeatShape.roundedSquare,
    ),
    ZoneSection(
      id: 'SD-C',
      label: 'STANDARD',
      zone: SeatZone.standard,
      bounds: WorldRect(550, 870, 500, 290),
      rows: 5,
      columns: 8,
      price: 1200000,
      colorArgb: 0xFF818CF8,
      shape: SeatShape.roundedSquare,
    ),
    ZoneSection(
      id: 'SD-R',
      label: 'STANDARD',
      zone: SeatZone.standard,
      bounds: WorldRect(1120, 870, 380, 290),
      rows: 5,
      columns: 6,
      price: 1200000,
      colorArgb: 0xFF818CF8,
      shape: SeatShape.roundedSquare,
    ),
  ];

  static final List<Seat> seats = List.unmodifiable(_generateSeats());

  static List<Seat> _generateSeats() {
    final result = <Seat>[];
    for (final section in sections) {
      final cellWidth = section.bounds.width / section.columns;
      final cellHeight = section.bounds.height / section.rows;
      final width = section.zone == SeatZone.vip ? 36.0 : 32.0;
      const height = 32.0;
      for (var index = 0; index < section.rows * section.columns; index++) {
        // Coprime permutation spreads exactly 124/52/24 statuses over 200 seats.
        final bucket = (result.length * 37 + 11) % 100;
        final status = bucket < 62
            ? SeatStatus.available
            : bucket < 88
            ? SeatStatus.booked
            : SeatStatus.locked;
        result.add(
          Seat(
            id: '${section.id}${(index + 1).toString().padLeft(2, '0')}',
            sectionId: section.id,
            zone: section.zone,
            status: status,
            shape: section.shape,
            price: section.price,
            bounds: WorldRect(
              section.bounds.left +
                  (index % section.columns + 0.5) * cellWidth -
                  width / 2,
              section.bounds.top +
                  (index ~/ section.columns + 0.5) * cellHeight -
                  height / 2,
              width,
              height,
            ),
          ),
        );
      }
    }
    return result;
  }
}
