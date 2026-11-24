import 'package:flutter/material.dart';

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
  });
  final CameraController camera;
  final ConcertMapController mapController;
  final SeatMapPaintCache cache;
  @override
  State<InteractiveSeatCanvas> createState() => _InteractiveSeatCanvasState();
}

class _InteractiveSeatCanvasState extends State<InteractiveSeatCanvas> {
  bool _gestureConsumed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('seat-canvas-gestures'),
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _gestureConsumed = false,
    onScaleStart: (details) {
      _gestureConsumed = true;
      widget.camera.startGesture(details.localFocalPoint, details.pointerCount);
    },
    onScaleUpdate: (details) => widget.camera.updateGesture(
      focalPoint: details.localFocalPoint,
      scale: details.scale,
      pointerCount: details.pointerCount,
    ),
    onScaleEnd: (_) => widget.camera.endGesture(),
    onTapUp: (details) {
      if (_gestureConsumed || widget.camera.viewport == null) return;
      final seat = HitTester.hitTest(
        seats: ConcertMockData.seats,
        screenPoint: WorldPoint(
          details.localPosition.dx,
          details.localPosition.dy,
        ),
        camera: widget.camera.value,
      );
      if (seat == null) return;
      if (!widget.mapController.toggleSeat(seat.id)) {
        final status = seat.status == SeatStatus.booked
            ? 'đã được đặt'
            : 'đang khóa';
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('${seat.id}: ghế $status.')));
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
            camera: widget.camera,
            mapState: widget.mapController,
            fitScale: widget.camera.viewport!.fitScale,
          ),
        ),
      ),
    ),
  );
}
