import 'package:flutter/material.dart';

import '../../state/camera_controller.dart';
import '../../state/concert_map_controller.dart';
import '../canvas/interactive_seat_canvas.dart';
import '../canvas/seat_map_paint_cache.dart';

class ConcertMapScreen extends StatefulWidget {
  const ConcertMapScreen({super.key});
  @override
  State<ConcertMapScreen> createState() => _ConcertMapScreenState();
}

class _ConcertMapScreenState extends State<ConcertMapScreen> {
  late final SeatMapPaintCache _cache = SeatMapPaintCache();
  final _camera = CameraController();
  final _mapController = ConcertMapController();
  Size? _pendingSize;
  bool _viewportUpdateScheduled = false;

  void _scheduleViewport(Size size) {
    final current = _camera.viewport;
    _pendingSize = size;
    if (_viewportUpdateScheduled ||
        (current?.viewportWidth == size.width &&
            current?.viewportHeight == size.height))
      return;
    _viewportUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportUpdateScheduled = false;
      if (!mounted) return;
      final latest = _pendingSize!;
      if (_camera.updateViewport(latest.width, latest.height)) setState(() {});
    });
  }

  @override
  void dispose() {
    _camera.dispose();
    _mapController.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sơ đồ chỗ concert'),
      backgroundColor: const Color(0xFF0B1120),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '200 chỗ • Standing / VIP / Standard',
              style: TextStyle(color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
                    return const SizedBox.shrink();
                  }
                  _scheduleViewport(
                    Size(constraints.maxWidth, constraints.maxHeight),
                  );
                  if (_camera.viewport == null) return const SizedBox.expand();
                  return InteractiveSeatCanvas(
                    camera: _camera,
                    mapController: _mapController,
                    cache: _cache,
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
