import 'package:flutter_test/flutter_test.dart';
import 'package:concert_seat_map/main.dart';

void main() {
  testWidgets('concert map starts with local data', (tester) async {
    await tester.pumpWidget(const ConcertApp());
    expect(find.text('Sơ đồ chỗ concert'), findsOneWidget);
    expect(find.textContaining('200 chỗ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
