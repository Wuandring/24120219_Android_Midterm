import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/concert_mock_data.dart';
import '../data/seat.dart';
import 'seat_map_render_state.dart';

/// Single source of truth for selection; source booking statuses never change.
class ConcertMapController extends ValueNotifier<SeatMapRenderState> {
  ConcertMapController() : super(SeatMapRenderState());
  final LinkedHashSet<String> _selectedSeatIds = LinkedHashSet<String>();
  final Map<String, Seat> _seats = {
    for (final seat in ConcertMockData.seats) seat.id: seat,
  };
  Set<String> get selectedSeatIds => UnmodifiableSetView(_selectedSeatIds);

  bool toggleSeat(String id) {
    final seat = _seats[id];
    if (seat == null || seat.status != SeatStatus.available) return false;
    if (!_selectedSeatIds.remove(id)) _selectedSeatIds.add(id);
    value = SeatMapRenderState(selectedSeatIds: _selectedSeatIds);
    return true;
  }
}
