import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/notification_service.dart';
import 'core/services/settings_service.dart';
import 'core/providers/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  // 1. Đảm bảo Flutter binding sẵn sàng (phải gọi trước)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load biến môi trường từ .env
  await dotenv.load(fileName: ".env");

  // 3. Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 4. Khởi tạo Firebase
  await Firebase.initializeApp();

  // 5. Tắt App Verification (reCAPTCHA) trong chế độ debug
  if (kDebugMode) {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
    debugPrint('🟢 [Main] Firebase Auth: appVerificationDisabledForTesting = true');
  }

  // 6. Khởi tạo Settings Service (SharedPreferences)
  final settingsService = SettingsService();
  await settingsService.init();
  debugPrint('⚙️ [Main] SettingsService initialized');

  // 7. Khởi tạo Notification Service + nhắc ôn hàng ngày
  try {
    await NotificationService().init();
    if (settingsService.notificationsEnabled) {
      await NotificationService().scheduleDailyReminder(
        hour: settingsService.dailyReminderHour,
        minute: settingsService.dailyReminderMinute,
      );
    }
    debugPrint('🔔 [Main] NotificationService initialized');
  } catch (e) {
    debugPrint('⚠️ [Main] NotificationService init failed: $e');
  }

  // 8. Chạy app với Riverpod — override settingsServiceProvider
  runApp(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWithValue(settingsService),
      ],
      child: const EduApp(),
    ),
  );
}

/// Root Widget — EduApp
class EduApp extends ConsumerWidget {
  const EduApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'EduApp - Học Tập Thông Minh',

      // Theme — reactive từ SettingsProvider
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,

      // Router
      routerConfig: AppRouter.router,
    );
  }
}