import '../../domain/entities/document_entity.dart';
import 'attachment_model.dart';
import 'subject_model.dart';

/// Model ánh xạ bảng 'documents' trong CSDL SQLite
class DocumentModel extends DocumentEntity {
  const DocumentModel({
    required super.documentPk,
    required super.subjectFk,
    required super.title,
    required super.documentType,
    super.note = '',
    super.studyStatus = 'Chưa học',
    super.priority = 2,
    super.tags = '',
    super.isDeleted = false,
    required super.dateTimeCreated,
    required super.dateTimeModified,
    super.subject,
    super.attachments = const [],
  });

  /// Chuyển đổi từ Map (SQLite record) sang Model
  factory DocumentModel.fromMap(
    Map<String, dynamic> map, {
    SubjectModel? subject,
    List<AttachmentModel> attachments = const [],
  }) {
    return DocumentModel(
      documentPk: map['documentPk'] as String,
      subjectFk: map['subjectFk'] as String,
      title: map['title'] as String,
      documentType: map['documentType'] as String,
      note: map['note'] as String? ?? '',
      studyStatus: map['studyStatus'] as String? ?? 'Chưa học',
      priority: map['priority'] as int? ?? 2,
      tags: map['tags'] as String? ?? '',
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      dateTimeCreated: map['dateTimeCreated'] as int,
      dateTimeModified: map['dateTimeModified'] as int,
      subject: subject,
      attachments: attachments,
    );
  }

  /// Chuyển sang Map để insert / update vào SQLite
  Map<String, dynamic> toMap() {
    return {
      'documentPk': documentPk,
      'subjectFk': subjectFk,
      'title': title,
      'documentType': documentType,
      'note': note,
      'studyStatus': studyStatus,
      'priority': priority,
      'tags': tags,
      'isDeleted': isDeleted ? 1 : 0,
      'dateTimeCreated': dateTimeCreated,
      'dateTimeModified': dateTimeModified,
    };
  }

  factory DocumentModel.fromEntity(DocumentEntity entity) {
    return DocumentModel(
      documentPk: entity.documentPk,
      subjectFk: entity.subjectFk,
      title: entity.title,
      documentType: entity.documentType,
      note: entity.note,
      studyStatus: entity.studyStatus,
      priority: entity.priority,
      tags: entity.tags,
      isDeleted: entity.isDeleted,
      dateTimeCreated: entity.dateTimeCreated,
      dateTimeModified: entity.dateTimeModified,
      subject: entity.subject,
      attachments: entity.attachments,
    );
  }

  /// Trả về đối tượng thuần Domain Entity
  DocumentEntity toEntity() => DocumentEntity(
        documentPk: documentPk,
        subjectFk: subjectFk,
        title: title,
        documentType: documentType,
        note: note,
        studyStatus: studyStatus,
        priority: priority,
        tags: tags,
        isDeleted: isDeleted,
        dateTimeCreated: dateTimeCreated,
        dateTimeModified: dateTimeModified,
        subject: subject,
        attachments: attachments,
      );
}
