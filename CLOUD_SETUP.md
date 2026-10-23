# Thiết lập Cloud cho CashewDoc

Ứng dụng kết hợp **Firebase Authentication và Firebase Cloud Messaging** với
**Supabase Postgres và Supabase Storage**. SQLite vẫn là thư viện local mặc định,
hoạt động offline và không cần cấu hình Cloud.

## 1. Firebase Authentication và Messaging

Project Firebase hiện cấu hình trong ứng dụng: `device-streaming-33cac12e`.

1. Bật **Authentication > Sign-in method > Google**.
2. Bật **Cloud Messaging API (V1)** cho project.
3. Với Android, thêm SHA-1/SHA-256 của keystore cho các bản build sử dụng.
4. Với Web, tạo Web Push certificate trong **Cloud Messaging > Web configuration**
   và truyền public VAPID key bằng `FCM_WEB_VAPID_KEY`.
5. Tệp `web/firebase-messaging-sw.js` là service worker hiển thị thông báo khi
   ứng dụng Web ở nền. Trình duyệt cần HTTPS hoặc localhost và quyền notification.

Không đưa Firebase service-account JSON, private key, Supabase service-role key
hoặc OAuth client secret vào ứng dụng hay repository.

## 2. Supabase Database và Storage

1. Project mặc định: `https://oemlhoqptgrgtwaozmgu.supabase.co`. Publishable key đã có trong cấu hình; có thể ghi đè bằng `--dart-define`.
2. Vào **Authentication > Third-Party Auth > Firebase**, thêm Firebase Project ID
   `device-streaming-33cac12e`.
3. Với project đang có bảng theo báo cáo, chạy toàn bộ `supabase_setup.sql` trong SQL Editor. Script tương thích schema cũ và đã được kiểm tra chạy lại. Với môi trường quản lý migration bằng CLI, dùng:

   ```powershell
   supabase link --project-ref <project-ref>
   supabase db push
   ```

   Các migration tạo schema/RLS cho users, documents, sharing, tags, vị trí,
   yêu cầu mượn, bucket Storage riêng tư và token thiết bị. Storage RLS cấp quyền
   đọc cho chủ sở hữu/người được chia sẻ; tệp không có public URL.
4. Truyền Supabase URL và publishable key khi chạy Cloud:

   ```powershell
   flutter run -d chrome `
     --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
     --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key> `
     --dart-define=FCM_WEB_VAPID_KEY=<web-push-vapid-key>
   ```

   Trên Android, bỏ `-d chrome`; `FCM_WEB_VAPID_KEY` chỉ cần cho Web.

Firebase ID token được gửi cho Supabase Third-Party Auth. RLS xác nhận issuer,
audience và Firebase UID; `service_role` key tuyệt đối không được dùng trong app.

## 3. Gửi thông báo đẩy an toàn

Function `supabase/functions/send-cloud-notification` xác minh Firebase ID token,
kiểm tra người gọi có liên quan tới yêu cầu/chia sẻ, rồi gửi thông báo qua FCM
HTTP v1. Function đặt `verify_jwt = false` trong Supabase config vì token của app
là Firebase JWT; function tự xác minh chữ ký, issuer, audience và email đã xác
thực.

Trong Firebase Console, tạo service account riêng có quyền gửi FCM. Lưu JSON
service-account bằng Supabase secrets, không commit file JSON:

```powershell
supabase secrets set FIREBASE_PROJECT_ID=device-streaming-33cac12e
supabase secrets set FIREBASE_SERVICE_ACCOUNT='<service-account-json>'
supabase functions deploy send-cloud-notification --no-verify-jwt
```

`SUPABASE_URL` và `SUPABASE_SERVICE_ROLE_KEY` được cung cấp cho Edge Function
trong môi trường Supabase. Service-role key không được truyền đến Flutter.
Push token được lưu theo UID, có RLS riêng, và được chuyển sang tài khoản đang
đăng nhập lại trên cùng thiết bị.

Nếu Function/secrets chưa được triển khai, Cloud metadata vẫn hoạt động; UI báo
riêng khi một thao tác đã lưu thành công nhưng push notification không được gửi.
Thông báo trên Web không hoạt động nếu thiếu VAPID key hoặc người dùng từ chối
quyền trình duyệt.

## 4. Chạy và kiểm thử

Chạy local:

```powershell
flutter pub get
flutter run -d chrome
```

Cấu hình Supabase mặc định đã có. Trên Windows chạy `run.bat`; script tôn trọng biến môi trường ghi đè và truyền thêm `FCM_WEB_VAPID_KEY` nếu có. Cloud vẫn cần triển khai SQL và bật Third-Party Firebase Auth như mục 2.

Kiểm thử:

```powershell
flutter test
flutter analyze
supabase start
supabase db reset
supabase test db
```

SQL RLS tests nằm trong `supabase/tests/database/rls_3_users_test.sql` và kiểm
tra quyền theo ba Firebase UID, catalog/borrow, bucket riêng tư và token thiết
bị. Build Web release bằng `flutter build web --release`.

| Tài khoản | Thao tác | Kết quả mong đợi |
|---|---|---|
| Alice | Tải tài liệu, mở cho mượn và chia sẻ với Bob | Metadata và tệp nằm trong Supabase; Bob nhận quyền theo RLS |
| Bob | Tìm/mượn tài liệu Alice | Chỉ thấy catalog công khai; chủ sở hữu nhận push nếu đã đăng ký |
| Alice | Chấp nhận yêu cầu mượn | Bob được cấp viewer; Bob nhận thông báo trạng thái |
| Carol | Mở tài liệu chưa được chia sẻ | Không đọc được metadata hay tệp |

Firebase Google Sign-In được cấu hình cho Android/Web. Windows desktop Cloud
không hỗ trợ Google Sign-In/FCM; dùng Web trên Chrome để chạy đầy đủ luồng Cloud.

## 5. Tag, vị trí, Realtime và gợi ý

Xem `TH2_STATUS.md` để đối chiếu triển khai thực tế với bản đặc tả. Menu Cloud → Tag sở thích để lưu chủ đề; Khám phá & gợi ý tài liệu để xem catalog xếp hạng. Tọa độ mở bản đồ trong ứng dụng. Các migration 202610240003–202610240005 bổ sung publication Realtime, bảng quan hệ/thuật toán gợi ý và kiểm tra token rỗng.

Tài liệu chính thức: [Firebase Third-Party Auth](https://supabase.com/docs/guides/auth/third-party/firebase-auth), [Supabase Postgres Changes](https://supabase.com/docs/guides/realtime/postgres-changes), [flutter_map](https://docs.fleaflet.dev/usage/options).
