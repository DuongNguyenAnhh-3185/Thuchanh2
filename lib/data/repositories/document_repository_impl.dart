import '../../core/utils/uuid_helper.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/i_document_repository.dart';
import '../daos/delete_log_dao.dart';
import '../daos/document_dao.dart';
import '../models/delete_log_model.dart';
import '../models/document_model.dart';

/// Triển khai IDocumentRepository theo chuẩn Clean Architecture
/// Tách rời hoàn toàn giao diện khỏi chi tiết SQLite
class DocumentRepositoryImpl implements IDocumentRepository {
  final DocumentDao _documentDao;
  final DeleteLogDao _deleteLogDao;

  DocumentRepositoryImpl({
    DocumentDao? documentDao,
    DeleteLogDao? deleteLogDao,
  })  : _documentDao = documentDao ?? DocumentDao(),
        _deleteLogDao = deleteLogDao ?? DeleteLogDao();

  @override
  Future<List<DocumentEntity>> getAllDocuments({bool includeDeleted = false}) async {
    return await _documentDao.getAllDocuments(includeDeleted: includeDeleted);
  }

  @override
  Stream<List<DocumentEntity>> watchAllDocuments({bool includeDeleted = false}) {
    return _documentDao.watchAllDocuments(includeDeleted: includeDeleted);
  }

  @override
  Future<DocumentEntity?> getDocumentById(String documentPk) async {
    return await _documentDao.getDocumentById(documentPk);
  }

  @override
  Future<List<DocumentEntity>> getDocumentsBySubject(String subjectFk) async {
    return await _documentDao.getDocumentsBySubject(subjectFk);
  }

  @override
  Future<void> insertDocument(DocumentEntity document) async {
    final model = DocumentModel.fromEntity(document);
    await _documentDao.insertDocument(model);
  }

  @override
  Future<void> updateDocument(DocumentEntity document) async {
    final model = DocumentModel.fromEntity(document);
    await _documentDao.updateDocument(model);
  }

  @override
  Future<void> softDeleteDocument(String documentPk) async {
    // 1. Đánh dấu isDeleted = 1 trong bảng documents
    await _documentDao.setDeletedStatus(documentPk, true);

    // 2. Ghi nhật ký vào DeleteLogs (kế thừa kỹ thuật Cashew)
    final log = DeleteLogModel(
      logPk: UuidHelper.generate(),
      entityPk: documentPk,
      entityType: 'Document',
      dateTimeDeleted: DateTime.now().millisecondsSinceEpoch,
    );
    await _deleteLogDao.insertLog(log);
  }

  @override
  Future<void> restoreDocument(String documentPk) async {
    await _documentDao.setDeletedStatus(documentPk, false);
  }

  @override
  Future<void> permanentlyDeleteDocument(String documentPk) async {
    await _documentDao.permanentlyDeleteDocument(documentPk);
  }

  @override
  Future<List<DocumentEntity>> searchAndFilterDocuments({
    String? query,
    String? subjectFk,
    String? documentType,
    String? studyStatus,
  }) async {
    return await _documentDao.searchAndFilter(
      query: query,
      subjectFk: subjectFk,
      documentType: documentType,
      studyStatus: studyStatus,
    );
  }
}
