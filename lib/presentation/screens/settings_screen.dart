import 'package:flutter/material.dart';
import '../widgets/glass_container.dart';

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
    final result = await FilePicker.pickFile(
      type: FileType.image,
    );
    if (result != null && result.path != null) {
      ref.read(settingsProvider.notifier).updateProfileImage(result.path!);
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
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Text(
              'Settings',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        backgroundImage: settings.profileImagePath != null
                            ? FileImage(File(settings.profileImagePath!))
                            : null,
                        child: settings.profileImagePath == null
                            ? Icon(Icons.person_rounded, size: 50, color: colorScheme.onSurface)
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
                            icon: Icon(Icons.camera_alt_rounded, size: 20, color: colorScheme.onPrimary),
                            onPressed: _pickProfileImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // User Name
                Text('Profile Details', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.person_outline_rounded, color: colorScheme.onSurfaceVariant),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                  onChanged: (value) {
                    ref.read(userNameProvider.notifier).setName(value);
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Storage & Downloads', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Download Location', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                  subtitle: Text(settings.downloadDirectory, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  trailing: FilledButton.tonal(
                    onPressed: _pickDownloadDirectory,
                    child: const Text('Change'),
                  ),
                ),

              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About BeaconSync', style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                  title: Text('Version', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                  trailing: Text('1.0.0 (Alpha)', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.network_check_rounded, color: colorScheme.primary),
                  title: Text('Network Protocol', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                  trailing: Text('BeaconSync TCP (Direct)', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.security_rounded, color: colorScheme.primary),
                  title: Text('Encryption', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                  trailing: Text('Local E2E (AES-GCM)', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
