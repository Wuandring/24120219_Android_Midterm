import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/seat.dart';
import '../../engine/camera_transform.dart';
import '../../engine/coordinate_transformer.dart';
import '../../state/camera_controller.dart';
import '../../state/concert_map_controller.dart';
import '../canvas/interactive_seat_canvas.dart';
import '../canvas/seat_map_paint_cache.dart';
import '../canvas/seat_map_minimap.dart';
import '../widgets/camera_zoom_controls.dart';
import '../widgets/seat_bottom_sheet.dart';
import '../widgets/filter_search_bar.dart';
import '../widgets/legend_panel.dart';
import '../../state/seat_map_render_state.dart';
import '../concert_palette.dart';

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
  bool? _lastSheetLandscape;
  final _sheetFraction = ValueNotifier<double>(0);
  bool _pillUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_scheduleZoomPill);
    _focusAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        if (!_resetting) _spotlight.forward(from: 0);
        _resetting = false;
      }
    });
    _mapController.addListener(_selectionChanged);
  }

  void _scheduleZoomPill() {
    if (_pillUpdateScheduled) return;
    _pillUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pillUpdateScheduled = false;
      if (mounted && _sheet.isAttached) _sheetFraction.value = _sheet.size;
    });
  }

  void _selectionChanged() {
    if (_mapController.focusedSeatId == null && !_resetting) {
      _focusAnimation.stop();
      _spotlight.stop();
    }
  }

  bool get _landscape =>
      _pendingSize != null && _pendingSize!.width > _pendingSize!.height;
  EdgeInsets _safe = EdgeInsets.zero;
  double get _topInset => _safe.top + (_landscape ? 46 : 126) + 16;
  double _minFraction(Size size) => (68 / size.height).clamp(0.07, 0.24);
  double _maxFraction(Size size) =>
      math.max(_minFraction(size), size.width > size.height ? 0.55 : 0.48);
  void _scheduleReconcile() {
    if (_viewportUpdateScheduled) return;
    _viewportUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportUpdateScheduled = false;
      if (!mounted || _pendingSize == null) return;
      final size = _pendingSize!;
      final min = _minFraction(size), max = _maxFraction(size);
      final enteringLandscape = _landscape && _lastSheetLandscape != true;
      _lastSheetLandscape = _landscape;
      if (_sheet.isAttached) {
        final clamped = enteringLandscape
            ? min
            : _sheet.size.clamp(min, max).toDouble();
        if (_sheet.size != clamped) _sheet.jumpTo(clamped);
      }
      if (_camera.updateViewport(
        size.width,
        size.height,
        topInset: _topInset,
        bottomInset: _safe.bottom + (size.height - _safe.bottom) * min + 8,
        rightInset: 0,
      )) {
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
    return _landscape
        ? _safe.bottom + 8
        : (size.height - _safe.bottom) * fraction + _safe.bottom;
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
    HapticFeedback.selectionClick();
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

  void _zoomBy(double factor, [Offset? focal]) {
    final v = _camera.viewport;
    if (v == null) return;
    _camera.endGesture();
    _autoRefocus = false;
    _resetting = true; // camera-only animation, independent of selected focus
    _spotlight.stop();
    _from = _camera.value;
    _to = _camera.zoomTarget(
      factor,
      focal ?? Offset(v.viewportWidth / 2, v.viewportHeight / 2),
    );
    _focusAnimation.forward(from: 0);
  }

  void _doubleTapZoom(Offset focal) {
    final v = _camera.viewport;
    if (v == null) return;
    if (_camera.value.scale >= 0.9 * v.maxScale) {
      _resetView();
    } else {
      _zoomBy(1.8, focal);
    }
  }

  void _navigateMinimap(WorldPoint point, {bool animate = true}) {
    FocusManager.instance.primaryFocus?.unfocus();
    _manualGestureStart();
    _camera.endGesture();
    final target = _camera.centerTarget(point);
    if (!animate) {
      _camera.value = target;
      return;
    }
    _resetting = true;
    _from = _camera.value;
    _to = target;
    _focusAnimation.forward(from: 0);
  }

  @override
  void dispose() {
    _focusAnimation.dispose();
    _spotlight.dispose();
    _sheet.dispose();
    _sheetFraction.dispose();
    _camera.dispose();
    _mapController.dispose();
    _cache.dispose();
    super.dispose();
  }

  Widget _hudAction(
    String key,
    String tooltip,
    IconData icon,
    VoidCallback onPressed,
  ) => SizedBox(
    width: 34,
    height: 34,
    child: IconButton(
      key: ValueKey(key),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: ConcertPalette.gold),
    ),
  );
  List<Widget> _actions() => [
    _hudAction(
      'show-legend',
      'Bảng chú thích',
      Icons.info_outline,
      () => showDialog<void>(
        context: context,
        builder: (_) => const LegendPanel(),
      ),
    ),
    _hudAction(
      'reset-view',
      'Reset View',
      Icons.center_focus_strong,
      _resetView,
    ),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    backgroundColor: ConcertPalette.background,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.isEmpty) return const SizedBox.shrink();
        final safe = MediaQuery.viewPaddingOf(context);
        final previous = _pendingSize;
        final safeChanged = _safe != safe;
        _safe = safe;
        _pendingSize = size;
        if (previous != size || safeChanged || _camera.viewport == null)
          _scheduleReconcile();
        final landscape = size.width > size.height;
        final sheetWidth = landscape
            ? math.min(320.0, size.width * 0.42)
            : size.width;
        return Stack(
          children: [
            if (_camera.viewport != null)
              Positioned.fill(
                child: ClipRect(
                  child: InteractiveSeatCanvas(
                    camera: _camera,
                    mapController: _mapController,
                    cache: _cache,
                    spotlight: _spotlight,
                    onGestureStart: _manualGestureStart,
                    onEmptyDoubleTap: _doubleTapZoom,
                  ),
                ),
              ),
            Positioned(
              left: landscape ? 8 : 12,
              right: landscape ? 8 : 12,
              top: safe.top + 8,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  key: const ValueKey('concert-hud'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xEB141417),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF3A3326),
                      width: 0.7,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!landscape)
                        SizedBox(
                          height: 36,
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'SƠ ĐỒ CONCERT',
                                  style: TextStyle(
                                    fontSize: 14,
                                    letterSpacing: 2,
                                    color: ConcertPalette.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ..._actions(),
                            ],
                          ),
                        ),
                      FilterSearchBar(
                        controller: _mapController,
                        landscape: landscape,
                        actions: landscape ? _actions() : const [],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: _topInset + 4,
              left: 12,
              right: landscape ? sheetWidth + 12 : 12,
              child: ValueListenableBuilder<SeatMapRenderState>(
                valueListenable: _mapController,
                builder: (context, state, _) => _mapController.matchedCount != 0
                    ? const SizedBox.shrink()
                    : Material(
                        color: ConcertPalette.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: Text('Không tìm thấy chỗ phù hợp'),
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('empty-clear-filters'),
                              onPressed: _mapController.clearFilters,
                              child: const Text('Xóa bộ lọc'),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: _sheetFraction,
              child: AnimatedBuilder(
                animation: _camera,
                child: SeatMapMinimap(
                  camera: _camera,
                  mapController: _mapController,
                  cache: _cache,
                  onNavigate: (point) => _navigateMinimap(point),
                  onDrag: (point) => _navigateMinimap(point, animate: false),
                ),
                builder: (context, child) {
                  final visible =
                      _camera.viewport != null &&
                      _camera.value.scale > 1.35 * _camera.viewport!.fitScale;
                  return IgnorePointer(
                    ignoring: !visible,
                    child: AnimatedOpacity(
                      key: const ValueKey('minimap-visibility'),
                      opacity: visible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: child,
                    ),
                  );
                },
              ),
              builder: (context, fraction, child) => Positioned(
                left: 12,
                bottom:
                    safe.bottom +
                    (size.height - safe.bottom) *
                        (fraction > 0
                            ? fraction.clamp(
                                _minFraction(size),
                                _maxFraction(size),
                              )
                            : _minFraction(size)) +
                    10,
                child: child!,
              ),
            ),
            Positioned(
              key: const ValueKey('ticket-dock'),
              right: 0,
              bottom: safe.bottom,
              width: sheetWidth,
              height: size.height - safe.bottom,
              child: Align(
                alignment: Alignment.bottomRight,
                child: SeatBottomSheet(
                  mapController: _mapController,
                  sheetController: _sheet,
                  minSize: _minFraction(size),
                  maxSize: _maxFraction(size),
                  compact: landscape,
                  onFocus: _focusSeat,
                ),
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: _sheetFraction,
              builder: (context, measuredFraction, _) {
                final fraction = measuredFraction > 0
                    ? measuredFraction.clamp(
                        _minFraction(size),
                        _maxFraction(size),
                      )
                    : _minFraction(size);
                final bottom =
                    safe.bottom + (size.height - safe.bottom) * fraction + 10;
                return Positioned(
                  right: 8,
                  bottom: bottom,
                  child: CameraZoomControls(
                    camera: _camera,
                    onZoomIn: () {
                      HapticFeedback.selectionClick();
                      _zoomBy(1.25);
                    },
                    onZoomOut: () {
                      HapticFeedback.selectionClick();
                      _zoomBy(1 / 1.25);
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}
