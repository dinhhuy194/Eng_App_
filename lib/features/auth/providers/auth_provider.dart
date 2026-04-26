import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/services/firebase_service.dart';

/// Trạng thái authentication
enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

/// Auth Notifier — quản lý đăng nhập/đăng xuất
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseService _firebaseService = FirebaseService();

  AuthNotifier() : super(const AuthState()) {
    // Lắng nghe auth state changes
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  /// Đăng nhập bằng Google
  Future<void> signInWithGoogle() async {
    try {
      state = state.copyWith(status: AuthStatus.loading);

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _firebaseService.createUserProfile(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e.code),
      );
    } catch (e) {
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Đã xảy ra lỗi. Vui lòng thử lại.',
      );
    }
  }

  /// Đăng nhập bằng Email/Password
  Future<void> signInWithEmail(String email, String password) async {
    try {
      state = state.copyWith(status: AuthStatus.loading);

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (userCredential.user != null) {
        await _firebaseService.createUserProfile(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 [Auth] signIn FirebaseAuthException: ${e.code} - ${e.message}');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e.code),
      );
    } catch (e) {
      debugPrint('🔴 [Auth] signIn Error: $e');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Đã xảy ra lỗi khi đăng nhập: $e',
      );
    }
  }

  /// Đăng ký tài khoản bằng Email/Password
  Future<void> registerWithEmail(
      String name, String email, String password) async {
    try {
      state = state.copyWith(status: AuthStatus.loading);

      debugPrint('🟡 [Auth] Đang đăng ký với email: $email');

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      debugPrint('🟢 [Auth] Đã tạo tài khoản, uid: ${userCredential.user?.uid}');

      // Cập nhật display name
      await userCredential.user?.updateDisplayName(name.trim());
      await userCredential.user?.reload();

      debugPrint('🟢 [Auth] Đã cập nhật display name');

      if (_auth.currentUser != null) {
        await _firebaseService.createUserProfile(_auth.currentUser!);
        debugPrint('🟢 [Auth] Đã tạo user profile trên Firestore');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 [Auth] register FirebaseAuthException: ${e.code} - ${e.message}');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e.code),
      );
    } catch (e) {
      debugPrint('🔴 [Auth] register Error: $e');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Đã xảy ra lỗi khi đăng ký: $e',
      );
    }
  }

  /// Đăng xuất
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Xóa lỗi
  void clearError() {
    state = state.copyWith(
      status: state.user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      errorMessage: null,
    );
  }

  /// Map Firebase error codes → thông báo tiếng Việt
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
        return 'Mật khẩu không đúng.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Cần ít nhất 6 ký tự.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Vui lòng đợi một lúc.';
      case 'network-request-failed':
        return 'Không có kết nối mạng.';
      default:
        return 'Đã xảy ra lỗi ($code). Vui lòng thử lại.';
    }
  }
}

// ── Providers ──

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

/// Stream provider cho auth state (dùng cho router redirect)
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
