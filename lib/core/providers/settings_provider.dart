import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class SettingsState {
  final String? profileImagePath;
  final String downloadDirectory;

  SettingsState({
    this.profileImagePath,
    required this.downloadDirectory,
  });

  SettingsState copyWith({
    String? profileImagePath,
    String? downloadDirectory,
  }) {
    return SettingsState(
      profileImagePath: profileImagePath ?? this.profileImagePath,
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState(downloadDirectory: '')) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profileImagePath');
    
    String dir = prefs.getString('downloadDirectory') ?? '';
    if (dir.isEmpty) {
      final defaultDir = await getApplicationDocumentsDirectory();
      dir = defaultDir.path;
    }

    state = state.copyWith(
      profileImagePath: imagePath,
      downloadDirectory: dir,
    );
  }

  Future<void> updateProfileImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileImagePath', path);
    state = state.copyWith(profileImagePath: path);
  }

  Future<void> updateDownloadDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('downloadDirectory', path);
    state = state.copyWith(downloadDirectory: path);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
