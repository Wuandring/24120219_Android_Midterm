/// Immutable snapshot consumed by the painter, independent of UI classes.
class SeatMapRenderState {
  SeatMapRenderState({
    Set<String> selectedSeatIds = const {},
    Set<String>? matchingSeatIds,
    this.focusedSeatId,
  }) : selectedSeatIds = Set.unmodifiable(selectedSeatIds),
       matchingSeatIds = matchingSeatIds == null
           ? null
           : Set.unmodifiable(matchingSeatIds);
  final Set<String> selectedSeatIds;
  final Set<String>? matchingSeatIds;
  final String? focusedSeatId;
}
