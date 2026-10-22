import '../entities/document_entity.dart';

/// Hợp đồng giao tiếp (Interface) của Repository Tài liệu Học tập
abstract class IDocumentRepository {
  Future<List<DocumentEntity>> getAllDocuments({bool includeDeleted = false});
  Stream<List<DocumentEntity>> watchAllDocuments({bool includeDeleted = false});
  Future<DocumentEntity?> getDocumentById(String documentPk);
  Future<List<DocumentEntity>> getDocumentsBySubject(String subjectFk);
  Future<void> insertDocument(DocumentEntity document);
  Future<void> updateDocument(DocumentEntity document);
  Future<void> softDeleteDocument(String documentPk);
  Future<void> restoreDocument(String documentPk);
  Future<void> permanentlyDeleteDocument(String documentPk);
  Future<List<DocumentEntity>> searchAndFilterDocuments({
    String? query,
    String? subjectFk,
    String? documentType,
    String? studyStatus,
  });
}
