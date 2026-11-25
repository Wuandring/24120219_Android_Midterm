import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../concert_palette.dart';

class LegendPanel extends StatelessWidget {
  const LegendPanel({super.key});
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: ConcertPalette.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: ConcertPalette.gold, width: 0.7),
    ),
    title: const Text(
      'Bảng chú thích',
      style: TextStyle(color: Color(0xFFE5C67E)),
    ),
    content: const SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendLine(swatch: _Swatch(zone: 0), text: 'Standing — hình tròn'),
          _LegendLine(
            swatch: _Swatch(zone: 1),
            text: 'VIP — chữ nhật bo góc, có tựa lưng',
          ),
          _LegendLine(
            swatch: _Swatch(zone: 2),
            text: 'Standard — vuông bo góc',
          ),
          Divider(color: Color(0xFF3A3326)),
          _LegendLine(
            swatch: _Swatch(zone: 0),
            text: 'Trống — màu khu lì, không viền sáng',
          ),
          _LegendLine(
            swatch: _Swatch(state: 1),
            text: 'Đang chọn — vàng champagne, viền trắng, dấu ✓ tối',
          ),
          _LegendLine(
            swatch: _Swatch(state: 2),
            text: 'Đã đặt — nền than chì, dấu gạch chéo',
          ),
          _LegendLine(
            swatch: _Swatch(state: 3),
            text: 'Đang khóa — đỏ sẫm, dấu X',
          ),
          Divider(color: Color(0xFF3A3326)),
          Text(
            'Ghế không khớp bộ lọc được làm mờ (15%) và không thể chọn mới. Ghế đã chọn vẫn được giữ (45%), có viền đứt champagne-gold và có thể bỏ chọn.',
            style: TextStyle(color: ConcertPalette.muted),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({this.zone = 2, this.state = 0});
  final int zone, state;
  @override
  Widget build(BuildContext context) {
    final color = state == 0
        ? [
            const Color(0xFF7E7CE0),
            const Color(0xFFDF7A33),
            const Color(0xFF3FA8A8),
          ][zone]
        : [
            Colors.transparent,
            ConcertPalette.selected,
            const Color(0xFF222228),
            const Color(0xFF4A181D),
          ][state];
    return Container(
      width: 26,
      height: zone == 1 ? 20 : 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(zone == 0 ? 13 : 4),
        border: state == 1
            ? Border.all(color: Colors.white, width: 1.8)
            : state == 3
            ? Border.all(color: const Color(0xFF7F1D1D))
            : null,
      ),
      child: state == 1
          ? const Icon(Icons.check, size: 18, color: Color(0xFF111114))
          : state == 3
          ? const Icon(Icons.close, size: 18, color: Color(0xFFF87171))
          : state == 2
          ? Center(
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: Container(
                  width: 19,
                  height: 2,
                  color: const Color(0xFF52525B),
                ),
              ),
            )
          : zone == 1
          ? Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 18,
                height: 2,
                margin: const EdgeInsets.only(top: 3),
                color: const Color(0x47111114),
              ),
            )
          : null,
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.swatch, required this.text});
  final Widget swatch;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 28, child: swatch),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: ConcertPalette.text)),
        ),
      ],
    ),
  );
}
