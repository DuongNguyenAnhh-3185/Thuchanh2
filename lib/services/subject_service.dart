import '../core/utils/uuid_helper.dart';
import '../domain/entities/subject_entity.dart';
import '../domain/repositories/i_subject_repository.dart';

/// Dịch vụ nghiệp vụ Quản lý Môn học (Application / Service Layer)
class SubjectService {
  final ISubjectRepository subjectRepository;

  SubjectService({required this.subjectRepository});

  Future<List<SubjectEntity>> getAllSubjects() async {
    return await subjectRepository.getAllSubjects();
  }

  Stream<List<SubjectEntity>> watchAllSubjects() {
    return subjectRepository.watchAllSubjects();
  }

  Future<SubjectEntity?> getSubjectById(String subjectPk) async {
    return await subjectRepository.getSubjectById(subjectPk);
  }

  /// Thêm hoặc cập nhật môn học với Validation nghiệp vụ
  Future<void> saveSubject({
    String? subjectPk,
    required String code,
    required String name,
    String instructor = '',
    String colorHex = '#3B82F6',
    String iconName = 'book',
  }) async {
    if (code.trim().isEmpty) {
      throw ArgumentError('Mã môn học không được để trống.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Tên môn học không được để trống.');
    }

    final isNew = subjectPk == null || subjectPk.isEmpty;
    final pk = isNew ? UuidHelper.generate() : subjectPk;
    final now = DateTime.now().millisecondsSinceEpoch;

    final subject = SubjectEntity(
      subjectPk: pk,
      code: code.trim().toUpperCase(),
      name: name.trim(),
      instructor: instructor.trim(),
      colorHex: colorHex,
      iconName: iconName,
      dateTimeCreated: isNew
          ? now
          : (await getSubjectById(pk))?.dateTimeCreated ?? now,
    );

    if (isNew) {
      await subjectRepository.insertSubject(subject);
    } else {
      await subjectRepository.updateSubject(subject);
    }
  }

  /// Thêm mới nhanh môn học (Helper cho Unit Test & UseCases)
  Future<void> createSubject({
    required String code,
    required String name,
    String instructor = '',
    String colorHex = '#3B82F6',
    String iconName = 'book',
  }) async {
    await saveSubject(
      code: code,
      name: name,
      instructor: instructor,
      colorHex: colorHex,
      iconName: iconName,
    );
  }

  Future<void> deleteSubject(String subjectPk) async {
    await subjectRepository.deleteSubject(subjectPk);
  }
}
