import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

/// Login Screen — Đăng nhập / Đăng ký
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;

    // Lắng nghe auth state changes
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/');
      }
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A56A6),
              Color(0xFF0D9488),
              Color(0xFF667EEA),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.08),

                  // ── Logo & Title ──
                  _buildHeader(),

                  const SizedBox(height: 40),

                  // ── Login Card ──
                  _buildLoginCard(authState),

                  const SizedBox(height: 24),

                  // ── Divider ──
                  _buildDivider(),

                  const SizedBox(height: 24),

                  // ── Google Sign In ──
                  _buildGoogleButton(authState),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'EduApp',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Học tập thông minh với AI',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(AuthState authState) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tab: Đăng nhập / Đăng ký
            Row(
              children: [
                Expanded(
                  child: _buildTab('Đăng nhập', !_isRegisterMode),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTab('Đăng ký', _isRegisterMode),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Name field (chỉ hiện khi đăng ký)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isRegisterMode
                  ? Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: _isRegisterMode
                              ? (v) => v == null || v.trim().isEmpty
                                  ? 'Vui lòng nhập họ tên'
                                  : null
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                if (!v.contains('@')) return 'Email không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                if (v.length < 6) return 'Mật khẩu cần ít nhất 6 ký tự';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isRegisterMode ? 'Tạo tài khoản' : 'Đăng nhập',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isRegisterMode = text == 'Đăng ký';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: Colors.white.withValues(alpha: 0.3)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'hoặc',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: Colors.white.withValues(alpha: 0.3)),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(AuthState authState) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: authState.isLoading
            ? null
            : () => ref.read(authProvider.notifier).signInWithGoogle(),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimaryLight,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: Image.network(
          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
          height: 24,
          width: 24,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.g_mobiledata, size: 28),
        ),
        label: const Text(
          'Đăng nhập với Google',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isRegisterMode) {
      final name = _nameController.text.trim();
      ref.read(authProvider.notifier).registerWithEmail(name, email, password);
    } else {
      ref.read(authProvider.notifier).signInWithEmail(email, password);
    }
  }
}
