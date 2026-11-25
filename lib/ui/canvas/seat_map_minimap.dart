import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/concert_mock_data.dart';
import '../../data/seat.dart';
import '../../engine/coordinate_transformer.dart';
import '../../state/camera_controller.dart';
import '../../state/concert_map_controller.dart';
import 'seat_map_paint_cache.dart';

/// A small, independent repaint surface; the main seat Canvas stays unchanged.
class SeatMapMinimap extends StatefulWidget {
  const SeatMapMinimap({
    super.key,
    required this.camera,
    required this.mapController,
    required this.cache,
    required this.onNavigate,
    required this.onDrag,
  });
  final CameraController camera;
  final ConcertMapController mapController;
  final SeatMapPaintCache cache;
  final ValueChanged<WorldPoint> onNavigate, onDrag;

  static double worldScale(Size size) =>
      math.min((size.width - 8) / 1600, (size.height - 6) / 1200);

  static WorldPoint worldAt(Offset point, Size size) {
    final s = worldScale(size);
    final dx = (size.width - 1600 * s) / 2;
    final dy = (size.height - 1200 * s) / 2;
    return WorldPoint(
      ((point.dx - dx) / s).clamp(0.0, 1600.0),
      ((point.dy - dy) / s).clamp(0.0, 1200.0),
    );
  }

  @override
  State<SeatMapMinimap> createState() => _SeatMapMinimapState();
}

class _SeatMapMinimapState extends State<SeatMapMinimap> {
  late SeatMapMinimapPainter _painter;
  void _preparePainter() => _painter = SeatMapMinimapPainter(
    camera: widget.camera,
    mapController: widget.mapController,
    cache: widget.cache,
  );
  @override
  void initState() {
    super.initState();
    _preparePainter();
  }

  @override
  void didUpdateWidget(covariant SeatMapMinimap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera != widget.camera ||
        oldWidget.mapController != widget.mapController ||
        oldWidget.cache != widget.cache)
      _preparePainter();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('seat-minimap'),
    width: 112,
    height: 84,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6141417),
        border: Border.all(color: const Color(0xFFC9A96E)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Semantics(
          label: 'Bản đồ thu nhỏ. Chạm hoặc kéo để di chuyển sơ đồ chính.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => widget.onNavigate(
              SeatMapMinimap.worldAt(d.localPosition, const Size(112, 84)),
            ),
            onPanStart: (d) => widget.onDrag(
              SeatMapMinimap.worldAt(d.localPosition, const Size(112, 84)),
            ),
            onPanUpdate: (d) => widget.onDrag(
              SeatMapMinimap.worldAt(d.localPosition, const Size(112, 84)),
            ),
            child: RepaintBoundary(child: CustomPaint(painter: _painter)),
          ),
        ),
      ),
    ),
  );
}

class SeatMapMinimapPainter extends CustomPainter {
  SeatMapMinimapPainter({
    required this.camera,
    required this.mapController,
    required this.cache,
  }) : super(repaint: Listenable.merge([camera, mapController]));
  final CameraController camera;
  final ConcertMapController mapController;
  final SeatMapPaintCache cache;
  final _stage = Paint()..color = const Color(0xFF777B86);
  final _standing = Paint()..color = const Color(0x997E7CE0);
  final _vip = Paint()..color = const Color(0x99DF7A33);
  final _standard = Paint()..color = const Color(0x993FA8A8);
  final _selected = Paint()..color = const Color(0xFFF4D078);
  final _viewportFill = Paint()..color = const Color(0x1FF4D078);
  final _viewportStroke = Paint()
    ..color = const Color(0xFFF4D078)
    ..style = PaintingStyle.stroke;
  Rect lastVisibleWorldRect = Rect.zero;
  int lastSelectedDotCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    final v = camera.viewport;
    if (size.isEmpty || v == null) return;
    final s = SeatMapMinimap.worldScale(size);
    canvas.save();
    canvas.translate((size.width - 1600 * s) / 2, (size.height - 1200 * s) / 2);
    canvas.scale(s);
    canvas.drawPath(cache.mainStage, _stage);
    canvas.drawPath(cache.catwalk, _stage);
    canvas.drawPath(cache.bStage, _stage);
    canvas.drawPath(cache.foh, _stage);
    for (var i = 0; i < cache.pads.length; i++) {
      final ink = switch (ConcertMockData.sections[i].zone) {
        SeatZone.standing => _standing,
        SeatZone.vip => _vip,
        SeatZone.standard => _standard,
      };
      canvas.drawPath(cache.pads[i], ink);
    }
    final visible = CoordinateTransformer.visibleWorldRect(
      camera.value,
      viewportWidth: v.viewportWidth,
      viewportHeight: v.viewportHeight,
    );
    lastVisibleWorldRect = Rect.fromLTRB(
      visible.left.clamp(0.0, 1600.0),
      visible.top.clamp(0.0, 1200.0),
      visible.right.clamp(0.0, 1600.0),
      visible.bottom.clamp(0.0, 1200.0),
    );
    _viewportStroke.strokeWidth = 1 / s;
    canvas.drawRect(lastVisibleWorldRect, _viewportFill);
    canvas.drawRect(lastVisibleWorldRect, _viewportStroke);
    lastSelectedDotCount = 0;
    for (var i = 0; i < cache.seats.length; i++) {
      final g = cache.seats[i];
      if (mapController.value.selectedSeatIds.contains(g.seat.id)) {
        canvas.drawCircle(g.center, 1.5 / s, _selected);
        lastSelectedDotCount++;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SeatMapMinimapPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.mapController != mapController ||
      oldDelegate.cache != cache;
}
