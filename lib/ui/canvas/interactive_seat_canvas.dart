import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'dart:math' as math;

import '../../data/concert_mock_data.dart';
import '../../data/seat.dart';
import '../../engine/coordinate_transformer.dart';
import '../../engine/hit_tester.dart';
import '../../state/camera_controller.dart';
import '../../state/concert_map_controller.dart';
import 'seat_map_paint_cache.dart';
import 'seat_map_painter.dart';

class InteractiveSeatCanvas extends StatefulWidget {
  const InteractiveSeatCanvas({
    super.key,
    required this.camera,
    required this.mapController,
    required this.cache,
    this.spotlight = kAlwaysCompleteAnimation,
    this.onGestureStart,
    this.onEmptyDoubleTap,
  });
  final CameraController camera;
  final ConcertMapController mapController;
  final SeatMapPaintCache cache;
  final Animation<double> spotlight;
  final VoidCallback? onGestureStart;
  final ValueChanged<Offset>? onEmptyDoubleTap;
  @override
  State<InteractiveSeatCanvas> createState() => _InteractiveSeatCanvasState();
}

class _InteractiveSeatCanvasState extends State<InteractiveSeatCanvas> {
  bool _gestureConsumed = false;
  Duration _downTime = Duration.zero;
  Duration? _lastEmptyTap;
  Offset? _lastEmptyPosition;
  @override
  void initState() {
    super.initState();
    widget.mapController.addListener(_syncFocusCache);
    _syncFocusCache();
  }

  void _syncFocusCache() =>
      widget.cache.updateFocusedSeat(widget.mapController.focusedSeatId);

  @override
  void didUpdateWidget(covariant InteractiveSeatCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapController != widget.mapController) {
      oldWidget.mapController.removeListener(_syncFocusCache);
      widget.mapController.addListener(_syncFocusCache);
    }
    _syncFocusCache();
  }

  @override
  void dispose() {
    widget.mapController.removeListener(_syncFocusCache);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) => _downTime = event.timeStamp,
    onPointerSignal: (event) {
      if (event is! PointerScrollEvent) return;
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onGestureStart?.call();
      widget.camera.endGesture();
      final factor = math.exp((-event.scrollDelta.dy / 240).clamp(-2.0, 2.0));
      widget.camera.value = widget.camera.zoomTarget(
        factor,
        event.localPosition,
      );
      _lastEmptyTap = null;
    },
    child: GestureDetector(
      key: const ValueKey('seat-canvas-gestures'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _gestureConsumed = false,
      onScaleStart: (details) {
        FocusManager.instance.primaryFocus?.unfocus();
        _gestureConsumed = true;
        _lastEmptyTap = null;
        widget.onGestureStart?.call();
        widget.camera.startGesture(
          details.localFocalPoint,
          details.pointerCount,
        );
      },
      onScaleUpdate: (details) => widget.camera.updateGesture(
        focalPoint: details.localFocalPoint,
        scale: details.scale,
        pointerCount: details.pointerCount,
      ),
      onScaleEnd: (_) => widget.camera.endGesture(),
      onTapUp: (details) {
        FocusManager.instance.primaryFocus?.unfocus();
        if (_gestureConsumed || widget.camera.viewport == null) return;
        final seat = HitTester.hitTest(
          seats: ConcertMockData.seats,
          screenPoint: WorldPoint(
            details.localPosition.dx,
            details.localPosition.dy,
          ),
          camera: widget.camera.value,
          isEligible: widget.mapController.canTapSeat,
        );
        if (seat == null) {
          // Recognize empty-space double taps without delaying ordinary seat taps
          // behind GestureDetector's double-tap timeout.
          final anySeat = HitTester.hitTest(
            seats: ConcertMockData.seats,
            screenPoint: WorldPoint(
              details.localPosition.dx,
              details.localPosition.dy,
            ),
            camera: widget.camera.value,
          );
          if (anySeat != null) {
            _lastEmptyTap = null;
            return;
          }
          final previous = _lastEmptyTap;
          if (previous != null &&
              _downTime >= previous &&
              _downTime - previous <= const Duration(milliseconds: 300) &&
              (details.localPosition - _lastEmptyPosition!).distanceSquared <=
                  36 * 36) {
            widget.onEmptyDoubleTap?.call(details.localPosition);
            _lastEmptyTap = null;
          } else {
            _lastEmptyTap = _downTime;
            _lastEmptyPosition = details.localPosition;
          }
          return;
        }
        _lastEmptyTap = null;
        if (!widget.mapController.toggleSeat(seat.id)) {
          HapticFeedback.lightImpact();
          widget.mapController.inspectSeat(seat.id);
          final status = seat.status == SeatStatus.booked
              ? 'đã được đặt'
              : 'đang khóa';
          ScaffoldMessenger.maybeOf(context)
            ?..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('${seat.id}: ghế $status.')));
        } else {
          HapticFeedback.selectionClick();
        }
      },
      child: RepaintBoundary(
        child: Semantics(
          label: 'Sơ đồ concert: chạm ghế trống để chọn, kéo để di chuyển, dùng hai ngón để phóng to.',
          image: true,
          child: CustomPaint(
            size: Size.infinite,
            painter: SeatMapPainter(
              cache: widget.cache,
              spotlight: widget.spotlight,
              camera: widget.camera,
              mapState: widget.mapController,
              fitScale: widget.camera.viewport!.fitScale,
            ),
          ),
        ),
      ),
    ),
  );
}
