import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/auth_cubit.dart';
import '../../cubits/theme_cubit.dart';
import '../../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('Log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Log out',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !context.mounted) return;
    context.read<AuthCubit>().logout();
  }

  void _showAppearanceBottomSheet(
    BuildContext settingsContext,
    ThemeMode currentMode,
  ) {
    showModalBottomSheet(
      context: settingsContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: settingsContext.read<ThemeCubit>(),
          child: BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildThemeOption(
                      context,
                      themeMode,
                      ThemeMode.system,
                      'System default',
                    ),
                    _buildThemeOption(
                      context,
                      themeMode,
                      ThemeMode.light,
                      'Light',
                    ),
                    _buildThemeOption(
                      context,
                      themeMode,
                      ThemeMode.dark,
                      'Dark',
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeMode currentMode,
    ThemeMode mode,
    String label,
  ) {
    final isSelected = currentMode == mode;
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppTheme.primary)
          : null,
      onTap: () {
        context.read<ThemeCubit>().updateThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Appearance',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, currentMode) {
                  String modeText;
                  switch (currentMode) {
                    case ThemeMode.system:
                      modeText = 'System default';
                      break;
                    case ThemeMode.light:
                      modeText = 'Light';
                      break;
                    case ThemeMode.dark:
                      modeText = 'Dark';
                      break;
                  }
                  return ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Appearance'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          modeText,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                    onTap: () =>
                        _showAppearanceBottomSheet(context, currentMode),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Account',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.error,
                ),
                title: const Text('Logout'),
                textColor: AppTheme.error,
                iconColor: AppTheme.error,
                onTap: () => _confirmLogout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
