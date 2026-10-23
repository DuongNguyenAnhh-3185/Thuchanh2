import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../datasources/local/app_database.dart';
import '../models/subject_model.dart';

/// Data Access Object cho bảng Môn học (Subjects)
/// Hỗ trợ truy vấn CRUD và Reactive Stream phản ứng thay đổi
class SubjectDao {
  final AppDatabase _appDatabase;
  final StreamController<List<SubjectModel>> _subjectsStreamController =
      StreamController<List<SubjectModel>>.broadcast();

  SubjectDao({AppDatabase? appDatabase})
    : _appDatabase = appDatabase ?? AppDatabase.instance {
    // Kích hoạt nạp dữ liệu ban đầu cho Stream
    _notifyStream();
  }

  Stream<List<SubjectModel>> watchAllSubjects() {
    _notifyStream();
    return _subjectsStreamController.stream;
  }

  Future<void> _notifyStream() async {
    try {
      final list = await getAllSubjects();
      if (!_subjectsStreamController.isClosed) {
        _subjectsStreamController.add(list);
      }
    } catch (_) {}
  }

  Future<List<SubjectModel>> getAllSubjects() async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppConstants.tableSubjects,
      orderBy: 'code ASC',
    );
    return maps.map((m) => SubjectModel.fromMap(m)).toList();
  }

  Future<SubjectModel?> getSubjectById(String subjectPk) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppConstants.tableSubjects,
      where: 'subjectPk = ?',
      whereArgs: [subjectPk],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return SubjectModel.fromMap(maps.first);
    }
    return null;
  }

  Future<void> insertSubject(SubjectModel subject) async {
    final db = await _appDatabase.database;
    await db.insert(
      AppConstants.tableSubjects,
      subject.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifyStream();
  }

  Future<void> updateSubject(SubjectModel subject) async {
    final db = await _appDatabase.database;
    await db.update(
      AppConstants.tableSubjects,
      subject.toMap(),
      where: 'subjectPk = ?',
      whereArgs: [subject.subjectPk],
    );
    await _notifyStream();
  }

  Future<void> deleteSubject(String subjectPk) async {
    final db = await _appDatabase.database;
    await db.delete(
      AppConstants.tableSubjects,
      where: 'subjectPk = ?',
      whereArgs: [subjectPk],
    );
    await _notifyStream();
  }

  void dispose() {
    _subjectsStreamController.close();
  }
}
