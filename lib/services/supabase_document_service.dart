import 'package:supabase_flutter/supabase_flutter.dart';

/// Dịch vụ đồng bộ tài liệu lên Supabase PostgreSQL (REST API + Realtime)
/// Tích hợp với dự án CashewDoc — bổ sung song song với Firebase Cloud
class SupabaseDocumentService {
  static final SupabaseDocumentService instance =
      SupabaseDocumentService._internal();

  SupabaseDocumentService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// Lấy danh sách tài liệu từ bảng `cloud_documents` trên Supabase
  Future<List<Map<String, dynamic>>> getDocuments() async {
    final response = await _client
        .from('cloud_documents')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Stream realtime thay đổi bảng `cloud_documents`
  Stream<List<Map<String, dynamic>>> watchDocuments() {
    return _client
        .from('cloud_documents')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  /// Thêm tài liệu mới lên Supabase
  Future<Map<String, dynamic>> insertDocument({
    required String title,
    required String documentType,
    required String studyStatus,
    String note = '',
    String tags = '',
    int priority = 2,
    String? ownerEmail,
    String? ownerName,
  }) async {
    final payload = {
      'title': title,
      'document_type': documentType,
      'study_status': studyStatus,
      'note': note,
      'tags': tags,
      'priority': priority,
      'owner_email': ownerEmail ?? '',
      'owner_name': ownerName ?? '',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    final response = await _client
        .from('cloud_documents')
        .insert(payload)
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  /// Cập nhật tài liệu trên Supabase
  Future<void> updateDocument({
    required String id,
    required String title,
    required String documentType,
    required String studyStatus,
    String note = '',
    String tags = '',
    int priority = 2,
  }) async {
    await _client
        .from('cloud_documents')
        .update({
          'title': title,
          'document_type': documentType,
          'study_status': studyStatus,
          'note': note,
          'tags': tags,
          'priority': priority,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Xóa tài liệu trên Supabase theo id
  Future<void> deleteDocument(String id) async {
    await _client.from('cloud_documents').delete().eq('id', id);
  }

  /// Đồng bộ một tài liệu cục bộ (từ SQLite) lên Supabase
  /// Kiểm tra trùng theo `local_id`, nếu có thì update, chưa có thì insert
  Future<void> syncLocalDocument({
    required String localId,
    required String title,
    required String documentType,
    required String studyStatus,
    String note = '',
    String tags = '',
    int priority = 2,
    String? ownerEmail,
    String? ownerName,
  }) async {
    final existing = await _client
        .from('cloud_documents')
        .select('id')
        .eq('local_id', localId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('cloud_documents')
          .update({
            'title': title,
            'document_type': documentType,
            'study_status': studyStatus,
            'note': note,
            'tags': tags,
            'priority': priority,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('local_id', localId);
    } else {
      await _client.from('cloud_documents').insert({
        'local_id': localId,
        'title': title,
        'document_type': documentType,
        'study_status': studyStatus,
        'note': note,
        'tags': tags,
        'priority': priority,
        'owner_email': ownerEmail ?? '',
        'owner_name': ownerName ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Kiểm tra kết nối Supabase bằng cách truy vấn đơn giản
  Future<bool> testConnection() async {
    try {
      await _client.from('cloud_documents').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }
}
