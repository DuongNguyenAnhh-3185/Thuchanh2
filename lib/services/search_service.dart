import '../core/constants/app_constants.dart';
import '../domain/entities/document_entity.dart';
import '../domain/repositories/i_document_repository.dart';

/// Dịch vụ nghiệp vụ Tìm kiếm, Lọc và Thống kê Tiến độ (Application / Service Layer)
class SearchService {
  final IDocumentRepository documentRepository;

  SearchService({required this.documentRepository});

  /// Tìm kiếm & Lọc đa tiêu chí
  Future<List<DocumentEntity>> filterDocuments({
    String? query,
    String? subjectFk,
    String? documentType,
    String? studyStatus,
    String sortBy = 'date_desc', // date_desc, date_asc, title_asc, priority_desc
  }) async {
    final list = await documentRepository.searchAndFilterDocuments(
      query: query,
      subjectFk: subjectFk,
      documentType: documentType,
      studyStatus: studyStatus,
    );

    // Sắp xếp dữ liệu theo tùy chọn
    final result = List<DocumentEntity>.from(list);
    switch (sortBy) {
      case 'date_asc':
        result.sort((a, b) => a.dateTimeModified.compareTo(b.dateTimeModified));
        break;
      case 'title_asc':
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'priority_desc':
        result.sort((a, b) => b.priority.compareTo(a.priority));
        break;
      case 'date_desc':
      default:
        result.sort((a, b) => b.dateTimeModified.compareTo(a.dateTimeModified));
        break;
    }
    return result;
  }

  /// Tính toán số liệu thống kê học tập (phục vụ màn hình Dashboard kiểu Cashew)
  Future<Map<String, dynamic>> getLearningStatistics() async {
    final docs = await documentRepository.getAllDocuments(includeDeleted: false);
    final total = docs.length;

    int completed = 0;
    int inProgress = 0;
    int notStarted = 0;

    final Map<String, int> countByType = {};
    final Map<String, int> countBySubject = {};

    for (final doc in docs) {
      if (doc.studyStatus == AppConstants.statusCompleted) {
        completed++;
      } else if (doc.studyStatus == AppConstants.statusInProgress) {
        inProgress++;
      } else {
        notStarted++;
      }

      // Theo loại
      countByType[doc.documentType] = (countByType[doc.documentType] ?? 0) + 1;

      // Theo môn học
      final subjectName = doc.subject?.name ?? 'Chưa phân môn';
      countBySubject[subjectName] = (countBySubject[subjectName] ?? 0) + 1;
    }

    final double completionRate = total > 0 ? (completed / total) * 100 : 0.0;

    return {
      'totalDocuments': total,
      'completed': completed,
      'inProgress': inProgress,
      'notStarted': notStarted,
      'completionRate': completionRate,
      'countByType': countByType,
      'countBySubject': countBySubject,
    };
  }
}
