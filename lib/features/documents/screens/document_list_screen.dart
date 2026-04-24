import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/document_model.dart';
import '../../../shared/widgets/error_widget.dart';
import '../providers/document_provider.dart';

/// Màn hình danh sách tài liệu + Upload
class DocumentListScreen extends ConsumerWidget {
  const DocumentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docState = ref.watch(documentProvider);
    final docsAsync = ref.watch(documentsStreamProvider);

    // Lắng nghe upload errors
    ref.listen<DocumentState>(documentProvider, (prev, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(documentProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài liệu của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO: implement search
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Upload Progress
          if (docState.isProcessing) _buildUploadProgress(context, docState),

          // Document list
          Expanded(
            child: docsAsync.when(
              data: (docs) => docs.isEmpty
                  ? _buildEmptyState(context, ref)
                  : _buildDocumentList(context, ref, docs),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorWidget(
                message: 'Không thể tải danh sách tài liệu',
                details: e.toString(),
                onRetry: () => ref.invalidate(documentsStreamProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: docState.isProcessing
            ? null
            : () => _pickAndUpload(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tải lên'),
        backgroundColor:
            docState.isProcessing ? Colors.grey : AppColors.primary,
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  UPLOAD PROGRESS BAR
  // ═══════════════════════════════════════════
  Widget _buildUploadProgress(BuildContext context, DocumentState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.statusMessage ?? 'Đang xử lý...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.uploadProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  EMPTY STATE
  // ═══════════════════════════════════════════
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.upload_file_rounded,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bắt đầu học ngay!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tải lên tài liệu PDF hoặc DOCX để AI giúp bạn\ntạo quiz, kiểm tra phát âm và hỏi đáp thông minh.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _pickAndUpload(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tải tài liệu đầu tiên'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  DOCUMENT LIST
  // ═══════════════════════════════════════════
  Widget _buildDocumentList(
      BuildContext context, WidgetRef ref, List<DocumentModel> docs) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        return _DocumentCard(
          document: doc,
          onTap: () {
            ref.read(documentProvider.notifier).markAsOpened(doc.id);
            context.push(
              '/documents/${doc.id}?title=${Uri.encodeComponent(doc.title)}',
            );
          },
          onDelete: () => _confirmDelete(context, ref, doc),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  //  PICK FILE & UPLOAD
  // ═══════════════════════════════════════════
  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ApiConstants.supportedFileTypes,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final ext = file.extension?.toLowerCase() ?? '';

      // Kiểm tra size
      if (file.size > ApiConstants.maxFileSizeBytes) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'File quá lớn (>${ApiConstants.maxFileSizeMB}MB). Vui lòng chọn file nhỏ hơn.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (file.bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể đọc file. Vui lòng thử lại.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Upload & parse
      ref.read(documentProvider.notifier).uploadAndParse(
            fileName: file.name,
            fileBytes: file.bytes!,
            fileType: ext,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, DocumentModel doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài liệu?'),
        content: Text('Bạn có chắc muốn xóa "${doc.title}"?\n'
            'Tất cả quiz và dữ liệu liên quan sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(documentProvider.notifier).deleteDocument(doc.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  DOCUMENT CARD WIDGET
// ═══════════════════════════════════════════
class _DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocumentCard({
    required this.document,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: document.isReady ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // File icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _getFileColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    document.fileIcon,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildChip(
                          document.fileType.toUpperCase(),
                          _getFileColor(),
                        ),
                        const SizedBox(width: 8),
                        if (document.isReady)
                          Text(
                            '${document.chunkCount} phần • ${document.pageCount} trang',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        if (document.isParsing)
                          const Text(
                            'Đang xử lý...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                            ),
                          ),
                        if (document.isError)
                          const Text(
                            'Lỗi',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status & options
              Column(
                children: [
                  Icon(
                    document.isReady
                        ? Icons.check_circle_rounded
                        : document.isError
                            ? Icons.error_rounded
                            : Icons.hourglass_bottom_rounded,
                    color: document.isReady
                        ? AppColors.success
                        : document.isError
                            ? AppColors.error
                            : AppColors.warning,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondaryLight,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getFileColor() {
    switch (document.fileType) {
      case 'pdf':
        return const Color(0xFFE53E3E);
      case 'docx':
        return const Color(0xFF3182CE);
      case 'epub':
        return const Color(0xFF38A169);
      default:
        return AppColors.primary;
    }
  }
}
