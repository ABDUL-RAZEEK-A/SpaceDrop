import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme_type.dart';

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

// Provider that manages the user's app theme
final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeType>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});

class ThemeNotifier extends StateNotifier<AppThemeType> {
  final SharedPreferences _prefs;
  static const _key = 'app_theme_identity';

  ThemeNotifier(this._prefs) : super(_load(_prefs));

  static AppThemeType _load(SharedPreferences prefs) {
    final savedIndex = prefs.getInt(_key);
    if (savedIndex != null && savedIndex >= 0 && savedIndex < AppThemeType.values.length) {
      return AppThemeType.values[savedIndex];
    }
    return AppThemeType.pureLight; // default
  }

  Future<void> setPlanet(AppThemeType planet) async {
    await _prefs.setInt(_key, planet.index);
    state = planet;
  }
}
