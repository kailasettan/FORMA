import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/auth_cubit.dart';
import '../../cubits/theme_cubit.dart';
import '../../theme.dart';
import '../../router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;

  Future<void> _confirmLogout() async {
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

    if (shouldLogout != true || !mounted) return;
    context.read<AuthCubit>().logout();
  }

  Future<void> _deleteAccountFlow() async {
    final authCubit = context.read<AuthCubit>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final bool? continueFirst = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
          'This will permanently remove your access to ${Branding.appName} and hide your profile. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (continueFirst != true || !mounted) return;

    final bool? continueSecond = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text(
          'Your account will be disabled, your profile will be hidden, and you will be logged out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete Account',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (continueSecond != true || !mounted) return;

    final String? password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String enteredPassword = '';
        bool obscurePassword = true;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirm Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter your password to verify account deletion.'),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: obscurePassword,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                    onChanged: (val) {
                      enteredPassword = val;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, enteredPassword),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (password == null || password.isEmpty || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await authCubit.deleteAccount(password);
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Your account has been deleted successfully.'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
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
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                        onTap: _isDeleting
                            ? null
                            : () => _showAppearanceBottomSheet(
                                context,
                                currentMode,
                              ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Legal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () {
                          Navigator.pushNamed(context, AppRouter.privacy);
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Terms & Conditions'),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () {
                          Navigator.pushNamed(context, AppRouter.terms);
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.delete_outline_rounded),
                        title: const Text('How to Delete Account'),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () {
                          Navigator.pushNamed(context, AppRouter.deleteAccount);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: AppTheme.error,
                        ),
                        title: const Text('Logout'),
                        textColor: AppTheme.error,
                        iconColor: AppTheme.error,
                        onTap: _isDeleting ? null : () => _confirmLogout(),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(
                          Icons.delete_forever_rounded,
                          color: AppTheme.error,
                        ),
                        title: const Text('Delete Account'),
                        textColor: AppTheme.error,
                        iconColor: AppTheme.error,
                        onTap: _isDeleting ? null : () => _deleteAccountFlow(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isDeleting)
              const ModalBarrier(dismissible: false, color: Colors.black26),
            if (_isDeleting) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
