import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../features/discovery/presentation/providers/client_provider.dart';
import '../../core/providers/settings_provider.dart';

class ClientLobbyScreen extends ConsumerWidget {
  const ClientLobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientState = ref.watch(clientProvider);
    final settingsState = ref.watch(settingsProvider);
    final lobby = clientState.connectedLobby;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (lobby == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lobby Closed')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off_rounded, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Disconnected from the lobby',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              lobby.lobbyName,
              style: theme.textTheme.titleMedium,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Host: ${lobby.hostDeviceName}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (clientState.isCoHost)
            IconButton(
              icon: Icon(Icons.upload_file_rounded, color: colorScheme.primary),
              tooltip: 'Share File (Co-host)',
              onPressed: () async {
                final result = await FilePicker.pickFiles(allowMultiple: true);
                if (result != null) {
                  for (final file in result.files) {
                    if (file.path != null) {
                      ref.read(clientProvider.notifier).uploadFile(File(file.path!));
                    }
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Uploading ${result.files.length} file(s)...')),
                    );
                  }
                }
              },
            ),
          IconButton(
            icon: Icon(Icons.exit_to_app_rounded, color: colorScheme.error),
            tooltip: 'Leave Lobby',
            onPressed: () {
              ref.read(clientProvider.notifier).leaveLobby();
            },
          ),
        ],
      ),
      body: Container(
        color: colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!clientState.isApproved)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: colorScheme.primary),
                      const SizedBox(height: 24),
                      Text(
                        'Waiting for host to approve...',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (clientState.isCoHost && clientState.pendingRequests.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_rounded, color: colorScheme.tertiary),
                      const SizedBox(width: 8),
                      Text(
                        'Requests (${clientState.pendingRequests.length})',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: clientState.pendingRequests.length,
                  itemBuilder: (context, index) {
                    final request = clientState.pendingRequests[index];
                    return ListTile(
                      title: Text(request['deviceName'], style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text('Wants to join', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                            onPressed: () => ref.read(clientProvider.notifier).approveJoinRequest(request['requestId']),
                          ),
                          IconButton(
                            icon: Icon(Icons.cancel_rounded, color: colorScheme.error),
                            onPressed: () => ref.read(clientProvider.notifier).rejectJoinRequest(request['requestId']),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Files',
                      style: theme.textTheme.headlineLarge,
                    ),
                    if (clientState.availableFiles.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.select_all_rounded),
                        label: const Text('Select All'),
                        onPressed: () {
                          ref.read(clientProvider.notifier).selectAll();
                        },
                      ),
                  ],
                ),
              ),
              if (clientState.availableFiles.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Waiting for host to share files...',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '(Available files will appear here)',
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: clientState.availableFiles.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final file = clientState.availableFiles[index];
                      final fileId = file['fileId'] as String;
                      final fileName = file['fileName'] as String;
                      final fileSize = file['fileSize'] as int;
                      final sizeInMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
                      
                      final isSelected = clientState.selectedFileIds.contains(fileId);
                      final downloadProgress = clientState.downloadProgresses[fileId];
                      final isDownloading = downloadProgress != null && downloadProgress < 1.0;
                      final isCompleted = downloadProgress == 1.0;

                      return Card(
                        elevation: 0,
                        color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.3) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.5)
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            ref.read(clientProvider.notifier).toggleFileSelection(fileId);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    ref.read(clientProvider.notifier).toggleFileSelection(fileId);
                                  },
                                ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.insert_drive_file, color: colorScheme.onPrimaryContainer),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      if (isDownloading)
                                        LinearProgressIndicator(
                                          value: downloadProgress,
                                          backgroundColor: colorScheme.surfaceContainerHighest,
                                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                        )
                                      else
                                        Text(
                                          '$sizeInMB MB',
                                          style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                if (isCompleted)
                                  const Icon(Icons.check_circle_rounded, color: Colors.green)
                                else if (isDownloading)
                                  Text('${(downloadProgress * 100).toStringAsFixed(0)}%')
                                else
                                  Icon(Icons.download_rounded, color: colorScheme.primary),
                                if (clientState.isCoHost)
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                                    onPressed: () {
                                      ref.read(clientProvider.notifier).removeFile(fileId);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Bottom Action Bar
              if (clientState.isApproved && clientState.availableFiles.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref.read(clientProvider.notifier).downloadAllFiles(settingsState.downloadDirectory);
                          },
                          child: const Text('Download All'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: clientState.selectedFileIds.isEmpty
                              ? null
                              : () {
                                  ref.read(clientProvider.notifier).downloadSelectedFiles(settingsState.downloadDirectory);
                                },
                          child: Text('Download (${clientState.selectedFileIds.length})'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
