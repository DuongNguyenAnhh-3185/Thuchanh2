import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../datasources/local/app_database.dart';
import '../models/attachment_model.dart';
import '../models/document_model.dart';
import '../models/subject_model.dart';

/// Data Access Object cho bảng Tài liệu Học tập (Documents)
/// Kế thừa Reactive Watch Queries của Drift ORM trong Cashew
class DocumentDao {
  final AppDatabase _appDatabase;
  final StreamController<List<DocumentModel>> _docsStreamController =
      StreamController<List<DocumentModel>>.broadcast();

  DocumentDao({AppDatabase? appDatabase})
    : _appDatabase = appDatabase ?? AppDatabase.instance {
    _notifyStream();
  }

  Stream<List<DocumentModel>> watchAllDocuments({bool includeDeleted = false}) {
    _notifyStream(includeDeleted: includeDeleted);
    return _docsStreamController.stream;
  }

  Future<void> _notifyStream({bool includeDeleted = false}) async {
    try {
      final list = await getAllDocuments(includeDeleted: includeDeleted);
      if (!_docsStreamController.isClosed) {
        _docsStreamController.add(list);
      }
    } catch (_) {}
  }

  /// Lấy tất cả tài liệu kèm thông tin Môn học (JOIN bảng)
  Future<List<DocumentModel>> getAllDocuments({
    bool includeDeleted = false,
  }) async {
    final db = await _appDatabase.database;
    final whereClause = includeDeleted ? null : 'd.isDeleted = 0';

    final result = await db.rawQuery('''
      SELECT 
        d.*,
        s.code AS s_code,
        s.name AS s_name,
        s.instructor AS s_instructor,
        s.colorHex AS s_colorHex,
        s.iconName AS s_iconName,
        s.dateTimeCreated AS s_dateTimeCreated
      FROM ${AppConstants.tableDocuments} d
      LEFT JOIN ${AppConstants.tableSubjects} s ON d.subjectFk = s.subjectPk
      ${whereClause != null ? 'WHERE $whereClause' : ''}
      ORDER BY d.dateTimeModified DESC
    ''');

    final List<DocumentModel> documents = [];
    for (final row in result) {
      final docMap = Map<String, dynamic>.from(row);
      SubjectModel? subject;
      if (row['s_code'] != null) {
        subject = SubjectModel(
          subjectPk: row['subjectFk'] as String,
          code: row['s_code'] as String,
          name: row['s_name'] as String,
          instructor: row['s_instructor'] as String? ?? '',
          colorHex: row['s_colorHex'] as String? ?? '#3B82F6',
          iconName: row['s_iconName'] as String? ?? 'book',
          dateTimeCreated: row['s_dateTimeCreated'] as int? ?? 0,
        );
      }

      // Lấy danh sách tệp đính kèm của tài liệu
      final attachments = await getAttachmentsForDocument(
        docMap['documentPk'] as String,
      );

      documents.add(
        DocumentModel.fromMap(
          docMap,
          subject: subject,
          attachments: attachments,
        ),
      );
    }
    return documents;
  }

  /// Lấy chi tiết 1 tài liệu theo ID
  Future<DocumentModel?> getDocumentById(String documentPk) async {
    final db = await _appDatabase.database;
    final result = await db.rawQuery(
      '''
      SELECT 
        d.*,
        s.code AS s_code,
        s.name AS s_name,
        s.instructor AS s_instructor,
        s.colorHex AS s_colorHex,
        s.iconName AS s_iconName,
        s.dateTimeCreated AS s_dateTimeCreated
      FROM ${AppConstants.tableDocuments} d
      LEFT JOIN ${AppConstants.tableSubjects} s ON d.subjectFk = s.subjectPk
      WHERE d.documentPk = ?
      LIMIT 1
    ''',
      [documentPk],
    );

    if (result.isEmpty) return null;
    final row = result.first;
    final docMap = Map<String, dynamic>.from(row);

    SubjectModel? subject;
    if (row['s_code'] != null) {
      subject = SubjectModel(
        subjectPk: row['subjectFk'] as String,
        code: row['s_code'] as String,
        name: row['s_name'] as String,
        instructor: row['s_instructor'] as String? ?? '',
        colorHex: row['s_colorHex'] as String? ?? '#3B82F6',
        iconName: row['s_iconName'] as String? ?? 'book',
        dateTimeCreated: row['s_dateTimeCreated'] as int? ?? 0,
      );
    }

    final attachments = await getAttachmentsForDocument(documentPk);
    return DocumentModel.fromMap(
      docMap,
      subject: subject,
      attachments: attachments,
    );
  }

  /// Lấy tài liệu theo Môn học
  Future<List<DocumentModel>> getDocumentsBySubject(String subjectFk) async {
    final all = await getAllDocuments(includeDeleted: false);
    return all.where((d) => d.subjectFk == subjectFk).toList();
  }

  /// Thêm mới tài liệu (trong transaction SQLite)
  Future<void> insertDocument(DocumentModel document) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.insert(
        AppConstants.tableDocuments,
        document.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Thêm các tệp đính kèm (nếu có)
      for (final att in document.attachments) {
        final attModel = att is AttachmentModel
            ? att
            : AttachmentModel.fromEntity(att);
        await txn.insert(
          AppConstants.tableAttachments,
          attModel.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await _notifyStream();
  }

  /// Cập nhật tài liệu
  Future<void> updateDocument(DocumentModel document) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.update(
        AppConstants.tableDocuments,
        document.toMap(),
        where: 'documentPk = ?',
        whereArgs: [document.documentPk],
      );

      // Xóa và cập nhật lại attachments
      await txn.delete(
        AppConstants.tableAttachments,
        where: 'documentFk = ?',
        whereArgs: [document.documentPk],
      );

      for (final att in document.attachments) {
        final attModel = att is AttachmentModel
            ? att
            : AttachmentModel.fromEntity(att);
        await txn.insert(
          AppConstants.tableAttachments,
          attModel.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await _notifyStream();
  }

  /// Xóa mềm tài liệu (Soft-delete: đánh dấu isDeleted = 1)
  Future<void> setDeletedStatus(String documentPk, bool isDeleted) async {
    final db = await _appDatabase.database;
    await db.update(
      AppConstants.tableDocuments,
      {
        'isDeleted': isDeleted ? 1 : 0,
        'dateTimeModified': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'documentPk = ?',
      whereArgs: [documentPk],
    );
    await _notifyStream();
  }

  /// Xóa vĩnh viễn tài liệu khỏi cơ sở dữ liệu
  Future<void> permanentlyDeleteDocument(String documentPk) async {
    final db = await _appDatabase.database;
    await db.delete(
      AppConstants.tableDocuments,
      where: 'documentPk = ?',
      whereArgs: [documentPk],
    );
    await _notifyStream();
  }

  /// Lấy danh sách tệp đính kèm của một tài liệu
  Future<List<AttachmentModel>> getAttachmentsForDocument(
    String documentPk,
  ) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppConstants.tableAttachments,
      where: 'documentFk = ?',
      whereArgs: [documentPk],
    );
    return maps.map((m) => AttachmentModel.fromMap(m)).toList();
  }

  /// Tìm kiếm và lọc đa tiêu chí (Full-Text Search & Multi-criteria filter)
  Future<List<DocumentModel>> searchAndFilter({
    String? query,
    String? subjectFk,
    String? documentType,
    String? studyStatus,
  }) async {
    final all = await getAllDocuments(includeDeleted: false);

    return all.where((doc) {
      // 1. Lọc theo từ khóa tìm kiếm (tiêu đề, ghi chú, mã môn, tags)
      if (query != null && query.trim().isNotEmpty) {
        final q = query.toLowerCase().trim();
        final matchTitle = doc.title.toLowerCase().contains(q);
        final matchNote = doc.note.toLowerCase().contains(q);
        final matchTags = doc.tags.toLowerCase().contains(q);
        final matchSubject =
            doc.subject?.name.toLowerCase().contains(q) ?? false;
        final matchCode = doc.subject?.code.toLowerCase().contains(q) ?? false;
        if (!matchTitle &&
            !matchNote &&
            !matchTags &&
            !matchSubject &&
            !matchCode) {
          return false;
        }
      }

      // 2. Lọc theo môn học
      if (subjectFk != null &&
          subjectFk.isNotEmpty &&
          doc.subjectFk != subjectFk) {
        return false;
      }

      // 3. Lọc theo loại tài liệu
      if (documentType != null &&
          documentType.isNotEmpty &&
          doc.documentType != documentType) {
        return false;
      }

      // 4. Lọc theo trạng thái học tập
      if (studyStatus != null &&
          studyStatus.isNotEmpty &&
          doc.studyStatus != studyStatus) {
        return false;
      }

      return true;
    }).toList();
  }

  void dispose() {
    _docsStreamController.close();
  }
}
