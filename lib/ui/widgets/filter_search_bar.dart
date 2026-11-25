import 'package:flutter/material.dart';

import '../../data/seat.dart';
import '../../state/concert_map_controller.dart';
import '../../state/filter_state.dart';
import '../../state/seat_map_render_state.dart';
import '../concert_palette.dart';

class FilterSearchBar extends StatefulWidget {
  const FilterSearchBar({
    super.key,
    required this.controller,
    this.landscape = false,
    this.actions = const [],
  });
  final ConcertMapController controller;
  final bool landscape;
  final List<Widget> actions;
  @override
  State<FilterSearchBar> createState() => _FilterSearchBarState();
}

class _FilterSearchBarState extends State<FilterSearchBar> {
  late final TextEditingController _search = TextEditingController(
    text: widget.controller.filters.query,
  );
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncSearch);
  }

  void _syncSearch() {
    final q = widget.controller.filters.query;
    if (_search.text != q)
      _search.value = TextEditingValue(
        text: q,
        selection: TextSelection.collapsed(offset: q.length),
      );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSearch);
    _search.dispose();
    super.dispose();
  }

  Widget _pill(String label, bool active, String key, double width) =>
      Semantics(
        selected: active,
        child: Container(
          key: ValueKey(key),
          width: width,
          height: 34,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: active ? const Color(0x22C9A96E) : ConcertPalette.surface,
            border: Border.all(
              color: active ? ConcertPalette.gold : const Color(0xFF3A3326),
              width: 0.7,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.replaceAll(' ▾', ''),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: active
                          ? ConcertPalette.selected
                          : ConcertPalette.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 13,
                color: ConcertPalette.muted,
              ),
            ],
          ),
        ),
      );
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<SeatMapRenderState>(
    valueListenable: widget.controller,
    builder: (context, _, child) {
      final c = widget.controller;
      final search = SizedBox(
        width: widget.landscape ? 150 : double.infinity,
        height: 36,
        child: TextField(
          key: const ValueKey('seat-search'),
          controller: _search,
          onChanged: c.setSearchQuery,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 13, color: ConcertPalette.text),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF1B1B20),
            hintText: 'Tìm mã ghế',
            hintStyle: const TextStyle(
              color: ConcertPalette.muted,
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 17,
              color: ConcertPalette.gold,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 30),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey('clear-seat-search'),
                    tooltip: 'Xóa tìm kiếm',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => c.setSearchQuery(''),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(color: Color(0xFF3A3326)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: const BorderSide(
                color: Color(0xFF3A3326),
                width: 0.7,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
        ),
      );
      final selectors = <Widget>[
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
          child: _pill(
            '${c.filters.zone == null ? 'Khu' : FilterState.zoneLabel(c.filters.zone)} ▾',
            c.filters.zone != null,
            'zone-filter-style',
            96,
          ),
        ),
        PopupMenuButton<SeatFilterStatus>(
          key: const ValueKey('status-filter'),
          tooltip: 'Lọc trạng thái',
          onSelected: c.setStatusFilter,
          itemBuilder: (_) => [
            for (final s in SeatFilterStatus.values)
              PopupMenuItem(value: s, child: Text(FilterState.statusLabel(s))),
          ],
          child: _pill(
            '${c.filters.status == SeatFilterStatus.all ? 'Trạng thái' : FilterState.statusLabel(c.filters.status)} ▾',
            c.filters.status != SeatFilterStatus.all,
            'status-filter-style',
            110,
          ),
        ),
        Tooltip(
          message:
              'Hiển thị ${c.matchedCount}/200 chỗ • ${c.activeFilterDescription}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Text(
              '${c.matchedCount}/200',
              key: const ValueKey('match-count'),
              style: const TextStyle(
                fontSize: 11.5,
                color: ConcertPalette.selected,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (c.hasActiveFilters)
          TextButton(
            key: const ValueKey('clear-filters'),
            onPressed: c.clearFilters,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle: const TextStyle(fontSize: 11.5),
            ),
            child: const Text('Xóa lọc'),
          ),
      ];
      if (widget.landscape)
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              search,
              const SizedBox(width: 6),
              ...selectors,
              ...widget.actions,
            ],
          ),
        );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          search,
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: selectors),
          ),
        ],
      );
    },
  );
}
