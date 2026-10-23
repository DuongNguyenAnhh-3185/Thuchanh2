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
    this.tags = const [],
    this.physicalLocation = '',
    this.latitude,
    this.longitude,
    this.isBorrowable = false,
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
  final List<String> tags;
  final String physicalLocation;
  final double? latitude;
  final double? longitude;
  final bool isBorrowable;

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
      tags: (map['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag.toString())
          .toList(growable: false),
      physicalLocation: map['physical_location'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isBorrowable: map['is_borrowable'] as bool? ?? false,
    );
  }
}

class CloudBorrowRequest {
  const CloudBorrowRequest({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    required this.ownerId,
    required this.requesterId,
    required this.requesterEmail,
    required this.requesterName,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String documentId;
  final String documentTitle;
  final String ownerId;
  final String requesterId;
  final String requesterEmail;
  final String requesterName;
  final String message;
  final String status;
  final DateTime createdAt;

  bool isIncomingFor(String userId) => ownerId == userId;

  factory CloudBorrowRequest.fromMap(Map<String, dynamic> map) {
    return CloudBorrowRequest(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      documentTitle: map['document_title'] as String? ?? '',
      ownerId: map['owner_id'] as String,
      requesterId: map['requester_id'] as String,
      requesterEmail: map['requester_email'] as String? ?? '',
      requesterName: map['requester_name'] as String? ?? '',
      message: map['message'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
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
