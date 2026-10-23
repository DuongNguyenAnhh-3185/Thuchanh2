import 'package:flutter_test/flutter_test.dart';
import 'package:study_doc_manager/domain/entities/document_entity.dart';
import 'package:study_doc_manager/services/recommendation_service.dart';

void main() {
  final service = RecommendationService();

  DocumentEntity document({
    required String id,
    required String subject,
    required String tags,
    String status = 'Chưa học',
    int modified = 0,
  }) {
    return DocumentEntity(
      documentPk: id,
      subjectFk: subject,
      title: id,
      documentType: 'Bài giảng (Lecture)',
      tags: tags,
      studyStatus: status,
      dateTimeCreated: modified,
      dateTimeModified: modified,
    );
  }

  test('ranks unfinished documents by overlap with completed tags', () {
    final completed = document(
      id: 'completed',
      subject: 'math',
      tags: 'Algebra, Exam',
      status: 'Đã hoàn thành',
    );
    final matchingTags = document(
      id: 'matching-tags',
      subject: 'science',
      tags: 'exam, algebra',
    );
    final matchingSubject = document(
      id: 'matching-subject',
      subject: 'math',
      tags: 'history',
    );
    final unrelated = document(
      id: 'unrelated',
      subject: 'art',
      tags: 'painting',
    );

    final recommendations = service.recommend([
      unrelated,
      matchingSubject,
      completed,
      matchingTags,
    ]);

    expect(recommendations, [matchingTags, matchingSubject]);
  });

  test('deleted completed documents do not define preferences', () {
    final deleted = document(
      id: 'deleted',
      subject: 'math',
      tags: 'algebra',
      status: 'Đã hoàn thành',
    ).copyWith(isDeleted: true);
    final candidate = document(
      id: 'candidate',
      subject: 'math',
      tags: 'algebra',
    );
    expect(service.recommend([deleted, candidate]), isEmpty);
  });

  test('duplicate tags do not inflate scores and limit is respected', () {
    final completed = document(
      id: 'done',
      subject: 'math',
      tags: 'Algebra, algebra',
      status: 'Đã hoàn thành',
    );
    final older = document(
      id: 'older',
      subject: 'math',
      tags: 'algebra',
      modified: 1,
    );
    final newer = document(
      id: 'newer',
      subject: 'math',
      tags: 'ALGEBRA, algebra',
      modified: 2,
    );
    expect(service.recommend([completed, older, newer], limit: 1), [newer]);
    expect(service.recommend([completed, newer], limit: 0), isEmpty);
  });

  test('returns no suggestions when there are no completed preferences', () {
    expect(
      service.recommend([
        document(id: 'one', subject: 'math', tags: 'algebra'),
      ]),
      isEmpty,
    );
  });
}
