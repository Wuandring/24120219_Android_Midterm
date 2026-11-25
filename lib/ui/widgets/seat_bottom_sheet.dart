import 'package:flutter/material.dart';

import '../../data/seat.dart';
import '../../state/concert_map_controller.dart';
import '../../state/seat_map_render_state.dart';

class SeatBottomSheet extends StatelessWidget {
  const SeatBottomSheet({
    super.key,
    required this.mapController,
    required this.sheetController,
    required this.minSize,
    required this.maxSize,
    required this.onFocus,
  });
  final ConcertMapController mapController;
  final DraggableScrollableController sheetController;
  final double minSize, maxSize;
  final ValueChanged<Seat> onFocus;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    controller: sheetController,
    minChildSize: minSize,
    initialChildSize: minSize,
    maxChildSize: maxSize,
    snap: true,
    snapSizes: [minSize, maxSize],
    builder: (context, scrollController) => Material(
      color: const Color(0xFF1E293B),
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ValueListenableBuilder<SeatMapRenderState>(
        valueListenable: mapController,
        builder: (context, state, _) {
          final seats = mapController.selectedSeats;
          final inspected = mapController.inspectedSeat;
          final summary = seats.isNotEmpty
              ? '${mapController.selectedCount} ghế • ${mapController.formattedTotalPrice}'
              : inspected != null
              ? '${inspected.id} • ${inspected.status == SeatStatus.booked ? 'Đã đặt' : 'Đang khóa'}'
              : 'Chạm ghế trống để chọn vé';
          return Column(
            children: [
              GestureDetector(
                key: const ValueKey('ticket-drag-handle'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  final current = sheetController.size;
                  final delta = sheetController.pixelsToSize(details.delta.dy);
                  sheetController.jumpTo(
                    (current - delta).clamp(minSize, maxSize),
                  );
                },
                onVerticalDragEnd: (_) {
                  final target = sheetController.size < (minSize + maxSize) / 2
                      ? minSize
                      : maxSize;
                  sheetController.animateTo(
                    target,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: SizedBox(
                  height: 64,
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(top: 6, bottom: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF94A3B8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.confirmation_number_outlined,
                              color: Color(0xFF67E8F9),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                summary,
                                key: const ValueKey('ticket-summary'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF8FAFC),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: sheetController,
                              builder: (context, _) {
                                final expanded =
                                    sheetController.isAttached &&
                                    sheetController.size >
                                        (minSize + maxSize) / 2;
                                return IconButton(
                                  key: const ValueKey('toggle-ticket-sheet'),
                                  tooltip: expanded
                                      ? 'Thu gọn vé'
                                      : 'Mở danh sách vé',
                                  onPressed: () => sheetController.animateTo(
                                    expanded ? minSize : maxSize,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                  ),
                                  icon: Icon(
                                    expanded
                                        ? Icons.keyboard_arrow_down
                                        : Icons.keyboard_arrow_up,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: sheetController,
                  builder: (context, child) {
                    final collapsed =
                        !sheetController.isAttached ||
                        sheetController.size <= minSize + 0.01;
                    return IgnorePointer(
                      ignoring: collapsed,
                      child: Opacity(opacity: collapsed ? 0 : 1, child: child),
                    );
                  },
                  child: ListView.builder(
                    key: const ValueKey('selected-seats-list'),
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: seats.isEmpty ? 1 : seats.length,
                    itemBuilder: (context, index) {
                      if (seats.isEmpty)
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Chưa chọn ghế. Chọn trên sơ đồ để thêm vào vé.',
                            style: TextStyle(color: Color(0xFFCBD5E1)),
                          ),
                        );
                      final seat = seats[index];
                      final color = switch (seat.zone) {
                        SeatZone.standing => const Color(0xFF06B6D4),
                        SeatZone.vip => const Color(0xFFF59E0B),
                        SeatZone.standard => const Color(0xFF818CF8),
                      };
                      final zoneName = switch (seat.zone) {
                        SeatZone.standing => 'Standing',
                        SeatZone.vip => 'VIP',
                        SeatZone.standard => 'Standard',
                      };
                      return ListTile(
                        key: ValueKey('seat-row-${seat.id}'),
                        selected: state.focusedSeatId == seat.id,
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          '${seat.id} • $zoneName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          ConcertMapController.formatVnd(seat.price),
                        ),
                        onTap: () => onFocus(seat),
                        trailing: IconButton(
                          key: ValueKey('delete-${seat.id}'),
                          tooltip: 'Bỏ ghế ${seat.id}',
                          icon: const Icon(Icons.close),
                          onPressed: () => mapController.removeSeat(seat.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
