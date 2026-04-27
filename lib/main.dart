import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  // 1. Đảm bảo Flutter binding sẵn sàng (phải gọi trước)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load biến môi trường từ .env
  await dotenv.load(fileName: ".env");

  // 2. Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 3. Khởi tạo Firebase
  // Trên Android, Firebase tự cấu hình từ google-services.json
  // Trên các platform khác, cần firebase_options.dart
  await Firebase.initializeApp();

  // 4. Tắt App Verification (reCAPTCHA) trong chế độ debug
  // Trên emulator, reCAPTCHA bị treo khi đăng ký → cần tắt
  if (kDebugMode) {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
    debugPrint('🟢 [Main] Firebase Auth: appVerificationDisabledForTesting = true');
  }

  // 5. Khởi tạo Notification Service + nhắc ôn hàng ngày
  try {
    await NotificationService().init();
    await NotificationService().scheduleDailyReminder(hour: 8, minute: 0);
    debugPrint('🔔 [Main] NotificationService initialized');
  } catch (e) {
    debugPrint('⚠️ [Main] NotificationService init failed: $e');
  }

  // 6. Chạy app với Riverpod
  runApp(const ProviderScope(child: EduApp()));
}

/// Root Widget — EduApp
class EduApp extends StatelessWidget {
  const EduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'EduApp - Học Tập Thông Minh',

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Router
      routerConfig: AppRouter.router,
    );
  }
}