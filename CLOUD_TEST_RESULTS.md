# Kết quả kiểm thử Cloud

## Kiểm thử tự động

Ngày 22/10/2026: flutter analyze không có lỗi; flutter test đạt 35/35 bài.
flutter build web --debug: biên dịch thành công (bao gồm Wasm dry run).
RLS: chưa chạy (máy hiện chưa có Supabase CLI/Docker/Postgres). Bộ SQL có 18 ca.
Khi có môi trường: supabase start, supabase db reset, supabase test db.
SQL mô phỏng ba danh tính, không thay thế đăng nhập Google và Storage thực tế.

## Ba tài khoản Google sau triển khai

Chưa thực hiện. Cần bật Google Auth, Storage, Firestore, triển khai Rules và mọi
migration; bật Firebase Third-Party Auth trong Supabase.
Dùng ba hồ sơ Chrome riêng, nhấn Làm mới sau thay đổi quyền.
A/B/C: ba tài khoản Google khác nhau.

| Bước | Thao tác | Kỳ vọng | Kết quả thực tế |
|---|---|---|---|
| 1 | A/B/C đăng nhập Google | Ba UID/email đúng trong users | Chưa chạy |
| 2 | A tải PDF, tìm theo tên/mô tả | Tệp trên Storage, một dòng SQL | Chưa chạy |
| 3 | B/C tìm, tải bằng đường dẫn đã biết khi chưa có quyền | Metadata ẩn, SDK từ chối tải | Chưa chạy |
| 4 | A cấp editor cho B | B xem, tải, sửa metadata | Chưa chạy |
| 5 | B chia sẻ, xóa, đổi owner/path trực tiếp qua API | Bị từ chối | Chưa chạy |
| 6 | A cấp viewer cho C | C xem/tải; không sửa/chia sẻ/xóa | Chưa chạy |
| 7 | A hạ B xuống viewer | B không sửa được qua API | Chưa chạy |
| 8 | A thu hồi C | Metadata ẩn, SDK từ chối tải mới | Chưa chạy |
| 9 | A đăng xuất, B đăng nhập cùng tab | Không hiện dữ liệu riêng của A | Chưa chạy |
| 10 | C đăng ký email của A trong users | RLS từ chối | Chưa chạy |

Thu hồi quyền không thể xóa bản sao người nhận đã tải trước đó.
Ghi UID/email, thời gian và ảnh kết quả thực khi nộp bài.
