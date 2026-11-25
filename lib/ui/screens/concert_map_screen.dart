import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/seat.dart';
import '../../engine/camera_transform.dart';
import '../../state/camera_controller.dart';
import '../../state/concert_map_controller.dart';
import '../canvas/interactive_seat_canvas.dart';
import '../canvas/seat_map_paint_cache.dart';
import '../widgets/seat_bottom_sheet.dart';
import '../widgets/filter_search_bar.dart';
import '../widgets/legend_panel.dart';
import '../../state/seat_map_render_state.dart';

class ConcertMapScreen extends StatefulWidget {
  const ConcertMapScreen({super.key});
  @override
  State<ConcertMapScreen> createState() => _ConcertMapScreenState();
}

class _ConcertMapScreenState extends State<ConcertMapScreen>
    with TickerProviderStateMixin {
  late final SeatMapPaintCache _cache = SeatMapPaintCache();
  final _camera = CameraController();
  final _mapController = ConcertMapController();
  final _sheet = DraggableScrollableController();
  late final AnimationController _focusAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addListener(_animateCamera);
  late final AnimationController _spotlight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  CameraTransform? _from, _to;
  Size? _pendingSize;
  bool _viewportUpdateScheduled = false;
  bool _autoRefocus = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _focusAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        if (!_resetting) _spotlight.forward(from: 0);
        _resetting = false;
      }
    });
    _mapController.addListener(_selectionChanged);
  }

  void _selectionChanged() {
    if (_mapController.focusedSeatId == null && !_resetting) {
      _focusAnimation.stop();
      _spotlight.stop();
    }
  }

  double _minFraction(Size size) =>
      math.max(0.14, 64 / size.height).clamp(0.14, 0.6);
  double _maxFraction(Size size) =>
      math.max(_minFraction(size), size.width > size.height ? 0.42 : 0.50);
  void _scheduleReconcile() {
    if (_viewportUpdateScheduled) return;
    _viewportUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportUpdateScheduled = false;
      if (!mounted || _pendingSize == null) return;
      final size = _pendingSize!;
      final min = _minFraction(size), max = _maxFraction(size);
      if (_sheet.isAttached) {
        final clamped = _sheet.size.clamp(min, max).toDouble();
        if (_sheet.size != clamped) _sheet.jumpTo(clamped);
      }
      if (_camera.updateViewport(size.width, size.height)) {
        _focusAnimation.stop();
        _resetting = false;
        final seat = _mapController.focusedSeat;
        if (_autoRefocus && seat != null) {
          _camera.value = _camera.focusTarget(seat, bottomInset: _bottomInset);
        }
        setState(() {});
      }
    });
  }

  double get _bottomInset {
    final size = _pendingSize!;
    final fraction = _sheet.isAttached
        ? _sheet.size.clamp(_minFraction(size), _maxFraction(size))
        : _minFraction(size);
    return size.height * fraction;
  }

  void _manualGestureStart() {
    _resetting = false;
    _autoRefocus = false;
    _focusAnimation.stop();
  }

  void _animateCamera() {
    if (_from == null ||
        _to == null ||
        (!_resetting && _mapController.focusedSeatId == null))
      return;
    final t = Curves.easeInOutCubic.transform(_focusAnimation.value);
    double lerp(double a, double b) => a + (b - a) * t;
    _camera.value = _camera.viewport!.clamp(
      CameraTransform(
        scale: lerp(_from!.scale, _to!.scale),
        tx: lerp(_from!.tx, _to!.tx),
        ty: lerp(_from!.ty, _to!.ty),
      ),
    );
  }

  void _focusSeat(Seat seat) {
    _resetting = false;
    if (_camera.viewport == null || !_mapController.focusSeat(seat.id)) return;
    _camera.endGesture();
    _autoRefocus = true;
    _spotlight.stop();
    _from = _camera.value;
    _to = _camera.focusTarget(seat, bottomInset: _bottomInset);
    _focusAnimation.forward(from: 0);
  }

  void _resetView() {
    final viewport = _camera.viewport;
    if (viewport == null) return;
    _camera.endGesture();
    _autoRefocus = false;
    _resetting = true;
    _spotlight.stop();
    _from = _camera.value;
    _to = viewport.fit();
    _focusAnimation.forward(from: 0);
  }

  @override
  void dispose() {
    _focusAnimation.dispose();
    _spotlight.dispose();
    _sheet.dispose();
    _camera.dispose();
    _mapController.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    appBar: AppBar(
      title: const Text('Sơ đồ chỗ concert'),
      backgroundColor: const Color(0xFF0B1120),
      actions: [
        IconButton(
          key: const ValueKey('show-legend'),
          tooltip: 'Bảng chú thích',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const LegendPanel(),
          ),
          icon: const Icon(Icons.info_outline),
        ),
        IconButton(
          key: const ValueKey('reset-view'),
          tooltip: 'Reset View',
          onPressed: _resetView,
          icon: const Icon(Icons.center_focus_strong),
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSearchBar(controller: _mapController),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0)
                    return const SizedBox.shrink();
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final previousSize = _pendingSize;
                  _pendingSize = size;
                  if (previousSize != size || _camera.viewport == null)
                    _scheduleReconcile();
                  return Stack(
                    children: [
                      if (_camera.viewport != null)
                        Positioned.fill(
                          child: InteractiveSeatCanvas(
                            camera: _camera,
                            mapController: _mapController,
                            cache: _cache,
                            spotlight: _spotlight,
                            onGestureStart: _manualGestureStart,
                          ),
                        ),
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: ValueListenableBuilder<SeatMapRenderState>(
                          valueListenable: _mapController,
                          builder: (context, state, _) =>
                              _mapController.matchedCount != 0
                              ? const SizedBox.shrink()
                              : Material(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Không tìm thấy chỗ phù hợp',
                                          ),
                                        ),
                                        TextButton(
                                          key: const ValueKey(
                                            'empty-clear-filters',
                                          ),
                                          onPressed:
                                              _mapController.clearFilters,
                                          child: const Text('Xóa bộ lọc'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      SeatBottomSheet(
                        mapController: _mapController,
                        sheetController: _sheet,
                        minSize: _minFraction(size),
                        maxSize: _maxFraction(size),
                        onFocus: _focusSeat,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
