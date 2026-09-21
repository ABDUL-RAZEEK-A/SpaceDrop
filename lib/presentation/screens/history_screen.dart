import 'package:flutter/material.dart';
import '../widgets/glass_container.dart';
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
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Transfer History',
                    style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: colorScheme.onSurface),
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
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
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

                return GlassContainer(
                  padding: EdgeInsets.zero,
                  margin: const EdgeInsets.only(bottom: 12),
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
                      style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
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
                              style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(width: 8),
                            Container(width: 4, height: 4, decoration: BoxDecoration(color: colorScheme.onSurface.withValues(alpha: 0.3), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isDownload ? 'From: ${item.senderName}' : 'To: ${item.senderName}',
                                style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDate(item.completedAt),
                          style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                        ),
                      ],
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
