/// Thực thể Môn học (Domain Entity)
/// Không phụ thuộc vào cơ sở dữ liệu hay thư viện UI
class SubjectEntity {
  final String subjectPk; // UUID v4
  final String code; // Mã môn học (ví dụ: MOB101)
  final String name; // Tên môn học
  final String instructor; // Giảng viên phụ trách
  final String colorHex; // Mã màu HEX nhận diện
  final String iconName; // Tên biểu tượng
  final int dateTimeCreated;

  const SubjectEntity({
    required this.subjectPk,
    required this.code,
    required this.name,
    this.instructor = '',
    this.colorHex = '#3B82F6',
    this.iconName = 'book',
    required this.dateTimeCreated,
  });

  SubjectEntity copyWith({
    String? subjectPk,
    String? code,
    String? name,
    String? instructor,
    String? colorHex,
    String? iconName,
    int? dateTimeCreated,
  }) {
    return SubjectEntity(
      subjectPk: subjectPk ?? this.subjectPk,
      code: code ?? this.code,
      name: name ?? this.name,
      instructor: instructor ?? this.instructor,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      dateTimeCreated: dateTimeCreated ?? this.dateTimeCreated,
    );
  }
}
