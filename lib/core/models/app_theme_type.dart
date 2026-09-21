import 'package:flutter/material.dart';

enum AppThemeType {
  pureLight,
}

extension AppThemeTypeExtension on AppThemeType {
  String get displayName {
    switch (this) {
      case AppThemeType.pureLight:
        return 'Pure Light';
    }
  }

  Color get primaryColor {
    switch (this) {
      case AppThemeType.pureLight:
        return const Color(0xFF4F46E5); // Vibrant Indigo
    }
  }

  Brightness get brightness {
    switch (this) {
      case AppThemeType.pureLight:
        return Brightness.light;
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeType.pureLight:
        return Icons.flare_rounded;
    }
  }

  String get fontFamily {
    switch (this) {
      case AppThemeType.pureLight:
        return 'Inter';
    }
  }

  List<String> get radarWords {
    switch (this) {
      case AppThemeType.pureLight:
        return ['Syncing...', 'Uploading...', 'Receiving...', 'Connecting...', 'Sharing...'];
    }
  }

  String get backgroundAsset {
    switch (this) {
      case AppThemeType.pureLight:
        return 'assets/images/backgrounds/pure_light.jpg';
    }
  }

  IconData get spaceshipIcon {
    switch (this) {
      case AppThemeType.pureLight:
        return Icons.rocket_launch_rounded; 
    }
  }
}
