import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/preferences/user_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final userName = ref.read(userNameProvider);
    _nameController.text = userName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      ref.read(settingsProvider.notifier).updateProfileImage(result.files.single.path!);
    }
  }

  Future<void> _pickDownloadDirectory() async {
    String? selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory != null) {
      ref.read(settingsProvider.notifier).updateDownloadDirectory(selectedDirectory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Text(
              'Settings',
              style: theme.textTheme.titleLarge,
            ),
          ),
          // Profile Section
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  backgroundImage: settings.profileImagePath != null
                      ? FileImage(File(settings.profileImagePath!))
                      : null,
                  child: settings.profileImagePath == null
                      ? Icon(Icons.person_rounded, size: 50, color: colorScheme.onSurfaceVariant)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                      onPressed: _pickProfileImage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // User Name
          Text('Profile Details', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Username',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) {
              ref.read(userNameProvider.notifier).setName(value);
            },
          ),
          const SizedBox(height: 32),

          // Storage Section
          Text('Storage & Downloads', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 16),
          
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Download Location'),
            subtitle: Text(settings.downloadDirectory),
            trailing: FilledButton.tonal(
              onPressed: _pickDownloadDirectory,
              child: const Text('Change'),
            ),
          ),
          const SizedBox(height: 16),
          
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage_rounded, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('System Storage', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Dummy visualization since actual disk space requires native plugins
                  LinearProgressIndicator(
                    value: 0.6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: colorScheme.primary,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text('~ 60% Used on current drive', style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
