import 'package:flutter/material.dart';

/// Design System — Color Tokens
/// Dựa trên tài liệu thiết kế EduApp v1.0
class AppColors {
  AppColors._();

  // ── Primary ──
  static const Color primary = Color(0xFF1A56A6);
  static const Color primaryDark = Color(0xFF4B8FE2);
  static const Color primaryLight = Color(0xFFD4E4F7);

  // ── Secondary ──
  static const Color secondary = Color(0xFF0D9488);
  static const Color secondaryDark = Color(0xFF14B8A6);
  static const Color secondaryLight = Color(0xFFCCFBF1);

  // ── Background ──
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color backgroundDark = Color(0xFF111827);

  // ── Surface ──
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1F2937);

  // ── Text ──
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  // ── Status ──
  static const Color success = Color(0xFF059669);
  static const Color successDark = Color(0xFF34D399);
  static const Color error = Color(0xFFDC2626);
  static const Color errorDark = Color(0xFFF87171);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFFBBF24);

  // ── Quiz colors ──
  static const Color correctAnswer = Color(0xFF059669);
  static const Color wrongAnswer = Color(0xFFDC2626);
  static const Color selectedOption = Color(0xFF1A56A6);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A56A6), Color(0xFF0D9488)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF14B8A6)],
  );
}
