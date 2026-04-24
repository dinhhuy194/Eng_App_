import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/models/document_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Home Screen — Dashboard chính
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          _buildSliverAppBar(context, ref, user),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Greeting
                _buildGreeting(context, user),
                const SizedBox(height: 24),

                // Quick Actions
                _buildQuickActions(context),
                const SizedBox(height: 28),

                // Recent Documents
                _buildSectionTitle(context, 'Tài liệu gần đây', onSeeAll: () {
                  context.push('/documents');
                }),
                const SizedBox(height: 12),
                _buildRecentDocuments(context),

                const SizedBox(height: 28),

                // Learning Stats
                _buildSectionTitle(context, 'Thống kê học tập'),
                const SizedBox(height: 12),
                _buildLearningStats(context),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/documents'),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Tải tài liệu'),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  SLIVER APP BAR
  // ═══════════════════════════════════════════
  Widget _buildSliverAppBar(
      BuildContext context, WidgetRef ref, dynamic user) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'EduApp',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        // Avatar / Profile
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Text(
                      (user?.displayName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  GREETING
  // ═══════════════════════════════════════════
  Widget _buildGreeting(BuildContext context, dynamic user) {
    final hour = DateTime.now().hour;
    String greeting;
    String emoji;
    if (hour < 12) {
      greeting = 'Chào buổi sáng';
      emoji = '☀️';
    } else if (hour < 18) {
      greeting = 'Chào buổi chiều';
      emoji = '🌤️';
    } else {
      greeting = 'Chào buổi tối';
      emoji = '🌙';
    }

    final name = user?.displayName ?? 'bạn';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting $emoji',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hôm nay bạn muốn học gì?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  QUICK ACTIONS (4 cards)
  // ═══════════════════════════════════════════
  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.upload_file_rounded,
        label: 'Upload\nTài liệu',
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        onTap: () => context.push('/documents'),
      ),
      _QuickAction(
        icon: Icons.quiz_rounded,
        label: 'Làm\nTrắc nghiệm',
        gradient: const LinearGradient(
          colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
        ),
        onTap: () => context.push('/documents'),
      ),
      _QuickAction(
        icon: Icons.record_voice_over_rounded,
        label: 'Kiểm tra\nPhát âm',
        gradient: const LinearGradient(
          colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
        ),
        onTap: () => context.push('/documents'),
      ),
      _QuickAction(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Hỏi đáp\nAI',
        gradient: const LinearGradient(
          colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
        ),
        onTap: () => context.push('/documents'),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: actions.map((a) => _buildQuickActionCard(context, a)).toList(),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, _QuickAction action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: action.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: action.gradient.colors.first.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(action.icon, color: Colors.white, size: 28),
              Text(
                action.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  SECTION TITLE
  // ═══════════════════════════════════════════
  Widget _buildSectionTitle(BuildContext context, String title,
      {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('Xem tất cả'),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  RECENT DOCUMENTS
  // ═══════════════════════════════════════════
  Widget _buildRecentDocuments(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseService().getDocumentsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyDocuments(context);
        }

        final docs = snapshot.data!.docs
            .take(5)
            .map((doc) => DocumentModel.fromFirestore(doc))
            .toList();

        return Column(
          children: docs
              .map((doc) => _buildDocumentCard(context, doc))
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyDocuments(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 52,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có tài liệu nào',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tải lên PDF, DOCX hoặc EPUB để bắt đầu học',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, DocumentModel doc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () =>
            context.push('/documents/${doc.id}?title=${Uri.encodeComponent(doc.title)}'),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(doc.fileIcon, style: const TextStyle(fontSize: 22)),
          ),
        ),
        title: Text(
          doc.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${doc.fileType.toUpperCase()} • ${doc.chunkCount} phần',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryLight,
          ),
        ),
        trailing: Icon(
          doc.isReady
              ? Icons.check_circle_rounded
              : Icons.hourglass_bottom_rounded,
          color: doc.isReady ? AppColors.success : AppColors.warning,
          size: 20,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  LEARNING STATS
  // ═══════════════════════════════════════════
  Widget _buildLearningStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _buildStatCard(
                context, Icons.description_rounded, '0', 'Tài liệu',
                color: AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child: _buildStatCard(
                context, Icons.quiz_rounded, '0', 'Quiz hoàn thành',
                color: const Color(0xFFF5576C))),
        const SizedBox(width: 10),
        Expanded(
            child: _buildStatCard(
                context, Icons.mic_rounded, '0', 'Phát âm',
                color: AppColors.secondary)),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String value,
    String label, {
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                  fontSize: 11,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Helper class
class _QuickAction {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });
}
