import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/history/presentation/providers/history_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transfer History',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    ref.read(historyProvider.notifier).loadHistory();
                  },
                )
              ],
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  Icon(
                    Icons.history_rounded,
                    size: 80,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transfers yet',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: history.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = history[index];
                final isDownload = item.direction == 'DOWNLOAD';
                final isCompleted = item.status == 'COMPLETED';

                return Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: isCompleted 
                        ? Colors.green.withValues(alpha: 0.1) 
                        : colorScheme.error.withValues(alpha: 0.1),
                      child: Icon(
                        isDownload ? Icons.download_rounded : Icons.upload_rounded,
                        color: isCompleted ? Colors.green : colorScheme.error,
                      ),
                    ),
                    title: Text(
                      item.fileName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${(item.fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
                              style: theme.textTheme.labelMedium,
                            ),
                            const SizedBox(width: 8),
                            Container(width: 4, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(
                              isDownload ? 'From: ${item.senderName}' : 'To: ${item.senderName}',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                        if (!isCompleted && item.errorReason != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.errorReason!,
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                          ),
                        ]
                      ],
                    ),
                    trailing: Text(
                      _formatDate(item.completedAt),
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}
