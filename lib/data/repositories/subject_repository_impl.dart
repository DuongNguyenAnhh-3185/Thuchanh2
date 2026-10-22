import '../../domain/entities/subject_entity.dart';
import '../../domain/repositories/i_subject_repository.dart';
import '../daos/subject_dao.dart';
import '../models/subject_model.dart';

/// Triển khai ISubjectRepository theo chuẩn Clean Architecture
class SubjectRepositoryImpl implements ISubjectRepository {
  final SubjectDao _subjectDao;

  SubjectRepositoryImpl({SubjectDao? subjectDao})
      : _subjectDao = subjectDao ?? SubjectDao();

  @override
  Future<List<SubjectEntity>> getAllSubjects() async {
    return await _subjectDao.getAllSubjects();
  }

  @override
  Stream<List<SubjectEntity>> watchAllSubjects() {
    return _subjectDao.watchAllSubjects();
  }

  @override
  Future<SubjectEntity?> getSubjectById(String subjectPk) async {
    return await _subjectDao.getSubjectById(subjectPk);
  }

  @override
  Future<void> insertSubject(SubjectEntity subject) async {
    final model = SubjectModel.fromEntity(subject);
    await _subjectDao.insertSubject(model);
  }

  @override
  Future<void> updateSubject(SubjectEntity subject) async {
    final model = SubjectModel.fromEntity(subject);
    await _subjectDao.updateSubject(model);
  }

  @override
  Future<void> deleteSubject(String subjectPk) async {
    await _subjectDao.deleteSubject(subjectPk);
  }
}
