# Kết quả kiểm thử TH2

Bản ghi hiện tại ngày 24/10/2026 nằm tại [TH2_STATUS.md](TH2_STATUS.md).

- Flutter test: 41 bài đạt.
- Flutter analyzer: không có lỗi.
- Web release: build thành công; smoke test Chrome headless thành công ở Desktop/Mobile.
- PostgreSQL WASM: 25 kiểm tra schema/RLS/nghiệp vụ đạt. Đây là môi trường cục bộ mô phỏng Auth/Storage, không phải Supabase online.
- API Supabase project mới truy cập được. Chưa triển khai SQL bằng quyền quản trị; chưa kiểm thử ba tài khoản Google, FCM hoặc Storage thực tế.
- Android: chưa có SDK nên chưa build APK.

Sau khi chạy supabase_setup.sql và bật Firebase Third-Party Auth, dùng ba tài khoản riêng để kiểm tra tải lên, chia sẻ editor/viewer, mượn, duyệt/từ chối, Realtime và thu hồi quyền. Thông báo FCM cần Edge Function/secrets/VAPID như CLOUD_SETUP.md. Ghi nhận kết quả thực trước khi nộp bài.
