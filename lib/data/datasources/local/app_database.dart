import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../../core/constants/app_constants.dart';

/// Quản lý kết nối và khởi tạo cơ sở dữ liệu SQLite
/// Kế thừa kiến trúc Cashew: Local Storage, SQLite Native FFI, Schema Versioning
class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  /// Cho phép thiết lập database tùy chỉnh hoặc mock cho Unit Tests
  static void setCustomDatabase(Database? db) {
    _database = db;
  }

  /// Khởi tạo database hoàn toàn trên RAM (In-Memory) cho Unit Tests mà không phụ thuộc path_provider
  static Future<Database> createInMemoryDatabase({
    bool useIsolate = true,
  }) async {
    sqfliteFfiInit();
    final factory = useIsolate
        ? databaseFactoryFfi
        : databaseFactoryFfiNoIsolate;
    databaseFactory = factory;
    final db = await factory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          await instance._onCreate(database, version);
        },
        onUpgrade: instance._onUpgrade,
      ),
    );
    _database = db;
    return db;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactoryFfiWeb.openDatabase(
        'cashew_study.db',
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
    }

    // Khởi tạo FFI driver cho Windows / Linux nếu cần
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final docDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docDir.path, 'cashew_study.db');

    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Bật hỗ trợ ràng buộc khóa ngoại (Foreign Keys)
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Bảng Môn học (Subjects)
    await db.execute('''
      CREATE TABLE ${AppConstants.tableSubjects} (
        subjectPk TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        instructor TEXT,
        colorHex TEXT NOT NULL DEFAULT '#3B82F6',
        iconName TEXT NOT NULL DEFAULT 'book',
        dateTimeCreated INTEGER NOT NULL
      )
    ''');

    // 2. Bảng Tài liệu Học tập (Documents)
    await db.execute('''
      CREATE TABLE ${AppConstants.tableDocuments} (
        documentPk TEXT PRIMARY KEY,
        subjectFk TEXT NOT NULL,
        title TEXT NOT NULL,
        documentType TEXT NOT NULL,
        note TEXT,
        studyStatus TEXT NOT NULL DEFAULT 'Chưa học',
        priority INTEGER NOT NULL DEFAULT 2,
        tags TEXT DEFAULT '',
        physicalLocation TEXT NOT NULL DEFAULT '',
        latitude REAL,
        longitude REAL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        dateTimeCreated INTEGER NOT NULL,
        dateTimeModified INTEGER NOT NULL,
        FOREIGN KEY (subjectFk) REFERENCES ${AppConstants.tableSubjects} (subjectPk) ON DELETE CASCADE
      )
    ''');

    // 3. Bảng Tệp đính kèm (Attachments)
    await db.execute('''
      CREATE TABLE ${AppConstants.tableAttachments} (
        attachmentPk TEXT PRIMARY KEY,
        documentFk TEXT NOT NULL,
        fileName TEXT NOT NULL,
        fileExtension TEXT NOT NULL,
        localPath TEXT NOT NULL,
        fileSizeBytes INTEGER NOT NULL DEFAULT 0,
        dateTimeCreated INTEGER NOT NULL,
        FOREIGN KEY (documentFk) REFERENCES ${AppConstants.tableDocuments} (documentPk) ON DELETE CASCADE
      )
    ''');

    // 4. Bảng Nhật ký xóa (DeleteLogs) - Kế thừa chiến lược Cashew Soft-delete & Sync tracking
    await db.execute('''
      CREATE TABLE ${AppConstants.tableDeleteLogs} (
        logPk TEXT PRIMARY KEY,
        entityPk TEXT NOT NULL,
        entityType TEXT NOT NULL,
        dateTimeDeleted INTEGER NOT NULL
      )
    ''');

    // Khởi tạo một số môn học mẫu ban đầu
    await _insertInitialSeedData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE ${AppConstants.tableDocuments} ADD COLUMN physicalLocation TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableDocuments} ADD COLUMN latitude REAL',
      );
      await db.execute(
        'ALTER TABLE ${AppConstants.tableDocuments} ADD COLUMN longitude REAL',
      );
    }
  }

  Future<void> _insertInitialSeedData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final subjects = [
      {
        'subjectPk': 'sub-mob-001',
        'code': 'MOB101',
        'name': 'Phát triển Ứng dụng Di động',
        'instructor': 'Thầy Trọng / Bộ môn KTPM',
        'colorHex': '#3B82F6',
        'iconName': 'smartphone',
        'dateTimeCreated': now,
      },
      {
        'subjectPk': 'sub-arc-002',
        'code': 'ARC201',
        'name': 'Kiến trúc & Thiết kế Phần mềm',
        'instructor': 'Cô Lan',
        'colorHex': '#10B981',
        'iconName': 'architecture',
        'dateTimeCreated': now,
      },
      {
        'subjectPk': 'sub-db-003',
        'code': 'DBS301',
        'name': 'Hệ Quản trị Cơ sở Dữ liệu',
        'instructor': 'Thầy Tuấn',
        'colorHex': '#F59E0B',
        'iconName': 'database',
        'dateTimeCreated': now,
      },
    ];

    for (final s in subjects) {
      await db.insert(
        AppConstants.tableSubjects,
        s,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Nạp hàng loạt tài liệu mẫu (Bài giảng, Bài tập, Tham khảo, Đề thi)
  Future<void> seedSampleDocuments({bool force = false}) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as total FROM ${AppConstants.tableDocuments} ',
    );
    final count = res.isNotEmpty ? (res.first['total'] as int? ?? 0) : 0;

    if (count > 0 && !force) return;

    final seedSubjects = await db.query(
      AppConstants.tableSubjects,
      columns: ['subjectPk'],
      where: 'subjectPk IN (?, ?, ?)',
      whereArgs: ['sub-mob-001', 'sub-arc-002', 'sub-db-003'],
    );
    if (seedSubjects.length != 3) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final dayMs = 24 * 60 * 60 * 1000;

    final sampleDocs = [
      // --- MÔN MOB101: Phát triển Ứng dụng Di động ---
      {
        'documentPk': 'doc-mob-001',
        'subjectFk': 'sub-mob-001',
        'title': 'Slide Bài giảng Chương 1 - Tổng quan Flutter & Dart 3.x',
        'documentType': 'Bài giảng (Lecture)',
        'note': 'Nắm vững cây Widget, phân biệt StatelessWidget và StatefulWidget, vòng đời State và BuildContext trong Flutter.',
        'studyStatus': 'Đã hoàn thành',
        'priority': 2,
        'tags': 'Flutter, Dart, Slide, CoBan',
        'isDeleted': 0,
        'dateTimeCreated': now - 5 * dayMs,
        'dateTimeModified': now - 4 * dayMs,
      },
      {
        'documentPk': 'doc-mob-002',
        'subjectFk': 'sub-mob-001',
        'title': 'Bài tập Thực hành 1 - Quản lý Tài liệu theo Kiến trúc Cashew',
        'documentType': 'Bài tập (Assignment)',
        'note': 'Thiết kế ứng dụng phân lớp Clean Architecture, tích hợp CSDL SQLite Native FFI, khóa chính UUID v4 và xuất báo cáo Word.',
        'studyStatus': 'Đang học',
        'priority': 3,
        'tags': 'ThucHanh, TH1, Cashew, CleanArchitecture',
        'isDeleted': 0,
        'dateTimeCreated': now - 3 * dayMs,
        'dateTimeModified': now - 1 * dayMs,
      },
      {
        'documentPk': 'doc-mob-003',
        'subjectFk': 'sub-mob-001',
        'title': 'Đề thi Giữa kỳ - Lập trình Di động Flutter (Năm 2025)',
        'documentType': 'Đề thi & Đề cương (Exam)',
        'note': 'Thời gian 60 phút: Trắc nghiệm State Management (BLoC, Provider) và bài code xây dựng màn hình Reactive List.',
        'studyStatus': 'Chưa học',
        'priority': 3,
        'tags': 'DeThi, GiuaKy, OnThi, Flutter',
        'isDeleted': 0,
        'dateTimeCreated': now - 2 * dayMs,
        'dateTimeModified': now - 2 * dayMs,
      },

      // --- MÔN ARC201: Kiến trúc & Thiết kế Phần mềm ---
      {
        'documentPk': 'doc-arc-001',
        'subjectFk': 'sub-arc-002',
        'title': 'Slide Chương 4 - Clean Architecture & Nguyên tắc Đảo ngược Phụ thuộc (DIP)',
        'documentType': 'Bài giảng (Lecture)',
        'note': 'Chi tiết quy tắc Dependency Rule: Tầng Presentation & Data phụ thuộc Domain. Domain độc lập hoàn toàn.',
        'studyStatus': 'Đã hoàn thành',
        'priority': 3,
        'tags': 'CleanArchitecture, SOLID, DIP, Slide',
        'isDeleted': 0,
        'dateTimeCreated': now - 6 * dayMs,
        'dateTimeModified': now - 5 * dayMs,
      },
      {
        'documentPk': 'doc-arc-002',
        'subjectFk': 'sub-arc-002',
        'title':
            'Bài tập Lớn - Phân tích & Tái cấu trúc Hệ thống Cashew Monolith',
        'documentType': 'Bài tập (Assignment)',
        'note': 'Giải quyết điểm nghẽn tập tin tables.dart 7.600 dòng bằng cách bóc tách mô-đun DAOs, Repositories, Services.',
        'studyStatus': 'Đang học',
        'priority': 3,
        'tags': 'BTL, Cashew, Refactoring, Daos',
        'isDeleted': 0,
        'dateTimeCreated': now - 4 * dayMs,
        'dateTimeModified': now - 1 * dayMs,
      },
      {
        'documentPk': 'doc-arc-003',
        'subjectFk': 'sub-arc-002',
        'title':
            'Sách tham khảo: Clean Architecture - Robert C. Martin (Uncle Bob)',
        'documentType': 'Tài liệu tham khảo (Reference)',
        'note': 'Sách kinh điển về kiến trúc phần mềm, hướng dẫn thiết kế hệ thống decoupled, testable và maintainable.',
        'studyStatus': 'Chưa học',
        'priority': 2,
        'tags': 'Sach, UncleBob, Reference, PDF',
        'isDeleted': 0,
        'dateTimeCreated': now - 7 * dayMs,
        'dateTimeModified': now - 7 * dayMs,
      },
      {
        'documentPk': 'doc-arc-004',
        'subjectFk': 'sub-arc-002',
        'title': 'Bộ Đề cương Ôn tập Cuối kỳ - Kiến trúc Phần mềm (20 Câu hỏi Lý thuyết)',
        'documentType': 'Đề thi & Đề cương (Exam)',
        'note': 'Tổng hợp các chủ đề thi: Microservices vs Monolith, Clean Architecture vs MVC, Sơ đồ DFD và State Machine.',
        'studyStatus': 'Đang học',
        'priority': 3,
        'tags': 'DeCuong, CuoiKy, OnTap, LyThuyet',
        'isDeleted': 0,
        'dateTimeCreated': now - 2 * dayMs,
        'dateTimeModified': now - 1 * dayMs,
      },

      // --- MÔN DBS301: Hệ Quản trị Cơ sở Dữ liệu ---
      {
        'documentPk': 'doc-db-001',
        'subjectFk': 'sub-db-003',
        'title': 'Bài giảng Chương 5 - Chỉ mục B-Tree & Tối ưu Truy vấn SQLite',
        'documentType': 'Bài giảng (Lecture)',
        'note': 'Phương pháp tạo Composite Index, phân tích kế hoạch thực thi EXPLAIN QUERY PLAN, tối ưu tốc độ đọc dưới 10ms.',
        'studyStatus': 'Đã hoàn thành',
        'priority': 2,
        'tags': 'SQLite, Index, Performance, Slide',
        'isDeleted': 0,
        'dateTimeCreated': now - 8 * dayMs,
        'dateTimeModified': now - 6 * dayMs,
      },
      {
        'documentPk': 'doc-db-002',
        'subjectFk': 'sub-db-003',
        'title':
            'Bài tập Lab 3 - Thiết kế CSDL Cục bộ hỗ trợ Soft-Delete & UUID v4',
        'documentType': 'Bài tập (Assignment)',
        'note': 'Viết bảng DeleteLogs và trigger ghi vết xóa để đảm bảo khả năng đồng bộ đa thiết bị không mất dữ liệu.',
        'studyStatus': 'Đã hoàn thành',
        'priority': 2,
        'tags': 'Lab, SQL, UUID, DeleteLogs',
        'isDeleted': 0,
        'dateTimeCreated': now - 5 * dayMs,
        'dateTimeModified': now - 3 * dayMs,
      },
      {
        'documentPk': 'doc-db-003',
        'subjectFk': 'sub-db-003',
        'title': 'Tài liệu Đặc tả: SQLite Native FFI & Drift Reactive Stream Documentation',
        'documentType': 'Tài liệu tham khảo (Reference)',
        'note': 'Tài liệu kỹ thuật hướng dẫn cơ chế MultiExecutor FFI và cách thức Drift phát tín hiệu Stream khi bảng có thay đổi.',
        'studyStatus': 'Chưa học',
        'priority': 1,
        'tags': 'Drift, FFI, Stream, Docs',
        'isDeleted': 0,
        'dateTimeCreated': now - 9 * dayMs,
        'dateTimeModified': now - 9 * dayMs,
      },
      {
        'documentPk': 'doc-db-004',
        'subjectFk': 'sub-db-003',
        'title':
            'Đề thi Thực hành SQL Cuối kỳ - Đề số 02 (Kèm Lời giải chi tiết)',
        'documentType': 'Đề thi & Đề cương (Exam)',
        'note': 'Đề thi thực hành 90 phút: Truy vấn phức hợp JOIN 4 bảng, hàm cửa sổ Window Functions, Transaction ACID.',
        'studyStatus': 'Chưa học',
        'priority': 3,
        'tags': 'DeThi, SQL, LoiGiai, ThucHanh',
        'isDeleted': 0,
        'dateTimeCreated': now - 1 * dayMs,
        'dateTimeModified': now - 1 * dayMs,
      },
    ];

    for (final doc in sampleDocs) {
      await db.insert(
        AppConstants.tableDocuments,
        doc,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Nạp tệp đính kèm mẫu
    final sampleAttachments = [
      {
        'attachmentPk': 'att-mob-001-1',
        'documentFk': 'doc-mob-001',
        'fileName': 'Slide_Chuong1_TongQuanFlutter.pptx',
        'fileExtension': 'pptx',
        'localPath':
            '/storage/emulated/0/Download/Slide_Chuong1_TongQuanFlutter.pptx',
        'fileSizeBytes': 5420000,
        'dateTimeCreated': now - 5 * dayMs,
      },
      {
        'attachmentPk': 'att-mob-001-2',
        'documentFk': 'doc-mob-001',
        'fileName': 'Giao_Trinh_Dart_Flutter_Chuan.pdf',
        'fileExtension': 'pdf',
        'localPath':
            '/storage/emulated/0/Download/Giao_Trinh_Dart_Flutter_Chuan.pdf',
        'fileSizeBytes': 12580000,
        'dateTimeCreated': now - 5 * dayMs,
      },
      {
        'attachmentPk': 'att-mob-002-1',
        'documentFk': 'doc-mob-002',
        'fileName': 'De_Bai_Thuc_Hanh_1_CashewDoc.pdf',
        'fileExtension': 'pdf',
        'localPath':
            '/storage/emulated/0/Download/De_Bai_Thuc_Hanh_1_CashewDoc.pdf',
        'fileSizeBytes': 1850000,
        'dateTimeCreated': now - 3 * dayMs,
      },
      {
        'attachmentPk': 'att-mob-002-2',
        'documentFk': 'doc-mob-002',
        'fileName': 'Ma_Nguon_Cashew_Starter.zip',
        'fileExtension': 'zip',
        'localPath': '/storage/emulated/0/Download/Ma_Nguon_Cashew_Starter.zip',
        'fileSizeBytes': 4560000,
        'dateTimeCreated': now - 3 * dayMs,
      },
      {
        'attachmentPk': 'att-arc-001-1',
        'documentFk': 'doc-arc-001',
        'fileName': 'Clean_Architecture_Uncle_Bob_Notes.docx',
        'fileExtension': 'docx',
        'localPath': '/storage/emulated/0/Download/Clean_Architecture_Uncle_Bob_Notes.docx',
        'fileSizeBytes': 2350000,
        'dateTimeCreated': now - 6 * dayMs,
      },
    ];

    for (final att in sampleAttachments) {
      await db.insert(
        AppConstants.tableAttachments,
        att,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Đóng cơ sở dữ liệu khi không sử dụng
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
