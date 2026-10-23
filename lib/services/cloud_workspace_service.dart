import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:uuid/uuid.dart';

import '../domain/entities/cloud_document.dart';
import 'supabase_service.dart';

class CloudOperationException implements Exception {
  const CloudOperationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Điều phối Firebase Storage và metadata quan hệ trên Supabase.
///
/// Supabase là nguồn dữ liệu chính. Firestore chỉ giữ ACL tối thiểu để
/// Firebase Storage Rules có thể kiểm tra người được chia sẻ.
class CloudWorkspaceService {
  CloudWorkspaceService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
    SupabaseClient? supabase,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _providedSupabase = supabase;

  static const int maxFileSizeBytes = 25 * 1024 * 1024;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final SupabaseClient? _providedSupabase;
  final Uuid _uuid = const Uuid();

  SupabaseClient get _supabase => _providedSupabase ?? SupabaseService.client;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw const CloudOperationException(
        'Bạn cần đăng nhập bằng Google trước khi sử dụng Cloud.',
      );
    }
    return user;
  }

  Future<void> syncCurrentUser() async {
    final user = _user;
    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty || !user.emailVerified) {
      throw const CloudOperationException(
        'Tài khoản Google không cung cấp địa chỉ email.',
      );
    }

    await _supabase.from('users').upsert({
      'id': user.uid,
      'email': email,
      'display_name': user.displayName ?? email.split('@').first,
      'photo_url': user.photoURL,
    }, onConflict: 'id');
  }

  Future<List<CloudDocument>> getDocuments({String query = ''}) async {
    final user = _user;
    final responses = await Future.wait<dynamic>([
      _supabase
          .from('documents')
          .select()
          .order('updated_at', ascending: false),
      _supabase
          .from('permissions')
          .select('document_id, access_level')
          .eq('user_id', user.uid),
    ]);

    final permissionByDocument = <String, String>{};
    for (final row in _asRows(responses[1])) {
      permissionByDocument[row['document_id'] as String] =
          row['access_level'] as String;
    }

    final normalizedQuery = query.trim().toLowerCase();
    return _asRows(responses[0])
        .map(
          (row) => CloudDocument.fromMap(
            row,
            currentUserId: user.uid,
            grantedAccess: permissionByDocument[row['id']],
          ),
        )
        .where((document) {
          if (normalizedQuery.isEmpty) return true;
          return document.title.toLowerCase().contains(normalizedQuery) ||
              document.description.toLowerCase().contains(normalizedQuery) ||
              document.fileName.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  Future<CloudDocument> uploadDocument({
    required PlatformFile file,
    required String title,
    String description = '',
    String? storageRoom,
    String? shelfCode,
    String? boxNumber,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? tags,
  }) async {
    final user = _user;
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const CloudOperationException(
        'Tiêu đề tài liệu không được để trống.',
      );
    }

    final fileSize = file.size;
    if (fileSize <= 0 || fileSize > maxFileSizeBytes) {
      throw const CloudOperationException(
        'Tệp phải có dung lượng lớn hơn 0 và không vượt quá 25 MB.',
      );
    }

    final Uint8List bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else if (file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    } else {
      throw const CloudOperationException('Không thể đọc dữ liệu tệp.');
    }
    if (bytes.length != fileSize) {
      throw const CloudOperationException(
        'Dữ liệu tệp đọc được không khớp kích thước ban đầu.',
      );
    }

    final documentId = _uuid.v4();
    final safeName = _safeFileName(file.name);
    final storagePath = 'documents/${user.uid}/$documentId/$safeName';
    final mimeType = _mimeTypeOf(safeName);
    final storageRef = _storage.ref().child(storagePath);
    var metadataCreated = false;

    try {
      await storageRef.putData(
        bytes,
        SettableMetadata(
          contentType: mimeType,
          customMetadata: {
            'documentId': documentId,
            'ownerUid': user.uid,
            'originalName': file.name,
          },
        ),
      );

    final inserted = await _supabase
          .from('documents')
          .insert({
            'id': documentId,
            'owner_id': user.uid,
            'title': normalizedTitle,
            'description': description.trim(),
            'file_name': file.name,
            'storage_path': storagePath,
            'file_size_bytes': fileSize,
            'mime_type': mimeType,
            if (storageRoom != null && storageRoom.trim().isNotEmpty)
              'storage_room': storageRoom.trim(),
            if (shelfCode != null && shelfCode.trim().isNotEmpty)
              'shelf_code': shelfCode.trim(),
            if (boxNumber != null && boxNumber.trim().isNotEmpty)
              'box_number': boxNumber.trim(),
            if (address != null && address.trim().isNotEmpty)
              'address': address.trim(),
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (tags != null && tags.isNotEmpty) 'tags': tags,
          })
          .select()
          .single();
      metadataCreated = true;

      await _createOwnerAcl(documentId, user.uid);
      return CloudDocument.fromMap(
        Map<String, dynamic>.from(inserted),
        currentUserId: user.uid,
      );
    } catch (error) {
      if (metadataCreated) {
        try {
          await _supabase.from('documents').delete().eq('id', documentId);
        } catch (_) {
          // Giữ lỗi gốc; tài liệu hướng dẫn có quy trình đối soát orphan.
        }
      }
      try {
        await storageRef.delete();
      } catch (_) {
        // Upload có thể chưa hoàn tất nên đối tượng chưa tồn tại.
      }
      rethrow;
    }
  }

  Future<void> updateDocument({
    required String documentId,
    required String title,
    required String description,
    String? storageRoom,
    String? shelfCode,
    String? boxNumber,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? tags,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const CloudOperationException(
        'Tiêu đề tài liệu không được để trống.',
      );
    }
    await _supabase
        .from('documents')
        .update({
          'title': normalizedTitle,
          'description': description.trim(),
          if (storageRoom != null)
            'storage_room': storageRoom.trim().isEmpty ? null : storageRoom.trim(),
          if (shelfCode != null)
            'shelf_code': shelfCode.trim().isEmpty ? null : shelfCode.trim(),
          if (boxNumber != null)
            'box_number': boxNumber.trim().isEmpty ? null : boxNumber.trim(),
          if (address != null)
            'address': address.trim().isEmpty ? null : address.trim(),
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (tags != null) 'tags': tags,
        })
        .eq('id', documentId)
        .select('id')
        .single();
  }

  // --- LUỒNG MƯỢN TÀI LIỆU (BORROW REQUESTS) ---
  Future<void> createBorrowRequest({
    required String documentId,
    required DateTime borrowDate,
    required DateTime dueDate,
    String? ownerId,
    String? notes,
  }) async {
    final user = _user;
    String? resolvedOwnerId = ownerId;
    if (resolvedOwnerId == null || resolvedOwnerId.trim().isEmpty) {
      final doc = await _supabase
          .from('documents')
          .select('owner_id')
          .eq('id', documentId)
          .maybeSingle();
      if (doc != null && doc['owner_id'] != null) {
        resolvedOwnerId = doc['owner_id'] as String;
      }
    }

    await _supabase.from('borrow_requests').insert({
      'document_id': documentId,
      if (resolvedOwnerId != null) 'owner_id': resolvedOwnerId,
      'requester_id': user.uid,
      'requester_uid': user.uid,
      'borrow_date': borrowDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
      'status': 'pending',
    });
  }

  Future<List<BorrowRequestEntity>> getBorrowRequests() async {
    try {
      final response = await _supabase
          .from('borrow_requests')
          .select('*, documents(id, title, shelf_code, storage_room), users(id, email, display_name)')
          .order('created_at', ascending: false);
      return _asRows(response).map(BorrowRequestEntity.fromMap).toList();
    } catch (_) {
      final response = await _supabase
          .from('borrow_requests')
          .select()
          .order('created_at', ascending: false);
      return _asRows(response).map(BorrowRequestEntity.fromMap).toList();
    }
  }

  Future<void> updateBorrowRequestStatus(String requestId, String status) async {
    await _supabase
        .from('borrow_requests')
        .update({'status': status})
        .eq('id', requestId);
  }

  // --- THUẬT TOÁN GỢI Ý (RECOMMENDATION) ---
  Future<List<RecommendedDocumentEntity>> getRecommendations({int limit = 6}) async {
    final user = _user;
    final response = await _supabase.rpc(
      'get_recommended_documents',
      params: {
        'target_user_id': user.uid,
        'limit_count': limit,
      },
    );
    return _asRows(response).map(RecommendedDocumentEntity.fromMap).toList();
  }

  Future<bool> downloadDocument(CloudDocument document) async {
    final bytes = await _storage
        .ref()
        .child(document.storagePath)
        .getData(maxFileSizeBytes);
    if (bytes == null) {
      throw const CloudOperationException('Không đọc được dữ liệu tệp.');
    }

    final savedFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu tài liệu',
      fileName: document.fileName,
      bytes: Uint8List.fromList(bytes),
    );
    return savedFile != null;
  }

  Future<List<DocumentPermission>> getPermissions(String documentId) async {
    final response = await _supabase.rpc(
      'list_document_permissions',
      params: {'p_document_id': documentId},
    );
    return _asRows(response)
        .map(DocumentPermission.fromMap)
        .toList(growable: false);
  }

  Future<DocumentPermission> shareDocument({
    required String documentId,
    required String email,
    required CloudAccessLevel accessLevel,
  }) async {
    if (accessLevel == CloudAccessLevel.owner) {
      throw const CloudOperationException('Không thể cấp quyền chủ sở hữu.');
    }
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@')) {
      throw const CloudOperationException('Email người nhận không hợp lệ.');
    }

    final previousPermissions = await getPermissions(documentId);
    final response = await _supabase.rpc(
      'share_document',
      params: {
        'p_document_id': documentId,
        'p_user_email': normalizedEmail,
        'p_access_level': accessLevel.databaseValue,
      },
    );
    final rows = _asRows(response);
    if (rows.isEmpty) {
      throw const CloudOperationException(
        'Không tìm thấy người dùng để chia sẻ.',
      );
    }
    final permission = DocumentPermission.fromMap(rows.first);

    try {
      await _firestore
          .collection('storage_acl')
          .doc(documentId)
          .collection('readers')
          .doc(permission.userId)
          .set({
            'uid': permission.userId,
            'access_level': permission.accessLevel.databaseValue,
            'granted_at': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      // Preserve the previous role when changing an existing share fails.
      final previous = previousPermissions
          .where((entry) => entry.userId == permission.userId)
          .firstOrNull;
      try {
        if (previous == null) {
          await _supabase.rpc(
            'revoke_document_permission',
            params: {
              'p_document_id': documentId,
              'p_user_id': permission.userId,
            },
          );
        } else {
          await _supabase.rpc(
            'share_document',
            params: {
              'p_document_id': documentId,
              'p_user_email': previous.email,
              'p_access_level': previous.accessLevel.databaseValue,
            },
          );
        }
      } catch (_) {
        throw const CloudOperationException(
          'Chia sẻ chưa đồng bộ giữa Supabase và Storage. '
          'Hãy kiểm tra danh sách quyền và thử lại thao tác.',
        );
      }
      rethrow;
    }
    return permission;
  }

  Future<void> revokePermission({
    required String documentId,
    required DocumentPermission permission,
  }) async {
    final readerRef = _firestore
        .collection('storage_acl')
        .doc(documentId)
        .collection('readers')
        .doc(permission.userId);
    await readerRef.delete();
    try {
      await _supabase.rpc(
        'revoke_document_permission',
        params: {'p_document_id': documentId, 'p_user_id': permission.userId},
      );
    } catch (error) {
      // Keep file access revoked if SQL fails or its response times out.
      throw const CloudOperationException(
        'Đã chặn quyền tải tệp nhưng chưa xác nhận thu hồi metadata. '
        'Hãy thử thu hồi lại để hoàn tất.',
      );
    }
  }

  Future<void> _createOwnerAcl(String documentId, String ownerUid) async {
    final documentRef = _firestore.collection('storage_acl').doc(documentId);
    final batch = _firestore.batch();
    batch.set(documentRef, {
      'owner_uid': ownerUid,
      'created_at': FieldValue.serverTimestamp(),
    });
    batch.set(documentRef.collection('readers').doc(ownerUid), {
      'uid': ownerUid,
      'access_level': 'owner',
      'granted_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static List<Map<String, dynamic>> _asRows(dynamic response) {
    if (response is! List) return const [];
    return response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  static String _safeFileName(String original) {
    final sanitized = original
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return sanitized.isEmpty ? 'document.bin' : sanitized;
  }

  static String _mimeTypeOf(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }
}
