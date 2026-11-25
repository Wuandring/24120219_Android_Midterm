import '../data/seat.dart';

enum SeatFilterStatus { all, available, selected, booked, locked }

class FilterState {
  const FilterState({
    this.zone,
    this.status = SeatFilterStatus.all,
    this.query = '',
  });
  final SeatZone? zone;
  final SeatFilterStatus status;
  final String query;
  bool get isActive =>
      zone != null || status != SeatFilterStatus.all || query.trim().isNotEmpty;
  static String zoneLabel(SeatZone? zone) => switch (zone) {
    null => 'Tất cả khu',
    SeatZone.standing => 'Standing',
    SeatZone.vip => 'VIP',
    SeatZone.standard => 'Standard',
  };
  static String statusLabel(SeatFilterStatus status) => switch (status) {
    SeatFilterStatus.all => 'Tất cả trạng thái',
    SeatFilterStatus.available => 'Trống',
    SeatFilterStatus.selected => 'Đang chọn',
    SeatFilterStatus.booked => 'Đã đặt',
    SeatFilterStatus.locked => 'Đang khóa',
  };
  String get description => !isActive
      ? 'Tất cả chỗ'
      : [
          if (zone != null) zoneLabel(zone),
          if (status != SeatFilterStatus.all) statusLabel(status),
          if (query.trim().isNotEmpty) 'Mã ghế: ${query.trim()}',
        ].join(' • ');
  bool matches(Seat seat, Set<String> selected) {
    if (zone != null && seat.zone != zone) return false;
    if (!seat.id.toLowerCase().contains(query.trim().toLowerCase()))
      return false;
    final isSelected = selected.contains(seat.id);
    return switch (status) {
      SeatFilterStatus.all => true,
      SeatFilterStatus.available =>
        seat.status == SeatStatus.available && !isSelected,
      SeatFilterStatus.selected => isSelected,
      SeatFilterStatus.booked => seat.status == SeatStatus.booked,
      SeatFilterStatus.locked => seat.status == SeatStatus.locked,
    };
  }
}
