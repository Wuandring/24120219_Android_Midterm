import 'package:flutter/material.dart';

import '../../state/camera_controller.dart';
import '../concert_palette.dart';

class CameraZoomControls extends StatelessWidget {
  const CameraZoomControls({
    super.key,
    required this.camera,
    required this.onZoomIn,
    required this.onZoomOut,
  });
  final CameraController camera;
  final VoidCallback onZoomIn, onZoomOut;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ValueListenableBuilder(
        valueListenable: camera,
        builder: (context, value, _) {
          final ratio =
              value.scale / (camera.viewport?.fitScale ?? value.scale);
          if (ratio >= 0.95 && ratio <= 1.05) return const SizedBox.shrink();
          return Container(
            key: const ValueKey('zoom-badge'),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: ConcertPalette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3A3326), width: 0.7),
            ),
            child: Text(
              '${ratio.toStringAsFixed(1)}×',
              style: const TextStyle(
                color: ConcertPalette.gold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
      Material(
        color: ConcertPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF3A3326), width: 0.7),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('zoom-in'),
              tooltip: 'Phóng to',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add, size: 20, color: ConcertPalette.gold),
              onPressed: onZoomIn,
            ),
            IconButton(
              key: const ValueKey('zoom-out'),
              tooltip: 'Thu nhỏ',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.remove,
                size: 20,
                color: ConcertPalette.gold,
              ),
              onPressed: onZoomOut,
            ),
          ],
        ),
      ),
    ],
  );
}
