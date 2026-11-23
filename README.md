# Interactive Concert Seat Map

Flutter / Dart / Material 3; Android. M1: setup and local data only.

## Run

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --debug
```

## M1 data

`lib/data/seat.dart`: immutable seats, source statuses and pure Dart world geometry.
`lib/data/zone_section.dart`: block metadata, grid, color, shape and price.
`lib/data/concert_mock_data.dart`: immutable lists, world 1600×1200, T-stage, aisles, 8 blocks. Codes are row-major: ST-L/R (20 each), VP-L/C/R (15/30/15), SD-L/C/R (30/40/30). Prices: Standing 1.800.000 đ, VIP 3.500.000 đ, Standard 1.200.000 đ. Status permutation produces exactly 124 available, 52 booked, 24 locked. Selected status belongs to later controller state.

The startup screen confirms 200 seats. Canvas, gestures, selection and filters are later milestones.

## Manual verification

1. Run on an Android emulator/device: dark Vietnamese startup screen shows 200 seats.
2. Rotate the device: text remains visible without overflow.
3. Run data tests to verify counts, codes, prices and geometry.

Suggested commit: `feat: scaffold Flutter app and deterministic concert data (M1)`

## AI Usage Log

- 2026-11-24 — M1: generated Android scaffold; edited pubspec, analysis options and main screen; created Seat, ZoneSection, ConcertMockData, data/widget tests and implementation plan. Removed scaffold flutter_lints to keep SDK-only dependencies. No canvas or interaction implemented in this milestone. Verification results are reported in the delivery message.

Verification: flutter analyze — 0 issues; flutter test — 4/4 passed; flutter build apk --debug — passed. Android Gradle emitted a Java native-access warning; it did not prevent the build. Manual emulator/device verification remains for the reviewer.
