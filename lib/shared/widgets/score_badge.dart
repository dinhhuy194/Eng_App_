import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Badge hiển thị điểm số (quiz result, pronunciation score)
class ScoreBadge extends StatelessWidget {
  final double score; // 0-100
  final double size;
  final bool showPercentSign;

  const ScoreBadge({
    super.key,
    required this.score,
    this.size = 80,
    this.showPercentSign = true,
  });

  Color get _color {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  Color get _backgroundColor {
    if (score >= 80) return AppColors.success.withValues(alpha: 0.1);
    if (score >= 60) return AppColors.warning.withValues(alpha: 0.1);
    return AppColors.error.withValues(alpha: 0.1);
  }

  String get _emoji {
    if (score >= 90) return '🎉';
    if (score >= 80) return '👏';
    if (score >= 60) return '💪';
    if (score >= 40) return '📚';
    return '🔄';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _backgroundColor,
            border: Border.all(color: _color, width: 3),
          ),
          child: Center(
            child: Text(
              '${score.round()}${showPercentSign ? '%' : ''}',
              style: TextStyle(
                fontSize: size * 0.28,
                fontWeight: FontWeight.bold,
                color: _color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _emoji,
          style: TextStyle(fontSize: size * 0.3),
        ),
      ],
    );
  }
}

/// Mini score chip — dùng trong danh sách
class ScoreChip extends StatelessWidget {
  final double score;

  const ScoreChip({super.key, required this.score});

  Color get _color {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${score.round()}%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}
