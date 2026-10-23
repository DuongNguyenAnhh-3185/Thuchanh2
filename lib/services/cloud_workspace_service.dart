import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

/// Điều phối Supabase Storage và metadata quan hệ trên Supabase.
class CloudWorkspaceService {
  CloudWorkspaceService({FirebaseAuth? auth, SupabaseClient? supabase})
    : _auth = auth ?? FirebaseAuth.instance,
      _providedSupabase = supabase;

  void Function(String message)? onNotificationWarning;

  /// Re-query under RLS instead of trusting event payloads.
  Stream<void> watchChanges() {
    late StreamController<void> controller;
    RealtimeChannel? channel;
    StreamSubscription<User?>? tokenSubscription;
    var closed = false;
    controller = StreamController<void>(
      onListen: () async {
        try {
          await _supabase.realtime.setAuth(await _user.getIdToken());
          if (closed) return;
          channel = _supabase.channel('workspace-${_user.uid}-${_uuid.v4()}');
          for (final table in ['documents', 'permissions', 'borrow_requests']) {
            channel!.onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              callback: (_) {
                if (!closed) controller.add(null);
              },
            );
          }
          channel!.subscribe((status, error) {
            if (closed) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              controller.add(null);
            } else if (error != null) {
              controller.addError(error);
            }
          });
          tokenSubscription = _auth.idTokenChanges().listen((user) async {
            try {
              if (user != null && !closed) {
                await _supabase.realtime.setAuth(await user.getIdToken());
              }
            } catch (error) {
              if (!closed) controller.addError(error);
            }
          });
        } catch (error) {
          if (!closed) controller.addError(error);
        }
      },
      onCancel: () async {
        closed = true;
        await tokenSubscription?.cancel();
        if (channel != null) await _supabase.removeChannel(channel!);
      },
    );
    return controller.stream;
  }

  static const int maxFileSizeBytes = 25 * 1024 * 1024;
  static const String _storageBucket = 'documents';

  final FirebaseAuth _auth;
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
              document.fileName.toLowerCase().contains(normalizedQuery) ||
              document.tags.any(
                (tag) => tag.toLowerCase().contains(normalizedQuery),
              );
        })
        .toList(growable: false);
  }

  Future<CloudDocument> uploadDocument({
    required PlatformFile file,
    required String title,
    String description = '',
    List<String> tags = const [],
    String physicalLocation = '',
    double? latitude,
    double? longitude,
    bool isBorrowable = false,
  }) async {
    final user = _user;
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const CloudOperationException(
        'Tiêu đề tài liệu không được để trống.',
      );
    }
    _validateCoordinates(latitude, longitude);

    final fileSize = file.lengthSync() ?? await file.length();
    if (fileSize == null) {
      throw const CloudOperationException('Không thể xác định kích thước tệp.');
    }
    if (fileSize <= 0 || fileSize > maxFileSizeBytes) {
      throw const CloudOperationException(
        'Tệp phải có dung lượng lớn hơn 0 và không vượt quá 25 MB.',
      );
    }

    final bytes = await file.readAsBytes();
    if (bytes.length != fileSize) {
      throw const CloudOperationException(
        'Dữ liệu tệp đọc được không khớp kích thước ban đầu.',
      );
    }

    final documentId = _uuid.v4();
    final safeName = _safeFileName(file.name);
    final storagePath = 'documents/${user.uid}/$documentId/$safeName';
    final mimeType = _mimeTypeOf(safeName);
    var metadataCreated = false;

    try {
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
            'tags': tags,
            'physical_location': physicalLocation.trim(),
            'latitude': latitude,
            'longitude': longitude,
            'is_borrowable': isBorrowable,
          })
          .select()
          .single();
      metadataCreated = true;

      await _supabase.storage
          .from(_storageBucket)
          .uploadBinary(
            _storageObjectKey(storagePath),
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );

      return CloudDocument.fromMap(
        Map<String, dynamic>.from(inserted),
        currentUserId: user.uid,
      );
    } catch (error) {
      if (metadataCreated) {
        try {
          await _supabase.storage.from(_storageBucket).remove([
            _storageObjectKey(storagePath),
          ]);
        } catch (cleanupError) {
          // Keep the original operation error; report failed compensation.
          debugPrint('Supabase Storage upload cleanup failed: $cleanupError');
        }
        try {
          await _supabase.from('documents').delete().eq('id', documentId);
        } catch (cleanupError) {
          debugPrint('Supabase metadata upload cleanup failed: $cleanupError');
        }
      }
      rethrow;
    }
  }

  Future<void> updateDocument({
    required String documentId,
    required String title,
    required String description,
    required List<String> tags,
    required String physicalLocation,
    required double? latitude,
    required double? longitude,
    required bool isBorrowable,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const CloudOperationException(
        'Tiêu đề tài liệu không được để trống.',
      );
    }
    _validateCoordinates(latitude, longitude);
    await _supabase
        .from('documents')
        .update({
          'title': normalizedTitle,
          'description': description.trim(),
          'tags': tags,
          'physical_location': physicalLocation.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'is_borrowable': isBorrowable,
        })
        .eq('id', documentId)
        .select('id')
        .single();
  }

  Future<List<String>> getInterests() async {
    final row = await _supabase
        .from('users')
        .select('interests')
        .eq('id', _user.uid)
        .single();
    return List<String>.from(row['interests'] as List? ?? const []);
  }

  Future<void> saveInterests(String value) async {
    final tags = value
        .split(',')
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    await _supabase
        .from('users')
        .update({'interests': tags})
        .eq('id', _user.uid);
  }

  Future<bool> downloadDocument(CloudDocument document) async {
    final bytes = await _supabase.storage
        .from(_storageBucket)
        .download(_storageObjectKey(document.storagePath));
    if (bytes.isEmpty) {
      throw const CloudOperationException('Không đọc được dữ liệu tệp.');
    }

    final savedFile = await FilePicker.saveFile(
      dialogTitle: 'Lưu tài liệu',
      fileName: document.fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: document.mimeType,
    );
    if (savedFile != null) {
      try {
        await _supabase.rpc(
          'record_document_activity',
          params: {'p_document_id': document.id, 'p_action': 'download'},
        );
      } catch (error) {
        debugPrint('Activity recording failed: $error');
      }
    }
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
    await _sendCloudNotification(
      event: 'document_shared',
      resourceId: documentId,
      recipientId: permission.userId,
      savedAction: 'Quyền chia sẻ đã được cấp',
    );
    return permission;
  }

  Future<void> revokePermission({
    required String documentId,
    required DocumentPermission permission,
  }) async {
    await _supabase.rpc(
      'revoke_document_permission',
      params: {'p_document_id': documentId, 'p_user_id': permission.userId},
    );
  }

  Future<List<CloudBorrowRequest>> getBorrowRequests() async {
    final userId = _user.uid;
    final responses = await Future.wait<dynamic>([
      _supabase
          .from('borrow_requests')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: false),
      _supabase
          .from('borrow_requests')
          .select()
          .eq('requester_id', userId)
          .order('created_at', ascending: false),
    ]);
    final rows = <String, Map<String, dynamic>>{};
    for (final response in responses) {
      for (final row in _asRows(response)) {
        rows[row['id'] as String] = row;
      }
    }
    return rows.values.map(CloudBorrowRequest.fromMap).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> searchBorrowableDocuments({
    String query = '',
    bool recommended = false,
  }) async {
    final response = await _supabase.rpc(
      recommended
          ? 'recommend_borrowable_documents'
          : 'search_borrowable_documents',
      params: {'p_query': query.trim()},
    );
    return _asRows(response);
  }

  Future<void> requestBorrow({
    required String documentId,
    String message = '',
  }) async {
    final response = await _supabase.rpc(
      'request_document_borrow',
      params: {'p_document_id': documentId, 'p_message': message.trim()},
    );
    final rows = _asRows(response);
    if (rows.isEmpty) {
      throw const CloudOperationException(
        'Không nhận được thông tin yêu cầu mượn vừa tạo.',
      );
    }
    await _sendCloudNotification(
      event: 'borrow_requested',
      resourceId: rows.first['id'] as String,
      savedAction: 'Yêu cầu mượn đã được lưu',
    );
  }

  Future<void> respondToBorrowRequest(
    CloudBorrowRequest request, {
    required bool approve,
  }) async {
    final response = await _supabase.rpc(
      'respond_document_borrow',
      params: {
        'p_request_id': request.id,
        'p_status': approve ? 'approved' : 'rejected',
      },
    );
    final rows = _asRows(response);
    if (rows.isEmpty) {
      throw const CloudOperationException(
        'Không nhận được trạng thái mới của yêu cầu mượn.',
      );
    }
    await _sendCloudNotification(
      event: 'borrow_responded',
      resourceId: request.id,
      savedAction: approve
          ? 'Yêu cầu mượn đã được chấp nhận'
          : 'Yêu cầu mượn đã bị từ chối',
    );
  }

  Future<void> _sendCloudNotification({
    required String event,
    required String resourceId,
    String? recipientId,
    required String savedAction,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-cloud-notification',
        body: {
          'event': event,
          'resource_id': resourceId,
          'recipient_id': ?recipientId,
        },
      );
    } catch (error) {
      debugPrint('Notification delivery failed after $savedAction: $error');
      onNotificationWarning?.call('$savedAction; chưa gửi được thông báo đẩy.');
    }
  }

  static List<Map<String, dynamic>> _asRows(dynamic response) {
    if (response is! List) return const [];
    return response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  static void _validateCoordinates(double? latitude, double? longitude) {
    if ((latitude == null) != (longitude == null) ||
        (latitude != null &&
            (!latitude.isFinite || latitude < -90 || latitude > 90)) ||
        (longitude != null &&
            (!longitude.isFinite || longitude < -180 || longitude > 180))) {
      throw const CloudOperationException('Tọa độ vị trí không hợp lệ.');
    }
  }

  static String _safeFileName(String original) {
    final sanitized = original
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return sanitized.isEmpty ? 'document.bin' : sanitized;
  }

  static String _storageObjectKey(String storagePath) {
    const prefix = '$_storageBucket/';
    final segments = storagePath.split('/');
    if (!storagePath.startsWith(prefix) ||
        segments.length != 4 ||
        segments.any((segment) => segment.isEmpty)) {
      throw const CloudOperationException(
        'Đường dẫn tệp trên Supabase Storage không hợp lệ.',
      );
    }
    return segments.skip(1).join('/');
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
