import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'create_lobby_screen.dart';
import 'discover_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';

import '../../features/lobby/presentation/providers/active_lobbies_provider.dart';
import '../../features/lobby/presentation/providers/host_provider.dart';
import 'host_lobby_screen.dart';

import '../widgets/space_background_wrapper.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 1;

  final List<Widget> _pages = [
    const CreateLobbyScreen(),
    const DiscoverScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: AnimatedTextKit(
          animatedTexts: [
            ColorizeAnimatedText(
              'BeaconSync',
              textStyle: TextStyle(
                fontSize: (_currentIndex == 0 || _currentIndex == 1) ? 24.2 : 22.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily,
              ),
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.onSurface,
                Theme.of(context).colorScheme.onSurfaceVariant,
                Theme.of(context).colorScheme.primary,
              ],
            ),
          ],
          isRepeatingAnimation: true,
          repeatForever: true,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: SpaceBackgroundWrapper(
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'Create',
          ),
          NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar_rounded),
            label: 'Join',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
      ],
      ),
      floatingActionButton: _buildActiveMissionsFab(context, ref),
    );
  }

  Widget? _buildActiveMissionsFab(BuildContext context, WidgetRef ref) {
    final activeLobbies = ref.watch(activeLobbiesProvider);
    if (activeLobbies.isEmpty) return null;

    return FloatingActionButton.extended(
      onPressed: () => _showActiveMissions(context, ref, activeLobbies),
      icon: const Icon(Icons.rocket_launch_rounded),
      label: Text('${activeLobbies.length} Active Missions'),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }

  void _showActiveMissions(BuildContext context, WidgetRef ref, List<String> activeLobbies) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Active Missions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: activeLobbies.length,
                  itemBuilder: (context, index) {
                    final lobbyId = activeLobbies[index];
                    return Consumer(
                      builder: (context, ref, child) {
                        final hostState = ref.watch(hostProvider(lobbyId));
                        final lobby = hostState.currentLobby;
                        if (lobby == null) return const SizedBox.shrink();

                        return ListTile(
                          leading: const Icon(Icons.public),
                          title: Text(lobby.lobbyName),
                          subtitle: Text('${lobby.currentParticipants} participant(s)'),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: () {
                            Navigator.pop(context); // close bottom sheet
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HostLobbyScreen(lobbyId: lobbyId),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
