import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Huy hiệu hiển thị trạng thái học tập (Chưa học, Đang học, Đã hoàn thành)
class StatusBadge extends StatelessWidget {
  final String status;
  final VoidCallback? onTap;

  const StatusBadge({
    super.key,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    IconData icon;

    switch (status) {
      case AppConstants.statusCompleted:
        bg = const Color(0xFFDCFCE7); // Green light
        text = const Color(0xFF166534); // Green dark
        icon = Icons.check_circle_outline;
        break;
      case AppConstants.statusInProgress:
        bg = const Color(0xFFFEF3C7); // Amber light
        text = const Color(0xFF92400E); // Amber dark
        icon = Icons.timelapse;
        break;
      case AppConstants.statusNotStarted:
      default:
        bg = const Color(0xFFF1F5F9); // Gray light
        text = const Color(0xFF475569); // Gray dark
        icon = Icons.radio_button_unchecked;
        break;
    }

    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: text.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: widget,
      );
    }
    return widget;
  }
}
