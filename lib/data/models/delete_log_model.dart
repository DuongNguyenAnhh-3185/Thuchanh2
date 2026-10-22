/// Model cho bảng nhật ký xóa (DeleteLogs) - Kế thừa từ Cashew
class DeleteLogModel {
  final String logPk; // UUID v4
  final String entityPk; // ID của đối tượng bị xóa
  final String entityType; // 'Document' hoặc 'Subject'
  final int dateTimeDeleted;

  const DeleteLogModel({
    required this.logPk,
    required this.entityPk,
    required this.entityType,
    required this.dateTimeDeleted,
  });

  factory DeleteLogModel.fromMap(Map<String, dynamic> map) {
    return DeleteLogModel(
      logPk: map['logPk'] as String,
      entityPk: map['entityPk'] as String,
      entityType: map['entityType'] as String,
      dateTimeDeleted: map['dateTimeDeleted'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'logPk': logPk,
      'entityPk': entityPk,
      'entityType': entityType,
      'dateTimeDeleted': dateTimeDeleted,
    };
  }
}
