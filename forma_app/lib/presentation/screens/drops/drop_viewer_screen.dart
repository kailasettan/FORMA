import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../data/api_config.dart';
import '../../../domain/entities/drop.dart';
import '../../cubits/auth_cubit.dart';
import '../../cubits/public_profile_cubit.dart';
import '../../cubits/scout_shortlist_cubit.dart';
import '../../theme.dart';
import '../profile/public_profile_screen.dart';
import 'comments_sheet.dart';

class DropViewerScreen extends StatefulWidget {
  final List<Drop> drops;
  final int initialIndex;

  const DropViewerScreen({
    super.key,
    required this.drops,
    required this.initialIndex,
  });

  @override
  State<DropViewerScreen> createState() => _DropViewerScreenState();
}

class _DropViewerScreenState extends State<DropViewerScreen> {
  late PageController _pageController;
  late List<Drop> _currentDrops;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusedIndex = widget.initialIndex;
    _currentDrops = List.from(widget.drops);
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _currentDrops.length,
        onPageChanged: (index) {
          setState(() {
            _focusedIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final drop = _currentDrops[index];
          final isFocused = index == _focusedIndex;

          return DropVideoPlayerItem(
            drop: drop,
            isFocused: isFocused,
            onDropUpdated: (updatedDrop) {
              setState(() {
                _currentDrops[index] = updatedDrop;
              });
            },
          );
        },
      ),
    );
  }
}

class DropVideoPlayerItem extends StatefulWidget {
  final Drop drop;
  final bool isFocused;
  final Function(Drop updatedDrop) onDropUpdated;
  final Future<void> Function(String dropId)? onToggleProps;
  final void Function(String dropId, int count)? onCommentsCountUpdated;

  const DropVideoPlayerItem({
    super.key,
    required this.drop,
    required this.isFocused,
    required this.onDropUpdated,
    this.onToggleProps,
    this.onCommentsCountUpdated,
  });

  @override
  State<DropVideoPlayerItem> createState() => _DropVideoPlayerItemState();
}

class _DropVideoPlayerItemState extends State<DropVideoPlayerItem>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showPlayPauseIcon = false;
  bool _isPlaying = false;
  bool _hasVideoError = false;
  bool _isPropBusy = false;
  bool _isShortlistBusy = false;

  // Double tap animation states
  bool _showFireOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isFocused) {
      _initPlayer();
    }
  }

  @override
  void didUpdateWidget(covariant DropVideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused && !oldWidget.isFocused) {
      _initPlayer();
    } else if (!widget.isFocused && oldWidget.isFocused) {
      _disposePlayer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposePlayer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _controller?.pause();
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    } else if (state == AppLifecycleState.resumed &&
        widget.isFocused &&
        _isInitialized) {
      _controller?.play();
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
    }
  }

  Future<void> _initPlayer() async {
    _disposePlayer();
    setState(() {
      _hasVideoError = false;
    });
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.drop.playbackUrl),
      );
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _isPlaying = true;
      });
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasVideoError = true;
      });
    }
  }

  void _disposePlayer() {
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isPlaying = false;
  }

  void _togglePlayPause() {
    if (!_isInitialized || _controller == null) return;

    setState(() {
      _showPlayPauseIcon = true;
    });

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showPlayPauseIcon = false;
        });
      }
    });
  }

  void _handleDoubleTap() {
    setState(() {
      _showFireOverlay = true;
    });

    if (!widget.drop.hasPropped) {
      _triggerProp();
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showFireOverlay = false;
        });
      }
    });
  }

  void _triggerProp() async {
    if (_isPropBusy) return;
    _isPropBusy = true;
    final bool originalHasPropped = widget.drop.hasPropped;
    final int originalPropsCount = widget.drop.propsCount;

    final bool newHasPropped = !originalHasPropped;
    final int newPropsCount = newHasPropped
        ? originalPropsCount + 1
        : (originalPropsCount - 1).clamp(0, 999999);

    final updatedDrop = widget.drop.copyWith(
      hasPropped: newHasPropped,
      propsCount: newPropsCount,
    );
    widget.onDropUpdated(updatedDrop);

    try {
      if (widget.onToggleProps != null) {
        await widget.onToggleProps!(widget.drop.id);
      } else {
        final publicProfileCubit = context.read<PublicProfileCubit>();
        await publicProfileCubit.togglePropOnDrop(widget.drop.id);
      }
    } catch (_) {
      // Rollback on failure
      final rollbackDrop = widget.drop.copyWith(
        hasPropped: originalHasPropped,
        propsCount: originalPropsCount,
      );
      widget.onDropUpdated(rollbackDrop);
    } finally {
      _isPropBusy = false;
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentsSheet(
        dropId: widget.drop.id,
        onCommentsCountUpdated: (count) {
          final updatedDrop = widget.drop.copyWith(commentsCount: count);
          widget.onDropUpdated(updatedDrop);
          widget.onCommentsCountUpdated?.call(widget.drop.id, count);
        },
      ),
    );
  }

  Future<void> _copyDropLink() async {
    final link = '${ApiConfig.baseUrl}/drops/${widget.drop.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Drop link copied')));
  }

  Future<void> _shortlistDrop() async {
    if (_isShortlistBusy) return;
    _isShortlistBusy = true;
    try {
      await context.read<ScoutShortlistCubit>().shortlistAthlete(
        widget.drop.userId,
        dropId: widget.drop.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to shortlist')));
    } finally {
      _isShortlistBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final isScout =
        authState is AuthAuthenticated && authState.user.role == 'scout';

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Black
          Container(color: Colors.black),

          // Video Player or Loader
          if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else if (_hasVideoError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white70,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Drop unavailable',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _initPlayer,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('RETRY'),
                  ),
                ],
              ),
            )
          else
            Stack(
              fit: StackFit.expand,
              children: [
                if (widget.drop.thumbnailUrl != null)
                  Image.network(
                    widget.drop.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                const Center(child: CircularProgressIndicator()),
              ],
            ),

          // Sc scrim overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.25, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Double Tap Fire Overlay Pop Animation
          if (_showFireOverlay)
            const Center(
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: Duration(milliseconds: 200),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 110,
                  color: AppTheme.accent,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 20)],
                ),
              ),
            ),

          // Play/Pause Overlay Indicator
          if (_showPlayPauseIcon)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),

          // Close Button (Top Left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Bottom & Side Overlays
          Positioned(
            bottom: 30,
            left: 16,
            right: 80, // Space for side buttons
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Athlete Name & Username
                GestureDetector(
                  onTap: () {
                    if (widget.drop.user != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicProfileScreen(userId: widget.drop.userId),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            widget.drop.user?.profilePhotoUrl != null
                            ? NetworkImage(widget.drop.user!.profilePhotoUrl!)
                            : null,
                        child: widget.drop.user?.profilePhotoUrl == null
                            ? const Icon(Icons.person, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.drop.user?.fullName ?? 'Athlete',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              widget.drop.user?.username != null
                                  ? '@${widget.drop.user!.username}'
                                  : '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Caption
                if (widget.drop.caption != null &&
                    widget.drop.caption!.isNotEmpty)
                  Text(
                    widget.drop.caption!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                const SizedBox(height: 8),

                // Sport and Category Badges
                Row(
                  children: [
                    if (widget.drop.sport?.name != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          widget.drop.sport!.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (widget.drop.category?.name != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          widget.drop.category!.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Side Actions Overlay (Right Side)
          Positioned(
            bottom: 40,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fire Action
                _buildSideAction(
                  icon: widget.drop.hasPropped
                      ? Icons.local_fire_department_rounded
                      : Icons.local_fire_department_outlined,
                  color: widget.drop.hasPropped
                      ? AppTheme.accent
                      : Colors.white,
                  label: '${widget.drop.propsCount}',
                  onTap: _triggerProp,
                ),
                const SizedBox(height: 20),

                // Comments Action
                _buildSideAction(
                  icon: Icons.comment_rounded,
                  color: Colors.white,
                  label: '${widget.drop.commentsCount}',
                  onTap: _showComments,
                ),
                const SizedBox(height: 20),

                // Copy Link Action
                _buildSideAction(
                  icon: Icons.link_rounded,
                  color: Colors.white,
                  label: 'Copy',
                  onTap: _copyDropLink,
                ),
                if (isScout) ...[
                  const SizedBox(height: 20),
                  _buildSideAction(
                    icon: Icons.bookmark_add_outlined,
                    color: Colors.white,
                    label: 'Scout',
                    onTap: _shortlistDrop,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideAction({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
