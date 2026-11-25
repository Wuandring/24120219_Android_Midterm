import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/concert_mock_data.dart';
import '../data/seat.dart';
import 'seat_map_render_state.dart';

class ConcertMapController extends ValueNotifier<SeatMapRenderState> {
  ConcertMapController() : super(SeatMapRenderState());
  final LinkedHashSet<String> _selectedSeatIds = LinkedHashSet<String>();
  final Map<String, Seat> _seats = {
    for (final seat in ConcertMockData.seats) seat.id: seat,
  };
  String? _focusedSeatId;
  Seat? _inspectedSeat;
  Set<String> get selectedSeatIds => UnmodifiableSetView(_selectedSeatIds);
  List<Seat> get selectedSeats =>
      List.unmodifiable(_selectedSeatIds.map((id) => _seats[id]!));
  int get selectedCount => _selectedSeatIds.length;
  int get totalPrice =>
      _selectedSeatIds.fold(0, (sum, id) => sum + _seats[id]!.price);
  String get formattedTotalPrice => formatVnd(totalPrice);
  String? get focusedSeatId => _focusedSeatId;
  Seat? get inspectedSeat => _inspectedSeat;
  Seat? get focusedSeat => _seats[_focusedSeatId];

  static String formatVnd(int amount) =>
      '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';

  void _publish() => value = SeatMapRenderState(
    selectedSeatIds: _selectedSeatIds,
    matchingSeatIds: value.matchingSeatIds,
    focusedSeatId: _focusedSeatId,
  );

  bool toggleSeat(String id) {
    final seat = _seats[id];
    if (seat == null || seat.status != SeatStatus.available) return false;
    _inspectedSeat = null;
    if (_selectedSeatIds.contains(id)) {
      removeSeat(id);
    } else {
      _selectedSeatIds.add(id);
      _publish();
    }
    return true;
  }

  void inspectSeat(String id) {
    final seat = _seats[id];
    if (seat == null) return;
    _inspectedSeat = seat;
    _publish();
  }

  void removeSeat(String id) {
    if (!_selectedSeatIds.remove(id)) return;
    if (_focusedSeatId == id) _focusedSeatId = null;
    if (_inspectedSeat?.id == id) _inspectedSeat = null;
    _publish();
  }

  void clearSelection() {
    if (_selectedSeatIds.isEmpty &&
        _focusedSeatId == null &&
        _inspectedSeat == null)
      return;
    _selectedSeatIds.clear();
    _focusedSeatId = null;
    _inspectedSeat = null;
    _publish();
  }

  bool focusSeat(String id) {
    if (!_selectedSeatIds.contains(id)) return false;
    _focusedSeatId = id;
    _inspectedSeat = null;
    _publish();
    return true;
  }
}
