import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/main.dart';

void main() {
  testWidgets('concert map starts with local data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const ConcertApp());
    await tester.pump();
    expect(find.text('SƠ ĐỒ CONCERT'), findsOneWidget);
    expect(find.text('200/200'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });
}
