import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'dart:ui' as ui;

import '../../data/concert_mock_data.dart';
import '../../data/seat.dart';
import '../concert_palette.dart';

class SeatInk {
  SeatInk(Color zone, int state, bool dim) {
    final alpha = dim ? (state == 1 ? 0.45 : 0.15) : 1.0;
    final color = [
      zone,
      ConcertPalette.selected,
      const Color(0xFF222228),
      const Color(0xFF4A181D),
    ][state];
    fill = Paint()..color = color.withValues(alpha: alpha);
    border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = state == 1 ? 1.8 : 1
      ..color = (state == 1 ? Colors.white : const Color(0xFF7F1D1D))
          .withValues(alpha: alpha);
    symbol = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = [
        Colors.transparent,
        const Color(0xFF111114),
        const Color(0xFF52525B),
        const Color(0xFFF87171),
      ][state].withValues(alpha: alpha);
    backrest = Paint()
      ..color = const Color(0xFF111114).withValues(alpha: alpha * 0.28);
  }
  late final Paint fill, border, symbol, backrest;
}

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
      for (double d = 0; d < metric.length; d += 10) {
        dashed.addPath(metric.extractPath(d, d + 6), Offset.zero);
      }
    }
    code = SeatMapPaintCache.text(
      seat.id,
      9,
      ConcertPalette.muted,
      letterSpacing: 0,
    );
    codePosition = Offset(center.dx - code.width / 2, rect.bottom + 3);
    cullBounds = rect.inflate(20);
    inks = List.generate(
      8,
      (i) => SeatInk(ConcertPalette.zone(seat.zone), i % 4, i >= 4),
      growable: false,
    );
  }
  final Seat seat;
  late final Rect rect, cullBounds;
  late final RRect rounded, backrest;
  late final Offset center, codePosition;
  late final double radius;
  late final Path check, slash, cross, dashed;
  late final TextPainter code;
  late final List<SeatInk> inks;
}

class MapLabel {
  MapLabel(
    String label,
    double x,
    double y,
    double size,
    Color color, {
    double spacing = 2,
    this.readableSection = false,
    FontWeight weight = FontWeight.w600,
  }) : painter = SeatMapPaintCache.text(
         label,
         size,
         color,
         letterSpacing: spacing,
         weight: weight,
       ) {
    position = Offset(x - painter.width / 2, y - painter.height / 2);
    anchor = Offset(x, y);
    centeredPosition = Offset(-painter.width / 2, -painter.height / 2);
  }
  final TextPainter painter;
  late final Offset position;
  late final Offset anchor, centeredPosition;
  final bool readableSection;
}

class StardustDot {
  StardustDot(int i)
    : position = Offset(
        i.isEven ? 40.0 + (i * 17 % 45) : 1515.0 + (i * 17 % 45),
        220.0 + (i * 127 % 920),
      ),
      radius = 0.7 + (i % 3) * 0.25,
      paint = (Paint()
        ..color = const Color(0xFFD4B475)
            .withValues(alpha: 0.12 + (i % 11) * 0.02));
  final Offset position;
  final double radius;
  final Paint paint;
}

/// All render geometry, typography and state variants are prepared here.
class SeatMapPaintCache {
  SeatMapPaintCache() {
    seats = List.unmodifiable(ConcertMockData.seats.map(SeatPaintGeometry.new));
    for (final s in ConcertMockData.sections) {
      final pad = chamfer(
        Rect.fromLTRB(
          s.bounds.left - 12,
          s.bounds.top - 36,
          s.bounds.right + 12,
          s.bounds.bottom + 12,
        ),
        12,
      );
      pads.add(pad);
      final depth = s.zone == SeatZone.vip
          ? 5.0
          : s.zone == SeatZone.standard
          ? 7.0
          : 0.0;
      if (depth > 0) {
        deckShadows.add(pad.shift(Offset(0, depth + 3)));
        deckLips.add(
          Path.combine(
            PathOperation.difference,
            pad.shift(Offset(0, depth)),
            pad,
          ),
        );
      }
      if (s.zone == SeatZone.standard) {
        for (var row = 1; row < s.rows; row++) {
          final y = s.bounds.top + row * s.bounds.height / s.rows;
          tierSteps
            ..moveTo(s.bounds.left + 8, y)
            ..lineTo(s.bounds.right - 8, y);
        }
      }
      labels.add(
        MapLabel(
          '${s.label} ${s.id.split('-').last}',
          s.bounds.centerX,
          s.bounds.top - 20,
          19,
          const Color(0xFFD6D1C4),
          readableSection: true,
          weight: FontWeight.w700,
        ),
      );
    }
    mainStage = Path()
      ..moveTo(430, 70)
      ..lineTo(1170, 70)
      ..lineTo(1200, 140)
      ..lineTo(1170, 210)
      ..lineTo(430, 210)
      ..lineTo(400, 140)
      ..close();
    catwalk = Path()..addRect(const Rect.fromLTRB(776, 210, 824, 395));
    bStage = Path()
      ..moveTo(750, 395)
      ..lineTo(850, 395)
      ..lineTo(882, 430)
      ..lineTo(870, 500)
      ..lineTo(855, 512)
      ..lineTo(745, 512)
      ..lineTo(730, 500)
      ..lineTo(718, 430)
      ..close();
    foh = chamfer(const Rect.fromLTWH(745, 782, 110, 36), 8);
    innerBStage = Path()
      ..moveTo(752, 407)
      ..lineTo(848, 407)
      ..lineTo(868, 434)
      ..lineTo(858, 492)
      ..lineTo(850, 500)
      ..lineTo(750, 500)
      ..lineTo(742, 492)
      ..lineTo(732, 434)
      ..close();
    bevel = Path()
      ..moveTo(430, 70)
      ..lineTo(1170, 70)
      ..lineTo(1182, 84)
      ..lineTo(418, 84)
      ..close();
    labels.addAll([
      MapLabel('SÂN KHẤU', 800, 140, 26, Colors.white),
      MapLabel('B-STAGE', 800, 453, 14, Colors.white, spacing: 1),
      MapLabel('FOH', 800, 800, 14, Colors.white),
    ]);
    for (final path in [mainStage, catwalk, bStage, foh]) {
      stageShadows.add(path.shift(const Offset(0, 11)));
      stageExtrusions.add(
        Path.combine(
          PathOperation.difference,
          path.shift(const Offset(0, 8)),
          path,
        ),
      );
    }
    leftCone = Path()
      ..moveTo(640, 205)
      ..lineTo(350, 530)
      ..lineTo(710, 530)
      ..close();
    rightCone = Path()
      ..moveTo(960, 205)
      ..lineTo(890, 530)
      ..lineTo(1250, 530)
      ..close();
    leftLight.shader = ui.Gradient.linear(
      const Offset(640, 205),
      const Offset(530, 530),
      [const Color(0x0DE5C67E), const Color(0x00E5C67E)],
    );
    rightLight.shader = ui.Gradient.linear(
      const Offset(960, 205),
      const Offset(1070, 530),
      [const Color(0x0DE5C67E), const Color(0x00E5C67E)],
    );
  }
  static Path chamfer(Rect r, double c) => Path()
    ..moveTo(r.left + c, r.top)
    ..lineTo(r.right - c, r.top)
    ..lineTo(r.right, r.top + c)
    ..lineTo(r.right, r.bottom - c)
    ..lineTo(r.right - c, r.bottom)
    ..lineTo(r.left + c, r.bottom)
    ..lineTo(r.left, r.bottom - c)
    ..lineTo(r.left, r.top + c)
    ..close();
  static TextPainter text(
    String value,
    double size,
    Color color, {
    double letterSpacing = 2,
    FontWeight weight = FontWeight.w600,
  }) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  late final List<SeatPaintGeometry> seats;
  late final Path mainStage, catwalk, bStage, foh, innerBStage, bevel;
  final pads = <Path>[];
  final deckShadows = <Path>[], deckLips = <Path>[];
  final stageShadows = <Path>[], stageExtrusions = <Path>[];
  final tierSteps = Path();
  late final Path leftCone, rightCone;
  final leftLight = Paint(), rightLight = Paint();
  final groundShadow = Paint()..color = const Color(0xFF050507);
  final extrusion = Paint()..color = const Color(0xFF2A2D34);
  final stepPaint = Paint()
    ..color = const Color(0x442A2D34)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  final labels = <MapLabel>[];
  final stardust = List.generate(65, StardustDot.new, growable: false);
  final background = Paint()..color = ConcertPalette.background;
  final padFill = Paint()..color = const Color(0xFF151519);
  final padBorder = Paint()
    ..color = const Color(0xFF27272E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final stageFill = Paint()..color = const Color(0xFF5C606B);
  final stageBorder = Paint()
    ..color = const Color(0xFF9CA3AF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final bevelFill = Paint()..color = const Color(0xFF7A808E);
  final innerBorder = Paint()
    ..color = const Color(0xFF7A808E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final dashedBorder = Paint()
    ..color = const Color(0x73F4D078)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final spotlightGlow = Paint()
    ..color = const Color(0x44F4D078)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7;
  final spotlightRing = Paint()
    ..color = const Color(0xFFF4D078)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  final sightline = Path();
  final sightlineInk = Paint()
    ..color = const Color(0x8CE5C67E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final sightlineTagInk = Paint()..color = const Color(0xF5141417);
  final sightlineTagBorder = Paint()
    ..color = const Color(0x73C9A96E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7;
  final sightlineText = text('', 11, const Color(0xFFE5C67E), letterSpacing: 0);
  String? _focusedSeatId;
  String? get focusedSeatId => _focusedSeatId;
  Offset sightlineTagAnchor = Offset.zero;
  Offset sightlineTextPosition = Offset.zero;
  RRect sightlineTag = RRect.zero;

  /// Runs on state changes, never in paint or camera animation callbacks.
  /// The same Path and TextPainter survive every focus/zoom frame.
  void updateFocusedSeat(String? id) {
    if (_focusedSeatId == id) return;
    _focusedSeatId = id;
    sightline.reset();
    if (id == null) return;
    final seat = seats.firstWhere((g) => g.seat.id == id);
    final dx = 800 - seat.center.dx, dy = 140 - seat.center.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length > 0) {
      for (double d = 0; d < length; d += 18) {
        final end = math.min(d + 10, length);
        sightline
          ..moveTo(
            seat.center.dx + dx * d / length,
            seat.center.dy + dy * d / length,
          )
          ..lineTo(
            seat.center.dx + dx * end / length,
            seat.center.dy + dy * end / length,
          );
      }
    }
    final angle = math.atan2(dx.abs(), -dy) * 180 / math.pi;
    final direction = angle <= 15
        ? 'Chính diện'
        : seat.center.dx < 800
        ? 'Cánh trái'
        : 'Cánh phải';
    sightlineText.text = TextSpan(
      text: '${(length * 0.04).round()}m • $direction',
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE5C67E),
      ),
    );
    sightlineText.layout();
    sightlineTagAnchor = seat.center;
    sightlineTextPosition = Offset(
      -sightlineText.width / 2,
      -sightlineText.height / 2,
    );
    sightlineTag = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: sightlineText.width + 16,
        height: sightlineText.height + 10,
      ),
      const Radius.circular(8),
    );
  }

  void dispose() {
    sightlineText.dispose();
    for (final s in seats) {
      s.code.dispose();
    }
    for (final l in labels) {
      l.painter.dispose();
    }
  }
}
