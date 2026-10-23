import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../services/document_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/search_service.dart';
import '../../services/subject_service.dart';

/// Controller quản lý trạng thái hiển thị cho màn hình chính (Presentation Layer)
class DocumentController extends ChangeNotifier {
  final DocumentService documentService;
  final SubjectService subjectService;
  final SearchService searchService;
  final RecommendationService recommendationService;

  StreamSubscription<List<DocumentEntity>>? _docSub;
  StreamSubscription<List<SubjectEntity>>? _subjectSub;

  List<DocumentEntity> _documents = [];
  List<DocumentEntity> _recommendations = [];
  List<SubjectEntity> _subjects = [];
  bool _isLoading = true;
  bool _disposed = false;
  int _generation = 0;

  String _searchQuery = '';
  String? _selectedTag;
  String? _selectedSubjectFk;
  String? _selectedDocumentType;
  String? _selectedStudyStatus;
  String _sortBy = 'date_desc';

  DocumentController({
    required this.documentService,
    required this.subjectService,
    required this.searchService,
    RecommendationService? recommendationService,
  }) : recommendationService =
           recommendationService ?? RecommendationService() {
    _initStreams();
  }

  List<DocumentEntity> get documents {
    final selectedTag = _selectedTag;
    if (selectedTag == null) return _documents;

    return _documents
        .where(
          (document) => document.tags
              .split(',')
              .any(
                (tag) => tag.trim().toLowerCase() == selectedTag.toLowerCase(),
              ),
        )
        .toList();
  }

  List<DocumentEntity> get recommendations => _recommendations;

  List<String> get availableTags {
    final tags =
        _documents
            .expand((document) => document.tags.split(','))
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  List<SubjectEntity> get subjects => _subjects;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedTag => _selectedTag;
  String? get selectedSubjectFk => _selectedSubjectFk;
  String? get selectedDocumentType => _selectedDocumentType;
  String? get selectedStudyStatus => _selectedStudyStatus;
  String get sortBy => _sortBy;

  void _initStreams() {
    _isLoading = true;
    notifyListeners();

    // Lắng nghe thay đổi tự động từ SubjectDao
    _subjectSub = subjectService.watchAllSubjects().listen((subList) {
      if (_disposed) return;
      _subjects = subList;
      notifyListeners();
    });

    // Lắng nghe thay đổi tự động từ DocumentDao (Reactive Stream kiểu Cashew)
    _docSub = documentService.watchAllDocuments().listen((_) async {
      await refreshFilteredList();
    });
  }

  Future<void> refreshFilteredList() async {
    final generation = ++_generation;
    if (_disposed) return;
    _isLoading = true;
    notifyListeners();

    try {
      final documents = await searchService.filterDocuments(
        query: _searchQuery,
        subjectFk: _selectedSubjectFk,
        documentType: _selectedDocumentType,
        studyStatus: _selectedStudyStatus,
        sortBy: _sortBy,
      );
      final allDocuments = await documentService.getAllDocuments();
      if (_disposed || generation != _generation) return;
      _documents = documents;
      _recommendations = recommendationService.recommend(allDocuments);
    } catch (_) {
      if (!_disposed && generation == _generation) _documents = [];
    } finally {
      if (!_disposed && generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    refreshFilteredList();
  }

  void setSelectedTag(String? tag) {
    _selectedTag = tag;
    notifyListeners();
  }

  void setSelectedSubject(String? subjectFk) {
    _selectedSubjectFk = subjectFk;
    refreshFilteredList();
  }

  void setSelectedType(String? type) {
    _selectedDocumentType = type;
    refreshFilteredList();
  }

  void setSelectedStatus(String? status) {
    _selectedStudyStatus = status;
    refreshFilteredList();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    refreshFilteredList();
  }

  Future<void> quickToggleStatus(DocumentEntity doc) async {
    String nextStatus;
    if (doc.studyStatus == AppConstants.statusNotStarted) {
      nextStatus = AppConstants.statusInProgress;
    } else if (doc.studyStatus == AppConstants.statusInProgress) {
      nextStatus = AppConstants.statusCompleted;
    } else {
      nextStatus = AppConstants.statusNotStarted;
    }
    await documentService.updateStudyStatus(doc.documentPk, nextStatus);
  }

  Future<void> softDelete(String documentPk) async {
    await documentService.softDeleteDocument(documentPk);
  }

  Future<void> restoreDocument(String documentPk) async {
    await documentService.restoreDocument(documentPk);
    await refreshFilteredList();
  }

  Future<void> permanentlyDelete(String documentPk) async {
    await documentService.permanentlyDeleteDocument(documentPk);
    await refreshFilteredList();
  }

  Future<List<DocumentEntity>> getDeletedDocuments() async {
    final all = await documentService.getAllDocuments(includeDeleted: true);
    return all.where((d) => d.isDeleted).toList();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _docSub?.cancel();
    _subjectSub?.cancel();
    super.dispose();
  }
}
