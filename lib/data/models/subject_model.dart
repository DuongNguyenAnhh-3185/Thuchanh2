import '../../domain/entities/subject_entity.dart';

/// Model ánh xạ bảng 'subjects' trong CSDL SQLite
class SubjectModel extends SubjectEntity {
  const SubjectModel({
    required super.subjectPk,
    required super.code,
    required super.name,
    super.instructor = '',
    super.colorHex = '#3B82F6',
    super.iconName = 'book',
    required super.dateTimeCreated,
  });

  /// Chuyển đổi từ Map (SQLite record) sang Model
  factory SubjectModel.fromMap(Map<String, dynamic> map) {
    return SubjectModel(
      subjectPk: map['subjectPk'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      instructor: map['instructor'] as String? ?? '',
      colorHex: map['colorHex'] as String? ?? '#3B82F6',
      iconName: map['iconName'] as String? ?? 'book',
      dateTimeCreated: map['dateTimeCreated'] as int,
    );
  }

  /// Chuyển đổi từ Model sang Map để lưu trữ vào SQLite
  Map<String, dynamic> toMap() {
    return {
      'subjectPk': subjectPk,
      'code': code,
      'name': name,
      'instructor': instructor,
      'colorHex': colorHex,
      'iconName': iconName,
      'dateTimeCreated': dateTimeCreated,
    };
  }

  /// Chuyển từ Domain Entity sang Data Model
  factory SubjectModel.fromEntity(SubjectEntity entity) {
    return SubjectModel(
      subjectPk: entity.subjectPk,
      code: entity.code,
      name: entity.name,
      instructor: entity.instructor,
      colorHex: entity.colorHex,
      iconName: entity.iconName,
      dateTimeCreated: entity.dateTimeCreated,
    );
  }

  /// Trả về đối tượng thuần Domain Entity
  SubjectEntity toEntity() => SubjectEntity(
        subjectPk: subjectPk,
        code: code,
        name: name,
        instructor: instructor,
        colorHex: colorHex,
        iconName: iconName,
        dateTimeCreated: dateTimeCreated,
      );
}
