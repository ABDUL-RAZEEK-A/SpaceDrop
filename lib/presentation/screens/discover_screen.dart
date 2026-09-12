import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/discovery/presentation/providers/client_provider.dart';
import '../../features/lobby/presentation/providers/host_provider.dart';
import '../../core/preferences/user_preferences.dart';
import '../../features/lobby/domain/models/lobby.dart';
import 'client_lobby_screen.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> with SingleTickerProviderStateMixin {
  final _deviceNameController = TextEditingController();
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = ref.read(userNameProvider);
      if (name.isNotEmpty) {
        _deviceNameController.text = name;
      }
      ref.read(clientProvider.notifier).startScanning();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _joinLobby(Lobby lobby) async {
    if (_deviceNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your device name'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    String? pin;
    if (lobby.pinEnabled) {
      pin = await showDialog<String>(
        context: context,
        builder: (context) {
          final pinController = TextEditingController();
          return AlertDialog(
            title: const Text('Enter PIN'),
            content: TextField(
              controller: pinController,
              decoration: const InputDecoration(labelText: 'Lobby PIN'),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, pinController.text), child: const Text('Join')),
            ],
          );
        },
      );
      if (pin == null || pin.isEmpty) return; // Cancelled
    }

    ref.read(clientProvider.notifier).stopScanning();
    await ref
        .read(clientProvider.notifier)
        .joinLobby(lobby, _deviceNameController.text.trim(), pin: pin);
  }

  @override
  Widget build(BuildContext context) {
    final clientState = ref.watch(clientProvider);
    if (clientState.connectedLobby != null) {
      return const ClientLobbyScreen();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hostState = ref.watch(hostProvider);
    final myHostDeviceId = hostState.currentLobby?.hostDeviceId;
    
    final filteredLobbies = clientState.availableLobbies
        .where((lobby) => lobby.hostDeviceId != myHostDeviceId)
        .toList();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Device Name Input Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            color: colorScheme.surfaceContainerLowest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Join a Space',
                      style: theme.textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                      onPressed: () {
                        ref.read(clientProvider.notifier).stopScanning();
                        ref.read(clientProvider.notifier).startScanning();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Set your display name to join a local lobby.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _deviceNameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Device Name',
                    hintText: "e.g., Jane's iPhone",
                    prefixIcon: Icon(Icons.smartphone_rounded),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Radar Scanning Visual or Lobbies List
          Expanded(
            child: filteredLobbies.isEmpty
                ? _buildScanningView(theme, colorScheme, clientState.isScanning)
                : _buildLobbiesList(theme, colorScheme, filteredLobbies),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningView(ThemeData theme, ColorScheme colorScheme, bool isScanning) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        if (isScanning)
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1), width: 1),
                  ),
                ),
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2), width: 1),
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4), width: 1),
                  ),
                ),
                RotationTransition(
                  turns: _radarController,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.transparent,
                          colorScheme.primary.withValues(alpha: 0.05),
                          colorScheme.primary.withValues(alpha: 0.5),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.6),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: colorScheme.outlineVariant,
          ),
        const SizedBox(height: 32),
        Text(
          isScanning ? 'Scanning Local Network' : 'No lobbies found',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          isScanning ? 'Looking for active LobbyCast sessions...' : 'Try refreshing or host your own.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildLobbiesList(ThemeData theme, ColorScheme colorScheme, List<Lobby> lobbies) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: lobbies.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final lobby = lobbies[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.dns_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lobby.lobbyName,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            lobby.hostDeviceName,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(width: 8),
                          Container(width: 4, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Icon(lobby.pinEnabled ? Icons.lock_rounded : Icons.lock_open_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            lobby.lobbyType,
                            style: theme.textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Action
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () => _joinLobby(lobby),
                  child: const Text('Join'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
