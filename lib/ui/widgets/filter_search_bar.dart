import 'package:flutter/material.dart';

import '../../data/seat.dart';
import '../../state/concert_map_controller.dart';
import '../../state/filter_state.dart';
import '../../state/seat_map_render_state.dart';

class FilterSearchBar extends StatefulWidget {
  const FilterSearchBar({super.key, required this.controller});
  final ConcertMapController controller;
  @override
  State<FilterSearchBar> createState() => _FilterSearchBarState();
}

class _FilterSearchBarState extends State<FilterSearchBar> {
  Widget _selectorLabel(
    String label, {
    required bool active,
    required Key key,
  }) => Semantics(
    selected: active,
    child: Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0x2222D3EE) : Colors.transparent,
        border: Border.all(
          color: active ? const Color(0xFF22D3EE) : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF67E8F9) : null,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ),
  );
  late final TextEditingController _search = TextEditingController(
    text: widget.controller.filters.query,
  );
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncSearch);
  }

  void _syncSearch() {
    final query = widget.controller.filters.query;
    if (_search.text != query)
      _search.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSearch);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<SeatMapRenderState>(
        valueListenable: widget.controller,
        builder: (context, _, child) {
          final c = widget.controller;
          final search = SizedBox(
            width: 200,
            height: 42,
            child: TextField(
              key: const ValueKey('seat-search'),
              controller: _search,
              onChanged: c.setSearchQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF1E293B),
                hintText: 'Tìm mã ghế',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('clear-seat-search'),
                        tooltip: 'Xóa tìm kiếm',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => c.setSearchQuery(''),
                      ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          );
          final selectors = [
            PopupMenuButton<SeatZone?>(
              key: const ValueKey('zone-filter'),
              tooltip: 'Lọc khu',
              onSelected: c.setZoneFilter,
              itemBuilder: (_) => [
                for (final z in <SeatZone?>[null, ...SeatZone.values])
                  PopupMenuItem<SeatZone?>(
                    value: z,
                    onTap: z == null ? () => c.setZoneFilter(null) : null,
                    child: Text(FilterState.zoneLabel(z)),
                  ),
              ],
              child: _selectorLabel(
                'Khu: ${FilterState.zoneLabel(c.filters.zone)} ▾',
                active: c.filters.zone != null,
                key: const ValueKey('zone-filter-style'),
              ),
            ),
            PopupMenuButton<SeatFilterStatus>(
              key: const ValueKey('status-filter'),
              tooltip: 'Lọc trạng thái',
              onSelected: c.setStatusFilter,
              itemBuilder: (_) => [
                for (final s in SeatFilterStatus.values)
                  PopupMenuItem(
                    value: s,
                    child: Text(FilterState.statusLabel(s)),
                  ),
              ],
              child: _selectorLabel(
                '${FilterState.statusLabel(c.filters.status)} ▾',
                active: c.filters.status != SeatFilterStatus.all,
                key: const ValueKey('status-filter-style'),
              ),
            ),
            Tooltip(
              message: c.activeFilterDescription,
              child: Text(
                'Hiển thị ${c.matchedCount}/200 chỗ',
                key: const ValueKey('match-count'),
                style: const TextStyle(color: Color(0xFF67E8F9)),
              ),
            ),
            if (c.hasActiveFilters)
              TextButton(
                key: const ValueKey('clear-filters'),
                onPressed: c.clearFilters,
                child: const Text('Xóa lọc'),
              ),
          ];
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 600)
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [search, ...selectors]),
                );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: constraints.maxWidth, child: search),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: selectors),
                  ),
                ],
              );
            },
          );
        },
      );
}
