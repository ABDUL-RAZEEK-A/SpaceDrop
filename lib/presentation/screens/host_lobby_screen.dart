import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/lobby/presentation/providers/host_provider.dart';
import '../../features/lobby/domain/models/lobby.dart';

class HostLobbyScreen extends ConsumerWidget {
  const HostLobbyScreen({super.key});

  Future<void> _pickFile(WidgetRef ref) async {
    FilePickerResult? result = await FilePicker.pickFiles(allowMultiple: true);
    if (result != null) {
      for (final file in result.files) {
        if (file.path != null) {
          await ref.read(hostProvider.notifier).addSharedFile(File(file.path!));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostState = ref.watch(hostProvider);
    final lobby = hostState.currentLobby;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (lobby == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lobby Closed')),
        body: const Center(child: Text('This lobby has been closed.')),
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
            Text(
              'ID: ${lobby.lobbyId}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_rounded,
              color: colorScheme.onSurface,
            ),
            tooltip: 'Lobby Settings',
            onPressed: () => _showSettingsBottomSheet(context, ref, lobby),
          ),
          IconButton(
            icon: Icon(
              Icons.exit_to_app_rounded,
              color: colorScheme.error,
            ),
            tooltip: 'Close Lobby',
            onPressed: () {
              ref.read(hostProvider.notifier).closeLobby();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: _buildSidebar(context, ref, hostState, theme, colorScheme),
                ),
                VerticalDivider(width: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                Expanded(
                  flex: 2,
                  child: _buildMainContent(context, ref, hostState, theme, colorScheme),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                _buildSidebar(context, ref, hostState, theme, colorScheme, isCompact: true),
                Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                Expanded(child: _buildMainContent(context, ref, hostState, theme, colorScheme)),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    WidgetRef ref,
    dynamic hostState,
    ThemeData theme,
    ColorScheme colorScheme, {
    bool isCompact = false,
  }) {
    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          if (hostState.pendingRequests.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Requests (${hostState.pendingRequests.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            if (isCompact)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: hostState.pendingRequests.length,
                itemBuilder: (context, index) {
                  final request = hostState.pendingRequests[index];
                  return _buildPendingRequestTile(request, context, ref, theme, colorScheme);
                },
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: hostState.pendingRequests.length,
                  itemBuilder: (context, index) {
                    final request = hostState.pendingRequests[index];
                    return _buildPendingRequestTile(request, context, ref, theme, colorScheme);
                  },
                ),
              ),
            if (!isCompact) Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ],

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.people_alt_rounded,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Participants (${hostState.participants.length})',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
          if (hostState.participants.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No participants yet.',
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              ),
            )
          else if (isCompact)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: hostState.participants.length,
              itemBuilder: (context, index) {
                final device = hostState.participants[index];
                return _buildParticipantTile(device, context, ref, theme, colorScheme);
              },
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: hostState.participants.length,
                itemBuilder: (context, index) {
                  final device = hostState.participants[index];
                  return _buildParticipantTile(device, context, ref, theme, colorScheme);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestTile(dynamic request, BuildContext context, WidgetRef ref, ThemeData theme, ColorScheme colorScheme) {
    return ListTile(
      title: Text(
        request.deviceName,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('Wants to join', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
            ),
            onPressed: () => ref.read(hostProvider.notifier).approveRequest(request),
          ),
          IconButton(
            icon: Icon(
              Icons.cancel_rounded,
              color: colorScheme.error,
            ),
            onPressed: () => ref.read(hostProvider.notifier).rejectRequest(request),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(dynamic device, BuildContext context, WidgetRef ref, ThemeData theme, ColorScheme colorScheme) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondary.withValues(alpha: 0.1),
        child: Icon(
          Icons.person,
          color: colorScheme.secondary,
        ),
      ),
      title: Text(device.deviceName, style: theme.textTheme.bodyLarge),
      subtitle: Text('Connected', style: theme.textTheme.labelLarge?.copyWith(color: Colors.green)),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
        onSelected: (value) {
          if (value == 'promote') {
            ref.read(hostProvider.notifier).promoteToCoHost(device.deviceId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${device.deviceName} promoted to Co-host!')),
            );
          } else if (value == 'remove') {
            ref.read(hostProvider.notifier).removeParticipant(device.deviceId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${device.deviceName} removed.')),
            );
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'promote',
            child: Row(
              children: [
                Icon(Icons.star_rounded, size: 20),
                SizedBox(width: 8),
                Text('Make Co-host'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.person_remove_rounded, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Remove', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    dynamic hostState,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final filteredFiles = hostState.filteredAndSortedFiles;
    
    // Group files by category if sorted by category
    Map<String, List<dynamic>> groupedFiles = {};
    if (hostState.sortType == FileSortType.category) {
      for (var file in filteredFiles) {
        if (!groupedFiles.containsKey(file.category)) {
          groupedFiles[file.category] = [];
        }
        groupedFiles[file.category]!.add(file);
      }
    }

    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Shared Files',
                  style: theme.textTheme.headlineLarge,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Share File'),
                  onPressed: () => _pickFile(ref),
                ),
              ],
            ),
          ),
          
          // Search and Sort Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search files...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      ref.read(hostProvider.notifier).setSearchQuery(value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<FileSortType>(
                      value: hostState.sortType,
                      items: const [
                        DropdownMenuItem(value: FileSortType.category, child: Text('Sort by Category')),
                        DropdownMenuItem(value: FileSortType.name, child: Text('Sort by Name')),
                        DropdownMenuItem(value: FileSortType.size, child: Text('Sort by Size')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          ref.read(hostProvider.notifier).setSortType(value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: hostState.sharedFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 80,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your lobby is empty',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share files for participants to download',
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  )
                : filteredFiles.isEmpty 
                  ? const Center(child: Text('No files match your search.'))
                  : (hostState.sortType == FileSortType.category)
                    ? ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: groupedFiles.keys.length,
                        itemBuilder: (context, index) {
                          String category = groupedFiles.keys.elementAt(index);
                          List<dynamic> categoryFiles = groupedFiles[category]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  category,
                                  style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary),
                                ),
                              ),
                              ...categoryFiles.map((file) => _buildFileCard(file, theme, colorScheme)),
                            ],
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: filteredFiles.length,
                        itemBuilder: (context, index) {
                          final file = filteredFiles[index];
                          return _buildFileCard(file, theme, colorScheme);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(dynamic file, ThemeData theme, ColorScheme colorScheme) {
    IconData fileIcon = Icons.insert_drive_file_rounded;
    if (file.category == 'Images') fileIcon = Icons.image_rounded;
    if (file.category == 'Videos') fileIcon = Icons.video_file_rounded;
    if (file.category == 'Audio') fileIcon = Icons.audio_file_rounded;
    if (file.category == 'APKs') fileIcon = Icons.android_rounded;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            fileIcon,
            color: colorScheme.primary,
          ),
        ),
        title: Text(
          file.fileName,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Text(
                '${(file.fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  file.category,
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(
          Icons.cloud_done_rounded,
          color: Colors.green,
        ),
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context, WidgetRef ref, Lobby lobby) {
    int maxParticipants = lobby.maxParticipants;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Lobby Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<int>(
                    value: maxParticipants,
                    decoration: const InputDecoration(
                      labelText: 'Max Devices',
                      prefixIcon: Icon(Icons.group_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 Devices')),
                      DropdownMenuItem(value: 10, child: Text('10 Devices')),
                      DropdownMenuItem(value: 20, child: Text('20 Devices')),
                      DropdownMenuItem(value: 50, child: Text('50 Devices')),
                      DropdownMenuItem(value: 100, child: Text('100 Devices')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() {
                          maxParticipants = value;
                        });
                        ref.read(hostProvider.notifier).updateMaxParticipants(value);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
