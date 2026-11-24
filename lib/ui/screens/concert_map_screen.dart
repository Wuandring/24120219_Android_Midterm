import 'package:flutter/material.dart';

import '../../data/concert_mock_data.dart';
import '../../engine/camera_transform.dart';
import '../../engine/viewport_clamper.dart';
import '../canvas/seat_map_paint_cache.dart';
import '../canvas/seat_map_painter.dart';

class ConcertMapScreen extends StatefulWidget {
  const ConcertMapScreen({super.key});
  @override
  State<ConcertMapScreen> createState() => _ConcertMapScreenState();
}

class _ConcertMapScreenState extends State<ConcertMapScreen> {
  late final SeatMapPaintCache _cache = SeatMapPaintCache();
  final _camera = ValueNotifier(CameraTransform(scale: 1));
  final _mapState = ValueNotifier(SeatMapRenderState());
  @override
  void dispose() {
    _camera.dispose();
    _mapState.dispose();
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
                  final viewport = ViewportClamper(
                    worldBounds: ConcertMockData.worldBounds,
                    viewportWidth: constraints.maxWidth,
                    viewportHeight: constraints.maxHeight,
                  );
                  _camera.value = viewport.fit();
                  return RepaintBoundary(
                    child: Semantics(
                      label: 'Sơ đồ concert: sân khấu chữ T, 40 Standing, 60 VIP và 100 Standard.',
                      image: true,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: SeatMapPainter(
                          cache: _cache,
                          camera: _camera,
                          mapState: _mapState,
                          fitScale: viewport.fitScale,
                        ),
                      ),
                    ),
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
