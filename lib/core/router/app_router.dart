import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/documents/screens/document_list_screen.dart';
import '../../features/documents/screens/document_detail_screen.dart';
import '../../features/quiz/screens/quiz_setup_screen.dart';
import '../../features/quiz/screens/quiz_screen.dart';
import '../../features/quiz/screens/quiz_result_screen.dart';
import '../../features/tts/screens/reading_screen.dart';
import '../../features/pronunciation/screens/pronunciation_screen.dart';
import '../../features/qa/screens/qa_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/review/screens/review_screen.dart';
import '../../features/splash/screens/splash_screen.dart';

/// App Router — GoRouter configuration
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,

    // Auth redirect
    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final isLoginRoute = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      // Cho phép splash screen luôn hiển thị
      if (isSplash) return null;

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },

    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/documents',
        name: 'documents',
        builder: (context, state) => const DocumentListScreen(),
      ),
      GoRoute(
        path: '/documents/:docId',
        name: 'document-detail',
        builder: (context, state) {
          final docId = state.pathParameters['docId']!;
          final title = state.uri.queryParameters['title'] ?? 'Tài liệu';
          return DocumentDetailScreen(documentId: docId, title: title);
        },
      ),
      GoRoute(
        path: '/quiz/setup/:docId',
        name: 'quiz-setup',
        builder: (context, state) =>
            QuizSetupScreen(documentId: state.pathParameters['docId']!),
      ),
      GoRoute(
        path: '/quiz/play/:quizId',
        name: 'quiz-play',
        builder: (context, state) =>
            QuizPlayScreen(quizId: state.pathParameters['quizId']!),
      ),
      GoRoute(
        path: '/quiz/result/:quizId',
        name: 'quiz-result',
        builder: (context, state) =>
            QuizResultScreen(quizId: state.pathParameters['quizId']!),
      ),
      GoRoute(
        path: '/reading/:docId',
        name: 'reading',
        builder: (context, state) =>
            ReadingScreen(documentId: state.pathParameters['docId']!),
      ),
      GoRoute(
        path: '/pronunciation/:docId',
        name: 'pronunciation',
        builder: (context, state) =>
            PronunciationScreen(documentId: state.pathParameters['docId']!),
      ),
      GoRoute(
        path: '/qa/:docId',
        name: 'qa',
        builder: (context, state) =>
            QAScreen(documentId: state.pathParameters['docId']!),
      ),
      GoRoute(
        path: '/review',
        name: 'review',
        builder: (context, state) => const ReviewScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Trang không tồn tại',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Về trang chủ'),
            ),
          ],
        ),
      ),
    ),
  );
}
