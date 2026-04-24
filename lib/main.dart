import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  // 4. Chạy app với Riverpod
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