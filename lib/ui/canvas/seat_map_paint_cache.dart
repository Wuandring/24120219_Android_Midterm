import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/concert_mock_data.dart';
import '../../data/seat.dart';

class SeatPaintGeometry {
  SeatPaintGeometry(this.seat) {
    final b = seat.bounds;
    rect = Rect.fromLTWH(b.left, b.top, b.width, b.height);
    rounded = RRect.fromRectAndRadius(
      rect,
      Radius.circular(seat.shape == SeatShape.roundedRectangle ? 7 : 5),
    );
    center = rect.center;
    radius = rect.shortestSide / 2;
    backrest = RRect.fromRectAndRadius(
      Rect.fromLTWH(b.left + 5, b.top + 3, b.width - 10, 3),
      const Radius.circular(1.5),
    );
    check = Path()
      ..moveTo(center.dx - 7, center.dy)
      ..lineTo(center.dx - 2, center.dy + 5)
      ..lineTo(center.dx + 8, center.dy - 6);
    slash = Path()
      ..moveTo(center.dx - 7, center.dy + 7)
      ..lineTo(center.dx + 7, center.dy - 7);
    cross = Path()
      ..addPath(slash, Offset.zero)
      ..moveTo(center.dx - 7, center.dy - 7)
      ..lineTo(center.dx + 7, center.dy + 7);
    final outline = Path();
    if (seat.shape == SeatShape.circle) {
      outline.addOval(rect.inflate(3));
    } else {
      outline.addRRect(rounded.inflate(3));
    }
    dashed = Path();
    for (final metric in outline.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 10) {
        dashed.addPath(metric.extractPath(distance, distance + 6), Offset.zero);
      }
    }
    code = SeatMapPaintCache.text(seat.id, 7.5, const Color(0xFFE2E8F0));
    codePosition = Offset(center.dx - code.width / 2, rect.bottom + 3);
    cullBounds = rect.inflate(15);
  }
  final Seat seat;
  late final Rect rect, cullBounds;
  late final RRect rounded, backrest;
  late final Offset center, codePosition;
  late final double radius;
  late final Path check, slash, cross, dashed;
  late final TextPainter code;
}

class MapLabel {
  MapLabel(String label, double x, double y, double size, Color color)
    : painter = SeatMapPaintCache.text(label, size, color) {
    position = Offset(x - painter.width / 2, y - painter.height / 2);
  }
  final TextPainter painter;
  late final Offset position;
}

/// Owns painting resources for one map. No Paint/TextPainter creation per frame.
class SeatMapPaintCache {
  SeatMapPaintCache() {
    seats = List.unmodifiable(ConcertMockData.seats.map(SeatPaintGeometry.new));
    for (final section in ConcertMockData.sections) {
      zoneColors[section.id] = Color(section.colorArgb);
      labels.add(
        MapLabel(
          section.label,
          section.bounds.centerX,
          section.bounds.top - 20,
          22,
          Color(section.colorArgb),
        ),
      );
    }
    labels.addAll([
      MapLabel('MAIN STAGE', 800, 140, 28, const Color(0xFFF8FAFC)),
      MapLabel('CATWALK', 800, 370, 15, const Color(0xFF67E8F9)),
    ]);
    stage = Path()
      ..moveTo(400, 70)
      ..lineTo(1200, 70)
      ..lineTo(1200, 210)
      ..lineTo(860, 210)
      ..lineTo(860, 520)
      ..lineTo(740, 520)
      ..lineTo(740, 210)
      ..lineTo(400, 210)
      ..close();
    glow.shader = ui.Gradient.radial(const Offset(800, 290), 580, [
      const Color(0x4406B6D4),
      const Color(0x0006B6D4),
    ]);
    aisles = List.unmodifiable(
      ConcertMockData.aisles.map(
        (b) => Rect.fromLTWH(b.left, b.top, b.width, b.height),
      ),
    );
  }
  static TextPainter text(String value, double size, Color color) =>
      TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: size,
            color: color,
            fontWeight: FontWeight.w600,
            letterSpacing: size > 10 ? 1.8 : 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  late final List<SeatPaintGeometry> seats;
  late final List<Rect> aisles;
  final labels = <MapLabel>[];
  final zoneColors = <String, Color>{};
  late final Path stage;
  final arena = RRect.fromRectAndRadius(
    const Rect.fromLTWH(35, 25, 1530, 1160),
    const Radius.circular(100),
  );
  final glowRect = const Rect.fromLTWH(180, 0, 1240, 840);
  final glow = Paint();
  final background = Paint()..color = const Color(0xFF0B1120);
  final aisle = Paint()..color = const Color(0xFF090F1C);
  final stageFill = Paint()..color = const Color(0xFF1E293B);
  final stageBorder = Paint()
    ..color = const Color(0xFF67E8F9)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final contour = Paint()
    ..color = const Color(0xFF263449)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final fill = Paint();
  final border = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final symbol = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final accent = Paint();
  void dispose() {
    for (final seat in seats) {
      seat.code.dispose();
    }
    for (final label in labels) {
      label.painter.dispose();
    }
  }
}
