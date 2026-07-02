import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/drop.dart';
import '../../../domain/entities/player_profile.dart';
import '../../cubits/profile_cubit.dart';
import '../../cubits/drop_cubit.dart';
import '../../theme.dart';
import '../drops/drop_viewer_screen.dart';
import '../drops/drop_upload_screen.dart';
import 'edit_profile_screen.dart';

class OwnProfileSection extends StatefulWidget {
  final User user;

  const OwnProfileSection({super.key, required this.user});

  @override
  State<OwnProfileSection> createState() => _OwnProfileSectionState();
}

class _OwnProfileSectionState extends State<OwnProfileSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileCubit>().loadProfiles(widget.user.id);
      context.read<DropCubit>().loadUserDrops(widget.user.id);
    });
  }

  int _calculateCompletion(List<PlayerProfile> profiles, List<Drop> drops) {
    int score = 0;
    if (widget.user.profilePhotoUrl != null && widget.user.profilePhotoUrl!.isNotEmpty) score += 15;
    if (widget.user.headline != null && widget.user.headline!.isNotEmpty) score += 15;
    if (widget.user.bio != null && widget.user.bio!.isNotEmpty) score += 15;
    if (widget.user.location != null && widget.user.location!.isNotEmpty) score += 15;
    if (widget.user.availability != null && widget.user.availability!.isNotEmpty) score += 15;
    if (profiles.isNotEmpty) score += 15;
    if (drops.isNotEmpty) score += 10;
    return score;
  }

  void _showDropOptions(BuildContext context, Drop drop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
              title: const Text('Delete Drop', style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, drop.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String dropId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Drop'),
        content: const Text('This action is permanent and will delete your video from Cloudinary. Proceed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<DropCubit>().deleteDrop(dropId, widget.user.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Drop deleted'), backgroundColor: AppTheme.success),
              );
            },
            child: const Text('DELETE', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        final List<PlayerProfile> profiles =
            profileState is ProfileLoaded ? profileState.profiles : [];

        return BlocBuilder<DropCubit, DropState>(
          builder: (context, dropState) {
            final List<Drop> drops = dropState is DropLoaded ? dropState.drops : [];
            final completion = _calculateCompletion(profiles, drops);

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ProfileCubit>().loadProfiles(widget.user.id);
                context.read<DropCubit>().loadUserDrops(widget.user.id);
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
                                    radius: 32,
                                    backgroundImage: widget.user.profilePhotoUrl != null
                                        ? NetworkImage(widget.user.profilePhotoUrl!)
                                        : null,
                                    child: widget.user.profilePhotoUrl == null
                                        ? Text(
                                            widget.user.fullName.isNotEmpty
                                                ? widget.user.fullName.substring(0, 1).toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.user.fullName,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '@${widget.user.username}',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (widget.user.location != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSecondary),
                                              const SizedBox(width: 4),
                                              Text(
                                                widget.user.location!,
                                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
                              if (widget.user.headline != null) ...[
                                Text(
                                  widget.user.headline!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (widget.user.availability != null) ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      widget.user.availability!,
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Owner Actions Row
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditProfileScreen(user: widget.user),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.edit_rounded, size: 16),
                                      label: const Text('EDIT PROFILE'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const DropUploadScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                                      label: const Text('ADD DROP'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Profile Completion Guidance Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        color: AppTheme.cardBg,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Profile Completion',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    '$completion%',
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: completion / 100,
                                backgroundColor: Colors.white10,
                                color: AppTheme.primary,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              if (completion < 100) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'Complete these items to stand out to scouts:',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                _buildCompletionCheckItem('Add a profile photo',
                                    widget.user.profilePhotoUrl != null && widget.user.profilePhotoUrl!.isNotEmpty),
                                _buildCompletionCheckItem('Add a sports headline',
                                    widget.user.headline != null && widget.user.headline!.isNotEmpty),
                                _buildCompletionCheckItem('Write your athletic bio',
                                    widget.user.bio != null && widget.user.bio!.isNotEmpty),
                                _buildCompletionCheckItem('Set your location',
                                    widget.user.location != null && widget.user.location!.isNotEmpty),
                                _buildCompletionCheckItem('Set your availability status',
                                    widget.user.availability != null && widget.user.availability!.isNotEmpty),
                                _buildCompletionCheckItem('Create a sports specialization profile', profiles.isNotEmpty),
                                _buildCompletionCheckItem('Upload a portfolio video Drop', drops.isNotEmpty),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Sports Specializations Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Specializations',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/profile-form');
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Sport'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Profiles list
                  if (profiles.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              'Add your first sport specialization card above.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final p = profiles[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.sports_rounded, color: AppTheme.primary),
                            ),
                            title: Text(
                              p.sportDetails?.name.toUpperCase() ?? p.sport.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Role: ${p.roleOrDiscipline ?? p.position ?? "N/A"} • Level: ${p.skillLevel.toUpperCase()}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/profile-form',
                                  arguments: p,
                                );
                              },
                            ),
                          ),
                        );
                      }, childCount: profiles.length),
                    ),

                  // Drops Section Header
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
                      child: Text(
                        'Your Drops Portfolio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),

                  // Drops grid
                  if (dropState is DropLoading)
                    const SliverToBoxAdapter(
                      child: Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator())),
                    )
                  else if (drops.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(
                          child: Text(
                            'Your Drops gallery is empty.\nClick "ADD DROP" above to upload your first clip.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8.0,
                          mainAxisSpacing: 8.0,
                          childAspectRatio: 9 / 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final drop = drops[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DropViewerScreen(
                                      drops: drops,
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
                                    // Thumbnail
                                    drop.thumbnailUrl != null
                                        ? Image.network(
                                            drop.thumbnailUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) => Container(
                                              color: Colors.white12,
                                              child: const Icon(Icons.video_library_rounded),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.white12,
                                            child: const Icon(Icons.video_library_rounded),
                                          ),
                                    // Lower Scrim
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: const [0.6, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Manage options top right
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: InkWell(
                                        onTap: () => _showDropOptions(context, drop),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black38,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.more_vert_rounded, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    // Visibility badge bottom left
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: drop.visibility == 'public'
                                              ? AppTheme.success.withValues(alpha: 0.8)
                                              : Colors.red.withValues(alpha: 0.8),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          drop.visibility.toUpperCase(),
                                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    // Duration and counts bottom
                                    Positioned(
                                      bottom: 8,
                                      left: 8,
                                      right: 8,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.play_arrow_rounded, size: 10, color: Colors.white),
                                              Text(
                                                '${drop.durationSeconds.toStringAsFixed(1)}s',
                                                style: const TextStyle(color: Colors.white, fontSize: 9),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.emoji_events_rounded, size: 10, color: AppTheme.accent),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${drop.propsCount}',
                                                style: const TextStyle(color: Colors.white, fontSize: 9),
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
                          },
                          childCount: drops.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompletionCheckItem(String text, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: isChecked ? AppTheme.success : AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isChecked ? AppTheme.textSecondary : AppTheme.textPrimary,
                decoration: isChecked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
