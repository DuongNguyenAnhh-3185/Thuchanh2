import 'package:flutter/material.dart';

/// Trạng thái yêu cầu mượn tài liệu vật lý
enum BorrowStatus {
  pending,
  approved,
  rejected,
  returned,
}

extension BorrowStatusX on BorrowStatus {
  String get value => switch (this) {
    BorrowStatus.pending => 'pending',
    BorrowStatus.approved => 'approved',
    BorrowStatus.rejected => 'rejected',
    BorrowStatus.returned => 'returned',
  };

  String get label => switch (this) {
    BorrowStatus.pending => 'Chờ duyệt',
    BorrowStatus.approved => 'Đã duyệt',
    BorrowStatus.rejected => 'Đã từ chối',
    BorrowStatus.returned => 'Đã hoàn trả',
  };

  Color get color => switch (this) {
    BorrowStatus.pending => Colors.orange,
    BorrowStatus.approved => Colors.green,
    BorrowStatus.rejected => Colors.red,
    BorrowStatus.returned => Colors.blueGrey,
  };

  IconData get icon => switch (this) {
    BorrowStatus.pending => Icons.hourglass_top_rounded,
    BorrowStatus.approved => Icons.check_circle_outline,
    BorrowStatus.rejected => Icons.cancel_outlined,
    BorrowStatus.returned => Icons.assignment_turned_in_outlined,
  };

  static BorrowStatus fromString(String? val) => switch (val?.toLowerCase()) {
    'approved' => BorrowStatus.approved,
    'rejected' => BorrowStatus.rejected,
    'returned' => BorrowStatus.returned,
    _ => BorrowStatus.pending,
  };
}

/// Model yêu cầu mượn tài liệu vật lý (Bảng `borrow_requests`)
class BorrowRequestModel {
  const BorrowRequestModel({
    required this.id,
    required this.documentId,
    required this.requesterUid,
    required this.status,
    required this.borrowDate,
    this.dueDate,
    this.notes = '',
    required this.createdAt,
    this.documentTitle,
    this.storageRoom,
    this.shelfCode,
    this.boxNumber,
    this.address,
    this.latitude,
    this.longitude,
    this.ownerId,
    this.requesterEmail,
    this.requesterName,
  });

  final String id;
  final String documentId;
  final String requesterUid;
  final String status;
  final DateTime borrowDate;
  final DateTime? dueDate;
  final String notes;
  final DateTime createdAt;

  // Joined properties từ bảng `documents` và `users`
  final String? documentTitle;
  final String? storageRoom;
  final String? shelfCode;
  final String? boxNumber;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? ownerId;
  final String? requesterEmail;
  final String? requesterName;

  BorrowStatus get statusEnum => BorrowStatusX.fromString(status);
  bool get isPending => statusEnum == BorrowStatus.pending;
  bool get isApproved => statusEnum == BorrowStatus.approved;
  bool get isRejected => statusEnum == BorrowStatus.rejected;
  bool get isReturned => statusEnum == BorrowStatus.returned;

  String get locationSummary {
    final parts = <String>[];
    if (storageRoom != null && storageRoom!.isNotEmpty) parts.add(storageRoom!);
    if (shelfCode != null && shelfCode!.isNotEmpty) parts.add('Kệ $shelfCode');
    if (boxNumber != null && boxNumber!.isNotEmpty) parts.add('Hộp $boxNumber');
    return parts.isEmpty ? 'Chưa rõ vị trí lưu kho' : parts.join(' - ');
  }

  factory BorrowRequestModel.fromMap(Map<String, dynamic> map) {
    final docData = map['documents'] as Map<String, dynamic>?;
    final userData = map['users'] as Map<String, dynamic>?;

    return BorrowRequestModel(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      requesterUid: (map['requester_uid'] ?? map['requester_id'] ?? '') as String,
      status: map['status'] as String? ?? 'pending',
      borrowDate: map['borrow_date'] != null
          ? DateTime.parse(map['borrow_date'] as String).toLocal()
          : DateTime.now(),
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String).toLocal()
          : null,
      notes: map['notes'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String).toLocal()
          : DateTime.now(),
      documentTitle: docData?['title'] as String?,
      storageRoom: docData?['storage_room'] as String?,
      shelfCode: docData?['shelf_code'] as String?,
      boxNumber: docData?['box_number'] as String?,
      address: docData?['address'] as String?,
      latitude: (docData?['latitude'] as num?)?.toDouble(),
      longitude: (docData?['longitude'] as num?)?.toDouble(),
      ownerId: (map['owner_id'] ?? docData?['owner_id']) as String?,
      requesterEmail: userData?['email'] as String?,
      requesterName: userData?['display_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'document_id': documentId,
      if (ownerId != null) 'owner_id': ownerId,
      'requester_id': requesterUid,
      'requester_uid': requesterUid,
      'status': status,
      'borrow_date': borrowDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'notes': notes,
    };
  }
}

/// Model chia sẻ tài liệu số (Bảng `document_shares`)
class DocumentShareModel {
  const DocumentShareModel({
    required this.id,
    required this.documentId,
    required this.sharedWithUid,
    required this.permission,
    required this.createdAt,
    this.documentTitle,
    this.recipientEmail,
  });

  final String id;
  final String documentId;
  final String sharedWithUid;
  final String permission; // 'view' hoặc 'edit'
  final DateTime createdAt;
  final String? documentTitle;
  final String? recipientEmail;

  bool get canEdit => permission.toLowerCase() == 'edit';
  String get permissionLabel => canEdit ? 'Có thể chỉnh sửa' : 'Chỉ xem';

  factory DocumentShareModel.fromMap(Map<String, dynamic> map) {
    final docData = map['documents'] as Map<String, dynamic>?;
    final userData = map['users'] as Map<String, dynamic>?;

    return DocumentShareModel(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      sharedWithUid: map['shared_with_uid'] as String,
      permission: map['permission'] as String? ?? 'view',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String).toLocal()
          : DateTime.now(),
      documentTitle: docData?['title'] as String?,
      recipientEmail: userData?['email'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'document_id': documentId,
      'shared_with_uid': sharedWithUid,
      'permission': permission,
    };
  }
}

/// Model tài liệu gợi ý từ thuật toán RPC `get_recommended_documents`
class RecommendedDocumentModel {
  const RecommendedDocumentModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.ownerId,
    this.storageRoom,
    this.shelfCode,
    this.boxNumber,
    this.latitude,
    this.longitude,
    this.address,
    this.tags = const [],
    this.matchedTags = const [],
    this.matchedCount = 0,
  });

  final String id;
  final String title;
  final String description;
  final String ownerId;
  final String? storageRoom;
  final String? shelfCode;
  final String? boxNumber;
  final double? latitude;
  final double? longitude;
  final String? address;
  final List<String> tags;
  final List<String> matchedTags;
  final int matchedCount;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude != 0.0 &&
      longitude != 0.0;

  String get locationSummary {
    final parts = <String>[];
    if (storageRoom != null && storageRoom!.isNotEmpty) parts.add(storageRoom!);
    if (shelfCode != null && shelfCode!.isNotEmpty) parts.add('Kệ $shelfCode');
    if (boxNumber != null && boxNumber!.isNotEmpty) parts.add('Hộp $boxNumber');
    return parts.isEmpty ? 'Chưa định vị kho' : parts.join(' - ');
  }

  factory RecommendedDocumentModel.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString().trim()).toList();
      return [];
    }

    return RecommendedDocumentModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Tài liệu không tên',
      description: map['description'] as String? ?? '',
      ownerId: map['owner_id'] as String? ?? '',
      storageRoom: map['storage_room'] as String?,
      shelfCode: map['shelf_code'] as String?,
      boxNumber: map['box_number'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      address: map['address'] as String?,
      tags: parseList(map['tags']),
      matchedTags: parseList(map['matched_tags']),
      matchedCount: (map['matched_count'] as num?)?.toInt() ?? 0,
    );
  }
}
