enum CloudAccessLevel { owner, editor, viewer }

extension CloudAccessLevelX on CloudAccessLevel {
  String get databaseValue => switch (this) {
    CloudAccessLevel.owner => 'owner',
    CloudAccessLevel.editor => 'editor',
    CloudAccessLevel.viewer => 'viewer',
  };

  String get label => switch (this) {
    CloudAccessLevel.owner => 'Chủ sở hữu',
    CloudAccessLevel.editor => 'Có thể chỉnh sửa',
    CloudAccessLevel.viewer => 'Chỉ xem',
  };

  static CloudAccessLevel fromDatabase(String? value) => switch (value) {
    'owner' => CloudAccessLevel.owner,
    'editor' => CloudAccessLevel.editor,
    _ => CloudAccessLevel.viewer,
  };
}

class CloudDocument {
  const CloudDocument({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.fileName,
    required this.storagePath,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.createdAt,
    required this.updatedAt,
    required this.accessLevel,
    this.storageRoom,
    this.shelfCode,
    this.boxNumber,
    this.latitude,
    this.longitude,
    this.address,
    this.tags = const [],
  });

  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String fileName;
  final String storagePath;
  final int fileSizeBytes;
  final String mimeType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CloudAccessLevel accessLevel;
  final String? storageRoom;
  final String? shelfCode;
  final String? boxNumber;
  final double? latitude;
  final double? longitude;
  final String? address;
  final List<String> tags;

  bool get canEdit =>
      accessLevel == CloudAccessLevel.owner ||
      accessLevel == CloudAccessLevel.editor;
  bool get isOwner => accessLevel == CloudAccessLevel.owner;

  factory CloudDocument.fromMap(
    Map<String, dynamic> map, {
    required String currentUserId,
    String? grantedAccess,
  }) {
    final ownerId = map['owner_id'] as String;
    return CloudDocument(
      id: map['id'] as String,
      ownerId: ownerId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      fileName: map['file_name'] as String? ?? '',
      storagePath: map['storage_path'] as String? ?? '',
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      mimeType: map['mime_type'] as String? ?? 'application/octet-stream',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      accessLevel: ownerId == currentUserId
          ? CloudAccessLevel.owner
          : CloudAccessLevelX.fromDatabase(grantedAccess),
      storageRoom: map['storage_room'] as String?,
      shelfCode: map['shelf_code'] as String?,
      boxNumber: map['box_number'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      address: map['address'] as String?,
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

class DocumentPermission {
  const DocumentPermission({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.accessLevel,
  });

  final String userId;
  final String email;
  final String displayName;
  final CloudAccessLevel accessLevel;

  factory DocumentPermission.fromMap(Map<String, dynamic> map) {
    return DocumentPermission(
      userId: map['user_id'] as String,
      email: map['email'] as String? ?? '',
      displayName: map['display_name'] as String? ?? '',
      accessLevel: CloudAccessLevelX.fromDatabase(
        map['access_level'] as String?,
      ),
    );
  }
}

class BorrowRequestEntity {
  const BorrowRequestEntity({
    required this.id,
    required this.documentId,
    required this.requesterId,
    required this.status,
    required this.borrowDate,
    required this.dueDate,
    this.notes,
    required this.createdAt,
    this.documentTitle,
    this.requesterEmail,
    this.requesterName,
  });

  final String id;
  final String documentId;
  final String requesterId;
  final String status;
  final DateTime borrowDate;
  final DateTime dueDate;
  final String? notes;
  final DateTime createdAt;
  final String? documentTitle;
  final String? requesterEmail;
  final String? requesterName;

  String get statusLabel => switch (status) {
    'pending' => 'Chờ duyệt',
    'approved' => 'Đã duyệt',
    'rejected' => 'Từ chối',
    'returned' => 'Đã trả',
    _ => status,
  };

  factory BorrowRequestEntity.fromMap(Map<String, dynamic> map) {
    final doc = map['documents'] as Map<String, dynamic>?;
    final user = map['users'] as Map<String, dynamic>?;
    return BorrowRequestEntity(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      requesterId: map['requester_id'] as String,
      status: map['status'] as String? ?? 'pending',
      borrowDate: DateTime.tryParse(map['borrow_date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      dueDate: DateTime.tryParse(map['due_date'] as String? ?? '')?.toLocal() ?? DateTime.now().add(const Duration(days: 7)),
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      documentTitle: doc?['title'] as String?,
      requesterEmail: user?['email'] as String?,
      requesterName: user?['display_name'] as String?,
    );
  }
}

class RecommendedDocumentEntity {
  const RecommendedDocumentEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.fileName,
    required this.tags,
    this.storageRoom,
    this.shelfCode,
    this.boxNumber,
    this.address,
    required this.matchedTags,
    required this.similarityScore,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String fileName;
  final List<String> tags;
  final String? storageRoom;
  final String? shelfCode;
  final String? boxNumber;
  final String? address;
  final List<String> matchedTags;
  final double similarityScore;
  final DateTime createdAt;

  factory RecommendedDocumentEntity.fromMap(Map<String, dynamic> map) {
    return RecommendedDocumentEntity(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      fileName: map['file_name'] as String? ?? '',
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      storageRoom: map['storage_room'] as String?,
      shelfCode: map['shelf_code'] as String?,
      boxNumber: map['box_number'] as String?,
      address: map['address'] as String?,
      matchedTags: (map['matched_tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      similarityScore: (map['similarity_score'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

