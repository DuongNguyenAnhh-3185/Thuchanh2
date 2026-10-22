import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_constants.dart';
import '../datasources/local/app_database.dart';
import '../models/delete_log_model.dart';

/// Data Access Object cho bảng DeleteLogs
/// Kế thừa kỹ thuật DeleteLogs trong Cashew: lưu vết xóa để hỗ trợ đồng bộ & hoàn tác
class DeleteLogDao {
  final AppDatabase _appDatabase;

  DeleteLogDao({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase.instance;

  Future<void> insertLog(DeleteLogModel log) async {
    final db = await _appDatabase.database;
    await db.insert(
      AppConstants.tableDeleteLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DeleteLogModel>> getAllLogs() async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppConstants.tableDeleteLogs,
      orderBy: 'dateTimeDeleted DESC',
    );
    return maps.map((m) => DeleteLogModel.fromMap(m)).toList();
  }
}
