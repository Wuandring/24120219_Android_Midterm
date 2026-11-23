import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/data/seat.dart';

bool contains(WorldRect outer, WorldRect inner) =>
    inner.left >= outer.left &&
    inner.top >= outer.top &&
    inner.right <= outer.right &&
    inner.bottom <= outer.bottom;
bool overlaps(WorldRect a, WorldRect b) =>
    a.left < b.right &&
    a.right > b.left &&
    a.top < b.bottom &&
    a.bottom > b.top;

void main() {
  test('200 unique seats have exact codes, grids, prices and zone shapes', () {
    final seats = ConcertMockData.seats;
    expect(seats.length, 200);
    expect(seats.map((s) => s.id).toSet().length, 200);
    expect(
      [for (final z in SeatZone.values) seats.where((s) => s.zone == z).length],
      [40, 60, 100],
    );
    for (final section in ConcertMockData.sections) {
      final block = seats.where((s) => s.sectionId == section.id).toList();
      expect(block.length, section.rows * section.columns);
      for (var i = 0; i < block.length; i++) {
        expect(
          block[i].id,
          '${section.id}${(i + 1).toString().padLeft(2, '0')}',
        );
        expect(block[i].price, section.price);
        expect(block[i].shape, section.shape);
        expect(block[i].zone, section.zone);
        expect(contains(section.bounds, block[i].bounds), isTrue);
      }
    }
  });
  test('statuses are fixed at 62/26/12 percent and collections immutable', () {
    expect(
      [
        for (final s in SeatStatus.values)
          ConcertMockData.seats.where((seat) => seat.status == s).length,
      ],
      [124, 52, 24],
    );
    expect(() => ConcertMockData.seats.clear(), throwsUnsupportedError);
    expect(() => ConcertMockData.sections.clear(), throwsUnsupportedError);
  });
  test('seats stay in world and do not overlap seats, stage or aisles', () {
    final seats = ConcertMockData.seats;
    for (var i = 0; i < seats.length; i++) {
      final bounds = seats[i].bounds;
      expect(contains(ConcertMockData.worldBounds, bounds), isTrue);
      for (final obstacle in [
        ...ConcertMockData.stageParts,
        ...ConcertMockData.aisles,
      ]) {
        expect(overlaps(bounds, obstacle), isFalse, reason: seats[i].id);
      }
      for (var j = i + 1; j < seats.length; j++) {
        expect(overlaps(bounds, seats[j].bounds), isFalse);
      }
    }
    expect(ConcertMockData.mainStage.bottom, ConcertMockData.catwalk.top);
    expect(ConcertMockData.mainStage.centerX, ConcertMockData.catwalk.centerX);
  });
}
