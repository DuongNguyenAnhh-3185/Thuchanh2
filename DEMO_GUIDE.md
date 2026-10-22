# Hướng dẫn demo hệ thống quản lý tài liệu Cloud

Tài liệu này hướng dẫn demo ứng dụng CashewDoc với Flutter, Firebase
Authentication, Cloud Firestore và Supabase. Kịch bản sử dụng ba tài khoản
Google để kiểm tra quyền `owner`, `editor` và `viewer`.

## 1. Phạm vi demo

Các chức năng được demo trực tiếp:

1. Đăng nhập Google bằng Firebase Authentication.
2. Đồng bộ người dùng Firebase vào bảng `public.users` trên Supabase.
3. Quản lý metadata tài liệu bằng bảng `public.documents`.
4. Tìm kiếm và cập nhật thông tin tài liệu.
5. Chia sẻ tài liệu với quyền `editor` và `viewer`.
6. Thu hồi quyền và kiểm tra Supabase Row Level Security bằng ba tài khoản.

### Giới hạn Firebase Storage

Mã nguồn đã có lớp tích hợp Firebase Storage, cấu trúc đường dẫn file và
`storage.rules`. Tuy nhiên, nếu Firebase Console yêu cầu nâng cấp dự án lên gói
Blaze để sử dụng Storage thì không thể demo upload/download file thật trên gói
Spark.

Trong trường hợp đó, kịch bản này sử dụng một bản ghi metadata mẫu để kiểm thử
tìm kiếm, cập nhật, chia sẻ và RLS. Không chọn **Tải xuống** đối với tài liệu mẫu
vì không có file vật lý tương ứng trong Firebase Storage.

Khi thuyết trình cần nói rõ:

> Lớp tích hợp Firebase Storage và Security Rules đã được xây dựng trong mã
> nguồn. Môi trường Firebase Spark hiện tại không cấp bucket Storage nên bản
> demo sử dụng metadata mẫu để kiểm thử các chức năng dữ liệu và phân quyền.

## 2. Chuẩn bị

### 2.1. Ba tài khoản Google

Chuẩn bị ba tài khoản Google độc lập:

| Tài khoản | Vai trò | Quyền cần kiểm tra |
|---|---|---|
| A | Owner | Xem, sửa và chia sẻ |
| B | Editor | Xem và sửa, không chia sẻ |
| C | Viewer | Chỉ xem, không sửa và không chia sẻ |

Không sử dụng các địa chỉ Gmail chỉ khác dấu chấm hoặc hậu tố `+test`, vì chúng
có thể vẫn thuộc cùng một tài khoản Google. Không ghi mật khẩu hoặc mã xác minh
vào tài liệu, slide hay mã nguồn.

### 2.2. Cấu hình đã triển khai

Kiểm tra trước khi demo:

- Firebase Authentication đã bật Google provider.
- Supabase Third-Party Auth đã bật Firebase với project ID
  `device-streaming-33cac12e`.
- Hai migration Supabase đã được đẩy lên project.
- Supabase có ba bảng `users`, `documents`, `permissions`.
- Máy có Flutter, Chrome, Node.js và kết nối Internet.

## 3. Chạy ứng dụng

Mở PowerShell:

```powershell
cd D:\BTL_NA\Cloud_Cashewstudy

$env:Path = "C:\Users\phuy0\flutter\bin;$env:Path"

flutter --version
flutter pub get
flutter devices
```

Khai báo cấu hình Supabase. Chỉ dùng **Publishable Key**, tuyệt đối không dùng
Secret Key hoặc Service Role Key trong ứng dụng:

```powershell
$supabaseUrl = "https://jzyuvqmcrbponebkrgwm.supabase.co"
$supabaseKey = Read-Host "Dan Supabase Publishable Key"

$supabaseKey.StartsWith("sb_publishable_")
```

Kết quả kiểm tra key phải là `True`.

Chạy ứng dụng:

```powershell
flutter run -d chrome --web-port=5200 `
  "--dart-define=SUPABASE_URL=$supabaseUrl" `
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=$supabaseKey"
```

Giữ Terminal này hoạt động trong suốt buổi demo. Nhấn `q` khi muốn dừng ứng
dụng.

## 4. Đăng ký ba người dùng vào hệ thống

Không tạo người dùng thủ công trong Supabase Authentication. Hệ thống dùng
Firebase Authentication làm nguồn danh tính và tự đồng bộ hồ sơ vào
`public.users`.

Trong ứng dụng:

1. Tại màn hình CashewDoc, nhấn dấu ba chấm ở góc trên bên phải.
2. Chọn **Đám mây Firebase**.
3. Nhấn **Đăng nhập bằng Google**.
4. Đăng nhập tài khoản A và chờ tên, email, ảnh đại diện xuất hiện.
5. Nhấn biểu tượng đăng xuất.
6. Lặp lại với tài khoản B.
7. Lặp lại với tài khoản C.

Kiểm tra người dùng:

- Firebase Console: **Authentication > Users** phải có A, B và C.
- Supabase: **Table Editor > users** phải có ba dòng tương ứng.

Có thể kiểm tra bằng SQL:

```sql
select id, email, display_name, created_at
from public.users
order by created_at;
```

Lưu lại UID trong cột `id` và email của tài khoản A. UID này được sử dụng ở các
bước tiếp theo.

## 5. Tạo metadata tài liệu mẫu

Mở **Supabase > SQL Editor > New query** và chạy đoạn SQL sau. Thay
`EMAIL_TAI_KHOAN_A` bằng email thật của tài khoản A.

```sql
do $$
declare
  v_owner_id text;
begin
  select id
  into v_owner_id
  from public.users
  where email = 'EMAIL_TAI_KHOAN_A';

  if v_owner_id is null then
    raise exception 'Không tìm thấy tài khoản A trong public.users';
  end if;

  insert into public.documents (
    id,
    owner_id,
    title,
    description,
    file_name,
    storage_path,
    file_size_bytes,
    mime_type
  )
  values (
    '33333333-3333-4333-8333-333333333333',
    v_owner_id,
    'Tài liệu demo Cloud',
    'Metadata mẫu dùng để kiểm thử tìm kiếm, cập nhật, chia sẻ và RLS',
    'tai_lieu_demo.pdf',
    'documents/' || v_owner_id ||
      '/33333333-3333-4333-8333-333333333333/tai_lieu_demo.pdf',
    102400,
    'application/pdf'
  )
  on conflict (id) do update set
    owner_id = excluded.owner_id,
    title = excluded.title,
    description = excluded.description,
    file_name = excluded.file_name,
    storage_path = excluded.storage_path,
    file_size_bytes = excluded.file_size_bytes,
    mime_type = excluded.mime_type,
    updated_at = now();
end
$$;
```

Kiểm tra kết quả:

```sql
select
  d.id,
  d.title,
  d.owner_id,
  u.email as owner_email,
  d.storage_path
from public.documents d
join public.users u on u.id = d.owner_id
where d.id = '33333333-3333-4333-8333-333333333333';
```

`owner_email` phải là email của tài khoản A.

## 6. Tạo ACL mẫu trong Cloud Firestore

ACL giúp Firestore Rules xác nhận A là chủ sở hữu khi ứng dụng thêm hoặc thu hồi
người đọc.

### 6.1. Tạo document ACL

1. Mở **Firebase Console > Firestore Database > Data**.
2. Nhấn **Start collection**.
3. Nhập Collection ID: `storage_acl`.
4. Nhập Document ID:
   `33333333-3333-4333-8333-333333333333`.
5. Thêm các trường:

| Field | Type | Value |
|---|---|---|
| `owner_uid` | string | UID của tài khoản A |
| `created_at` | timestamp | Thời gian hiện tại |

### 6.2. Tạo reader cho owner

Trong document vừa tạo:

1. Nhấn **Start collection**.
2. Nhập Collection ID: `readers`.
3. Nhập Document ID bằng UID của tài khoản A.
4. Thêm các trường:

| Field | Type | Value |
|---|---|---|
| `uid` | string | UID của tài khoản A |
| `access_level` | string | `owner` |
| `granted_at` | timestamp | Thời gian hiện tại |

Cấu trúc kết quả:

```text
storage_acl
└── 33333333-3333-4333-8333-333333333333
    ├── owner_uid: UID-A
    └── readers
        └── UID-A
            ├── uid: UID-A
            └── access_level: owner
```

## 7. Triển khai Firestore Rules

Mở PowerShell mới:

```powershell
cd D:\BTL_NA\Cloud_Cashewstudy

npx firebase-tools@latest login
npx firebase-tools@latest projects:list
```

Danh sách project phải có `device-streaming-33cac12e`.

Triển khai riêng Firestore Rules:

```powershell
npx firebase-tools@latest deploy `
  --project device-streaming-33cac12e `
  --only firestore:rules
```

Kết quả mong đợi:

```text
Deploy complete!
```

Không triển khai Storage trong kịch bản này nếu Firebase Storage chưa được cấp
bucket.

## 8. Demo tài khoản A - Owner

1. Đăng nhập ứng dụng bằng tài khoản A.
2. Nhấn biểu tượng **Làm mới**.
3. Xác nhận `Tài liệu demo Cloud` xuất hiện với nhãn **Chủ sở hữu**.

### 8.1. Tìm kiếm

Lần lượt nhập các từ khóa:

```text
demo
metadata
tai_lieu_demo.pdf
```

Cả ba từ khóa phải tìm thấy tài liệu, tương ứng tìm theo tiêu đề, mô tả và tên
file.

### 8.2. Cập nhật

1. Nhấn dấu ba chấm trên tài liệu.
2. Chọn **Sửa thông tin**.
3. Đổi tiêu đề thành `Tài liệu đã được Owner cập nhật`.
4. Nhấn **Lưu**.
5. Mở bảng `documents` trên Supabase để xác nhận `title` và `updated_at` đã đổi.

Không chọn **Tải xuống** vì đây là metadata mẫu.

## 9. Demo chia sẻ

### 9.1. Chia sẻ cho B với quyền Editor

Từ tài khoản A:

1. Mở menu của tài liệu.
2. Chọn **Chia sẻ & phân quyền**.
3. Nhập email tài khoản B.
4. Chọn **Xem và sửa thông tin**.
5. Nhấn **Cấp quyền**.

### 9.2. Chia sẻ cho C với quyền Viewer

1. Nhập email tài khoản C.
2. Chọn **Chỉ xem và tải xuống**.
3. Nhấn **Cấp quyền**.

Kiểm tra bảng `permissions`:

```sql
select
  p.document_id,
  u.email,
  p.access_level,
  p.created_at
from public.permissions p
join public.users u on u.id = p.user_id
where p.document_id = '33333333-3333-4333-8333-333333333333'
order by u.email;
```

Kết quả phải có một dòng `editor` cho B và một dòng `viewer` cho C.

## 10. Demo tài khoản B - Editor

1. Đăng xuất A và đăng nhập B.
2. Nhấn **Làm mới**.
3. Xác nhận tài liệu của A xuất hiện với nhãn **Có thể chỉnh sửa**.
4. Mở menu và chọn **Sửa thông tin**.
5. Đổi tiêu đề thành `Tài liệu được Editor cập nhật`.
6. Nhấn **Lưu**.

Kết quả cần trình bày:

- B đọc được tài liệu đã chia sẻ.
- B cập nhật được tiêu đề và mô tả.
- B không có chức năng **Chia sẻ & phân quyền**.
- B không phải chủ sở hữu.

## 11. Demo tài khoản C - Viewer

1. Đăng xuất B và đăng nhập C.
2. Nhấn **Làm mới**.
3. Xác nhận tài liệu xuất hiện với nhãn **Chỉ xem**.
4. Mở menu tài liệu.

Kết quả cần trình bày:

- C nhìn thấy tài liệu đã được chia sẻ.
- C không có chức năng **Sửa thông tin**.
- C không có chức năng **Chia sẻ & phân quyền**.

Không chọn **Tải xuống** vì tài liệu mẫu không có file vật lý.

## 12. Demo thu hồi quyền

1. Đăng xuất C và đăng nhập lại A.
2. Mở **Chia sẻ & phân quyền**.
3. Nhấn biểu tượng thu hồi bên cạnh tài khoản C.
4. Đăng xuất A và đăng nhập lại C.
5. Nhấn **Làm mới**.

Kết quả mong đợi:

- C không còn nhìn thấy tài liệu.
- Dòng quyền của C biến mất khỏi `public.permissions`.
- Reader của C biến mất khỏi `storage_acl/{documentId}/readers`.

## 13. Kiểm thử mã nguồn

Mở PowerShell mới:

```powershell
cd D:\BTL_NA\Cloud_Cashewstudy
$env:Path = "C:\Users\phuy0\flutter\bin;$env:Path"

flutter analyze
flutter test
```

Chụp kết quả kiểm thử để đưa vào báo cáo hoặc slide.

Nếu máy đã cài Docker Desktop và Supabase local CLI, có thể chạy kiểm thử RLS
tự động:

```powershell
npx supabase@latest start
npx supabase@latest db reset
npx supabase@latest test db
```

## 14. Bảng kết quả kiểm thử thủ công

| Trường hợp | Tài khoản | Kết quả mong đợi |
|---|---|---|
| Đăng nhập Google | A, B, C | Cả ba đăng nhập thành công |
| Owner xem tài liệu | A | Nhìn thấy tài liệu |
| Owner sửa tài liệu | A | Thành công |
| Owner chia sẻ | A | Thành công |
| Editor xem tài liệu | B | Thành công |
| Editor sửa metadata | B | Thành công |
| Editor chia sẻ tiếp | B | Không có chức năng chia sẻ |
| Viewer xem tài liệu | C | Thành công |
| Viewer sửa metadata | C | Không có chức năng sửa |
| Người bị thu hồi truy cập | C | Không còn thấy tài liệu |

## 15. Đối chiếu checklist

| Checklist | Minh chứng trong demo |
|---|---|
| 1. Firebase Google Sign-In | A, B, C đăng nhập trực tiếp |
| 2. Firebase Storage và metadata | Trình bày code, `storage.rules`, `storage_path` và giới hạn bucket |
| 3. Ba bảng Supabase | `users`, `documents`, `permissions` |
| 4. Tìm kiếm, cập nhật, chia sẻ | Demo trực tiếp trên tài liệu mẫu |
| 5. RLS | Owner, Editor và Viewer nhận dữ liệu/chức năng khác nhau |
| 6. Kiểm thử ba tài khoản | Bảng kiểm thử và thao tác A, B, C |

Checklist 2 chỉ được xem là hoàn thành chức năng thực tế khi upload/download một
file thật thành công trên Firebase Storage hoặc môi trường Firebase Storage
Emulator đã được cấu hình rõ ràng. Không khẳng định file đã được lưu trên Cloud
nếu dự án chưa có bucket hoạt động.

## 16. Xử lý lỗi thường gặp

### Flutter không được nhận diện

```powershell
$env:Path = "C:\Users\phuy0\flutter\bin;$env:Path"
```

### Không thấy tài liệu ở tài khoản A

Kiểm tra `documents.owner_id` phải bằng chính xác `users.id` của A:

```sql
select d.id, d.title, d.owner_id, u.email
from public.documents d
left join public.users u on u.id = d.owner_id
where d.id = '33333333-3333-4333-8333-333333333333';
```

### Không thể chia sẻ

Kiểm tra:

- Người nhận đã đăng nhập ứng dụng ít nhất một lần.
- Email nhập vào giống email trong `public.users`.
- Document `storage_acl/33333333-3333-4333-8333-333333333333` tồn tại.
- `owner_uid` trong Firestore đúng bằng Firebase UID của A.
- Firestore Rules đã được deploy.

### Supabase báo Invalid API key

Dừng ứng dụng bằng `q`, lấy Publishable Key còn hiệu lực rồi chạy lại toàn bộ
lệnh `flutter run`. Không sử dụng Secret Key trong ứng dụng.

