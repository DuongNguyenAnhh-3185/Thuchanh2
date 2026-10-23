# Kịch bản demo CashewDoc

CashewDoc dùng Firebase Authentication và Firebase Cloud Messaging; metadata,
phân quyền và file Cloud được lưu bằng Supabase Postgres/Storage. SQLite local
vẫn dùng được khi không có mạng hoặc chưa cấu hình Cloud.

## Chuẩn bị

1. Bật Google provider và Firebase Cloud Messaging cho Firebase project.
2. Cấu hình Supabase Third-Party Auth với Firebase project ID.
3. Chạy toàn bộ `supabase/migrations/` theo thứ tự.
4. Deploy Edge Function và cấu hình VAPID/service-account secrets theo
   [CLOUD_SETUP.md](CLOUD_SETUP.md).
5. Chạy `flutter run -d chrome` với `SUPABASE_URL`,
   `SUPABASE_PUBLISHABLE_KEY` và `FCM_WEB_VAPID_KEY`.

Không đưa publishable key dạng secret, service-role key, Firebase service-account
JSON hay thông tin đăng nhập vào mã nguồn/tài liệu demo. Chỉ sử dụng tài khoản
kiểm thử do nhóm sở hữu.

## Luồng demo

### 1. Thư viện cá nhân, tag, vị trí và gợi ý

1. Thêm một tài liệu cục bộ, đặt tag và vị trí hoặc tọa độ.
2. Đánh dấu một tài liệu là hoàn thành.
3. Kiểm tra gợi ý tài liệu chưa hoàn thành có tag/môn học tương đồng.
4. Mở chi tiết tài liệu và dùng nút bản đồ để xem vị trí trên OpenStreetMap.

### 2. Cloud, chia sẻ và mượn tài liệu

1. Mở **Đám mây Firebase**, đăng nhập tài khoản A và tải tệp lên.
2. Gắn tag/vị trí và bật **Cho phép người khác yêu cầu mượn**.
3. Đăng nhập tài khoản B, mở danh mục cho mượn và gửi yêu cầu.
4. Đăng nhập lại A, chấp nhận yêu cầu; B được quyền xem/tải tệp.
5. Kiểm tra thông báo đẩy nếu người nhận đã cấp quyền notification và FCM
   service đã được triển khai.
6. Thu hồi quyền chia sẻ và xác nhận người nhận không còn đọc được metadata
   hoặc file.

## Kiểm tra phân quyền

Chạy kiểm thử database:

```powershell
supabase start
supabase db reset
supabase test db
```

`supabase/tests/database/rls_3_users_test.sql` kiểm tra ba Firebase UID giả lập,
quyền owner/editor/viewer, mượn tài liệu, bucket riêng tư và token thiết bị.
Kiểm thử này không thay thế cho kiểm thử Google Sign-In/FCM trên Firebase đã
triển khai.

