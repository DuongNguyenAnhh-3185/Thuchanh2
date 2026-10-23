# Kiểm tra và triển khai TH2 — CashewDoc

Ứng dụng trong thư mục `th2final` dùng Firebase Authentication/Messaging và Supabase Database/Storage. Đã cấu hình mặc định project `oemlhoqptgrgtwaozmgu` bằng publishable key do người dùng cung cấp; có thể ghi đè bằng `--dart-define`. Không cần truyền anon JWT cũ vào Flutter.

## Đối chiếu yêu cầu

| Yêu cầu | Mã nguồn / hành vi đã triển khai |
|---|---|
| Kiến trúc hybrid | Firebase UID/ID token cho Supabase Third-party Auth; hồ sơ `users`; RLS kiểm tra issuer, audience và UID. Storage bucket `documents` riêng tư. |
| Flutter Mobile/Web | Thư viện SQLite, form thêm/sửa, giao diện danh sách responsive; menu Cloud thu gọn; sửa tràn footer thẻ tài liệu. |
| Tag | Thêm/sửa tag, lọc local, tìm kiếm Cloud/catalog theo tag; bảng `tags`, `document_tags` được đồng bộ trong transaction SQL. |
| Vị trí | Mô tả vị trí, cặp tọa độ có validation, bảng `document_locations`; bản đồ OpenStreetMap trong Flutter khi có tọa độ. Địa chỉ không có tọa độ mở tìm kiếm trên OpenStreetMap. |
| Mượn/chia sẻ | Chủ tài liệu mở cho mượn; người khác gửi yêu cầu; chủ chấp nhận/từ chối; cấp viewer khi chấp nhận. Chia sẻ viewer/editor qua email; thu hồi quyền đồng thời chặn các lần đọc/tải mới bằng RLS. |
| Recommendation | Local: tag của tài liệu đã học, trọng số 3, cộng mức trùng môn học. Cloud: tag sở thích trọng số 3; tag tài liệu sở hữu trọng số 1; lịch sử tải trong 90 ngày và mượn đã duyệt trọng số 2. Catalog sắp theo điểm rồi thời gian; chưa có sở thích dùng tài liệu mới nhất. |
| Realtime / Messaging | Subscribe documents/permissions/borrow_requests bằng Firebase JWT. Re-query sau event/reconnect; kiểm tra quyền lại mỗi 15 giây để xử lý cả thu hồi quyền. FCM qua Edge Function đã kiểm tra chữ ký Firebase token; lỗi push không biến nghiệp vụ đã commit thành thất bại. |

## Khác biệt cần phản ánh trong báo cáo

- `documents.tags` và trường vị trí là API ghi tương thích với giao diện hiện tại. Trigger tạo các bảng quan hệ tương ứng trong cùng transaction. Đây là các bản chiếu có kiểm soát, không tuyên bố toàn bộ schema chỉ lưu một bản sao đạt 3NF.
- Token FCM nằm trong `device_tokens`, hỗ trợ nhiều thiết bị và chuyển token khi đổi tài khoản trên cùng trình duyệt; không dùng mảng token công khai trong hồ sơ.
- Upload tối đa 25 MB. Metadata được tạo trước để Storage RLS xác minh chủ sở hữu; lỗi upload có cơ chế bù trừ. Database và Object Storage không có transaction chung. Chưa triển khai TUS resumable upload.
- Đăng nhập hiện dùng Google qua Firebase. Các trường hạn trả/trả thực tế trong bản đặc tả chưa có luồng giao diện trả sách; nghiệp vụ mượn hiện cấp quyền truy cập số sau duyệt.
- Có bản đồ marker cho từng tài liệu; chưa triển khai tự lấy GPS hoặc tìm tài liệu gần nhất. Chưa có cấu hình Firebase/iOS trong repository.

## Chạy ứng dụng

```powershell
cd D:\adrstu\th2final
flutter pub get
.\run.bat
```

Hoặc `flutter run -d chrome`. Dữ liệu local hoạt động trước khi hoàn tất triển khai Cloud.

## Hoàn tất Cloud trên project đã cung cấp

1. Mở Supabase SQL Editor của `oemlhoqptgrgtwaozmgu`, rà soát và chạy toàn bộ `supabase_setup.sql`. Script được tạo từ các migration bởi `node scripts/build_setup.cjs`; giữ bảng/dữ liệu hiện có, không có DROP TABLE hoặc xóa dữ liệu người dùng. Sao lưu database trước khi áp dụng thay đổi schema. Các đường dẫn Storage cũ không theo dạng `documents/<uid>/<uuid>/<filename>` cần được đối soát riêng.
2. Supabase Authentication → Third-Party Auth → Firebase: thêm `device-streaming-33cac12e`. Bật Google Sign-in trên Firebase, thêm `localhost` vào Authorized domains; Android cần SHA-1/SHA-256.
3. Muốn có push thật: làm theo `CLOUD_SETUP.md` để triển khai `send-cloud-notification`, lưu Firebase service account trong secrets và truyền Web VAPID key. Publishable/anon key không có quyền triển khai schema, cấu hình Auth hoặc gửi FCM.

## Kết quả xác minh ngày 24/10/2026

- `flutter analyze --no-pub`: không có lỗi.
- `flutter test`: 41 bài đạt; bao gồm render thư viện 360×800 và 1440×900, validation/vị trí, CRUD, phân lớp, gợi ý.
- `flutter build web --release --no-pub`: thành công.
- `node scripts/smoke_web.cjs`: bản Web release khởi động trong Chrome headless, hiển thị CashewDoc, không có uncaught runtime exception; ảnh `build/web-verification/desktop.png`, `mobile.png`.
- `node scripts/verify_database.cjs`: 25 kiểm tra PostgreSQL WASM đạt; bao gồm chạy SQL mới, chạy lại, nâng cấp schema trong bản đặc tả, RLS ba người dùng, mượn, thu hồi, Storage, token thiết bị, gợi ý và chặn danh tính rỗng.
- API Supabase online truy cập được; kiểm tra chỉ đọc phát hiện chưa có API cho `permissions`, `device_tokens`, `document_locations`. Chưa áp dụng SQL online, chưa xác minh đăng nhập ba tài khoản Google thật, push FCM thật hoặc tải lên/tải xuống Storage online.
- Máy hiện không có Android SDK; chưa build APK hoặc chạy trên thiết bị Android. Flutter doctor đã xác nhận có Chrome và Flutter 3.47.2 / Dart 3.13.2.

Để chạy lại kiểm tra database cục bộ, không cần Docker/Postgres:

```powershell
npm.cmd install --prefix build/sql-verification --no-audit --no-fund @electric-sql/pglite
node scripts/verify_database.cjs
```

PostgreSQL WASM mô phỏng role/schema Auth/Storage của Supabase để kiểm tra SQL. Nó không thay thế kiểm thử dịch vụ Supabase Realtime, Firebase và Storage thật.
