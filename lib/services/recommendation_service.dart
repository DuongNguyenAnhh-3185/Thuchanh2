import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/borrow_share_models.dart';
import 'supabase_service.dart';

class RecommendationServiceException implements Exception {
  const RecommendationServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Service phụ trách thuật toán Gợi ý tài liệu học tập dựa trên thẻ (Tags) & hành vi mượn/chia sẻ
class RecommendationService {
  RecommendationService({
    FirebaseAuth? auth,
    SupabaseClient? client,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _providedClient = client;

  final FirebaseAuth _auth;
  final SupabaseClient? _providedClient;

  SupabaseClient get _client {
    if (_providedClient != null) return _providedClient;
    if (SupabaseService.isInitialized) return SupabaseService.client;
    return Supabase.instance.client;
  }

  /// Gọi PostgreSQL Function `get_recommended_documents` trên Supabase
  ///
  /// - [limit]: Số lượng tài liệu tối đa cần trả về (mặc định 10).
  /// - Tự động trích xuất `p_user_uid` từ Firebase Auth (`FirebaseAuth.instance.currentUser?.uid`).
  Future<List<RecommendedDocumentModel>> getRecommendedDocuments({
    int limit = 10,
  }) async {
    final currentUser = _auth.currentUser;
    final userUid = currentUser?.uid;

    try {
      // Gọi RPC trên Supabase
      final response = await _client.rpc(
        'get_recommended_documents',
        params: {
          'p_user_uid': userUid ?? '',
          'p_limit': limit,
        },
      );

      if (response == null || response is! List) {
        return const [];
      }

      final rows = response.cast<Map<String, dynamic>>();
      return rows.map(RecommendedDocumentModel.fromMap).toList();
    } on PostgrestException catch (e) {
      debugPrint('[RecommendationService] PostgrestException: ${e.message}');
      // Fallback: nếu RPC chưa được tạo trên SQL Editor, truy vấn SELECT dự phòng
      return _fallbackGetDocuments(limit: limit, excludeOwnerId: userUid);
    } catch (e) {
      debugPrint('[RecommendationService] Error: $e');
      return _fallbackGetDocuments(limit: limit, excludeOwnerId: userUid);
    }
  }

  /// Dự phòng lấy danh sách tài liệu nếu RPC gặp lỗi kết nối hoặc database chưa migrate
  Future<List<RecommendedDocumentModel>> _fallbackGetDocuments({
    required int limit,
    String? excludeOwnerId,
  }) async {
    try {
      var query = _client.from('documents').select();
      if (excludeOwnerId != null && excludeOwnerId.isNotEmpty) {
        query = query.neq('owner_id', excludeOwnerId);
      }
      final fallbackData = await query.order('created_at', ascending: false).limit(limit);
      final list = (fallbackData as List).cast<Map<String, dynamic>>();
      return list.map(RecommendedDocumentModel.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }
}
