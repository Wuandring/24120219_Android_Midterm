# Sơ đồ chỗ ngồi Concert tương tác

## 1. Mô tả đề tài

Ứng dụng Flutter/Dart, Material 3 dành cho Android, hiển thị **200 ghế trong 3 phân khu Standing, VIP và Standard** trên nền concert tối. Sân khấu chữ T, lối đi, nhãn khu và toàn bộ ghế được vẽ bằng **một CustomPainter**. Ghế không phải các Widget riêng lẻ; ứng dụng không dùng InteractiveViewer.

| Trạng thái trực quan | Cách hiển thị | Thao tác |
| --- | --- | --- |
| Trống (available) | Màu phân khu, viền sáng | Chạm để chọn nếu khớp bộ lọc |
| Đang chọn (selected) | Champagne-gold `#F4D078`, viền trắng, dấu ✓ tối | Chạm lần nữa hoặc xóa trong danh sách vé để bỏ chọn |
| Đã đặt (booked) | Xám slate, gạch chéo | Chỉ xem thông tin |
| Đang khóa (locked) | Đỏ sẫm, dấu X | Chỉ xem thông tin |

Dữ liệu hoàn toàn cục bộ và cố định, không có API, cơ sở dữ liệu hoặc thanh toán. Tổng tiền vé là **giá mô phỏng**. Chức năng gồm kéo bản đồ, pinch-to-zoom, chọn ghế, danh sách vé mở rộng, focus/spotlight, chú thích, lọc/tìm kiếm và Reset View. Chỉ khai báo Flutter SDK và flutter_test từ SDK; không thêm package bên thứ ba trực tiếp. Các dependency bắc cầu do SDK cung cấp được khóa trong `pubspec.lock`.

## 2. Hướng dẫn chạy và kiểm thử

Môi trường đã kiểm chứng: Flutter **3.47.9 stable**, Dart **3.13.7**. `pubspec.yaml` yêu cầu Dart `^3.13.7`. Cần Android SDK, JDK tương thích với cấu hình Gradle của dự án và emulator hoặc thiết bị Android bật USB debugging. Có thể dùng `flutter doctor` để kiểm tra môi trường và `flutter devices` để chọn thiết bị.

Chạy tại thư mục gốc dự án:

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --debug
```

APK debug được tạo tại `build/app/outputs/flutter-apk/app-debug.apk`. Thư mục `build/` không đưa vào Git. Nếu có nhiều thiết bị, chạy `flutter run -d <device-id>`.

Các nhóm kiểm thử:

| Đường dẫn | Nội dung |
| --- | --- |
| `test/data/` | Đúng 200 ghế, mã duy nhất, giá/khu, tỷ lệ trạng thái, không giao ghế/sân khấu/lối đi |
| `test/engine/` | Đổi tọa độ, focal zoom, kẹp biên, hit-test sau pan/zoom và tại biên hình |
| `test/state/` | Camera, lựa chọn, tổng tiền, focus, bộ lọc, snapshot bất biến |
| `test/ui/` | Gesture thật trong widget test, đồng bộ hai chiều, sheet dài, focus, xoay màn hình, legend, reset, bàn phím |
| `test/widget_test.dart` | Khởi động ứng dụng |

Để chạy riêng một nhóm: `flutter test test/engine/` hoặc `flutter test test/ui/m6_tools_test.dart`.

## 3. Kiến trúc mã nguồn

```text
lib/
├── main.dart
├── data/
│   ├── seat.dart
│   ├── zone_section.dart
│   └── concert_mock_data.dart
├── engine/
│   ├── camera_transform.dart
│   ├── coordinate_transformer.dart
│   ├── viewport_clamper.dart
│   └── hit_tester.dart
├── state/
│   ├── camera_controller.dart
│   ├── framed_viewport.dart
│   ├── concert_map_controller.dart
│   ├── seat_map_render_state.dart
│   └── filter_state.dart
└── ui/
    ├── canvas/
    │   ├── seat_map_paint_cache.dart
    │   ├── seat_map_painter.dart
    │   └── interactive_seat_canvas.dart
    ├── widgets/
    │   ├── seat_bottom_sheet.dart
    │   ├── filter_search_bar.dart
    │   └── legend_panel.dart
    └── screens/
        └── concert_map_screen.dart
```

- **Data:** model bất biến, hình học thế giới và mock layout. Không phụ thuộc Widget.
- **Engine:** toán Dart thuần, không import Flutter hoặc dart:ui; có thể unit-test độc lập với UI.
- **State:** nguồn sự thật duy nhất cho camera, lựa chọn, kiểm tra ghế, focus và bộ lọc. Xuất snapshot bất biến cho painter.
- **UI Canvas:** nhận gesture tọa độ cục bộ, chuyển sang engine/controller và vẽ bản đồ.
- **UI Widgets/Screen:** điều khiển lọc, chú thích, danh sách vé; quản lý vòng đời controller/cache/animation. Reset View nằm trong HUD nổi của screen, không có file map_controls.dart riêng.

## 4. Tổ chức dữ liệu và bố cục

`Seat` lưu id, sectionId, zone, trạng thái gốc, hình dạng, giá VND nguyên và `WorldRect`. `ZoneSection` mô tả block, số hàng/cột, màu, giá và hình dạng. `ConcertMockData` cung cấp danh sách chỉ đọc, không dùng random hoặc thời gian hệ thống.

Thế giới có kích thước **1600×1200**. MAIN STAGE là hình chữ nhật `(400,70,800,140)`; CATWALK `(740,210,120,310)` nối xuống giữa, tạo sân khấu chữ T. Standing nằm hai bên catwalk; VIP ở giữa; Standard phía dưới. Các hình chữ nhật lối đi chia ngang và dọc giữa các block, không đè lên ghế.

| Khu | Block và lưới hàng × cột | Số ghế | Hình / màu | Giá mô phỏng |
| --- | --- | ---: | --- | ---: |
| Standing | ST-L: 4×5; ST-R: 4×5 | 40 | Tròn, periwinkle lì `#7E7CE0` | 1.800.000 đ |
| VIP | VP-L: 3×5; VP-C: 3×10; VP-R: 3×5 | 60 | Chữ nhật bo góc có tựa lưng, terracotta lì `#DF7A33` | 3.500.000 đ |
| Standard | SD-L: 5×6; SD-C: 5×8; SD-R: 5×6 | 100 | Vuông bo góc, teal lì `#3FA8A8` | 1.200.000 đ |

Đánh số từng block theo hàng, từ trái sang phải, bắt đầu 01: `ST-L01..20`, `ST-R01..20`, `VP-L01..15`, `VP-C01..30`, `VP-R01..15`, `SD-L01..30`, `SD-C01..40`, `SD-R01..30`. Nhãn Canvas có hậu tố L/C/R để phân biệt 8 section.

Với chỉ số ghế toàn cục i, đặt `bucket = (i * 37 + 11) % 100`: bucket < 62 là available, < 88 là booked, còn lại locked. Hai chu kỳ 100 phần tử tạo đúng **124 ghế trống / 52 đã đặt / 24 khóa**. Selected là lớp trạng thái của controller, không thay đổi trạng thái gốc trong Seat.

## 5. Chuyển đổi tọa độ, pinch-to-zoom và kẹp biên

Gọi s là scale, `(tx,ty)` là translation theo pixel cục bộ Canvas, `(xw,yw)` là điểm World và `(xs,ys)` là điểm Screen:

```text
World → Screen: xs = xw * s + tx; ys = yw * s + ty
Screen → World: xw = (xs - tx) / s; yw = (ys - ty) / s
fitScale = min(viewportWidth / 1600, viewportHeight / 1200)
sMin = 0.9 * fitScale; sMax = 4.5 * fitScale
```

Pan cộng độ dịch pixel vào translation. Với focal point f và hệ số zoom gia tăng d:

```text
sNew = clamp(sOld * d, sMin, sMax)
r = sNew / sOld
txNew = fx - (fx - txOld) * r
tyNew = fy - (fy - tyOld) * r
```

Công thức giữ nguyên điểm World dưới focal point trước bước kẹp biên. Flutter cung cấp scale tích lũy từ đầu gesture; `CameraController` dùng `d = currentScale / lastScale`. Khi focal point di chuyển, controller cộng delta focal trước rồi zoom quanh focal mới; khi số ngón thay đổi, nó lấy lại mốc focal/scale để tránh nhảy. Dùng onScaleStart/Update/End cho cả pan và pinch; không trộn onPan. Tap sau drag/pinch bị loại.

Kẹp biên từng trục với world start a, world length L, kích thước viewport V, padding pixel p:

```text
Nếu L*s + 2*p <= V: t = (V - L*s)/2 - a*s
Ngược lại: t = clamp(t, V - (a+L)*s - p, -a*s + p)
```

Engine mặc định p = 0. Camera dùng padding cố định `width/2` theo x và `0.8*height` theo y để đưa các hàng Standard cuối lên trên sheet mà vẫn giữ một phần bản đồ trong màn hình. Padding không phụ thuộc chiều cao sheet đang kéo; fitScale vẫn tính theo world gốc.

Viewport gắn với **toàn bộ container Canvas**. Fit chỉ khởi tạo lần đầu; chỉ resize khi width/height thực sự thay đổi. LayoutBuilder chỉ ghi nhận kích thước và lên lịch cập nhật sau frame, không ghi ValueNotifier trong build. Resize giữ tỷ lệ `oldScale/oldFitScale`, giữ tâm World cũ nếu biên cho phép, rồi clamp lại. Nếu đang focus và người dùng chưa tự pan/zoom, screen tính lại focus theo hướng mới.

## 6. Hit-testing và điều kiện chọn ghế

`onTapUp` dùng `details.localPosition`, không dùng tọa độ toàn màn hình. `HitTester` đổi Screen → World trước khi duyệt ghế:

- Standing: tâm `(cx,cy)`, bán kính `min(width,height)/2`; kiểm tra khoảng cách bình phương <= `(radius + epsilon)^2`.
- VIP/Standard: kiểm tra cả bốn cạnh hình chữ nhật bao gồm điểm trên biên, theo quy định hit-test của đề. Hình vẽ có góc bo nhưng hit-test dùng Rect bounds.
- `epsilon = 1e-12 * max(1.0, max(abs(left)+width, abs(top)+height))` chỉ bù sai số số thực, không tạo vùng chạm mở rộng đáng kể.

Eligibility dùng chung với controller: ghế không khớp bộ lọc và chưa chọn không được chọn mới; ghế đã chọn dù bị làm mờ vẫn có thể bỏ chọn. Ghế booked/locked đủ điều kiện chạm chỉ hiện thông tin/snackbar, không vào ticket. Kiểm thử engine bao gồm tâm của cả 200 ghế sau pan/zoom, đường tròn, góc Rect và điểm trong/ngoài biên ở mức zoom cao.

## 7. Quản lý trạng thái và đồng bộ hai chiều

`ConcertMapController` là **Single Source of Truth** cho lựa chọn, inspection, focusedSeatId và FilterState. Nó kế thừa ValueNotifier, đồng thời là ChangeNotifier/Listenable. `LinkedHashSet<String>` giữ thứ tự chọn, chống trùng; danh sách Seat, số ghế, tổng giá nguyên và chuỗi VND được suy ra từ tập này. `SeatMapRenderState` giữ selectedSeatIds, matchingSeatIds, focusedSeatId bất biến.

`CameraController` kế thừa `ValueNotifier<CameraTransform>`, sở hữu viewport, transform và mốc gesture. Các controller sống suốt vòng đời screen; xoay/rebuild không tạo lại lựa chọn hoặc bộ lọc. Trạng thái nằm trong bộ nhớ, không được lưu qua việc đóng/khởi động lại ứng dụng.

Chạm ghế cập nhật snapshot cho painter và Bottom Sheet ngay. Sheet luôn liệt kê toàn bộ lựa chọn, kể cả ghế không khớp bộ lọc. Xóa một dòng cập nhật Canvas và xóa focus nếu cần. Chạm dòng vé tạo animation camera 300ms; mục tiêu y là `(viewportHeight - bottomInset)/2`, trong đó bottomInset là chiều cao sheet tại thời điểm yêu cầu focus. Zoom được clamp trong giới hạn. Sau đó chạy vòng spotlight 1,2 giây và giữ viền ổn định. Tự pan/zoom dừng camera animation và tắt auto-refocus.

Sheet có tay nắm kéo và nút mở/thu; thả tay nắm sẽ snap về đầu gần nhất. Sheet thu gọn cao khoảng 58px ở dọc, 50px ở ngang; max tương ứng 0,48 và 0,55. Ở ngang, sheet dock bên phải, rộng tối đa 320px, chừa toàn bộ vùng trái/giữa để pinch. Kéo/mở sheet không đổi viewport, zoom hoặc tự kéo camera về ghế focus. Thanh thu gọn ưu tiên số ghế/tổng tiền khi có lựa chọn, chỉ hiện inspection khi không có ghế đã chọn.

FilterState kết hợp zone, trạng thái trực quan và tìm chuỗi con id không phân biệt hoa/thường, bỏ khoảng trắng đầu/cuối. Available không bao gồm Selected. Không có điều kiện: matchingSeatIds = null; không khớp ghế nào: tập rỗng và banner “Không tìm thấy chỗ phù hợp”. Xóa lọc không xóa ticket. Bộ lọc đang hoạt động có viền/tint champagne-gold.

**Reset View chỉ animate camera về viewport.fit() trong khoảng 300ms; không xóa query, bộ lọc, lựa chọn, tổng tiền, inspection hay focusedSeatId.** Reset tắt auto-refocus để không bị snap ngược. Legend mở bằng HUD và đóng khi không dùng. Scaffold đặt resizeToAvoidBottomInset = false; tap Canvas hoặc bắt đầu pan/pinch sẽ unfocus bàn phím để không ép layout hay đổi viewport.

## 8. Tối ưu hiệu năng

- `SeatMapPaintCache` chuẩn bị và tái sử dụng Paint cho từng trạng thái/opacity, Path, Rect/RRect, vị trí/geometry ghế và TextPainter cho nhãn/mã. Không tạo Paint hoặc TextPainter trong vòng lặp paint(); không dùng blur theo từng frame. TextPainter được dispose khi screen kết thúc.
- **Viewport Culling:** đổi khung nhìn sang World và bỏ qua ghế nằm ngoài cached cullBounds (đã chừa chỗ cho viền/mã/spotlight).
- **LOD:** chỉ hiện mã ghế khi `scale >= 1.35 * fitScale`; mã dùng font 9.0, letterSpacing = 0 để vừa ô VIP-C rộng 50 world units.
- Một CustomPainter vẽ toàn bộ bản đồ trong `RepaintBoundary`. `Listenable.merge([camera, mapState, spotlight])` kích hoạt repaint trực tiếp; pan/zoom không cần rebuild screen hoặc danh sách vé. Filter/sheet lắng nghe map state riêng.
- Spotlight dùng Paint cache và animation số; không tạo Paint/Path/TextPainter mới theo frame. paint() chỉ đọc snapshot, dùng số vô hướng để culling và các vòng lặp theo chỉ số; không khởi tạo Paint, Path, Shader, RRect, Rect, Offset, Color hoặc TextPainter trong mã paint(). Không dùng neon/blur; chỉ dùng hai shader ánh sáng kiến trúc champagne rất nhẹ, tạo trước trong cache.

Mục tiêu là tương tác mượt; **chưa đo/chứng nhận 60fps trên thiết bị thật**. Widget test và ảnh render không thay thế profile hiệu năng hoặc thử cảm giác gesture trên Android.

## 9. Kiểm tra thủ công trước khi nộp

1. Chọn hai ghế trống, bỏ một ghế; thử booked/locked. Đối chiếu số lượng/tổng VND và danh sách vé.
2. Pan/pinch đến min/max, thêm/bớt ngón trong gesture, tap ghế sau biến đổi và sát biên; không được chọn nhầm khi vừa kéo.
3. Mở sheet, cuộn danh sách dài, focus hàng Standard cuối, xóa dòng focus. Kéo sheet sau khi tự pan: camera không zoom/snap ngược.
4. Lọc khu/trạng thái, tìm VP-C hoặc ST-L05; giữ nguyên ticket khi đổi lọc. Thử query không khớp và nút xóa.
5. Reset khi đang zoom và có lọc/lựa chọn: camera về fit, ticket/query/bộ lọc giữ nguyên. Mở/đóng legend.
6. Xoay khi sheet mở và ghế focus; mở bàn phím tìm kiếm rồi tap/pan Canvas để ẩn. Kiểm tra không overflow hoặc mất điều khiển. Kiểm tra thêm cỡ chữ trợ năng trên thiết bị.

## 10. Video minh họa

**[Chèn link video demo 1–5 phút tại đây]**

Video nên thể hiện pan/pinch, chọn/bỏ ghế, sheet hai chiều, spotlight, lọc/empty state, Reset View giữ trạng thái và xoay màn hình. Placeholder chưa phải video đã quay.

## 11. Nhật ký sử dụng AI Agent

Agent sử dụng ở tất cả các mốc: **Codex**. Người thực hiện review mã, chạy thử trên thiết bị, quay video và commit. Nhật ký dưới đây ghi nhận lỗi/hạn chế thực tế, không coi kết quả sinh mã ban đầu là kết quả đã kiểm chứng.

| Mốc | Nhiệm vụ giao và phần mã sinh/sửa | Lỗi/hạn chế phát hiện, điều chỉnh và cách kiểm tra |
| --- | --- | --- |
| M1 | Codex tạo scaffold Android, Seat/ZoneSection/ConcertMockData, main, pubspec, ignore và test dữ liệu. | Scaffold thêm flutter_lints nên đã bỏ để giữ dependency SDK-only. Tên lint unused_local_variable không hợp lệ được loại khỏi cấu hình. Kiểm tra đúng mã/giá, 200 ghế, 124/52/24 và không chồng hình; analyze/test/build. |
| M2 | Codex sinh CameraTransform, CoordinateTransformer, ViewportClamper, HitTester và test/engine. | HitTester xung đột tên với flutter_test; sửa import bằng hide HitTester. Kiểm tra round-trip, focal-point giữ nguyên kể cả khi chạm giới hạn zoom, clamp, pan/zoom hit-test và biên. |
| M3 | Codex sinh paint cache, painter, screen và test renderer. | Ảnh test ban đầu dùng font hộp Ahem; sửa xuất ảnh trong runAsync và nạp font SDK để review. Bản screen ban đầu ghi camera.fit() trong LayoutBuilder mỗi rebuild; lỗi này được xác định và sửa ở M4. Kiểm tra 200 ghế, culling, LOD, trạng thái và ảnh fit/zoom. |
| M4 | Codex sinh CameraController, ConcertMapController, render snapshot, InteractiveSeatCanvas và controller/gesture tests. | Sửa LayoutBuilder ghi đè camera.fit(): fit lần đầu, cập nhật sau frame chỉ khi kích thước thực đổi. Chuyển scale tích lũy thành delta, rebase khi đổi số ngón. Test gesture thật, tọa độ cục bộ, không chọn booked/locked, giữ lựa chọn/camera khi rebuild và xoay. |
| M5 | Codex thêm SeatBottomSheet, selection totals/remove/clear/focus, animation/spotlight, edge clearance, nhãn 8 section và test sheet/state. | Kéo Bottom Sheet từng làm giật zoom/snap ngược camera vì viewport phụ thuộc chiều cao sheet. Sửa về viewport toàn Canvas, focus nhận bottomInset, pan tay tắt auto-refocus. Font 11 kế thừa letterSpacing 1.8 làm mã VP-C tràn ô; sửa font 9.0/spacing 0. Thêm snap khi thả tay nắm, tên khu đúng chữ hoa và summary ưu tiên ticket. Kiểm tra zero camera notifications khi kéo sheet, tâm focus có inset, giới hạn clamp khi xoay, danh sách 124 ghế và delete hai chiều. |
| M6 | Codex thêm FilterState, FilterSearchBar, LegendPanel, empty banner, eligibility và camera-only Reset View; sinh unit/widget tests. | Bàn phím ảo có thể đẩy/crush layout; đặt resizeToAvoidBottomInset=false, unfocus khi tap hoặc pan/pinch Canvas. Thêm highlight bộ lọc đang bật. Test keyboard insets dọc/ngang không đổi viewport, lọc không rơi lựa chọn, tap ghế mờ, reset giữ snapshot/query/ticket, đóng/mở legend và không RenderFlex overflow. |
| M7 | Codex viết lại README tiếng Việt, đối chiếu công thức/kiến trúc với mã thật, bổ sung ignore audit/preview và chạy kiểm chứng cuối. | Giữ nguyên tính năng và dependency. Audit/preview/build là dữ liệu cục bộ được ignore; không xóa bản audit của người dùng. Kết quả tự động được ghi dưới đây sau khi chạy; video, profile FPS và thử thiết bị vẫn cần người thực hiện hoàn tất. |

## 12. Vệ sinh repository và kết quả kiểm chứng cuối

Giữ `pubspec.lock`, `.metadata`, nguồn Android, icon launcher, test và tài liệu kế hoạch vì chúng thuộc dự án. Build/cache, cấu hình máy cá nhân, file `*_audit.txt` và ảnh preview tạm được ignore. Hai bản audit cục bộ có thể còn trên máy để tham khảo, không thuộc nội dung commit. Không bỏ qua toàn bộ PNG vì icon Android là tài nguyên nguồn cần thiết.

Các lệnh kiểm tra vệ sinh:

```sh
git status --short
git ls-files --others --exclude-standard
git ls-files -ci --exclude-standard
git diff --check
```

Kết quả chạy cuối ngày **25/11/2026** trên môi trường nêu ở mục 2:

| Lệnh | Kết quả thực tế | Exit code |
| --- | --- | ---: |
| `flutter analyze` | `No issues found! (ran in 7.6s)` | 0 |
| `flutter test` | `00:18 +51: All tests passed!` — 51/51 tests đạt | 0 |
| `flutter build apk --debug` | `Running Gradle task 'assembleDebug'... 11.5s`; `√ Built build\app\outputs\flutter-apk\app-debug.apk` | 0 |

Build có cảnh báo Java/Gradle native access (`WARNING: A restricted method in java.lang.System has been called`), nhưng kết thúc thành công; không thay cấu hình build để che cảnh báo.

Kiểm tra hygiene: `git ls-files --others --exclude-standard` và `git ls-files -ci --exclude-standard` không có output; không có APK/AAB/audit/preview tạm đang được theo dõi. `git check-ignore -v` xác nhận audit, build và ảnh preview bị ignore; icon launcher PNG vẫn được theo dõi. `git diff --check` đạt, chỉ có thông báo chuẩn hóa LF/CRLF trên Windows. M7 chỉ sửa README.md và .gitignore, không đổi mã nguồn hoặc dependency.

Video demo vẫn là placeholder theo yêu cầu. Kết quả tự động trên không xác nhận đã chạy thủ công trên thiết bị thật, cỡ chữ trợ năng hoặc đạt 60fps.
## 13. Thiết kế matte concert và sửa pinch landscape (25/11/2026)

Thiết kế mới theo brief poster concert: nền charcoal #0D0D0F, 65 chấm champagne-gold cục bộ cố định ở hai mép ngoài; bỏ khung arena bo góc và toàn bộ glow cyan. Sân khấu lục giác vát cạnh màu slate #5C606B có bevel phẳng #7A808E; catwalk mảnh (776..824), B-stage vát cạnh và FOH đều nằm ngoài bounds ghế. Các section có pad charcoal vát 45°, nhãn ivory 19 world units, w700, tracking 2.0 và mức chữ tối thiểu khi fit. Bảng màu hiển thị được quản lý trong ConcertPalette; colorArgb và tất cả dữ liệu nguồn ConcertMockData được giữ nguyên.

Ghế trống không có viền nhựa sáng; VIP giữ tựa lưng chìm. Selected là champagne-gold với viền trắng và check tối, booked chìm xuống nền than, locked dùng burgundy và dấu X đỏ. Ghế chọn không khớp lọc giữ alpha 0,45 và viền đứt vàng. Legend và ticket dùng cùng palette, hairline champagne và swatch màu/hình/ký hiệu tương ứng.

Canvas là Positioned.fill trong Stack toàn màn hình, không AppBar hoặc padding 12px quanh bản đồ/sheet. HUD portrait gồm tiêu đề, search pill và một hàng selector/count; HUD landscape gộp thành một hàng khoảng 46px. Badge dùng 200/200 để không cắt chữ ở 390px. Sheet portrait edge-to-edge; sheet landscape chỉ chiếm góc phải dưới (maxWidth 320), để hai ngón tay thao tác thoải mái ở bên trái/giữa. Bàn phím vẫn không resize Canvas; viewPadding thay vì keyboard-dependent padding giữ framing ổn định.

FramedViewport trong State kế thừa engine ViewportClamper, giữ tọa độ gesture theo toàn Canvas nhưng fit/reset theo phần không bị HUD/sheet che. Với T/B/R là inset trên/dưới/phải:

```text
fitScale = min((viewportWidth - R)/1600, (viewportHeight - T - B)/1200)
fit center = ((viewportWidth - R)/2, T + (viewportHeight - T - B)/2)
```

Portrait dùng B là sheet thu gọn + safe area; landscape dùng R=0 và B là khoảng hở sheet thu gọn 50px + safe area. Bản đồ mặc định căn giữa toàn chiều rộng để hai điểm chạm đối xứng Ctrl+drag của emulator rơi trên Canvas và hàng Standard cuối không bị che. Khi focus, y dùng T + (viewportHeight - T - bottomInset)/2; khi xoay, giữ tỷ lệ zoom và tâm của vùng framing nếu biên cho phép. Kéo sheet không đổi fitScale hay viewport. Reset chỉ đổi camera, giữ nguyên query/filter/ticket/focus.

Tất cả geometry trang trí, mã/nhãn và 8 biến thể Paint cho ghế (4 trạng thái × khớp/không khớp lọc) được tạo trong SeatMapPaintCache. Painter không tạo tài nguyên hình học/vẽ theo frame. Test mới xác nhận deco không giao bounds ghế, đủ 65 stardust dots, đủ 200 ghế nằm trong vùng framing, HUD ngang <=46px và chuỗi gesture hai ngón ở Size(844,390) tăng scale liên tục mà không bị dock/HUD chặn.

**Nhật ký Codex:** thay cache/painter, palette, legend, HUD/search, sheet, camera framing và UI tests. Đã sửa lỗi persistent sheet bị attach hai lần khi Canvas xuất hiện sau frame đầu bằng key ổn định cho dock; thu gọn hitbox icon để HUD thực sự <=46px; cập nhật các test UI theo vị trí overlay mới, palette và inset mới. Không sửa lib/data, lib/engine, test/data, test/engine hoặc dependency. Ảnh kiểm tra nằm trong build/matte-preview-390x844.png và build/matte-preview-844x390.png (được Git ignore). Chưa tuyên bố đã đo 60fps trên thiết bị thật.

Kiểm chứng bản matte: flutter analyze — 0 issues; flutter test — 54/54 passed (gồm 51 test hiện hữu và 3 test mới); flutter build apk --debug — thành công (27.0s). git diff xác nhận Data/Engine, test/data và test/engine cùng pubspec/lock không đổi. Đã kiểm tra ảnh portrait 390×844 và landscape 844×390. Emulator không kết nối tại thời điểm thử cài nên chưa xác nhận chạy bản matte trên thiết bị thật/emulator; có thể mở Pixel 7 rồi chạy flutter run để xem tương tác.
## 14. Độ tin cậy zoom và chiều sâu kiến trúc 2.5D

CameraController không còn chặn scale theo pointerCount>1: delta luôn lấy scale/lastScale khi hợp lệ. Một ngón pan có ratio=1; recognizer emulator/trackpad báo một pointer nhưng scale thay đổi vẫn zoom. Khung đổi số ngón chỉ rebase focal/scale, các khung tiếp theo tiếp tục zoom; quay scale tích lũy về 1 cũng đảo đúng phần zoom trước đó.

HUD ngang là pill Align(topCenter) ôm nội dung, hai góc trên trả chạm về Canvas. Sheet ngang dock phải, maxWidth=320, dùng DraggableScrollableSheet(expand:false) trong Align(bottomRight), thu gọn về minSize khi vừa xoay sang landscape. Các phần bao trong suốt không nhận hit ngoài card. Vị trí pill zoom lắng nghe extent qua notifier cập nhật sau frame để tránh setState-during-build; kéo sheet không mutate camera.

Hai ngón vẫn là cách zoom chính. Double-tap vùng trống animate 1.8× quanh điểm chạm, hoặc về fit nếu gần maxScale. Double-tap được nhận từ hai empty tap có timestamp/vị trí gần nhau, không trì hoãn tap chọn ghế. Pill +/- bên phải dùng cùng zoomTarget và bounds để animate quanh tâm viewport. PointerScrollEvent zoom quanh localPosition, áp dụng từng delta ngay để không làm mất các sự kiện wheel/trackpad liên tiếp. Các thao tác zoom giữ nguyên ticket/filter/query.

FOH được vẽ tại Rect.fromLTWH(745,782,110,36), tâm nhãn y=800, cách header STANDARD C ở y=850. Tám header dùng font19/w700, #D6D1C4; painter giữ một mức chữ tối thiểu để đọc được ở fit mà không đổi anchor của khu hay tọa độ ghế. Main Stage/Catwalk/B-stage/FOH có mặt đùn xuống 8 world units (#2A2D34) và bóng đất phẳng (#050507). VIP có lip5, Standard lip7 và đường bậc ngang giữa hàng. Hai cone ánh sáng champagne alpha khoảng0.05→0.0 dùng shader linear được tạo sẵn, không neon hoặc blur.

Mọi Path/Paint/Shader/offset cho hiệu ứng trên được tạo trong SeatMapPaintCache. Không đổi hình học Seat, ConcertMockData, phép Screen↔World, HitTester hay mã/test engine. Đây là chiều sâu giả lập bằng lớp vẽ 2D, không xoay/phối cảnh các ghế nên hit-testing cũ vẫn khớp.

**Nhật ký Codex:** bổ sung test scale với một pointer, transition1→2, pinch mô phỏng Ctrl+drag đối xứng quanh tâm844×390, hit-through vùng trên sheet/góc HUD, +/- clamp min/max, double-tap focal/reset, wheel và sheet thu gọn khi xoay. Trong kiểm tra đã sửa external AnimatedBuilder lắng nghe sheet gây setState khi build bằng cập nhật extent sau frame. Kiểm thử no-overlap và hình học hiện hữu tiếp tục chạy cùng suite. Thử FPS/gesture trên thiết bị thật vẫn là kiểm tra thủ công.

Kiểm chứng cuối: `flutter analyze` — `No issues found! (ran in 2.9s)`; `flutter test` — `00:06 +60: All tests passed!`; `flutter build apk --debug` — thành công, `assembleDebug` 18.3s (exit 0). Gradle vẫn có cảnh báo Java native access đã ghi ở M7. Đã xem ảnh render portrait 390×844 và landscape 844×390. `git diff --exit-code` xác nhận Data/Engine, các test tương ứng và pubspec/lock không đổi; không thêm dependency.

Đã cài APK mới lên emulator-5554 (Pixel 7), mở MainActivity và kiểm tra screenshot portrait hiển thị đúng. Pinch đối xứng landscape được xác minh bằng widget test nhiều pointer; chưa kiểm tra thao tác Ctrl+drag thủ công hoặc đo FPS trên thiết bị thật.

## 15. Ticket thu gọn, Minimap, Sightline và phản hồi thao tác

Chiều cao thu gọn dùng `(68 / size.height).clamp(0.07, 0.24)`. Danh sách được bọc `Opacity(0)` và `IgnorePointer` khi extent `<= minSize + 0.015`; hàng ghế, giá và nút xóa không còn lộ qua phần trống dưới summary. Khi mở sheet và có từ hai ghế, nút **Xóa tất cả** gọi `clearSelection()`, đồng thời xóa focus và cập nhật Canvas. Kéo sheet vẫn không thay đổi viewport hay camera.

**Minimap tương tác:** card matte 112×84, viền champagne, chỉ hiện qua `AnimatedOpacity` khi zoom lớn hơn 1,35× fit. Khi ẩn, `IgnorePointer` trả thao tác về Canvas. Minimap nằm bên trái phía trên sheet, theo chiều cao sheet để không che hàng vé. Painter riêng nghe `Listenable.merge([camera, mapController])`, tái sử dụng geometry stage/8 khu và Paint đã tạo sẵn; chấm vàng biểu diễn ghế đang chọn, khung vàng biểu diễn `visibleWorldRect` được cắt vào thế giới 1600×1200. Chạm animate camera 300ms tới tâm World tương ứng; kéo cập nhật trực tiếp. Cả hai dùng bounds cũ và dừng animation/auto-refocus; không thay đổi selection, filter hoặc focus đã lưu.

**Sightline khi focus:** nối ghế được chọn với Main Stage `(800,140)` bằng nét đứt champagne alpha55%, stroke1,5 screen px. Segment được tính bằng khoảng cách đơn giản, lưu vào Path dùng lại khi đổi ID focus. Nhãn matte ngay trên ghế ghi khoảng cách mô phỏng `round(distanceWorld × 0.04)` mét; góc so với trục hướng sân khấu <=15° là “Chính diện”, còn lại “Cánh trái/phải”. Một TextPainter duy nhất được layout lại khi đổi focus, không tạo Paint/TextPainter trong paint(). Đây là thông tin mô phỏng hình học, không phải khoảng cách hoặc đánh giá tầm nhìn của sân vận động thật.

**Phản hồi SDK:** chọn/bỏ ghế, xóa vé và nút +/−/Reset gọi `HapticFeedback.selectionClick()`; chạm ghế đã đặt/đang khóa gọi `lightImpact()`. Badge cạnh cụm zoom hiển thị `scale / fitScale` (ví dụ `2.1×`) khi tỷ lệ ngoài `[0.95,1.05]`. Độ rung thực tế tùy phần cứng/cài đặt; test kiểm tra lời gọi platform channel, không khẳng định emulator tạo rung vật lý.

**Nhật ký Codex:** sửa camera target, screen, ticket sheet, Canvas gesture/cache/painter; thêm `seat_map_minimap.dart`, `camera_zoom_controls.dart`, test sheet/minimap/haptic/cache. Đã phát hiện điểm double-tap của test cũ nằm trên minimap mới và chuyển điểm thử ra Canvas trống; sửa fixture “Chính diện” dùng ghế gần trục sân khấu thay vì ghế đầu của STANDARD C vốn lệch trái. Nhãn khoảng cách đặt trên ghế thay vì midpoint để không ra khỏi màn hình khi zoom cao. Không sửa dữ liệu ghế, engine tọa độ/hit-test hoặc dependency.

Kiểm chứng: `flutter analyze` — `No issues found! (ran in 4.1s)`; `flutter test` — `00:20 +66: All tests passed!`; `flutter build apk --debug` — thành công, `assembleDebug` 17.1s, cả ba exit 0. Đã xem ảnh sheet thu gọn/mở ở portrait và landscape, cùng ảnh sightline/minimap/badge. Kiểm tra lại font Roboto cho nút “Xóa tất cả” sau khi ảnh test dùng font thay thế. Ảnh nằm trong build/polish-*.png, được ignore; Data/Engine và các test tương ứng cùng pubspec/lock không đổi.
