import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/borrow_share_models.dart';
import 'supabase_service.dart';

class BorrowShareServiceException implements Exception {
  const BorrowShareServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Service quản lý mượn trả tài liệu vật lý và chia sẻ quyền tài liệu số
class BorrowShareService {
  BorrowShareService({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;

  SupabaseClient get _client {
    if (_providedClient != null) return _providedClient;
    if (SupabaseService.isInitialized) return SupabaseService.client;
    return Supabase.instance.client;
  }

  /// 1. Gửi yêu cầu mượn tài liệu vật lý (Bảng `borrow_requests`)
  Future<BorrowRequestModel> requestBorrow({
    required String docId,
    required String requesterUid,
    required DateTime dueDate,
    String? ownerId,
    String notes = '',
  }) async {
    try {
      final now = DateTime.now();
      if (dueDate.isBefore(now)) {
        throw const BorrowShareServiceException(
          'Hạn ngày trả sách phải sau thời điểm hiện tại.',
        );
      }

      // Tự động truy vấn owner_id từ bảng documents nếu chưa được truyền vào
      String? resolvedOwnerId = ownerId;
      if (resolvedOwnerId == null || resolvedOwnerId.trim().isEmpty) {
        final doc = await _client
            .from('documents')
            .select('owner_id')
            .eq('id', docId)
            .maybeSingle();
        if (doc != null && doc['owner_id'] != null) {
          resolvedOwnerId = doc['owner_id'] as String;
        }
      }

      if (resolvedOwnerId == null || resolvedOwnerId.trim().isEmpty) {
        throw const BorrowShareServiceException(
          'Không tìm thấy thông tin chủ sở hữu tài liệu (owner_id).',
        );
      }

      final payload = {
        'document_id': docId,
        'owner_id': resolvedOwnerId.trim(),
        'requester_id': requesterUid,
        'requester_uid': requesterUid,
        'status': 'pending',
        'borrow_date': now.toIso8601String(),
        'due_date': dueDate.toIso8601String(),
        'notes': notes.trim(),
      };

      final response = await _client
          .from('borrow_requests')
          .insert(payload)
          .select('*, documents(title, storage_room, shelf_code, box_number, address, owner_id)')
          .single();

      return BorrowRequestModel.fromMap(response);
    } on PostgrestException catch (e) {
      throw BorrowShareServiceException('Lỗi Supabase khi gửi yêu cầu: ${e.message}');
    } catch (e) {
      if (e is BorrowShareServiceException) rethrow;
      throw BorrowShareServiceException('Không thể gửi yêu cầu mượn: $e');
    }
  }

  /// 2. Lấy danh sách các yêu cầu mượn đang chờ duyệt của chủ tài liệu (`ownerUid`)
  Future<List<BorrowRequestModel>> getPendingRequestsForOwner(String ownerUid) async {
    try {
      final response = await _client
          .from('borrow_requests')
          .select('*, documents!inner(title, storage_room, shelf_code, box_number, address, owner_id)')
          .eq('documents.owner_id', ownerUid)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map(BorrowRequestModel.fromMap).toList();
    } on PostgrestException catch (e) {
      throw BorrowShareServiceException('Lỗi tải danh sách yêu cầu chờ duyệt: ${e.message}');
    } catch (e) {
      throw BorrowShareServiceException('Không thể lấy danh sách chờ duyệt: $e');
    }
  }

  /// Lấy toàn bộ yêu cầu mượn gửi đến chủ tài liệu (hỗ trợ lọc theo status)
  Future<List<BorrowRequestModel>> getAllRequestsForOwner(
    String ownerUid, {
    String? status,
  }) async {
    try {
      var query = _client
          .from('borrow_requests')
          .select('*, documents!inner(title, storage_room, shelf_code, box_number, address, owner_id)')
          .eq('documents.owner_id', ownerUid);

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map(BorrowRequestModel.fromMap).toList();
    } on PostgrestException catch (e) {
      throw BorrowShareServiceException('Lỗi tải danh sách yêu cầu: ${e.message}');
    } catch (e) {
      throw BorrowShareServiceException('Không thể lấy danh sách yêu cầu: $e');
    }
  }

  /// Lấy danh sách các yêu cầu mượn do chính người dùng hiện tại gửi đi
  Future<List<BorrowRequestModel>> getRequestsByRequester(String requesterUid) async {
    try {
      final response = await _client
          .from('borrow_requests')
          .select('*, documents(title, storage_room, shelf_code, box_number, address, owner_id)')
          .eq('requester_uid', requesterUid)
          .order('created_at', ascending: false);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map(BorrowRequestModel.fromMap).toList();
    } on PostgrestException catch (e) {
      throw BorrowShareServiceException('Lỗi tải lịch sử mượn: ${e.message}');
    } catch (e) {
      throw BorrowShareServiceException('Không thể lấy lịch sử mượn: $e');
    }
  }

  /// 3. Cập nhật trạng thái yêu cầu mượn ('approved', 'rejected', 'returned')
  Future<void> updateBorrowStatus({
    required String requestId,
    required String newStatus,
  }) async {
    try {
      final validStatuses = ['pending', 'approved', 'rejected', 'returned'];
      if (!validStatuses.contains(newStatus)) {
        throw BorrowShareServiceException('Trạng thái "$newStatus" không hợp lệ.');
      }

      await _client
          .from('borrow_requests')
          .update({'status': newStatus})
          .eq('id', requestId);
    } on PostgrestException catch (e) {
      throw BorrowShareServiceException('Lỗi cập nhật trạng thái: ${e.message}');
    } catch (e) {
      if (e is BorrowShareServiceException) rethrow;
      throw BorrowShareServiceException('Không thể cập nhật yêu cầu: $e');
    }
  }

  /// 4. Chia sẻ quyền tài liệu số (Bảng `document_shares`)
  Future<DocumentShareModel> shareDocument({
    required String docId,
    required String targetUid,
    required String permission, // 'view' hoặc 'edit'
  }) async {
    try {
      final normalizedPerm = permission.toLowerCase().trim();
      if (normalizedPerm != 'view' && normalizedPerm != 'edit') {
        throw const BorrowShareServiceException('Quyền chia sẻ chỉ có thể là "view" hoặc "edit".');
      }

      final response = await _client
          .from('document_shares')
          .upsert(
            {
              'document_id': docId,
              'shared_with_uid': targetUid.trim(),
              'permission': normalizedPerm,
            },
            onConflict: 'document_id, shared_with_uid',
          )
          .select('*, documents(title)')
          .single();

      return DocumentShareModel.fromMap(response);
    } on PostgrestException catch (e) {
      throw BorrowShareServiceException('Lỗi Supabase khi chia sẻ tài liệu: ${e.message}');
    } catch (e) {
      if (e is BorrowShareServiceException) rethrow;
      throw BorrowShareServiceException('Không thể chia sẻ tài liệu: $e');
    }
  }

  /// Chia sẻ tài liệu số qua địa chỉ Email người nhận
  Future<DocumentShareModel> shareDocumentByEmail({
    required String docId,
    required String targetEmail,
    required String permission,
  }) async {
    try {
      final normalizedEmail = targetEmail.trim().toLowerCase();
      // Tìm UID người dùng tương ứng trong bảng users
      final userResponse = await _client
          .from('users')
          .select('id, email')
          .eq('email', normalizedEmail)
          .maybeSingle();

      if (userResponse == null) {
        throw BorrowShareServiceException(
          'Không tìm thấy người dùng có email "$targetEmail" trong hệ thống.',
        );
      }

      final targetUid = userResponse['id'] as String;
      return await shareDocument(
        docId: docId,
        targetUid: targetUid,
        permission: permission,
      );
    } catch (e) {
      if (e is BorrowShareServiceException) rethrow;
      throw BorrowShareServiceException('Lỗi chia sẻ qua email: $e');
    }
  }

  /// Lấy danh sách chia sẻ của một tài liệu
  Future<List<DocumentShareModel>> getDocumentShares(String docId) async {
    try {
      final response = await _client
          .from('document_shares')
          .select('*, documents(title)')
          .eq('document_id', docId)
          .order('created_at', ascending: false);

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map(DocumentShareModel.fromMap).toList();
    } on PostgrestException catch (e) {
      throw BorrowShareServiceException('Lỗi tải danh sách chia sẻ: ${e.message}');
    } catch (e) {
      throw BorrowShareServiceException('Không thể lấy danh sách chia sẻ: $e');
    }
  }

  /// Hủy chia sẻ tài liệu
  Future<void> revokeShare(String shareId) async {
    try {
      await _client.from('document_shares').delete().eq('id', shareId);
    } on PostgrestException catch (e) {
      throw BorrowShareServiceException('Lỗi hủy chia sẻ: ${e.message}');
    } catch (e) {
      throw BorrowShareServiceException('Không thể hủy chia sẻ: $e');
    }
  }

  /// Nạp dữ liệu mẫu để kiểm thử luồng mượn trả & gợi ý tài liệu
  Future<void> seedTestBorrowData({String? currentUid}) async {
    try {
      final effectiveUid = currentUid ?? 'sample_librarian_admin';
      const studentUid = 'sample_student_k21';

      // 1. Đảm bảo users tồn tại trong bảng users
      await _client.from('users').upsert([
        {
          'id': studentUid,
          'email': 'sinhvien.k21@studyapp.local',
          'display_name': 'Nguyễn Văn An (K21 - CNTT)',
        },
        {
          'id': 'sample_lecturer_uid',
          'email': 'giangvien.cntt@studyapp.local',
          'display_name': 'TS. Lê Hoàng Minh (Khoa CNTT)',
        },
        if (effectiveUid == 'sample_librarian_admin')
          {
            'id': 'sample_librarian_admin',
            'email': 'thuvien.admin@studyapp.local',
            'display_name': 'Thư Viện Trung Tâm (Quản thư)',
          },
      ], onConflict: 'id');

      // 2. Nạp 10 tài liệu mẫu đa dạng chủ đề và vị trí lưu kho
      const doc1Id = 'a1111111-1111-1111-1111-111111111111';
      const doc2Id = 'b2222222-2222-2222-2222-222222222222';
      const doc3Id = 'c3333333-3333-3333-3333-333333333333';
      const doc4Id = 'd4444444-4444-4444-4444-444444444444';
      const doc5Id = 'e5555555-5555-5555-5555-555555555555';
      const doc6Id = 'f6666666-6666-6666-6666-666666666666';
      const doc7Id = '77777777-7777-7777-7777-777777777777';
      const doc8Id = '88888888-8888-8888-8888-888888888888';
      const doc9Id = '99999999-9999-9999-9999-999999999999';
      const doc10Id = '00000000-0000-0000-0000-000000000000';

      await _client.from('documents').upsert([
        {
          'id': doc1Id,
          'owner_id': effectiveUid,
          'title': 'Giáo trình Lập trình Ứng dụng Di động với Flutter & Dart',
          'description': 'Tài liệu toàn diện từ cơ bản đến nâng cao về Flutter framework, State Management và tích hợp Firebase/Supabase.',
          'file_name': 'flutter_dart_handbook_2026.pdf',
          'storage_path': 'sample_seeds/flutter_handbook.pdf',
          'file_size_bytes': 10485760,
          'mime_type': 'application/pdf',
          'storage_room': 'Phòng 402 - Thư viện Trung tâm',
          'shelf_code': 'Kệ A3',
          'box_number': 'Hộp 07',
          'latitude': 10.7725,
          'longitude': 106.6980,
          'address': '268 Lý Thường Kiệt, Phường 14, Quận 10, TP.HCM',
          'tags': ['cntt', 'flutter', 'dart', 'mobile', 'laptrinh', 'giao-trinh'],
        },
        {
          'id': doc2Id,
          'owner_id': effectiveUid,
          'title': 'Cẩm nang Cấu trúc Dữ liệu & Thuật toán Nâng cao (Python & C++)',
          'description': 'Tổng hợp các dạng bài toán đồ thị, quy hoạch động, cây phân đoạn và độ phức tạp tính toán.',
          'file_name': 'dsa_advanced_guide.pdf',
          'storage_path': 'sample_seeds/dsa_guide.pdf',
          'file_size_bytes': 8388608,
          'mime_type': 'application/pdf',
          'storage_room': 'Phòng 402 - Thư viện Trung tâm',
          'shelf_code': 'Kệ A3',
          'box_number': 'Hộp 12',
          'latitude': 10.7725,
          'longitude': 106.6980,
          'address': '268 Lý Thường Kiệt, Phường 14, Quận 10, TP.HCM',
          'tags': ['cntt', 'thuat-toan', 'dsa', 'laptrinh', 'python', 'giao-trinh'],
        },
        {
          'id': doc3Id,
          'owner_id': studentUid,
          'title': 'Bộ Đề thi & Lời giải chi tiết Môn Học máy & Trí tuệ Nhân tạo',
          'description': 'Đề thi giữa kỳ và cuối kỳ kèm hướng dẫn giải code PyTorch/TensorFlow chi tiết.',
          'file_name': 'ai_ml_exam_solutions.pdf',
          'storage_path': 'sample_seeds/ai_ml_exams.pdf',
          'file_size_bytes': 5242880,
          'mime_type': 'application/pdf',
          'storage_room': 'Kho Lưu trữ Cơ sở 2 - Thư viện ĐHQG',
          'shelf_code': 'Kệ B1',
          'box_number': 'Hộp 05',
          'latitude': 10.8805,
          'longitude': 106.8055,
          'address': 'Khu Đô thị ĐHQG, Phường Linh Trung, TP. Thủ Đức, TP.HCM',
          'tags': ['cntt', 'ai', 'machine-learning', 'de-thi', 'pytorch', 'python'],
        },
        {
          'id': doc4Id,
          'owner_id': studentUid,
          'title': 'Giáo trình An toàn Thông tin & Mạng Máy tính Ứng dụng',
          'description': 'Kiến thức về bảo mật mạng, mã hóa khóa công khai RSA, chữ ký số và phòng chống tấn công mạng.',
          'file_name': 'network_security_cryptography.pdf',
          'storage_path': 'sample_seeds/security_crypto.pdf',
          'file_size_bytes': 7340032,
          'mime_type': 'application/pdf',
          'storage_room': 'Phòng 301 - Kho Tài liệu Chuyên ngành',
          'shelf_code': 'Kệ C2',
          'box_number': 'Hộp 18',
          'latitude': 10.7626,
          'longitude': 106.6823,
          'address': '227 Nguyễn Văn Cừ, Phường 4, Quận 5, TP.HCM',
          'tags': ['cntt', 'security', 'mang-may-tinh', 'laptrinh', 'giao-trinh'],
        },
        {
          'id': doc5Id,
          'owner_id': 'sample_lecturer_uid',
          'title': 'Thiết kế & Tối ưu Hóa Cơ sở Dữ liệu Quan hệ PostgreSQL & NoSQL',
          'description': 'Chỉ mục B-Tree, GIN, Partitioning bảng lớn và kiến trúc lưu trữ phân tán hiệu năng cao.',
          'file_name': 'database_optimization_postgresql.pdf',
          'storage_path': 'sample_seeds/postgresql_guide.pdf',
          'file_size_bytes': 9437184,
          'mime_type': 'application/pdf',
          'storage_room': 'Phòng 402 - Thư viện Trung tâm',
          'shelf_code': 'Kệ B4',
          'box_number': 'Hộp 09',
          'latitude': 10.7725,
          'longitude': 106.6980,
          'address': '268 Lý Thường Kiệt, Phường 14, Quận 10, TP.HCM',
          'tags': ['cntt', 'database', 'sql', 'postgresql', 'backend', 'laptrinh'],
        },
        {
          'id': doc6Id,
          'owner_id': 'sample_lecturer_uid',
          'title': 'Xử lý Ngôn ngữ Tự nhiên & Mô hình Ngôn ngữ Lớn (LLMs in Action)',
          'description': 'Kiến trúc Transformer, Fine-tuning Llama/BERT và kỹ thuật RAG trong các ứng dụng AI tạo sinh.',
          'file_name': 'nlp_llms_in_action_2026.pdf',
          'storage_path': 'sample_seeds/nlp_llms.pdf',
          'file_size_bytes': 15728640,
          'mime_type': 'application/pdf',
          'storage_room': 'Viện Nghiên cứu AI - Khu Công nghệ cao',
          'shelf_code': 'Kệ R1',
          'box_number': 'Hộp 03',
          'latitude': 10.8544,
          'longitude': 106.7852,
          'address': 'Xa lộ Hà Nội, Phường Hiệp Phú, TP. Thủ Đức, TP.HCM',
          'tags': ['cntt', 'ai', 'nlp', 'machine-learning', 'python', 'deep-learning'],
        },
        {
          'id': doc7Id,
          'owner_id': studentUid,
          'title': 'Kiến trúc Microservices, Docker & Kubernetes Thực chiến',
          'description': 'Triển khai Container hóa ứng dụng, Service Mesh, CI/CD pipeline và quản trị cụm Kubernetes.',
          'file_name': 'microservices_docker_k8s.pdf',
          'storage_path': 'sample_seeds/docker_k8s.pdf',
          'file_size_bytes': 11534336,
          'mime_type': 'application/pdf',
          'storage_room': 'Phòng Lab 505 - Tòa nhà H6',
          'shelf_code': 'Kệ D2',
          'box_number': 'Hộp 15',
          'latitude': 10.8805,
          'longitude': 106.8055,
          'address': 'Khu Đô thị ĐHQG, Phường Linh Trung, TP. Thủ Đức, TP.HCM',
          'tags': ['cntt', 'devops', 'docker', 'backend', 'laptrinh', 'cloud'],
        },
        {
          'id': doc8Id,
          'owner_id': studentUid,
          'title': 'Phát triển Web Hiện đại với Next.js 15, React & TypeScript',
          'description': 'Full-stack Web với Server Actions, App Router, tối ưu SEO và TailwindCSS components.',
          'file_name': 'nextjs_react_modern_web.pdf',
          'storage_path': 'sample_seeds/nextjs_react.pdf',
          'file_size_bytes': 6291456,
          'mime_type': 'application/pdf',
          'storage_room': 'Phòng Tự học Sinh viên - Tầng 2',
          'shelf_code': 'Kệ W1',
          'box_number': 'Hộp 04',
          'latitude': 10.7725,
          'longitude': 106.6980,
          'address': '268 Lý Thường Kiệt, Phường 14, Quận 10, TP.HCM',
          'tags': ['cntt', 'laptrinh', 'frontend', 'react', 'web', 'javascript'],
        },
        {
          'id': doc9Id,
          'owner_id': 'sample_lecturer_uid',
          'title': 'Đại số Tuyến tính & Xác suất Thống kê cho Khoa học Dữ liệu',
          'description': 'Nền tảng toán học cho các mô hình Máy học: Ma trận, SVD, PCA, phân phối xác suất và Bayes.',
          'file_name': 'linear_algebra_probability_datascience.pdf',
          'storage_path': 'sample_seeds/math_ai.pdf',
          'file_size_bytes': 8912896,
          'mime_type': 'application/pdf',
          'storage_room': 'Kho Lưu trữ Cơ sở 2 - Thư viện ĐHQG',
          'shelf_code': 'Kệ M3',
          'box_number': 'Hộp 22',
          'latitude': 10.8805,
          'longitude': 106.8055,
          'address': 'Khu Đô thị ĐHQG, Phường Linh Trung, TP. Thủ Đức, TP.HCM',
          'tags': ['toan', 'dai-so', 'xac-suat', 'data-science', 'ai', 'machine-learning'],
        },
        {
          'id': doc10Id,
          'owner_id': 'sample_lecturer_uid',
          'title': 'Cẩm nang Thiết kế Giao diện & Trải nghiệm Người dùng (UI/UX Design)',
          'description': 'Hệ thống thiết kế Figma, nguyên lý Design System, Micro-interactions và khả năng tiếp cận.',
          'file_name': 'ui_ux_design_handbook.pdf',
          'storage_path': 'sample_seeds/uiux_guide.pdf',
          'file_size_bytes': 14680064,
          'mime_type': 'application/pdf',
          'storage_room': 'Phòng Đồ họa & Đa phương tiện',
          'shelf_code': 'Kệ U2',
          'box_number': 'Hộp 01',
          'latitude': 10.7626,
          'longitude': 106.6823,
          'address': '227 Nguyễn Văn Cừ, Phường 4, Quận 5, TP.HCM',
          'tags': ['cntt', 'ui-ux', 'design', 'frontend', 'mobile', 'figma'],
        },
      ], onConflict: 'id');

      // 3. Nạp borrow_requests (với các trạng thái để test duyệt mượn & tạo lịch sử tags)
      final now = DateTime.now();
      await _client.from('borrow_requests').upsert([
        {
          'id': '11111111-bbbb-bbbb-bbbb-111111111111',
          'document_id': doc1Id,
          'requester_uid': studentUid,
          'status': 'pending',
          'borrow_date': now.toIso8601String(),
          'due_date': now.add(const Duration(days: 7)).toIso8601String(),
          'notes': 'Em xin phép mượn giáo trình Flutter để ôn thi cuối kỳ. SĐT: 0987.654.321.',
        },
        {
          'id': '22222222-bbbb-bbbb-bbbb-222222222222',
          'document_id': doc2Id,
          'requester_uid': studentUid,
          'status': 'approved',
          'borrow_date': now.subtract(const Duration(days: 2)).toIso8601String(),
          'due_date': now.add(const Duration(days: 12)).toIso8601String(),
          'notes': 'Mượn sách phục vụ làm đồ án môn Cấu trúc dữ liệu & Thuật toán.',
        },
        {
          'id': '33333333-bbbb-bbbb-bbbb-333333333333',
          'document_id': doc4Id,
          'requester_uid': effectiveUid,
          'status': 'returned',
          'borrow_date': now.subtract(const Duration(days: 15)).toIso8601String(),
          'due_date': now.subtract(const Duration(days: 1)).toIso8601String(),
          'notes': 'Đã hoàn trả tài liệu tại bàn thủ thư.',
        },
        {
          'id': '44444444-bbbb-bbbb-bbbb-444444444444',
          'document_id': doc3Id,
          'requester_uid': effectiveUid,
          'status': 'returned',
          'borrow_date': now.subtract(const Duration(days: 20)).toIso8601String(),
          'due_date': now.subtract(const Duration(days: 6)).toIso8601String(),
          'notes': 'Đã mượn đề thi AI/ML để ôn tập.',
        },
      ], onConflict: 'id');

      // 4. Nạp chia sẻ quyền tài liệu (document_shares) để mở rộng tập tag quan tâm của user
      await _client.from('document_shares').upsert([
        {
          'id': '55555555-ssss-ssss-ssss-555555555555',
          'document_id': doc10Id,
          'shared_with_uid': effectiveUid,
          'permission': 'view',
        },
      ], onConflict: 'id');
    } catch (e) {
      throw BorrowShareServiceException('Không thể nạp dữ liệu test: $e');
    }
  }
}
