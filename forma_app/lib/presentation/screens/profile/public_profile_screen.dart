import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/auth_cubit.dart';
import '../../cubits/public_profile_cubit.dart';
import '../../cubits/scout_shortlist_cubit.dart';
import '../../theme.dart';
import '../drops/drop_viewer_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicProfileCubit>().loadProfile(widget.userId);
    });
  }

  void _showShortlistDialog(BuildContext context, bool isShortlisted) {
    final noteController = TextEditingController();

    if (isShortlisted) {
      // If already shortlisted, remove immediately
      context.read<PublicProfileCubit>().toggleShortlist(widget.userId);
      context.read<ScoutShortlistCubit>().removeShortlist(widget.userId);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Shortlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Collect a private note about this athlete. Other athletes and scouts cannot see this.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Private Note',
                hintText:
                    'Enter notes (e.g. strong left foot, fast sprinter)...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              final note = noteController.text.trim();
              Navigator.pop(ctx);
              context.read<PublicProfileCubit>().toggleShortlist(
                widget.userId,
                privateNote: note.isNotEmpty ? note : null,
              );
              // Refresh private scout shortlist cubit if loaded
              context.read<ScoutShortlistCubit>().loadShortlist();
            },
            child: const Text(
              'ADD TO SHORTLIST',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final isScout =
        authState is AuthAuthenticated && authState.user.role == 'scout';

    return Scaffold(
      appBar: AppBar(title: const Text('Athlete Portfolio')),
      body: BlocBuilder<PublicProfileCubit, PublicProfileState>(
        builder: (context, state) {
          if (state is PublicProfileLoading || state is PublicProfileInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PublicProfileError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppTheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<PublicProfileCubit>().loadProfile(
                          widget.userId,
                        );
                      },
                      child: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is PublicProfileLoaded) {
            final profile = state.profile;
            final user = profile.user;
            final hasDrops = profile.drops.isNotEmpty;

            return RefreshIndicator(
              onRefresh: () async {
                await context.read<PublicProfileCubit>().loadProfile(
                  widget.userId,
                );
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Portfolio Header Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundImage:
                                        user.profilePhotoUrl != null
                                        ? NetworkImage(user.profilePhotoUrl!)
                                        : null,
                                    child: user.profilePhotoUrl == null
                                        ? Text(
                                            user.fullName.isNotEmpty
                                                ? user.fullName
                                                      .substring(0, 1)
                                                      .toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullName,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '@${user.username}',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (user.location != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on_outlined,
                                                size: 14,
                                                color: AppTheme.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                user.location!,
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (user.headline != null) ...[
                                Text(
                                  user.headline!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (user.availability != null) ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      user.availability!,
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Scout Shortlist Action
                              if (isScout) ...[
                                ElevatedButton.icon(
                                  onPressed: () => _showShortlistDialog(
                                    context,
                                    profile.isShortlisted,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: profile.isShortlisted
                                        ? AppTheme.surface
                                        : AppTheme.primary,
                                    foregroundColor: profile.isShortlisted
                                        ? AppTheme.textPrimary
                                        : Colors.white,
                                    side: profile.isShortlisted
                                        ? const BorderSide(
                                            color: Colors.white24,
                                          )
                                        : null,
                                  ),
                                  icon: Icon(
                                    profile.isShortlisted
                                        ? Icons.bookmark_added_rounded
                                        : Icons.bookmark_add_outlined,
                                  ),
                                  label: Text(
                                    profile.isShortlisted
                                        ? 'SHORTLISTED'
                                        : 'ADD TO SHORTLIST',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Athlete Bio Section
                  if (user.bio != null && user.bio!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bio',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  user.bio!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Sport Profile Cards
                  if (profile.playerProfiles.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sports & Specialties',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...profile.playerProfiles.map(
                              (p) => Card(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.sports_rounded,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  title: Text(
                                    p.sportDetails?.name.toUpperCase() ??
                                        p.sport.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Role/Discipline: ${p.roleOrDiscipline ?? p.position ?? "N/A"} • Level: ${p.skillLevel.toUpperCase()}',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Drops Section Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        top: 16.0,
                        bottom: 8.0,
                      ),
                      child: Text(
                        hasDrops ? 'Drops Gallery' : 'Drops',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),

                  // Drops Thumbnail Grid
                  if (!hasDrops)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(
                          child: Text(
                            'No Drops uploaded yet.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8.0,
                              mainAxisSpacing: 8.0,
                              childAspectRatio: 9 / 16,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final drop = profile.drops[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DropViewerScreen(
                                    drops: profile.drops,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.0),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Thumbnail Image
                                  drop.thumbnailUrl != null
                                      ? Image.network(
                                          drop.thumbnailUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) =>
                                              Container(
                                                color: Colors.white12,
                                                child: const Icon(
                                                  Icons.video_library_rounded,
                                                  size: 32,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          color: Colors.white12,
                                          child: const Icon(
                                            Icons.video_library_rounded,
                                            size: 32,
                                          ),
                                        ),
                                  // Lower Scrim
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.6),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          stops: const [0.6, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Duration and Category badge
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (drop.category?.name != null)
                                          Text(
                                            drop.category!.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppTheme.primary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.play_arrow_rounded,
                                                  size: 10,
                                                  color: Colors.white,
                                                ),
                                                Text(
                                                  '${drop.durationSeconds.toStringAsFixed(1)}s',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.emoji_events_rounded,
                                                  size: 10,
                                                  color: AppTheme.accent,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${drop.propsCount}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }, childCount: profile.drops.length),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
