import '../entities/subject_entity.dart';

/// Hợp đồng giao tiếp (Interface) của Repository Môn học
/// Tuân thủ nguyên lý Dependency Inversion Principle (DIP)
abstract class ISubjectRepository {
  Future<List<SubjectEntity>> getAllSubjects();
  Stream<List<SubjectEntity>> watchAllSubjects();
  Future<SubjectEntity?> getSubjectById(String subjectPk);
  Future<void> insertSubject(SubjectEntity subject);
  Future<void> updateSubject(SubjectEntity subject);
  Future<void> deleteSubject(String subjectPk);
}
