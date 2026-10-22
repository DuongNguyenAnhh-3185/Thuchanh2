import '../../domain/entities/attachment_entity.dart';

/// Model ánh xạ bảng 'attachments' trong CSDL SQLite
class AttachmentModel extends AttachmentEntity {
  const AttachmentModel({
    required super.attachmentPk,
    required super.documentFk,
    required super.fileName,
    required super.fileExtension,
    required super.localPath,
    required super.fileSizeBytes,
    required super.dateTimeCreated,
  });

  factory AttachmentModel.fromMap(Map<String, dynamic> map) {
    return AttachmentModel(
      attachmentPk: map['attachmentPk'] as String,
      documentFk: map['documentFk'] as String,
      fileName: map['fileName'] as String,
      fileExtension: map['fileExtension'] as String,
      localPath: map['localPath'] as String,
      fileSizeBytes: map['fileSizeBytes'] as int? ?? 0,
      dateTimeCreated: map['dateTimeCreated'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attachmentPk': attachmentPk,
      'documentFk': documentFk,
      'fileName': fileName,
      'fileExtension': fileExtension,
      'localPath': localPath,
      'fileSizeBytes': fileSizeBytes,
      'dateTimeCreated': dateTimeCreated,
    };
  }

  factory AttachmentModel.fromEntity(AttachmentEntity entity) {
    return AttachmentModel(
      attachmentPk: entity.attachmentPk,
      documentFk: entity.documentFk,
      fileName: entity.fileName,
      fileExtension: entity.fileExtension,
      localPath: entity.localPath,
      fileSizeBytes: entity.fileSizeBytes,
      dateTimeCreated: entity.dateTimeCreated,
    );
  }

  /// Trả về đối tượng thuần Domain Entity
  AttachmentEntity toEntity() => AttachmentEntity(
        attachmentPk: attachmentPk,
        documentFk: documentFk,
        fileName: fileName,
        fileExtension: fileExtension,
        localPath: localPath,
        fileSizeBytes: fileSizeBytes,
        dateTimeCreated: dateTimeCreated,
      );
}
