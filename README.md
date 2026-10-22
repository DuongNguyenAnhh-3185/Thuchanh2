# 📚 CashewDoc - Ứng Dụng Quản Lý Tài Liệu Học Tập (Kiến Trúc Cashew)

> Hướng dẫn triển khai Firebase Auth/Storage, Supabase và RLS: [CLOUD_SETUP.md](CLOUD_SETUP.md)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Cashew%20Clean%20Architecture-brightgreen.svg)](#kiến-trúc-cashew)
[![Tests](https://img.shields.io/badge/Tests-33%2F33%20Passed-success.svg)](#kiểm-thử-chất-lượng)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows-lightgrey.svg)](#đóng-gói-ứng-dụng)

Dự án thực hành môn **Lập trình Thiết bị Di động** - Xây dựng ứng dụng quản lý tài liệu học tập cá nhân theo chuẩn **kiến trúc phần mềm mã nguồn mở Cashew** (Clean Architecture, Offline-First, Reactive Stream, Soft-Delete & Độc lập Tầng).

---

## 📑 Báo Cáo & Tài Liệu Kèm Theo
- ☁️ **Báo cáo phân tích hệ thống & Lập phương án tích hợp Cloud (Word .docx)**: [phan_tich_va_lap_phuong_an.docx](phan_tich_va_lap_phuong_an.docx)
- 📘 **Báo cáo giải trình chuyên sâu kiến trúc Cashew (Word .docx)**: [Bao_Cao_Giai_Trinh_Kien_Truc_Cashew.docx](Bao_Cao_Giai_Trinh_Kien_Truc_Cashew.docx)
- 📄 **Báo cáo giải trình chuyên sâu kiến trúc Cashew (Markdown .md)**: [Bao_Cao_Giai_Trinh_Kien_Truc_Cashew.md](Bao_Cao_Giai_Trinh_Kien_Truc_Cashew.md)
- 📘 **Báo cáo thuyết minh đồ án tổng hợp (5 Bước hoàn chỉnh Word .docx)**: [TH1.docx](TH1.docx)
- 📊 **Phân tích yêu cầu & Thiết kế DFD**: [Buoc1_Phan_Tich_Yeu_Cau_Va_Thiet_Ke_DFD.md](Buoc1_Phan_Tich_Yeu_Cau_Va_Thiet_Ke_DFD.md)

---

## 🏛️ Tổng Quan Kiến Trúc Cashew Trong Dự Án

Dự án kế thừa và chuẩn hóa 5 triết lý kiến trúc cốt lõi từ dự án mã nguồn mở **Cashew** (Personal Finance App):

```
       [ PRESENTATION LAYER (Giao diện & Tương tác) ]
     UI Screens | Reusable Widgets | Provider & StreamBuilder
                           │
                           ▼
          [ DOMAIN LAYER (Nghiệp vụ cốt lõi) ]
         Use Cases | Business Rules | Validation
                           │
                           ▼
          [ SERVICES LAYER (Điều phối ứng dụng) ]
   DocumentService | SubjectService | SearchService (Reactive Streams)
                           │
                           ▼
           [ DATA LAYER (Truy xuất & CSDL) ]
Repositories | SQLite DB (CashewDatabase) | Models & Entities
```

### 5 Nguyên Tắc Kiến Trúc Nổi Bật:
1. **Offline-First & Local Persistence**: Toàn bộ dữ liệu nằm tại SQLite cục bộ thiết bị thông qua `sqflite`.
2. **Khóa chính toàn cục UUID v4**: Mọi thực thể (`Document`, `Subject`, `Attachment`, `DeleteLog`) sử dụng chuỗi UUID ngẫu nhiên 128-bit làm định danh bất biến, triệt tiêu xung đột ID.
3. **Phản ứng thời gian thực (Reactive Stream Architecture)**: Sử dụng Dart `StreamController.broadcast()` trong Service; khi dữ liệu thay đổi (Thêm, Sửa, Xóa, Lọc), các màn hình UI tự động render lại tức thì không cần gọi reload thủ công.
4. **Xóa mềm (Soft-Delete) & Bảng ghi vết (DeleteLogs)**: Bản ghi bị xóa sẽ cập nhật `is_deleted = 1` và tự động ghi một bản ghi vào bảng `delete_logs`. Hỗ trợ Thùng rác (Recycle Bin), khôi phục (Restore) và sẵn sàng cơ chế đồng bộ 2 chiều (Bidirectional Sync Engine).
5. **Phân rã đơn trách nhiệm (Single Responsibility Principle)**: Giải quyết dứt điểm phản mẫu (Anti-pattern) tập trung logic vào một file CSDL khổng lồ, phân tách rõ ràng thành 4 tầng riêng biệt.

---

## 📂 Cấu Trúc Thư Mục Chuẩn Hóa

```
lib/
├── core/                       # Thành phần dùng chung toàn ứng dụng
│   ├── constants/              # Bảng màu, typography, enum (DocumentType, Status)
│   ├── database/               # Khởi tạo SQLite, migrations, định nghĩa bảng CSDL
│   └── utils/                  # Hàm sinh UUID v4, định dạng ngày tháng, kích thước tệp
├── data/                       # Tầng dữ liệu (Data Layer)
│   ├── datasources/            # Truy vấn SQLite thô CRUD
│   ├── models/                 # Model ánh xạ DB (toMap / fromMap)
│   └── repositories/           # Triển khai Repository pattern
├── domain/                     # Tầng nghiệp vụ (Domain Layer)
│   ├── entities/               # Entity thuần Dart (Document, Subject, Attachment)
│   └── repositories/           # Interface trừu tượng Repository
├── services/                   # Tầng dịch vụ (Services Layer)
│   ├── document_service.dart   # Nghiệp vụ tài liệu & Broadcast Stream
│   ├── subject_service.dart    # Nghiệp vụ môn học & Broadcast Stream
│   └── search_service.dart     # Tìm kiếm đa tiêu chí, sắp xếp, lọc
└── presentation/               # Tầng giao diện (Presentation Layer)
    ├── screens/                # Màn hình chính, thêm/sửa, chi tiết, thùng rác
    └── widgets/                # Card tài liệu, thanh lọc môn học, upload file
```

---

## 🧪 Kiểm Thử Chất Lượng (Unit Tests & Layer Isolation)

Dự án sở hữu bộ kiểm thử tự động toàn diện đạt tỷ lệ vượt qua **100% (33/33 Test Cases)**:

### 1. Bước 3: Core Functions Test (16 Test Cases - `test/unit/core_functions_test.dart`)
- **TC-01 -> TC-05**: Thêm tài liệu hợp lệ, kiểm tra sinh UUID v4, kiểm tra validate dữ liệu đầu vào.
- **TC-06 -> TC-08**: Chỉnh sửa tài liệu, cập nhật `dateTimeModified`, chuyển trạng thái học tập 1-tap.
- **TC-09 -> TC-12**: Xóa mềm (Soft-delete), ghi vết DeleteLogs, khôi phục từ thùng rác, xóa vĩnh viễn (Hard-delete).
- **TC-13 -> TC-14**: Tìm kiếm từ khóa không phân biệt hoa thường, lọc kết hợp theo Môn học + Trạng thái.
- **TC-15 -> TC-16**: Kiểm tra phát xung Reactive Stream và đính kèm tệp tin.

### 2. Bước 4: Layer Isolation Testing (16 Test Cases - `test/unit/layer_isolation_test.dart`)
- Kiểm thử độc lập hoàn toàn bằng **Test Doubles / In-memory Mocks** (`FakeDocumentRepository`, `FakeSubjectRepository`).
- Tầng Service và Nghiệp vụ hoạt động độc lập 100%, không cần kết nối SQLite hay hệ điều hành thiết bị di động.
- Kiểm thử cô lập tầng Data: Chuyển đổi hai chiều Entity <-> Model <-> SQLite Map.

Chạy kiểm thử:
```bash
flutter test
```
Kiểm tra chất lượng code:
```bash
flutter analyze
```

---

## 📦 Đóng Gói Ứng Dụng (Build APK)

### Tạo gói cài đặt Android (APK):
```bash
flutter build apk --debug
# Hoặc đóng gói tối ưu phát hành (Release):
flutter build apk --release --split-per-abi
```

Tệp tin đóng gói được tạo tại:
`build/app/outputs/flutter-apk/app-debug.apk`

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Dự Án

### Yêu Cầu Môi Trường:
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK (API 34/35) & Android Studio

### Các Bước Thực Hiện:
1. **Clone mã nguồn từ GitHub**:
   ```bash
   git clone <URL_REPOSITORY_CUA_BAN>
   cd TH1
   ```
2. **Cài đặt các gói phụ thuộc (Dependencies)**:
   ```bash
   flutter pub get
   ```
3. **Chạy ứng dụng trên Thiết bị thật hoặc Giả lập (Emulator)**:
   ```bash
   flutter run
   ```

---

## 👥 Tác Giả & Bản Quyền
- **Sinh viên thực hiện**: Nhóm 15
- **Môn học**: Lập trình Thiết bị Di động (Mobile Programming)
- **Học viện**: Học viện Công nghệ Bưu chính Viễn thông (PTIT)
- **Kiến trúc tham chiếu**: Cashew Open Source Architecture
