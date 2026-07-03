import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/drop.dart';
import '../../domain/entities/user.dart';
import '../cubits/auth_cubit.dart';
import '../cubits/drop_cubit.dart';
import '../cubits/drop_feed_cubit.dart';
import '../cubits/profile_cubit.dart';
import '../theme.dart';
import '../router.dart';
import 'drops/drop_upload_screen.dart';
import 'drops/drops_feed_screen.dart';
import 'profile/own_profile_section.dart';
import 'search/user_search_screen.dart';
import 'scout/scout_shortlist_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      final userId = authState.user.id;
      context.read<ProfileCubit>().loadProfiles(userId);
    }
  }

  Future<void> _openUpload(User user) async {
    final dropCubit = context.read<DropCubit>();
    final profileCubit = context.read<ProfileCubit>();
    final dropFeedCubit = context.read<DropFeedCubit>();
    final createdDrop = await Navigator.push<Drop>(
      context,
      MaterialPageRoute(builder: (_) => const DropUploadScreen()),
    );
    if (createdDrop != null && mounted) {
      _debugUploadResult('created drop returned: id=${createdDrop.id}');
      try {
        dropCubit.insertDrop(createdDrop);
        _debugUploadResult('profile insertion success: id=${createdDrop.id}');
      } catch (error) {
        _debugUploadResult(
          'profile insertion failed: ${error.runtimeType}: $error',
        );
      }

      try {
        dropFeedCubit.insertNewlyCreatedDrop(createdDrop);
        _debugUploadResult('feed insertion success: id=${createdDrop.id}');
      } catch (error) {
        _debugUploadResult(
          'feed insertion failed: ${error.runtimeType}: $error',
        );
      }

      _refreshAfterUpload(
        user: user,
        dropCubit: dropCubit,
        profileCubit: profileCubit,
        dropFeedCubit: dropFeedCubit,
      );
    }
  }

  Future<void> _refreshAfterUpload({
    required User user,
    required DropCubit dropCubit,
    required ProfileCubit profileCubit,
    required DropFeedCubit dropFeedCubit,
  }) async {
    try {
      await Future.wait([
        dropCubit.loadUserDrops(user.id, preserveCurrent: true),
        profileCubit.loadProfiles(user.id),
        dropFeedCubit.refreshCurrent(),
      ]);
      _debugUploadResult('background refresh success');
      if (!mounted) return;
      final refreshFailed =
          dropCubit.state is DropError ||
          profileCubit.state is ProfileError ||
          dropFeedCubit.state.error != null;
      if (refreshFailed) {
        _showRefreshFailed();
      }
    } catch (error) {
      _debugUploadResult(
        'background refresh failed: ${error.runtimeType}: $error',
      );
      if (!mounted) return;
      _showRefreshFailed();
    }
  }

  void _showRefreshFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Drop posted, but refresh failed. Pull to refresh.'),
        backgroundColor: AppTheme.accent,
      ),
    );
  }

  void _debugUploadResult(String message) {
    if (kDebugMode) {
      debugPrint('[DropUploadResult] $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      // If we lose authentication, redirect to login cleanly
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRouter.login);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = authState.user;
    final isScout = user.role == 'scout';

    final List<Widget> tabs = isScout
        ? [
            DropsFeedScreen(isActive: _currentIndex == 0),
            const UserSearchScreen(),
            const ScoutShortlistScreen(),
          ]
        : [
            DropsFeedScreen(isActive: _currentIndex == 0),
            const UserSearchScreen(),
            OwnProfileSection(user: user),
          ];

    final List<BottomNavigationBarItem> navItems = isScout
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_outline_rounded),
              activeIcon: Icon(Icons.play_circle_rounded),
              label: 'Drops',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              activeIcon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmarks_outlined),
              activeIcon: Icon(Icons.bookmarks_rounded),
              label: 'Shortlist',
            ),
          ]
        : const [
            BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_outline_rounded),
              activeIcon: Icon(Icons.play_circle_rounded),
              label: 'Drops',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              activeIcon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline_rounded),
              activeIcon: Icon(Icons.add_circle_rounded),
              label: 'Upload',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ];

    final bodyIndex = isScout
        ? _currentIndex
        : (_currentIndex == 3 ? 2 : _currentIndex);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FORMA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Out',
            onPressed: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRouter.login,
              (route) => false,
            );
          }
        },
        child: IndexedStack(index: bodyIndex, children: tabs),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (!isScout && index == 2) {
            _openUpload(user);
            return;
          }
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        items: navItems,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to end your session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthCubit>().logout();
            },
            child: const Text(
              'LOG OUT',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
