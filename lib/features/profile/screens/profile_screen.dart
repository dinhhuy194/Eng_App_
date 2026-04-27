import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../review/services/flashcard_service.dart';

/// Profile Screen — Thông tin cá nhân & Cài đặt (Functional)
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Stats
  int _docCount = 0;
  int _flashcardCount = 0;
  int _masteredCount = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Đếm documents
      final docsSnapshot = await FirebaseService().getDocumentsOnce();
      final docCount = docsSnapshot.docs.length;

      // Đếm flashcards
      final flashStats = await FlashcardService().getStats();
      final total = flashStats['total'] ?? 0;
      final mastered = flashStats['mastered'] ?? 0;

      if (mounted) {
        setState(() {
          _docCount = docCount;
          _flashcardCount = total;
          _masteredCount = mastered;
          _statsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statsLoaded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ & Cài đặt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar + Info
            _buildProfileHeader(context, user),
            const SizedBox(height: 28),

            // Thống kê — real data
            _buildStatsSection(context),
            const SizedBox(height: 24),

            // Cài đặt — functional
            _buildSettingsSection(context, settings),
            const SizedBox(height: 24),

            // Đăng xuất
            _buildLogoutButton(context, ref),
            const SizedBox(height: 32),

            // Version
            Text(
              'EduApp v1.0.0',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  PROFILE HEADER
  // ═══════════════════════════════════════════
  Widget _buildProfileHeader(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: user?.photoURL != null
                ? ClipOval(
                    child: Image.network(
                      user!.photoURL!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Người dùng',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  STATS — Real data from Firestore
  // ═══════════════════════════════════════════
  Widget _buildStatsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thống kê học tập',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              context,
              icon: Icons.description_rounded,
              label: 'Tài liệu',
              value: _statsLoaded ? '$_docCount' : '—',
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              context,
              icon: Icons.style_rounded,
              label: 'Flashcard',
              value: _statsLoaded ? '$_flashcardCount' : '—',
              color: AppColors.secondary,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              context,
              icon: Icons.check_circle_rounded,
              label: 'Đã thuộc',
              value: _statsLoaded ? '$_masteredCount' : '—',
              color: const Color(0xFF059669),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  SETTINGS — Functional
  // ═══════════════════════════════════════════
  Widget _buildSettingsSection(BuildContext context, SettingsState settings) {
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cài đặt',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            children: [
              // TTS Language
              _buildSettingsTile(
                icon: Icons.language_rounded,
                title: 'Ngôn ngữ TTS',
                subtitle: notifier.ttsLanguageLabel,
                onTap: () => _showTtsLanguagePicker(context),
              ),
              _buildDivider(),

              // TTS Speed
              _buildSettingsTile(
                icon: Icons.speed_rounded,
                title: 'Tốc độ đọc',
                subtitle: notifier.ttsSpeedLabel,
                onTap: () => _showTtsSpeedPicker(context, settings),
              ),
              _buildDivider(),

              // Theme Mode
              _buildSettingsTile(
                icon: Icons.dark_mode_rounded,
                title: 'Giao diện',
                subtitle: notifier.themeModeLabel,
                onTap: () => _showThemeModePicker(context, settings),
              ),
              _buildDivider(),

              // Notifications
              SwitchListTile(
                secondary: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'Nhắc ôn tập',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  settings.notificationsEnabled
                      ? 'Hàng ngày lúc ${settings.reminderHour.toString().padLeft(2, '0')}:${settings.reminderMinute.toString().padLeft(2, '0')}'
                      : 'Đã tắt',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                value: settings.notificationsEnabled,
                onChanged: (value) async {
                  await notifier.setNotificationsEnabled(value);
                  if (value) {
                    await NotificationService().scheduleDailyReminder(
                      hour: settings.reminderHour,
                      minute: settings.reminderMinute,
                    );
                  } else {
                    await NotificationService().cancelAll();
                  }
                },
                activeColor: AppColors.primary,
              ),
              _buildDivider(),

              // About
              _buildSettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'Về ứng dụng',
                subtitle: 'EduApp v1.0.0',
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  PICKERS / DIALOGS
  // ═══════════════════════════════════════════

  void _showTtsLanguagePicker(BuildContext context) {
    final notifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider).ttsLanguage;

    final languages = [
      ('en-US', 'English (US)'),
      ('en-GB', 'English (UK)'),
      ('en-AU', 'English (Australia)'),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Chọn ngôn ngữ TTS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            ...languages.map((lang) => RadioListTile<String>(
                  title: Text(lang.$2),
                  value: lang.$1,
                  groupValue: current,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    if (value != null) {
                      notifier.setTtsLanguage(value);
                      Navigator.pop(ctx);
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showTtsSpeedPicker(BuildContext context, SettingsState settings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          double speed = settings.ttsSpeed;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tốc độ đọc',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🐢 Chậm'),
                    Text(
                      '${(speed * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                    const Text('🐇 Nhanh'),
                  ],
                ),
                Slider(
                  value: speed,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    setSheetState(() => speed = value);
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(settingsProvider.notifier).setTtsSpeed(speed);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Lưu'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showThemeModePicker(BuildContext context, SettingsState settings) {
    final notifier = ref.read(settingsProvider.notifier);

    final modes = [
      (ThemeMode.system, 'Theo hệ thống', Icons.phone_android_rounded),
      (ThemeMode.light, 'Sáng', Icons.wb_sunny_rounded),
      (ThemeMode.dark, 'Tối', Icons.dark_mode_rounded),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Chọn giao diện',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            ...modes.map((mode) => RadioListTile<ThemeMode>(
                  secondary: Icon(mode.$3, color: AppColors.primary),
                  title: Text(mode.$2),
                  value: mode.$1,
                  groupValue: settings.themeMode,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    if (value != null) {
                      notifier.setThemeMode(value);
                      Navigator.pop(ctx);
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_stories_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('EduApp'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phiên bản: 1.0.0'),
            SizedBox(height: 8),
            Text('Ứng dụng học tiếng Anh thông minh với AI.'),
            SizedBox(height: 12),
            Text(
              '© 2024 EduApp. All rights reserved.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  COMMON WIDGETS
  // ═══════════════════════════════════════════

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondaryLight,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 60,
      color: Colors.grey.withValues(alpha: 0.1),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Đăng xuất'),
              content: const Text('Bạn có chắc muốn đăng xuất?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(authProvider.notifier).signOut();
                    context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  child: const Text('Đăng xuất',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
        label: const Text(
          'Đăng xuất',
          style: TextStyle(color: AppColors.error),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: AppColors.error.withValues(alpha: 0.3),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
