import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Widget hiển thị lỗi có nút retry
class AppErrorWidget extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final IconData icon;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.details,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  /// Error khi không có mạng
  factory AppErrorWidget.network({VoidCallback? onRetry}) {
    return AppErrorWidget(
      message: 'Không có kết nối mạng',
      details: 'Vui lòng kiểm tra kết nối và thử lại.',
      icon: Icons.wifi_off_rounded,
      onRetry: onRetry,
    );
  }

  /// Error khi hết rate limit
  factory AppErrorWidget.rateLimit({VoidCallback? onRetry}) {
    return AppErrorWidget(
      message: 'Đã đạt giới hạn sử dụng hôm nay',
      details: 'Bạn có thể thử lại vào ngày mai.',
      icon: Icons.hourglass_empty_rounded,
      onRetry: onRetry,
    );
  }

  /// Error rỗng — khi không có dữ liệu
  factory AppErrorWidget.empty({
    String message = 'Chưa có dữ liệu',
    String? details,
  }) {
    return AppErrorWidget(
      message: message,
      details: details,
      icon: Icons.inbox_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textSecondaryLight),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(
                details!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
