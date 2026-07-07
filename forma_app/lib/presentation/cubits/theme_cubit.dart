import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  final FlutterSecureStorage _secureStorage;
  static const String themeKey = 'forma_theme_mode';

  ThemeCubit({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final value = await _secureStorage.read(key: themeKey);
      if (value != null) {
        final mode = ThemeMode.values.firstWhere(
          (m) => m.name == value,
          orElse: () => ThemeMode.system,
        );
        emit(mode);
      }
    } catch (_) {
      emit(ThemeMode.system);
    }
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    emit(mode);
    try {
      await _secureStorage.write(key: themeKey, value: mode.name);
    } catch (_) {}
  }
}
