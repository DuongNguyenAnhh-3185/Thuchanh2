import 'attachment_entity.dart';
import 'subject_entity.dart';

/// Thực thể Tài liệu Học tập (Domain Entity cốt lõi)
class DocumentEntity {
  final String documentPk; // UUID v4
  final String subjectFk; // UUID khóa ngoại Môn học
  final String title; // Tiêu đề tài liệu
  final String documentType; // Bài giảng, Bài tập, Tham khảo, Đề thi
  final String note; // Mô tả, ghi chú nội dung
  final String studyStatus; // Chưa học, Đang học, Đã hoàn thành
  final int priority; // 1: Thấp, 2: TB, 3: Cao
  final String tags; // Chuỗi các tags phân cách bởi dấu phẩy
  final String physicalLocation;
  final double? latitude;
  final double? longitude;
  final bool isDeleted; // Soft-delete flag (chuẩn Cashew)
  final int dateTimeCreated; // Epoch ms
  final int dateTimeModified; // Epoch ms

  // Thực thể liên kết (Optional, nạp khi join dữ liệu)
  final SubjectEntity? subject;
  final List<AttachmentEntity> attachments;

  const DocumentEntity({
    required this.documentPk,
    required this.subjectFk,
    required this.title,
    required this.documentType,
    this.note = '',
    this.studyStatus = 'Chưa học',
    this.priority = 2,
    this.tags = '',
    this.physicalLocation = '',
    this.latitude,
    this.longitude,
    this.isDeleted = false,
    required this.dateTimeCreated,
    required this.dateTimeModified,
    this.subject,
    this.attachments = const [],
  });

  DocumentEntity copyWith({
    String? documentPk,
    String? subjectFk,
    String? title,
    String? documentType,
    String? note,
    String? studyStatus,
    int? priority,
    String? tags,
    String? physicalLocation,
    double? latitude,
    double? longitude,
    bool? isDeleted,
    int? dateTimeCreated,
    int? dateTimeModified,
    SubjectEntity? subject,
    List<AttachmentEntity>? attachments,
  }) {
    return DocumentEntity(
      documentPk: documentPk ?? this.documentPk,
      subjectFk: subjectFk ?? this.subjectFk,
      title: title ?? this.title,
      documentType: documentType ?? this.documentType,
      note: note ?? this.note,
      studyStatus: studyStatus ?? this.studyStatus,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      physicalLocation: physicalLocation ?? this.physicalLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDeleted: isDeleted ?? this.isDeleted,
      dateTimeCreated: dateTimeCreated ?? this.dateTimeCreated,
      dateTimeModified: dateTimeModified ?? this.dateTimeModified,
      subject: subject ?? this.subject,
      attachments: attachments ?? this.attachments,
    );
  }
}
