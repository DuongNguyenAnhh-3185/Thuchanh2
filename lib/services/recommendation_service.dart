import '../core/constants/app_constants.dart';
import '../domain/entities/document_entity.dart';

/// Recommends unfinished documents using tags and subjects from completed work.
class RecommendationService {
  List<DocumentEntity> recommend(
    List<DocumentEntity> documents, {
    int limit = 5,
  }) {
    final completed = documents
        .where(
          (document) =>
              document.studyStatus == AppConstants.statusCompleted &&
              !document.isDeleted,
        )
        .toList(growable: false);
    if (completed.isEmpty || limit <= 0) return const [];

    final preferredTags = <String, int>{};
    final preferredSubjects = <String, int>{};
    for (final document in completed) {
      for (final tag in _tags(document)) {
        preferredTags.update(tag, (count) => count + 1, ifAbsent: () => 1);
      }
      preferredSubjects.update(
        document.subjectFk,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final ranked =
        documents
            .where(
              (document) =>
                  document.studyStatus != AppConstants.statusCompleted &&
                  !document.isDeleted,
            )
            .map((document) {
              final tagScore = _tags(
                document,
              ).fold<int>(0, (score, tag) => score + (preferredTags[tag] ?? 0));
              final subjectScore = preferredSubjects[document.subjectFk] ?? 0;
              return (document: document, score: tagScore * 3 + subjectScore);
            })
            .where((entry) => entry.score > 0)
            .toList()
          ..sort((a, b) {
            final scoreOrder = b.score.compareTo(a.score);
            return scoreOrder != 0
                ? scoreOrder
                : b.document.dateTimeModified.compareTo(
                    a.document.dateTimeModified,
                  );
          });

    return ranked
        .take(limit)
        .map((entry) => entry.document)
        .toList(growable: false);
  }

  Set<String> _tags(DocumentEntity document) => document.tags
      .split(',')
      .map((tag) => tag.trim().toLowerCase())
      .where((tag) => tag.isNotEmpty)
      .toSet();
}
