import 'package:uuid/uuid.dart';

/// Tiện ích sinh mã định danh UUID v4 phân tán
/// Kế thừa nguyên lý kiến trúc Cashew: mọi thực thể đều có khóa chính UUID 36 ký tự
class UuidHelper {
  static const Uuid _uuid = Uuid();

  /// Sinh một UUID v4 mới
  static String generate() {
    return _uuid.v4();
  }

  /// Kiểm tra xem một chuỗi có phải UUID hợp lệ không
  static bool isValid(String? value) {
    if (value == null || value.isEmpty) return false;
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return regex.hasMatch(value);
  }
}
