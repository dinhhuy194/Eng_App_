import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

/// State chứa toàn bộ settings
class SettingsState {
  final ThemeMode themeMode;
  final double ttsSpeed;
  final String ttsLanguage;
  final bool notificationsEnabled;
  final int reminderHour;
  final int reminderMinute;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.ttsSpeed = 0.5,
    this.ttsLanguage = 'en-US',
    this.notificationsEnabled = true,
    this.reminderHour = 8,
    this.reminderMinute = 0,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? ttsSpeed,
    String? ttsLanguage,
    bool? notificationsEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }
}

/// Provider quản lý settings — persistent qua SharedPreferences
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsService _service;

  SettingsNotifier(this._service)
      : super(SettingsState(
          themeMode: _service.themeMode,
          ttsSpeed: _service.ttsSpeed,
          ttsLanguage: _service.ttsLanguage,
          notificationsEnabled: _service.notificationsEnabled,
          reminderHour: _service.dailyReminderHour,
          reminderMinute: _service.dailyReminderMinute,
        ));

  Future<void> setThemeMode(ThemeMode mode) async {
    await _service.setThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setTtsSpeed(double speed) async {
    await _service.setTtsSpeed(speed);
    state = state.copyWith(ttsSpeed: speed);
  }

  Future<void> setTtsLanguage(String language) async {
    await _service.setTtsLanguage(language);
    state = state.copyWith(ttsLanguage: language);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _service.setNotificationsEnabled(enabled);
    state = state.copyWith(notificationsEnabled: enabled);
  }

  Future<void> setReminderTime(int hour, int minute) async {
    await _service.setDailyReminderTime(hour, minute);
    state = state.copyWith(reminderHour: hour, reminderMinute: minute);
  }

  /// Labels cho UI
  String get themeModeLabel => _service.themeModeLabel;
  String get ttsSpeedLabel => _service.ttsSpeedLabel;
  String get ttsLanguageLabel => _service.ttsLanguageLabel;
}

/// SettingsService singleton — phải init() trước khi dùng
final settingsServiceProvider = Provider<SettingsService>((ref) {
  throw UnimplementedError(
    'settingsServiceProvider phải được override trong ProviderScope',
  );
});

/// Settings provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return SettingsNotifier(service);
});
