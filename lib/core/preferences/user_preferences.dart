import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider that holds the initialized SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

// Provider that manages the user's name
final userNameProvider = StateNotifierProvider<UserNameNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UserNameNotifier(prefs);
});

class UserNameNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;
  static const _key = 'user_name';

  UserNameNotifier(this._prefs) : super(_prefs.getString(_key) ?? '');

  Future<void> setName(String name) async {
    await _prefs.setString(_key, name);
    state = name;
  }
}
