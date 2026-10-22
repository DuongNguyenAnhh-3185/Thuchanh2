import 'data/daos/delete_log_dao.dart';
import 'data/daos/document_dao.dart';
import 'data/daos/subject_dao.dart';
import 'data/datasources/local/app_database.dart';
import 'data/repositories/document_repository_impl.dart';
import 'data/repositories/subject_repository_impl.dart';
import 'domain/repositories/i_document_repository.dart';
import 'domain/repositories/i_subject_repository.dart';
import 'services/document_service.dart';
import 'services/search_service.dart';
import 'services/subject_service.dart';

/// Bộ quản lý định vị dịch vụ (Service Locator / Dependency Injection)
/// Đảm bảo tính lỏng lẻo (Loose Coupling) giữa các lớp kiến trúc
class ServiceLocator {
  static final ServiceLocator instance = ServiceLocator._internal();

  ServiceLocator._internal();

  // 1. Data Layer Singletons
  late final AppDatabase database;
  late final SubjectDao subjectDao;
  late final DocumentDao documentDao;
  late final DeleteLogDao deleteLogDao;

  // 2. Repository Layer Singletons
  late final ISubjectRepository subjectRepository;
  late final IDocumentRepository documentRepository;

  // 3. Service Layer Singletons
  late final SubjectService subjectService;
  late final DocumentService documentService;
  late final SearchService searchService;

  bool _initialized = false;

  /// Khởi tạo toàn bộ các thành phần theo đúng thứ tự phụ thuộc
  Future<void> initialize() async {
    if (_initialized) return;

    // Tầng Data
    database = AppDatabase.instance;
    await database.database; // Kích hoạt mở SQLite và khởi tạo bảng

    subjectDao = SubjectDao(appDatabase: database);
    documentDao = DocumentDao(appDatabase: database);
    deleteLogDao = DeleteLogDao(appDatabase: database);

    // Tầng Domain / Repository
    subjectRepository = SubjectRepositoryImpl(subjectDao: subjectDao);
    documentRepository = DocumentRepositoryImpl(
      documentDao: documentDao,
      deleteLogDao: deleteLogDao,
    );

    // Tầng Application / Service
    subjectService = SubjectService(subjectRepository: subjectRepository);
    documentService = DocumentService(documentRepository: documentRepository);
    searchService = SearchService(documentRepository: documentRepository);

    // Nạp dữ liệu mẫu nếu bảng documents trống
    await database.seedSampleDocuments();

    _initialized = true;
  }
}
