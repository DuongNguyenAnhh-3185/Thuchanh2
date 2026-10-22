# Thiết lập Cloud cho CashewDoc

Ứng dụng dùng Firebase Authentication làm nguồn danh tính, Firebase Storage giữ
tệp vật lý và Supabase Postgres giữ `users`, `documents`, `permissions`. RLS trên
Supabase kiểm tra trực tiếp Firebase ID token. Firestore chỉ chứa bản sao ACL tối
thiểu để Firebase Storage Rules có thể kiểm tra quyền đọc tệp; không lưu metadata
nghiệp vụ trong Firestore.

Khi mở ứng dụng, màn hình mặc định là không gian Cloud: đăng nhập Google bằng
Firebase rồi xem danh sách tài liệu có metadata lấy từ Supabase. Dữ liệu SQLite
cục bộ vẫn được giữ riêng và mở qua biểu tượng kho lưu trữ trên thanh tiêu đề;
không trộn dữ liệu mẫu SQLite vào danh sách Supabase.

## 1. Firebase

Project đã được cấu hình trong mã nguồn là `device-streaming-33cac12e`.

1. Trong Firebase Console, bật **Authentication > Sign-in method > Google**.
2. Thêm SHA-1 và SHA-256 của debug/release keystore cho ứng dụng Android.
3. Tạo Cloud Firestore ở Production mode và bật Firebase Storage.
4. Triển khai Rules:

   ```bash
   firebase login
   firebase use device-streaming-33cac12e
   firebase deploy --only firestore:rules,storage
   ```

Không dùng Firebase download URL công khai. Ứng dụng đọc tệp qua Firebase SDK,
để `storage.rules` luôn kiểm tra người dùng hiện tại.

## 2. Firebase JWT và Postgres role

Firebase ID token mặc định không có custom claim `role`. Supabase ánh xạ request
này vào Postgres role `anon`; migration cấp quyền tối thiểu cho role đó và RLS
restrictive tiếp tục bắt buộc `iss`, `aud` và `sub` thuộc đúng Firebase project.
Request chỉ có publishable key nhưng không có Firebase JWT sẽ bị từ chối.

Vì vậy không cần triển khai thư mục `functions` hay bật Identity Platform chỉ để
thêm claim `role=authenticated`.

## 3. Supabase

1. Tạo một Supabase project.
2. Vào **Authentication > Third-Party Auth > Firebase**, thêm Firebase Project ID
   `device-streaming-33cac12e`.
3. Chạy file migration
   **tất cả file trong supabase/migrations/ theo thứ tự tên** trong SQL Editor, hoặc:

   ```bash
   supabase link --project-ref <project-ref>
   supabase db push
   ```

Migration tạo ba bảng, khóa ngoại, index, RPC chia sẻ/thu hồi và toàn bộ RLS.
Publishable key có thể đặt ở client; tuyệt đối không đưa `service_role` key vào app.

## 4. Chạy ứng dụng

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Trên PowerShell:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

## 5. Kiểm thử ba tài khoản

Bộ kiểm thử RLS tự động nằm tại
`supabase/tests/database/rls_3_users_test.sql`:

```bash
supabase start
supabase db reset
supabase test db
```

Kiểm thử thực tế sau khi deploy:

| Tài khoản | Thao tác | Kết quả mong đợi |
|---|---|---|
| Alice | Tải tài liệu và chia sẻ `editor` cho Bob | Alice thấy quyền của Bob |
| Bob | Tìm, tải và sửa tiêu đề tài liệu Alice | Thành công; không thể chia sẻ/xóa |
| Carol | Mở tài liệu trước khi được chia sẻ | Không thấy metadata và không tải được tệp |
| Alice | Chia sẻ `viewer` cho Carol | Carol thấy và tải được nhưng không sửa được |
| Alice | Thu hồi quyền Carol | Carol mất quyền metadata lẫn tệp ngay lập tức |

Chạy thêm kiểm thử Flutter:

```bash
flutter test
flutter analyze
```

## Lưu ý nền tảng

Google Sign-In chính thức hỗ trợ Android, iOS, macOS và Web. Với Windows, chạy
bản Web (`flutter run -d chrome`) hoặc bổ sung OAuth desktop broker riêng; không
nhúng OAuth client secret vào ứng dụng Flutter.

## 6. Bổ sung triển khai và kiểm thử

Dùng tài khoản Google A để thử; quyền trong app luôn dựa vào UID/email đã xác
thực, không hardcode email quản trị.

Trên Windows chạy run.bat ở thư mục gốc: script tải dependencies và chạy Chrome
cổng 7357. Cung cấp key qua biến môi trường `SUPABASE_PUBLISHABLE_KEY` hoặc nhập
khi được hỏi; không lưu key vào script. Có thể dùng run.bat --release.
Thêm localhost vào Firebase Authentication > Settings > Authorized domains.

Migration 202610220001_identity_and_storage_integrity.sql bắt buộc email đã xác
thực khớp JWT và đường dẫn khớp owner/UUID. Constraint được tạo NOT VALID để
không chặn dữ liệu cũ, vẫn kiểm tra mọi dòng mới/cập nhật. Đối soát đường dẫn cũ
rồi chạy ALTER TABLE public.documents VALIDATE CONSTRAINT documents_storage_path_matches_identity.

Storage Rules đối chiếu chủ ACL với UID trên đường dẫn. Tệp không được ghi đè;
editor chỉ sửa tiêu đề/mô tả. Không dùng download URL chứa token.

Firebase và Supabase không có transaction chung. Nếu ghi ACL thất bại, app hoàn
tác SQL về quyền cũ. Nếu thu hồi SQL thất bại, app giữ quyền tải tệp bị chặn và
yêu cầu thử lại. Nếu cả thao tác và hoàn tác lỗi, mở lại danh sách quyền và thử
lại. Kiểm thử Google/Storage thực theo CLOUD_TEST_RESULTS.md trước khi nộp bài.

Tham khảo chính thức:
- https://supabase.com/docs/guides/auth/third-party/firebase-auth
- https://firebase.google.com/docs/storage/security/rules-conditions

## 7. Tải tệp trên Web (CORS)

Nếu trình duyệt báo lỗi CORS khi tải tệp, quản trị dự án cấu hình bucket bằng
Google Cloud CLI (đăng nhập tài khoản quản trị dự án):

    gcloud auth login
    gcloud storage buckets update gs://device-streaming-33cac12e.firebasestorage.app --cors-file=storage.cors.json

File CORS cho phép hai origin local cổng 7357 dùng bởi run.bat; khi triển khai
Web thật, bổ sung origin HTTPS của ứng dụng. CORS không cấp quyền truy cập tệp;
Storage Rules vẫn kiểm tra Firebase Authentication và ACL.
