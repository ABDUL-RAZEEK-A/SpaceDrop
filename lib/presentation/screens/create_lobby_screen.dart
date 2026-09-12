import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/preferences/user_preferences.dart';
import '../../features/lobby/presentation/providers/host_provider.dart';
import 'host_lobby_screen.dart';

class CreateLobbyScreen extends ConsumerStatefulWidget {
  const CreateLobbyScreen({super.key});

  @override
  ConsumerState<CreateLobbyScreen> createState() => _CreateLobbyScreenState();
}

class _CreateLobbyScreenState extends ConsumerState<CreateLobbyScreen> {
  final _lobbyNameController = TextEditingController();
  final _hostNameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isPrivate = false;
  bool _isLoading = false;
  int _maxParticipants = 10;
  List<File> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = ref.read(userNameProvider);
      if (name.isNotEmpty) {
        _hostNameController.text = name;
      }
    });
  }

  @override
  void dispose() {
    _lobbyNameController.dispose();
    _hostNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null) {
            _selectedFiles.add(File(file.path!));
          }
        }
      });
    }
  }

  Future<void> _createLobby() async {
    if (_lobbyNameController.text.trim().isEmpty ||
        _hostNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all fields'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    await ref
        .read(hostProvider.notifier)
        .createLobby(
          _lobbyNameController.text.trim(),
          _hostNameController.text.trim(),
          _isPrivate ? 'Private' : 'Open',
          _isPrivate,
          _isPrivate ? _pinController.text.trim() : null,
          _maxParticipants,
        );

    // Add pre-selected files after lobby creation
    for (final file in _selectedFiles) {
      await ref.read(hostProvider.notifier).addSharedFile(file);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostState = ref.watch(hostProvider);
    if (hostState.isHosting) {
      return const HostLobbyScreen();
    }

    final userName = ref.watch(userNameProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient for Host Mode (Deep Indigo/Primary)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.15),
                    colorScheme.surface,
                  ],
                  stops: const [0.0, 0.4],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Text(
                        'Welcome, $userName!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    Card(
                      color: colorScheme.surfaceContainerLowest,
                      shadowColor: colorScheme.primary.withValues(alpha: 0.12),
                      elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.cell_tower_rounded,
                              size: 40,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Host a Local Space',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share files securely on your network.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 48),
                        TextField(
                          controller: _lobbyNameController,
                          decoration: const InputDecoration(
                            labelText: 'Lobby Name',
                            hintText: 'e.g., Design Sync',
                            prefixIcon: Icon(Icons.meeting_room_rounded),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _hostNameController,
                          decoration: const InputDecoration(
                            labelText: 'Your Name (Host)',
                            hintText: 'e.g., John Doe',
                            prefixIcon: Icon(Icons.person_rounded),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<int>(
                          value: _maxParticipants,
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
                              setState(() => _maxParticipants = value);
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        SwitchListTile(
                          title: const Text('Private Lobby'),
                          subtitle: const Text('Require a PIN to join'),
                          value: _isPrivate,
                          onChanged: (value) {
                            setState(() {
                              _isPrivate = value;
                            });
                          },
                        ),
                        if (_isPrivate) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _pinController,
                            decoration: const InputDecoration(
                              labelText: 'Lobby PIN',
                              hintText: 'e.g., 1234',
                              prefixIcon: Icon(Icons.lock_rounded),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 8,
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Selected Files Section
                        if (_selectedFiles.isNotEmpty) ...[
                          Text(
                            'Files to Share (${_selectedFiles.length})',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 150),
                            decoration: BoxDecoration(
                              border: Border.all(color: colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _selectedFiles.length,
                              itemBuilder: (context, index) {
                                final file = _selectedFiles[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.insert_drive_file_outlined),
                                  title: Text(
                                    file.path.split(Platform.pathSeparator).last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _selectedFiles.removeAt(index);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Add Files to Share'),
                        ),
                        const SizedBox(height: 32),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                ),
                                onPressed: _createLobby,
                                child: const Text('Start Hosting'),
                              ),
                      ],
                    ),
                  ),
                ),
                ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
