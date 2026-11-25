import 'package:flutter/material.dart';

import '../data/seat.dart';

abstract final class ConcertPalette {
  static const background = Color(0xFF0D0D0F);
  static const surface = Color(0xFF141417);
  static const gold = Color(0xFFC9A96E);
  static const selected = Color(0xFFF4D078);
  static const text = Color(0xFFF5F2EB);
  static const muted = Color(0xFFB8B3A6);
  static Color zone(SeatZone zone) => switch (zone) {
    SeatZone.standing => const Color(0xFF7E7CE0),
    SeatZone.vip => const Color(0xFFDF7A33),
    SeatZone.standard => const Color(0xFF3FA8A8),
  };
}
