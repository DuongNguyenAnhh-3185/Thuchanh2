import '../core/constants/app_constants.dart';
import '../core/utils/uuid_helper.dart';
import '../domain/entities/attachment_entity.dart';
import '../domain/entities/document_entity.dart';
import '../domain/repositories/i_document_repository.dart';

/// Dịch vụ nghiệp vụ Quản lý Tài liệu Học tập (Application / Service Layer)
/// Kế thừa kiến trúc Cashew: tách biệt hoàn toàn business rules khỏi UI và SQLite
class DocumentService {
  final IDocumentRepository documentRepository;

  DocumentService({required this.documentRepository});

  Future<List<DocumentEntity>> getAllDocuments({bool includeDeleted = false}) async {
    return await documentRepository.getAllDocuments(includeDeleted: includeDeleted);
  }

  Stream<List<DocumentEntity>> watchAllDocuments({bool includeDeleted = false}) {
    return documentRepository.watchAllDocuments(includeDeleted: includeDeleted);
  }

  Future<DocumentEntity?> getDocumentById(String documentPk) async {
    return await documentRepository.getDocumentById(documentPk);
  }

  /// Thêm hoặc cập nhật tài liệu với Validation nghiệp vụ
  Future<DocumentEntity> saveDocument({
    String? documentPk,
    required String subjectFk,
    required String title,
    required String documentType,
    String note = '',
    String studyStatus = AppConstants.statusNotStarted,
    int priority = AppConstants.priorityMedium,
    String tags = '',
    List<AttachmentEntity> attachments = const [],
  }) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('Tiêu đề tài liệu không được để trống.');
    }
    if (subjectFk.trim().isEmpty) {
      throw ArgumentError('Vui lòng chọn môn học cho tài liệu.');
    }
    if (!AppConstants.documentTypes.contains(documentType)) {
      throw ArgumentError('Loại tài liệu không hợp lệ: $documentType');
    }

    final isNew = documentPk == null || documentPk.isEmpty;
    final pk = isNew ? UuidHelper.generate() : documentPk;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Lấy thông tin thời gian tạo ban đầu nếu là cập nhật
    int createdAt = now;
    if (!isNew) {
      final existing = await getDocumentById(pk);
      if (existing != null) {
        createdAt = existing.dateTimeCreated;
      }
    }

    // Đảm bảo các tệp đính kèm đều có UUID và liên kết khóa ngoại documentFk
    final preparedAttachments = attachments.map((att) {
      final attPk = att.attachmentPk.isEmpty ? UuidHelper.generate() : att.attachmentPk;
      return att.copyWith(
        attachmentPk: attPk,
        documentFk: pk,
        dateTimeCreated: att.dateTimeCreated == 0 ? now : att.dateTimeCreated,
      );
    }).toList();

    final document = DocumentEntity(
      documentPk: pk,
      subjectFk: subjectFk,
      title: title.trim(),
      documentType: documentType,
      note: note.trim(),
      studyStatus: studyStatus,
      priority: priority,
      tags: tags.trim(),
      isDeleted: false,
      dateTimeCreated: createdAt,
      dateTimeModified: now,
      attachments: preparedAttachments,
    );

    if (isNew) {
      await documentRepository.insertDocument(document);
    } else {
      await documentRepository.updateDocument(document);
    }

    return document;
  }

  /// Cập nhật nhanh trạng thái học tập (Chưa học -> Đang học -> Đã hoàn thành)
  Future<void> updateStudyStatus(String documentPk, String newStatus) async {
    final doc = await getDocumentById(documentPk);
    if (doc != null) {
      final updated = doc.copyWith(
        studyStatus: newStatus,
        dateTimeModified: DateTime.now().millisecondsSinceEpoch,
      );
      await documentRepository.updateDocument(updated);
    }
  }

  /// Xóa mềm tài liệu (Soft delete)
  Future<void> softDeleteDocument(String documentPk) async {
    await documentRepository.softDeleteDocument(documentPk);
  }

  /// Khôi phục tài liệu từ thùng rác
  Future<void> restoreDocument(String documentPk) async {
    await documentRepository.restoreDocument(documentPk);
  }

  /// Xóa vĩnh viễn
  Future<void> permanentlyDeleteDocument(String documentPk) async {
    await documentRepository.permanentlyDeleteDocument(documentPk);
  }
}
