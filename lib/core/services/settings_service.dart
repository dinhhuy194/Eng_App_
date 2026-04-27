import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SettingsService — Quản lý cài đặt người dùng
/// Lưu trữ persistent: theme mode, TTS speed, TTS language
class SettingsService {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyTtsSpeed = 'tts_speed';
  static const String _keyTtsLanguage = 'tts_language';
  static const String _keyDailyReminderHour = 'daily_reminder_hour';
  static const String _keyDailyReminderMinute = 'daily_reminder_minute';
  static const String _keyNotificationsEnabled = 'notifications_enabled';

  late final SharedPreferences _prefs;

  /// Khởi tạo — phải gọi trước khi dùng
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Theme Mode ──

  ThemeMode get themeMode {
    final value = _prefs.getString(_keyThemeMode) ?? 'system';
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
      case ThemeMode.dark:
        value = 'dark';
      case ThemeMode.system:
        value = 'system';
    }
    await _prefs.setString(_keyThemeMode, value);
  }

  String get themeModeLabel {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Sáng';
      case ThemeMode.dark:
        return 'Tối';
      case ThemeMode.system:
        return 'Theo hệ thống';
    }
  }

  // ── TTS Speed ──

  double get ttsSpeed => _prefs.getDouble(_keyTtsSpeed) ?? 0.5;

  Future<void> setTtsSpeed(double speed) async {
    await _prefs.setDouble(_keyTtsSpeed, speed.clamp(0.1, 1.0));
  }

  String get ttsSpeedLabel {
    final speed = ttsSpeed;
    if (speed <= 0.3) return 'Chậm';
    if (speed <= 0.6) return 'Trung bình';
    return 'Nhanh';
  }

  // ── TTS Language ──

  String get ttsLanguage => _prefs.getString(_keyTtsLanguage) ?? 'en-US';

  Future<void> setTtsLanguage(String language) async {
    await _prefs.setString(_keyTtsLanguage, language);
  }

  String get ttsLanguageLabel {
    switch (ttsLanguage) {
      case 'en-US':
        return 'English (US)';
      case 'en-GB':
        return 'English (UK)';
      case 'en-AU':
        return 'English (AU)';
      default:
        return ttsLanguage;
    }
  }

  // ── Notifications ──

  bool get notificationsEnabled =>
      _prefs.getBool(_keyNotificationsEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  int get dailyReminderHour => _prefs.getInt(_keyDailyReminderHour) ?? 8;
  int get dailyReminderMinute => _prefs.getInt(_keyDailyReminderMinute) ?? 0;

  Future<void> setDailyReminderTime(int hour, int minute) async {
    await _prefs.setInt(_keyDailyReminderHour, hour);
    await _prefs.setInt(_keyDailyReminderMinute, minute);
  }
}
