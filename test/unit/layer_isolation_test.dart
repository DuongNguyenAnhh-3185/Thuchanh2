import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_doc_manager/core/constants/app_constants.dart';
import 'package:study_doc_manager/core/utils/uuid_helper.dart';
import 'package:study_doc_manager/data/models/attachment_model.dart';
import 'package:study_doc_manager/data/models/delete_log_model.dart';
import 'package:study_doc_manager/data/models/document_model.dart';
import 'package:study_doc_manager/data/models/subject_model.dart';
import 'package:study_doc_manager/domain/entities/attachment_entity.dart';
import 'package:study_doc_manager/domain/entities/document_entity.dart';
import 'package:study_doc_manager/domain/entities/subject_entity.dart';
import 'package:study_doc_manager/domain/repositories/i_document_repository.dart';
import 'package:study_doc_manager/domain/repositories/i_subject_repository.dart';
import 'package:study_doc_manager/services/document_service.dart';
import 'package:study_doc_manager/services/search_service.dart';
import 'package:study_doc_manager/services/subject_service.dart';

// ============================================================================
// FAKE REPOSITORIES CHO VIỆC KIỂM THỬ CÔ LẬP (IN-MEMORY TEST DOUBLES)
// Triển khai đúng các Interfaces của Domain Layer mà KHÔNG dùng SQLite/Drift
// ============================================================================

class FakeDocumentRepository implements IDocumentRepository {
  final List<DocumentEntity> _storage = [];
  final StreamController<List<DocumentEntity>> _streamController =
      StreamController<List<DocumentEntity>>.broadcast();

  void _notify() {
    _streamController.add(List.unmodifiable(_storage.where((d) => !d.isDeleted)));
  }

  @override
  Future<List<DocumentEntity>> getAllDocuments({bool includeDeleted = false}) async {
    if (includeDeleted) {
      return List.from(_storage);
    }
    return _storage.where((d) => !d.isDeleted).toList();
  }

  @override
  Stream<List<DocumentEntity>> watchAllDocuments({bool includeDeleted = false}) {
    // Phát ngay giá trị hiện tại
    Future.microtask(() => _notify());
    return _streamController.stream;
  }

  @override
  Future<DocumentEntity?> getDocumentById(String documentPk) async {
    try {
      return _storage.firstWhere((d) => d.documentPk == documentPk);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DocumentEntity>> getDocumentsBySubject(String subjectFk) async {
    return _storage.where((d) => d.subjectFk == subjectFk && !d.isDeleted).toList();
  }

  @override
  Future<void> insertDocument(DocumentEntity document) async {
    _storage.add(document);
    _notify();
  }

  @override
  Future<void> updateDocument(DocumentEntity document) async {
    final idx = _storage.indexWhere((d) => d.documentPk == document.documentPk);
    if (idx != -1) {
      _storage[idx] = document;
      _notify();
    }
  }

  @override
  Future<void> softDeleteDocument(String documentPk) async {
    final idx = _storage.indexWhere((d) => d.documentPk == documentPk);
    if (idx != -1) {
      _storage[idx] = _storage[idx].copyWith(isDeleted: true);
      _notify();
    }
  }

  @override
  Future<void> restoreDocument(String documentPk) async {
    final idx = _storage.indexWhere((d) => d.documentPk == documentPk);
    if (idx != -1) {
      _storage[idx] = _storage[idx].copyWith(isDeleted: false);
      _notify();
    }
  }

  @override
  Future<void> permanentlyDeleteDocument(String documentPk) async {
    _storage.removeWhere((d) => d.documentPk == documentPk);
    _notify();
  }

  @override
  Future<List<DocumentEntity>> searchAndFilterDocuments({
    String? query,
    String? subjectFk,
    String? documentType,
    String? studyStatus,
  }) async {
    return _storage.where((doc) {
      if (doc.isDeleted) return false;
      if (subjectFk != null && subjectFk.isNotEmpty && doc.subjectFk != subjectFk) {
        return false;
      }
      if (documentType != null && documentType.isNotEmpty && doc.documentType != documentType) {
        return false;
      }
      if (studyStatus != null && studyStatus.isNotEmpty && doc.studyStatus != studyStatus) {
        return false;
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchTitle = doc.title.toLowerCase().contains(q);
        final matchNote = doc.note.toLowerCase().contains(q);
        final matchTags = doc.tags.toLowerCase().contains(q);
        if (!matchTitle && !matchNote && !matchTags) return false;
      }
      return true;
    }).toList();
  }

  void dispose() {
    _streamController.close();
  }
}

class FakeSubjectRepository implements ISubjectRepository {
  final List<SubjectEntity> _subjects = [];
  final StreamController<List<SubjectEntity>> _streamController =
      StreamController<List<SubjectEntity>>.broadcast();

  void _notify() {
    _streamController.add(List.unmodifiable(_subjects));
  }

  @override
  Future<List<SubjectEntity>> getAllSubjects() async {
    return List.from(_subjects);
  }

  @override
  Stream<List<SubjectEntity>> watchAllSubjects() {
    Future.microtask(() => _notify());
    return _streamController.stream;
  }

  @override
  Future<SubjectEntity?> getSubjectById(String subjectPk) async {
    try {
      return _subjects.firstWhere((s) => s.subjectPk == subjectPk);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> insertSubject(SubjectEntity subject) async {
    _subjects.add(subject);
    _notify();
  }

  @override
  Future<void> updateSubject(SubjectEntity subject) async {
    final idx = _subjects.indexWhere((s) => s.subjectPk == subject.subjectPk);
    if (idx != -1) {
      _subjects[idx] = subject;
      _notify();
    }
  }

  @override
  Future<void> deleteSubject(String subjectPk) async {
    _subjects.removeWhere((s) => s.subjectPk == subjectPk);
    _notify();
  }

  void dispose() {
    _streamController.close();
  }
}

// ============================================================================
// BƯỚC 4: BỘ TEST KIỂM THỬ TÍNH ĐÚNG ĐẮN CỦA VIỆC PHÂN TÁCH LOGIC GIỮA CÁC LỚP
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDocumentRepository fakeDocRepo;
  late FakeSubjectRepository fakeSubjectRepo;
  late DocumentService docService;
  late SubjectService subjectService;
  late SearchService searchService;

  setUp(() {
    fakeDocRepo = FakeDocumentRepository();
    fakeSubjectRepo = FakeSubjectRepository();
    docService = DocumentService(documentRepository: fakeDocRepo);
    subjectService = SubjectService(subjectRepository: fakeSubjectRepo);
    searchService = SearchService(documentRepository: fakeDocRepo);
  });

  tearDown(() {
    fakeDocRepo.dispose();
    fakeSubjectRepo.dispose();
  });

  group('NHÓM 1: KIỂM THỬ TÍNH ĐỘC LẬP TẦNG MIỀN (DOMAIN LAYER ISOLATION)', () {
    test('TC-ISO-01: DocumentEntity tính bất biến và copyWith hoạt động hoàn hảo', () {
      const doc = DocumentEntity(
        documentPk: 'doc-uuid-1',
        subjectFk: 'sub-uuid-1',
        title: 'Tài liệu Gốc',
        documentType: AppConstants.typeLecture,
        note: 'Ghi chú gốc',
        studyStatus: AppConstants.statusNotStarted,
        priority: AppConstants.priorityMedium,
        tags: 'dart, clean-arch',
        isDeleted: false,
        dateTimeCreated: 100000,
        dateTimeModified: 100000,
      );

      final modified = doc.copyWith(
        title: 'Tài liệu Đã Cập Nhật',
        studyStatus: AppConstants.statusCompleted,
        dateTimeModified: 200000,
      );

      // Đối tượng gốc không bị thay đổi (Immutability)
      expect(doc.title, equals('Tài liệu Gốc'));
      expect(doc.studyStatus, equals(AppConstants.statusNotStarted));
      expect(doc.dateTimeModified, equals(100000));

      // Đối tượng mới phản ánh đúng thuộc tính mới và giữ nguyên thuộc tính cũ
      expect(modified.documentPk, equals('doc-uuid-1'));
      expect(modified.subjectFk, equals('sub-uuid-1'));
      expect(modified.title, equals('Tài liệu Đã Cập Nhật'));
      expect(modified.studyStatus, equals(AppConstants.statusCompleted));
      expect(modified.dateTimeModified, equals(200000));
      expect(modified.tags, equals('dart, clean-arch'));
    });

    test('TC-ISO-02: SubjectEntity cấu hình màu sắc HEX và icon độc lập', () {
      const subject = SubjectEntity(
        subjectPk: 'sub-001',
        code: 'MOB101',
        name: 'Lập trình Di động 1',
        instructor: 'ThS. Nguyễn Văn A',
        colorHex: '#3B82F6',
        iconName: 'smartphone',
        dateTimeCreated: 1234567,
      );

      expect(subject.code, equals('MOB101'));
      expect(subject.colorHex.startsWith('#'), isTrue);
      expect(subject.iconName, equals('smartphone'));
      expect(subject.instructor, contains('Nguyễn Văn A'));
    });

    test('TC-ISO-03: AttachmentEntity lưu trữ đầy đủ thuộc tính tệp và khóa ngoại', () {
      const att = AttachmentEntity(
        attachmentPk: 'att-001',
        documentFk: 'doc-001',
        fileName: 'Bai_giang_Clean_Arch.pdf',
        fileExtension: 'pdf',
        localPath: '/data/user/0/com.example/files/Bai_giang_Clean_Arch.pdf',
        fileSizeBytes: 2621440, // 2.5 MB
        dateTimeCreated: 1727930000,
      );

      expect(att.fileExtension, equals('pdf'));
      expect(att.documentFk, equals('doc-001'));
      expect(att.fileSizeBytes, equals(2621440));
    });
  });

  group('NHÓM 2: KIỂM THỬ CÔ LẬP TẦNG DỊCH VỤ VỚI FAKE REPOSITORY (SERVICE LAYER ISOLATION)', () {
    test('TC-ISO-04: DocumentService validation bắt buộc tiêu đề rỗng', () async {
      expect(
        () => docService.saveDocument(
          subjectFk: 'sub-001',
          title: '   ',
          documentType: AppConstants.typeLecture,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Tiêu đề tài liệu không được để trống'),
        )),
      );
    });

    test('TC-ISO-05: DocumentService validation bắt buộc môn học và loại tài liệu', () async {
      // Thiếu môn học
      expect(
        () => docService.saveDocument(
          subjectFk: '',
          title: 'Đề thi cuối kỳ',
          documentType: AppConstants.typeExam,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Vui lòng chọn môn học'),
        )),
      );

      // Loại tài liệu không hợp lệ
      expect(
        () => docService.saveDocument(
          subjectFk: 'sub-001',
          title: 'Đề thi cuối kỳ',
          documentType: 'Loại Không Tồn Tại',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Loại tài liệu không hợp lệ'),
        )),
      );
    });

    test('TC-ISO-06: DocumentService tự động sinh UUID v4 và thời gian timestamps khi thêm mới', () async {
      final doc = await docService.saveDocument(
        subjectFk: 'sub-mob-001',
        title: 'Tài liệu Kiến trúc Phần mềm',
        documentType: AppConstants.typeLecture,
        note: 'Thực thi kiểm thử cô lập',
      );

      expect(doc.documentPk.isNotEmpty, isTrue);
      expect(UuidHelper.isValid(doc.documentPk), isTrue);
      expect(doc.dateTimeCreated, greaterThan(0));
      expect(doc.dateTimeModified, equals(doc.dateTimeCreated));
      expect(doc.isDeleted, isFalse);

      final stored = await docService.getDocumentById(doc.documentPk);
      expect(stored, isNotNull);
      expect(stored!.title, equals('Tài liệu Kiến trúc Phần mềm'));
    });

    test('TC-ISO-07: DocumentService chuyển đổi trạng thái học tập theo State Machine', () async {
      final doc = await docService.saveDocument(
        subjectFk: 'sub-001',
        title: 'Thực hành State Machine',
        documentType: AppConstants.typeAssignment,
        studyStatus: AppConstants.statusNotStarted,
      );

      // Chuyển sang Đang học
      await docService.updateStudyStatus(doc.documentPk, AppConstants.statusInProgress);
      var fetched = await docService.getDocumentById(doc.documentPk);
      expect(fetched!.studyStatus, equals(AppConstants.statusInProgress));

      // Chuyển sang Đã hoàn thành
      await docService.updateStudyStatus(doc.documentPk, AppConstants.statusCompleted);
      fetched = await docService.getDocumentById(doc.documentPk);
      expect(fetched!.studyStatus, equals(AppConstants.statusCompleted));
    });

    test('TC-ISO-08: DocumentService thực hiện Soft-Delete và kích hoạt Reactive Stream', () async {
      final doc = await docService.saveDocument(
        subjectFk: 'sub-001',
        title: 'Tài liệu Chuẩn bị Xóa mềm',
        documentType: AppConstants.typeReference,
      );

      // Kiểm tra danh sách hiển thị
      var activeDocs = await docService.getAllDocuments(includeDeleted: false);
      expect(activeDocs.length, equals(1));

      // Thực hiện Soft-delete
      await docService.softDeleteDocument(doc.documentPk);

      // Danh sách bình thường không còn tài liệu này
      activeDocs = await docService.getAllDocuments(includeDeleted: false);
      expect(activeDocs.isEmpty, isTrue);

      // Danh sách bao gồm xóa vẫn còn với isDeleted = true
      final allDocs = await docService.getAllDocuments(includeDeleted: true);
      expect(allDocs.length, equals(1));
      expect(allDocs.first.isDeleted, isTrue);
    });

    test('TC-ISO-09: DocumentService khôi phục tài liệu từ trạng thái xóa mềm', () async {
      final doc = await docService.saveDocument(
        subjectFk: 'sub-001',
        title: 'Tài liệu Khôi phục',
        documentType: AppConstants.typeExam,
      );

      await docService.softDeleteDocument(doc.documentPk);
      expect((await docService.getAllDocuments(includeDeleted: false)).isEmpty, isTrue);

      // Khôi phục
      await docService.restoreDocument(doc.documentPk);
      final activeDocs = await docService.getAllDocuments(includeDeleted: false);
      expect(activeDocs.length, equals(1));
      expect(activeDocs.first.isDeleted, isFalse);
    });

    test('TC-ISO-10: SearchService tìm kiếm Full-Text độc lập với SQLite FTS', () async {
      await docService.saveDocument(
        subjectFk: 'sub-001',
        title: 'Lập trình Flutter nâng cao với Bloc và Cashew',
        documentType: AppConstants.typeLecture,
        tags: 'dart, flutter, state',
      );
      await docService.saveDocument(
        subjectFk: 'sub-002',
        title: 'Cơ sở Dữ liệu Phân tán MongoDB',
        documentType: AppConstants.typeLecture,
        tags: 'nosql, database',
      );

      // Tìm từ khóa 'flutter'
      final results1 = await searchService.filterDocuments(query: 'flutter');
      expect(results1.length, equals(1));
      expect(results1.first.title, contains('Flutter'));

      // Tìm từ khóa trong tags 'database'
      final results2 = await searchService.filterDocuments(query: 'database');
      expect(results2.length, equals(1));
      expect(results2.first.title, contains('MongoDB'));

      // Tìm từ khóa không khớp
      final results3 = await searchService.filterDocuments(query: 'machine learning');
      expect(results3.isEmpty, isTrue);
    });

    test('TC-ISO-11: SearchService lọc kết hợp đa chiều (Subject + Type + Status)', () async {
      await docService.saveDocument(
        subjectFk: 'sub-mob',
        title: 'Bài tập 1 - Mobile',
        documentType: AppConstants.typeAssignment,
        studyStatus: AppConstants.statusCompleted,
      );
      await docService.saveDocument(
        subjectFk: 'sub-mob',
        title: 'Bài giảng 1 - Mobile',
        documentType: AppConstants.typeLecture,
        studyStatus: AppConstants.statusNotStarted,
      );
      await docService.saveDocument(
        subjectFk: 'sub-web',
        title: 'Bài tập 1 - Web',
        documentType: AppConstants.typeAssignment,
        studyStatus: AppConstants.statusCompleted,
      );

      // Lọc: Môn MOB + Loại Bài tập + Đã hoàn thành
      final filtered = await searchService.filterDocuments(
        subjectFk: 'sub-mob',
        documentType: AppConstants.typeAssignment,
        studyStatus: AppConstants.statusCompleted,
      );

      expect(filtered.length, equals(1));
      expect(filtered.first.title, equals('Bài tập 1 - Mobile'));
    });

    test('TC-ISO-12: SearchService tính toán số liệu thống kê Dashboard và tỷ lệ hoàn thành', () async {
      await docService.saveDocument(
        subjectFk: 'sub-01',
        title: 'Tài liệu 1',
        documentType: AppConstants.typeLecture,
        studyStatus: AppConstants.statusCompleted,
      );
      await docService.saveDocument(
        subjectFk: 'sub-01',
        title: 'Tài liệu 2',
        documentType: AppConstants.typeAssignment,
        studyStatus: AppConstants.statusInProgress,
      );
      await docService.saveDocument(
        subjectFk: 'sub-02',
        title: 'Tài liệu 3',
        documentType: AppConstants.typeExam,
        studyStatus: AppConstants.statusNotStarted,
      );
      await docService.saveDocument(
        subjectFk: 'sub-02',
        title: 'Tài liệu 4',
        documentType: AppConstants.typeExam,
        studyStatus: AppConstants.statusCompleted,
      );

      final stats = await searchService.getLearningStatistics();

      expect(stats['totalDocuments'], equals(4));
      expect(stats['completed'], equals(2));
      expect(stats['inProgress'], equals(1));
      expect(stats['notStarted'], equals(1));
      expect(stats['completionRate'], equals(50.0)); // 2/4 = 50%
      expect(stats['countByType'][AppConstants.typeExam], equals(2));
      expect(stats['countByType'][AppConstants.typeLecture], equals(1));
    });

    test('TC-ISO-13: SubjectService quản lý danh mục môn học với Repository giả lập', () async {
      await subjectService.createSubject(
        code: 'CS101',
        name: 'Nhập môn Khoa học Máy tính',
        instructor: 'TS. Trần B',
        colorHex: '#10B981',
      );

      final subjects = await subjectService.getAllSubjects();
      expect(subjects.length, equals(1));
      expect(subjects.first.code, equals('CS101'));
      expect(subjects.first.colorHex, equals('#10B981'));
    });
  });

  group('NHÓM 3: KIỂM THỬ TẦNG DỮ LIỆU & ÁNH XẠ (DATA LAYER MAPPING & SERIALIZATION)', () {
    test('TC-ISO-14: DocumentModel chuyển đổi 2 chiều Entity <-> Model bảo toàn 100% dữ liệu', () {
      const originalEntity = DocumentEntity(
        documentPk: 'doc-map-001',
        subjectFk: 'sub-map-001',
        title: 'Kiểm tra Mapping 2 chiều',
        documentType: AppConstants.typeExam,
        note: 'Ghi chú mapping',
        studyStatus: AppConstants.statusInProgress,
        priority: AppConstants.priorityHigh,
        tags: 'mapping, sqlite, test',
        isDeleted: true,
        dateTimeCreated: 1727931000,
        dateTimeModified: 1727932000,
      );

      // Chuyển Entity -> Model
      final model = DocumentModel.fromEntity(originalEntity);
      expect(model.documentPk, equals('doc-map-001'));
      expect(model.isDeleted, isTrue);

      // Chuyển Model -> Map (Lưu vào SQLite)
      final map = model.toMap();
      expect(map['documentPk'], equals('doc-map-001'));
      expect(map['isDeleted'], equals(1)); // SQLite boolean integer
      expect(map['priority'], equals(3));

      // Chuyển Map -> Model (Đọc từ SQLite)
      final restoredModel = DocumentModel.fromMap(map);

      // Chuyển Model -> Entity (Trả về cho Domain Layer)
      final restoredEntity = restoredModel.toEntity();
      expect(restoredEntity.documentPk, equals(originalEntity.documentPk));
      expect(restoredEntity.subjectFk, equals(originalEntity.subjectFk));
      expect(restoredEntity.title, equals(originalEntity.title));
      expect(restoredEntity.documentType, equals(originalEntity.documentType));
      expect(restoredEntity.note, equals(originalEntity.note));
      expect(restoredEntity.studyStatus, equals(originalEntity.studyStatus));
      expect(restoredEntity.priority, equals(originalEntity.priority));
      expect(restoredEntity.tags, equals(originalEntity.tags));
      expect(restoredEntity.isDeleted, equals(originalEntity.isDeleted));
      expect(restoredEntity.dateTimeCreated, equals(originalEntity.dateTimeCreated));
      expect(restoredEntity.dateTimeModified, equals(originalEntity.dateTimeModified));
    });

    test('TC-ISO-15: SubjectModel, AttachmentModel và DeleteLogModel ánh xạ đúng định dạng CSDL', () {
      // Test SubjectModel
      const subEntity = SubjectEntity(
        subjectPk: 'sub-007',
        code: 'INT310',
        name: 'Mạng Máy Tính',
        instructor: 'ThS. Lê C',
        colorHex: '#F59E0B',
        iconName: 'wifi',
        dateTimeCreated: 1727900000,
      );
      final subModel = SubjectModel.fromEntity(subEntity);
      final subMap = subModel.toMap();
      expect(subMap['code'], equals('INT310'));
      expect(SubjectModel.fromMap(subMap).toEntity().name, equals('Mạng Máy Tính'));

      // Test AttachmentModel
      const attEntity = AttachmentEntity(
        attachmentPk: 'att-999',
        documentFk: 'doc-map-001',
        fileName: 'tailieu.pdf',
        fileExtension: 'pdf',
        localPath: '/storage/tailieu.pdf',
        fileSizeBytes: 1048576,
        dateTimeCreated: 1727911111,
      );
      final attModel = AttachmentModel.fromEntity(attEntity);
      final attMap = attModel.toMap();
      expect(attMap['fileSizeBytes'], equals(1048576));
      expect(AttachmentModel.fromMap(attMap).toEntity().fileName, equals('tailieu.pdf'));

      // Test DeleteLogModel
      const logModel = DeleteLogModel(
        logPk: 'log-001',
        entityPk: 'doc-map-001',
        entityType: 'Document',
        dateTimeDeleted: 1727922222,
      );
      final logMap = logModel.toMap();
      expect(logMap['entityType'], equals('Document'));
      expect(DeleteLogModel.fromMap(logMap).entityPk, equals('doc-map-001'));
    });
  });

  group('NHÓM 4: KIỂM THỬ RANH GIỚI KIẾN TRÚC & ĐẢO NGƯỢC PHỤ THUỘC (DIP)', () {
    test('TC-ISO-16: Hoán đổi linh hoạt giữa các triển khai IDocumentRepository mà không ảnh hưởng DocumentService', () async {
      // 1. Khởi tạo Service với FakeDocumentRepository (RAM)
      final repoA = FakeDocumentRepository();
      final serviceA = DocumentService(documentRepository: repoA);

      await serviceA.saveDocument(
        subjectFk: 'sub-test',
        title: 'Tài liệu trên Repo A',
        documentType: AppConstants.typeLecture,
      );
      expect((await serviceA.getAllDocuments()).length, equals(1));

      // 2. Khởi tạo Service với một Mock/Alternative Repository thứ hai
      final repoB = FakeDocumentRepository();
      final serviceB = DocumentService(documentRepository: repoB);

      // Repo B ban đầu rỗng, chứng minh tính độc lập của thể hiện Repository
      expect((await serviceB.getAllDocuments()).isEmpty, isTrue);

      await serviceB.saveDocument(
        subjectFk: 'sub-test',
        title: 'Tài liệu trên Repo B',
        documentType: AppConstants.typeAssignment,
      );
      expect((await serviceB.getAllDocuments()).length, equals(1));

      // Kiểm tra Service hoàn toàn không phụ thuộc vào lớp cụ thể của Repository
      expect(serviceA.documentRepository, isA<IDocumentRepository>());
      expect(serviceB.documentRepository, isA<IDocumentRepository>());
      repoA.dispose();
      repoB.dispose();
    });
  });
}
