import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeLobbiesProvider = StateNotifierProvider<ActiveLobbiesNotifier, List<String>>((ref) {
  return ActiveLobbiesNotifier();
});

class ActiveLobbiesNotifier extends StateNotifier<List<String>> {
  ActiveLobbiesNotifier() : super([]);

  void addLobby(String lobbyId) {
    if (!state.contains(lobbyId)) {
      state = [...state, lobbyId];
    }
  }

  void removeLobby(String lobbyId) {
    state = state.where((id) => id != lobbyId).toList();
  }
}
