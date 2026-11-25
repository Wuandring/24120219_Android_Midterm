import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/state/concert_map_controller.dart';
import 'package:concert_seat_map/state/filter_state.dart';
import 'package:concert_seat_map/data/concert_mock_data.dart';
import 'package:concert_seat_map/data/seat.dart';

void main() {
  late ConcertMapController c;
  setUp(() => c = ConcertMapController());
  tearDown(() => c.dispose());
  test('zone/status/query predicates intersect and no filter uses null', () {
    expect(c.value.matchingSeatIds, isNull);
    expect(c.matchedCount, 200);
    c.setZoneFilter(SeatZone.vip);
    expect(c.matchedCount, 60);
    c.setSearchQuery(' vp-c ');
    expect(c.matchedCount, 30);
    c.setStatusFilter(SeatFilterStatus.booked);
    expect(
      c.value.matchingSeatIds,
      ConcertMockData.seats
          .where(
            (s) =>
                s.zone == SeatZone.vip &&
                s.id.startsWith('VP-C') &&
                s.status == SeatStatus.booked,
          )
          .map((s) => s.id)
          .toSet(),
    );
    expect(c.activeFilterDescription, contains('VIP'));
    c.setSearchQuery('NO-SUCH-SEAT');
    expect(c.matchedCount, 0);
    expect(c.value.matchingSeatIds, isEmpty);
    c.clearFilters();
    expect(c.hasActiveFilters, isFalse);
    expect(c.value.matchingSeatIds, isNull);
  });
  test('every status count includes selected as a distinct visual state', () {
    final seat = ConcertMockData.seats.firstWhere(
      (s) => s.status == SeatStatus.available,
    );
    c.toggleSeat(seat.id);
    final expected = {
      SeatFilterStatus.all: 200,
      SeatFilterStatus.available: 123,
      SeatFilterStatus.selected: 1,
      SeatFilterStatus.booked: 52,
      SeatFilterStatus.locked: 24,
    };
    for (final status in SeatFilterStatus.values) {
      c.setStatusFilter(status);
      expect(c.matchedCount, expected[status]);
    }
    c.setStatusFilter(SeatFilterStatus.selected);
    c.removeSeat(seat.id);
    expect(c.matchedCount, 0);
  });
  test(
    'filtering preserves selections, totals and immutable previous matches',
    () {
      final seat = ConcertMockData.seats.firstWhere(
        (s) => s.status == SeatStatus.available,
      );
      c.toggleSeat(seat.id);
      c.focusSeat(seat.id);
      c.setZoneFilter(SeatZone.vip);
      final snapshot = c.value;
      expect(c.selectedSeatIds, {seat.id});
      expect(c.totalPrice, seat.price);
      expect(c.focusedSeatId, seat.id);
      c.clearFilters();
      expect(snapshot.matchingSeatIds!.length, 60);
      expect(() => snapshot.matchingSeatIds!.clear(), throwsUnsupportedError);
      expect(c.selectedSeatIds, {seat.id});
    },
  );
  test(
    'nonmatching new selections blocked; existing dim selection can be removed',
    () {
      final available = ConcertMockData.seats
          .where((s) => s.status == SeatStatus.available)
          .take(2)
          .toList();
      c.toggleSeat(available.first.id);
      c.setSearchQuery('VP-C');
      expect(c.toggleSeat(available.last.id), isFalse);
      expect(c.selectedCount, 1);
      expect(c.toggleSeat(available.first.id), isTrue);
      expect(c.selectedCount, 0);
    },
  );
  test('clear search and filters preserves ticket and inspection state', () {
    final seat = ConcertMockData.seats.firstWhere(
      (s) => s.status == SeatStatus.available,
    );
    final booked = ConcertMockData.seats.firstWhere(
      (s) => s.status == SeatStatus.booked,
    );
    c.toggleSeat(seat.id);
    c.inspectSeat(booked.id);
    c.setSearchQuery('st-l05');
    expect(c.value.matchingSeatIds, {'ST-L05'});
    c.clearFilters();
    expect(c.selectedCount, 1);
    expect(c.inspectedSeat, booked);
  });
}
