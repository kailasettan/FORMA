import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile/profile_form_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/stats/match_stat_form_screen.dart';
import '../domain/entities/player_profile.dart';

class AppRouter {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String profileForm = '/profile-form';
  static const String settings = '/settings';
  static const String matchStatForm = '/match-stat-form';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );
      case signup:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SignupScreen(),
        );
      case dashboard:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DashboardScreen(),
        );
      case profileForm:
        final profile = settings.arguments as PlayerProfile?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ProfileFormScreen(profile: profile),
        );
      case AppRouter.settings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );
      case matchStatForm:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MatchStatFormScreen(),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}
