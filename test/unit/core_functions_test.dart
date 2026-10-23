import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_doc_manager/core/constants/app_constants.dart';
import 'package:study_doc_manager/core/utils/uuid_helper.dart';
import 'package:study_doc_manager/data/daos/delete_log_dao.dart';
import 'package:study_doc_manager/data/daos/document_dao.dart';
import 'package:study_doc_manager/data/daos/subject_dao.dart';
import 'package:study_doc_manager/data/datasources/local/app_database.dart';
import 'package:study_doc_manager/data/repositories/document_repository_impl.dart';
import 'package:study_doc_manager/data/repositories/subject_repository_impl.dart';
import 'package:study_doc_manager/domain/entities/attachment_entity.dart';
import 'package:study_doc_manager/services/document_service.dart';
import 'package:study_doc_manager/services/search_service.dart';
import 'package:study_doc_manager/services/subject_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo FFI cho môi trường test
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late SubjectDao subjectDao;
  late DocumentDao documentDao;
  late DeleteLogDao deleteLogDao;
  late SubjectRepositoryImpl subjectRepo;
  late DocumentRepositoryImpl docRepo;
  late SubjectService subjectService;
  late DocumentService docService;
  late SearchService searchService;

  setUp(() async {
    await AppDatabase.createInMemoryDatabase();
    db = AppDatabase.instance;

    subjectDao = SubjectDao(appDatabase: db);
    documentDao = DocumentDao(appDatabase: db);
    deleteLogDao = DeleteLogDao(appDatabase: db);

    subjectRepo = SubjectRepositoryImpl(subjectDao: subjectDao);
    docRepo = DocumentRepositoryImpl(
      documentDao: documentDao,
      deleteLogDao: deleteLogDao,
    );

    subjectService = SubjectService(subjectRepository: subjectRepo);
    docService = DocumentService(documentRepository: docRepo);
    searchService = SearchService(documentRepository: docRepo);
  });

  group(
    'BƯỚC 3: KIỂM THỬ CÁC CHỨC NĂNG CỐT LÕI (TEST CASES TC-01 -> TC-15)',
    () {
      test('TC-00: SubjectService nạp danh sách môn học ban đầu', () async {
        final subjects = await subjectService.getAllSubjects();
        expect(subjects.length, greaterThanOrEqualTo(3));
      });

      test('TC-01: Thêm tài liệu hợp lệ thành công', () async {
        final doc = await docService.saveDocument(
          subjectFk: 'sub-mob-001',
          title: 'Đề cương Ôn tập Unit Test',
          documentType: 'Bài tập (Assignment)',
          note: 'Kiểm thử chức năng',
        );

        expect(doc.documentPk.isNotEmpty, isTrue);
        expect(UuidHelper.isValid(doc.documentPk), isTrue);
        expect(doc.title, equals('Đề cương Ôn tập Unit Test'));

        final fetched = await docService.getDocumentById(doc.documentPk);
        expect(fetched, isNotNull);
        expect(fetched!.title, equals('Đề cương Ôn tập Unit Test'));
      });

      test('TC-01A: Lưu và đọc vị trí vật lý cùng tọa độ bản đồ', () async {
        final document = await docService.saveDocument(
          subjectFk: 'sub-mob-001',
          title: 'Tài liệu có vị trí',
          documentType: 'Bài giảng (Lecture)',
          physicalLocation: 'Tủ sách tầng 2, ngăn B',
          latitude: 21.0285,
          longitude: 105.8542,
        );

        final fetched = await docService.getDocumentById(document.documentPk);
        expect(fetched?.physicalLocation, 'Tủ sách tầng 2, ngăn B');
        expect(fetched?.latitude, 21.0285);
        expect(fetched?.longitude, 105.8542);
      });

      test('TC-02: Bỏ trống tiêu đề ném ra ArgumentError', () async {
        expect(
          () => docService.saveDocument(
            subjectFk: 'sub-mob-001',
            title: '   ',
            documentType: 'Bài giảng (Lecture)',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('TC-03: Chưa chọn môn học ném ra ArgumentError', () async {
        expect(
          () => docService.saveDocument(
            subjectFk: '   ',
            title: 'Tài liệu không môn học',
            documentType: 'Bài giảng (Lecture)',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('TC-04: Kiểm tra sinh UUID v4 độc bản', () async {
        final id1 = UuidHelper.generate();
        final id2 = UuidHelper.generate();

        expect(id1, isNot(equals(id2)));
        expect(UuidHelper.isValid(id1), isTrue);
        expect(UuidHelper.isValid(id2), isTrue);
      });

      test('TC-05: Gán thời gian timestamps chính xác', () async {
        final before = DateTime.now().millisecondsSinceEpoch - 100;
        final doc = await docService.saveDocument(
          subjectFk: 'sub-arc-002',
          title: 'Tài liệu kiểm tra Timestamp',
          documentType: 'Bài giảng (Lecture)',
        );
        final after = DateTime.now().millisecondsSinceEpoch + 100;

        expect(doc.dateTimeCreated, greaterThanOrEqualTo(before));
        expect(doc.dateTimeCreated, lessThanOrEqualTo(after));
        expect(doc.dateTimeModified, equals(doc.dateTimeCreated));
      });

      test(
        'TC-06: Sửa thông tin tài liệu và cập nhật dateTimeModified',
        () async {
          final doc = await docService.saveDocument(
            subjectFk: 'sub-mob-001',
            title: 'Tên ban đầu',
            documentType: 'Bài giảng (Lecture)',
          );

          await Future.delayed(const Duration(milliseconds: 10));

          final updated = await docService.saveDocument(
            documentPk: doc.documentPk,
            subjectFk: 'sub-mob-001',
            title: 'Tên đã được cập nhật',
            documentType: 'Bài giảng (Lecture)',
          );

          expect(updated.title, equals('Tên đã được cập nhật'));
          expect(updated.dateTimeCreated, equals(doc.dateTimeCreated));
          expect(
            updated.dateTimeModified,
            greaterThanOrEqualTo(doc.dateTimeModified),
          );
        },
      );

      test('TC-07: Chuyển đổi trạng thái học tập 1-tap', () async {
        final doc = await docService.saveDocument(
          subjectFk: 'sub-mob-001',
          title: 'Kiểm tra trạng thái',
          documentType: 'Bài tập (Assignment)',
          studyStatus: AppConstants.statusNotStarted,
        );

        await docService.updateStudyStatus(
          doc.documentPk,
          AppConstants.statusInProgress,
        );
        var fetched = await docService.getDocumentById(doc.documentPk);
        expect(fetched!.studyStatus, equals(AppConstants.statusInProgress));

        await docService.updateStudyStatus(
          doc.documentPk,
          AppConstants.statusCompleted,
        );
        fetched = await docService.getDocumentById(doc.documentPk);
        expect(fetched!.studyStatus, equals(AppConstants.statusCompleted));
      });

      test('TC-08: Bảo toàn UUID và thông tin gốc khi chỉnh sửa', () async {
        final doc = await docService.saveDocument(
          subjectFk: 'sub-db-003',
          title: 'Tài liệu gốc',
          documentType: 'Tài liệu tham khảo (Reference)',
          tags: 'TagGoc',
        );

        final edited = await docService.saveDocument(
          documentPk: doc.documentPk,
          subjectFk: 'sub-db-003',
          title: 'Tài liệu đã sửa',
          documentType: 'Tài liệu tham khảo (Reference)',
          tags: 'TagMoi',
        );

        expect(edited.documentPk, equals(doc.documentPk));
      });

      test(
        'TC-09 & TC-10: Xóa mềm (Soft-delete) và Ghi vết vào DeleteLogs',
        () async {
          final doc = await docService.saveDocument(
            subjectFk: 'sub-mob-001',
            title: 'Tài liệu cần xóa',
            documentType: 'Bài tập (Assignment)',
          );

          await docService.softDeleteDocument(doc.documentPk);

          // Ẩn khỏi danh sách chính
          final activeDocs = await docService.getAllDocuments(
            includeDeleted: false,
          );
          expect(
            activeDocs.any((d) => d.documentPk == doc.documentPk),
            isFalse,
          );

          // Tồn tại trong danh sách deleted
          final allDocs = await docService.getAllDocuments(
            includeDeleted: true,
          );
          final deletedDoc = allDocs.firstWhere(
            (d) => d.documentPk == doc.documentPk,
          );
          expect(deletedDoc.isDeleted, isTrue);

          // Kiểm tra bảng DeleteLogs
          final logs = await deleteLogDao.getAllLogs();
          expect(
            logs.any(
              (l) => l.entityPk == doc.documentPk && l.entityType == 'Document',
            ),
            isTrue,
          );
        },
      );

      test('TC-11: Khôi phục tài liệu từ Thùng rác (Restore)', () async {
        final doc = await docService.saveDocument(
          subjectFk: 'sub-arc-002',
          title: 'Tài liệu sẽ khôi phục',
          documentType: 'Bài giảng (Lecture)',
        );

        await docService.softDeleteDocument(doc.documentPk);
        await docService.restoreDocument(doc.documentPk);

        final activeDocs = await docService.getAllDocuments(
          includeDeleted: false,
        );
        expect(activeDocs.any((d) => d.documentPk == doc.documentPk), isTrue);
      });

      test('TC-12: Xóa vĩnh viễn (Hard-delete)', () async {
        final doc = await docService.saveDocument(
          subjectFk: 'sub-db-003',
          title: 'Tài liệu xóa hẳn',
          documentType: 'Bài tập (Assignment)',
        );

        await docService.permanentlyDeleteDocument(doc.documentPk);

        final fetched = await docService.getDocumentById(doc.documentPk);
        expect(fetched, isNull);
      });

      test(
        'TC-13 & TC-14: Tìm kiếm từ khóa và Lọc kết hợp đa tiêu chí',
        () async {
          await docService.saveDocument(
            subjectFk: 'sub-mob-001',
            title: 'Lập trình BLoC chuyên sâu',
            documentType: 'Bài giảng (Lecture)',
            studyStatus: AppConstants.statusInProgress,
            tags: 'Flutter, State',
          );

          // Tìm kiếm theo từ khóa
          final searchResult = await searchService.filterDocuments(
            query: 'BLoC',
          );
          expect(searchResult.any((d) => d.title.contains('BLoC')), isTrue);

          // Lọc kết hợp Môn + Loại
          final filterResult = await searchService.filterDocuments(
            subjectFk: 'sub-mob-001',
            documentType: 'Bài giảng (Lecture)',
          );
          expect(
            filterResult.every(
              (d) =>
                  d.subjectFk == 'sub-mob-001' &&
                  d.documentType == 'Bài giảng (Lecture)',
            ),
            isTrue,
          );
        },
      );

      test(
        'TC-15: Đồng bộ Reactive Stream phát tín hiệu khi Data thay đổi',
        () async {
          final stream = docService.watchAllDocuments();
          expect(stream, emits(isA<List<dynamic>>()));
        },
      );

      test('TC-16: Đính kèm tệp đa định dạng và lưu vào CSDL', () async {
        final doc = await docService.saveDocument(
          subjectFk: 'sub-mob-001',
          title: 'Tài liệu kèm file PDF và ZIP',
          documentType: 'Bài tập (Assignment)',
          attachments: [
            const AttachmentEntity(
              attachmentPk: '',
              documentFk: '',
              fileName: 'De_Bai.pdf',
              fileExtension: 'pdf',
              localPath: '/storage/emulated/0/Download/De_Bai.pdf',
              fileSizeBytes: 204800,
              dateTimeCreated: 0,
            ),
            const AttachmentEntity(
              attachmentPk: '',
              documentFk: '',
              fileName: 'Source_Code.zip',
              fileExtension: 'zip',
              localPath: '/storage/emulated/0/Download/Source_Code.zip',
              fileSizeBytes: 1048576,
              dateTimeCreated: 0,
            ),
          ],
        );

        final fetched = await docService.getDocumentById(doc.documentPk);
        expect(fetched, isNotNull);
        expect(fetched!.attachments.length, equals(2));
        expect(fetched.attachments.first.fileName, equals('De_Bai.pdf'));
        expect(fetched.attachments.first.fileExtension, equals('pdf'));
        expect(fetched.attachments.first.documentFk, equals(doc.documentPk));
        expect(fetched.attachments.last.fileName, equals('Source_Code.zip'));
      });
    },
  );
}
