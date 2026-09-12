import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/preferences/user_preferences.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SpaceDropApp(),
    ),
  );
}

class SpaceDropApp extends ConsumerWidget {
  const SpaceDropApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);
    
    return MaterialApp(
      title: 'SpaceDrop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: userName.isEmpty ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
