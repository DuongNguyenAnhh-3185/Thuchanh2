import 'package:flutter/material.dart';

/// Hằng số toàn cục cho hệ thống Quản lý Tài liệu Học tập (CashewDoc)
/// Áp dụng bảng màu và chuẩn thiết kế theo phong cách Cashew
class AppConstants {
  static const String supabaseUrl = 'https://oemlhoqptgrgtwaozmgu.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_oo6cgZImDTT2zmc9SSZ-VQ_CzMkTGMW';

  static const String appName = 'CashewDoc';
  static const String appSubtitle =
      'Quản lý Tài liệu Học tập Chuẩn Kiến trúc Cashew';
  static const String appVersion = '1.0.0';

  // Tên các bảng CSDL SQLite
  static const String tableSubjects = 'subjects';
  static const String tableDocuments = 'documents';
  static const String tableAttachments = 'attachments';
  static const String tableDeleteLogs = 'delete_logs';

  // Loại tài liệu học tập
  static const String typeLecture = 'Bài giảng (Lecture)';
  static const String typeAssignment = 'Bài tập (Assignment)';
  static const String typeReference = 'Tài liệu tham khảo (Reference)';
  static const String typeExam = 'Đề thi & Đề cương (Exam)';

  static const List<String> documentTypes = [
    typeLecture,
    typeAssignment,
    typeReference,
    typeExam,
  ];

  // Trạng thái tiến độ học tập
  static const String statusNotStarted = 'Chưa học';
  static const String statusInProgress = 'Đang học';
  static const String statusCompleted = 'Đã hoàn thành';

  static const List<String> studyStatuses = [
    statusNotStarted,
    statusInProgress,
    statusCompleted,
  ];

  // Mức độ ưu tiên
  static const int priorityLow = 1;
  static const int priorityMedium = 2;
  static const int priorityHigh = 3;

  // Màu sắc chủ đạo (theo thiết kế Material You & Cashew)
  static const Color primaryColor = Color(0xFF1E3A8A); // Deep Navy
  static const Color secondaryColor = Color(0xFF0284C7); // Sky Blue
  static const Color accentColor = Color(0xFFD97706); // Warm Amber
  static const Color backgroundColor = Color(0xFFF8FAFC); // Clean Slate
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimaryColor = Color(0xFF0F172A);
  static const Color textSecondaryColor = Color(0xFF64748B);

  // Bảng màu đề xuất cho Môn học
  static const List<Color> subjectColorPalette = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Purple
    Color(0xFF14B8A6), // Teal
    Color(0xFFEF4444), // Red
    Color(0xFF6366F1), // Indigo
  ];
}
