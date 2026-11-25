import 'package:flutter/material.dart';

class LegendPanel extends StatelessWidget {
  const LegendPanel({super.key});
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF1E293B),
    title: const Text('Bảng chú thích'),
    content: const SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendLine(
            color: Color(0xFF06B6D4),
            icon: Icons.circle,
            text: 'Standing — hình tròn',
          ),
          _LegendLine(
            color: Color(0xFFF59E0B),
            icon: Icons.event_seat,
            text: 'VIP — chữ nhật bo góc, có tựa lưng',
          ),
          _LegendLine(
            color: Color(0xFF818CF8),
            icon: Icons.rounded_corner,
            text: 'Standard — vuông bo góc',
          ),
          Divider(),
          _LegendLine(
            color: Color(0xFF06B6D4),
            icon: Icons.circle_outlined,
            text: 'Trống — màu khu, viền sáng',
          ),
          _LegendLine(
            color: Color(0xFF10B981),
            icon: Icons.check_circle,
            text: 'Đang chọn — xanh ngọc, dấu ✓',
          ),
          _LegendLine(
            color: Color(0xFF94A3B8),
            icon: Icons.do_not_disturb_on,
            text: 'Đã đặt — xám, dấu gạch chéo',
          ),
          _LegendLine(
            color: Color(0xFFF87171),
            icon: Icons.close,
            text: 'Đang khóa — đỏ sẫm, dấu X',
          ),
          Divider(),
          Text(
            'Ghế không khớp bộ lọc được làm mờ (15%) và không thể chọn mới. Ghế đã chọn vẫn được giữ (40%), có viền đứt xanh ngọc và có thể bỏ chọn.',
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

class _LegendLine extends StatelessWidget {
  const _LegendLine({
    required this.color,
    required this.icon,
    required this.text,
  });
  final Color color;
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
