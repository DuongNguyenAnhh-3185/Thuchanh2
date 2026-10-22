import 'package:intl/intl.dart';

/// Tiện ích xử lý và định dạng thời gian kiểu Epoch Milliseconds
class DateHelper {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  /// Lấy timestamp hiện tại tính theo Epoch Milliseconds
  static int currentTimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// Chuyển timestamp sang chuỗi ngày tháng
  static String formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp == 0) return 'Chưa rõ';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return _dateFormat.format(dt);
  }

  /// Chuyển timestamp sang chuỗi giờ phút
  static String formatTime(int? timestamp) {
    if (timestamp == null || timestamp == 0) return 'Chưa rõ';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return _timeFormat.format(dt);
  }

  /// Chuyển timestamp sang chuỗi ngày giờ đầy đủ
  static String formatFullTimestamp(int? timestamp) {
    if (timestamp == null || timestamp == 0) return 'Chưa rõ';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return _dateTimeFormat.format(dt);
  }

  /// Định dạng kích thước tệp tin (Bytes sang KB, MB)
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
