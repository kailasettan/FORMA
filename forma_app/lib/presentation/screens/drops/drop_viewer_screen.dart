import 'dart:async';

import 'package:flutter/foundation.dart';
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
  late final DropVideoControllerWindow _videoWindow;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusedIndex = widget.initialIndex;
    _currentDrops = List.from(widget.drops);
    _pageController = PageController(initialPage: widget.initialIndex);
    _videoWindow = DropVideoControllerWindow(_refreshVideoState);
    WidgetsBinding.instance.addObserver(_videoWindow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncVideoWindow();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_videoWindow);
    _videoWindow.disposeAll();
    _pageController.dispose();
    super.dispose();
  }

  void _refreshVideoState() {
    if (mounted) setState(() {});
  }

  void _syncVideoWindow() {
    _videoWindow.sync(
      drops: _currentDrops,
      currentIndex: _focusedIndex,
      shouldPlayCurrent: true,
    );
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
          _videoWindow.pauseIndex(_focusedIndex);
          setState(() {
            _focusedIndex = index;
          });
          _syncVideoWindow();
        },
        itemBuilder: (context, index) {
          final drop = _currentDrops[index];
          final isFocused = index == _focusedIndex;

          return DropVideoPlayerItem(
            drop: drop,
            isFocused: isFocused,
            controller: _videoWindow.controllerFor(index),
            isInitializing: _videoWindow.isInitializing(index),
            videoError: _videoWindow.errorFor(index),
            onRetryVideo: () => _videoWindow.retry(
              index: index,
              drops: _currentDrops,
              currentIndex: _focusedIndex,
              shouldPlayCurrent: true,
            ),
            onDropUpdated: (updatedDrop) {
              setState(() {
                _currentDrops[index] = updatedDrop;
              });
            },
            onPauseForOverlay: _videoWindow.suppressPlayback,
            onResumeAfterOverlay: _videoWindow.resumePlayback,
          );
        },
      ),
    );
  }
}

class DropVideoControllerWindow with WidgetsBindingObserver {
  static const int _memoryWindowRadius = 2;
  static const String _cloudinaryPlaybackTransform = 'q_auto:good';

  final VoidCallback _onChanged;
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initializing = {};
  final Map<int, Object> _videoErrors = {};
  final Map<int, int> _generations = {};
  final Map<int, String> _dropIds = {};
  final Map<int, Stopwatch> _initializeTimers = {};
  final Map<int, DateTime> _initializeCompletedAt = {};
  final Map<int, DateTime> _focusedAt = {};
  final Map<int, DateTime> _loggedPlayFocusAt = {};
  int? _currentIndex;
  bool _shouldPlayCurrent = false;
  bool _lifecycleAllowsPlayback = true;
  bool _isPlaybackSuppressed = false;
  bool _isDisposed = false;

  DropVideoControllerWindow(this._onChanged);

  VideoPlayerController? controllerFor(int index) => _controllers[index];

  bool isInitializing(int index) => _initializing.contains(index);

  Object? errorFor(int index) => _videoErrors[index];

  Future<void> sync({
    required List<Drop> drops,
    required int currentIndex,
    required bool shouldPlayCurrent,
  }) async {
    if (_isDisposed) return;
    final previousIndex = _currentIndex;
    final previousShouldPlayCurrent = _shouldPlayCurrent;
    _currentIndex = currentIndex;
    _shouldPlayCurrent = shouldPlayCurrent;

    final orderedIndexes = <int>[
      currentIndex,
      for (var offset = 1; offset <= _memoryWindowRadius; offset++) ...[
        currentIndex - offset,
        currentIndex + offset,
      ],
    ].where((index) => index >= 0 && index < drops.length).toList();
    final allowedIndexes = orderedIndexes.toSet();

    if (previousIndex != currentIndex ||
        previousShouldPlayCurrent != shouldPlayCurrent) {
      _debugFocused(index: currentIndex, drops: drops);
    }
    _debug(
      'sync current=$currentIndex shouldPlay=$shouldPlayCurrent '
      'window=${orderedIndexes.join(',')} cached=${_controllers.keys.join(',')}',
    );

    final indexesToDispose = _controllers.keys
        .where(
          (index) =>
              !allowedIndexes.contains(index) ||
              _dropIds[index] != drops[index].id,
        )
        .toList();
    for (final index in indexesToDispose) {
      await disposeIndex(index);
    }
    _videoErrors.removeWhere((index, _) => !allowedIndexes.contains(index));

    await _applyPlaybackState();

    for (final index in orderedIndexes) {
      if (!_controllers.containsKey(index) &&
          !_initializing.contains(index) &&
          !_videoErrors.containsKey(index)) {
        unawaited(initialize(index: index, drops: drops));
      } else {
        _debug(
          'reuse index=$index initialized='
          '${_controllers[index]?.value.isInitialized ?? false} '
          'initializing=${_initializing.contains(index)}',
        );
      }
    }
  }

  Future<void> initialize({
    required int index,
    required List<Drop> drops,
  }) async {
    if (_isDisposed || index < 0 || index >= drops.length) return;
    if (_controllers.containsKey(index) || _initializing.contains(index)) {
      return;
    }

    _initializing.add(index);
    _videoErrors.remove(index);
    final generation = (_generations[index] ?? 0) + 1;
    _generations[index] = generation;
    _onChanged();

    final dropId = drops[index].id;
    final uri = _playbackUriFor(drops[index]);
    _initializeTimers[index] = Stopwatch()..start();
    _debug(
      'create index=$index current=${index == _currentIndex} '
      'urlKind=${_cloudinaryUrlKind(drops[index].playbackUrl, uri)} '
      'url=${_maskedUrl(uri)} '
      'metadata=${_metadataSummary(drops[index])}',
    );
    final controller = VideoPlayerController.networkUrl(uri);
    _controllers[index] = controller;
    _dropIds[index] = dropId;

    try {
      await controller.initialize();
      await controller.setLooping(true);

      if (_isDisposed ||
          _controllers[index] != controller ||
          _generations[index] != generation ||
          _dropIds[index] != dropId) {
        await controller.dispose();
        return;
      }

      if (_shouldPlayIndex(index)) {
        await _playController(index, controller, reason: 'initialize');
      } else {
        await controller.pause();
        _debug('initialized preload paused index=$index');
      }
    } catch (error) {
      if (_controllers[index] == controller &&
          _generations[index] == generation) {
        _controllers.remove(index);
        _dropIds.remove(index);
        _videoErrors[index] = error;
      }
      try {
        await controller.dispose();
      } catch (_) {
        // Safe cleanup after platform initialization failures.
      }
    } finally {
      final timer = _initializeTimers.remove(index);
      timer?.stop();
      if (_generations[index] == generation) {
        _initializing.remove(index);
        if (!_videoErrors.containsKey(index)) {
          _initializeCompletedAt[index] = DateTime.now();
        }
      }
      _debug(
        'initialize complete index=$index elapsedMs='
        '${timer?.elapsedMilliseconds ?? -1} '
        'success=${_controllers[index]?.value.isInitialized ?? false} '
        'preloadCompletedBeforeFocus='
        '${_initializeCompletedAt[index] != null && _focusedAt[index] != null && _initializeCompletedAt[index]!.isBefore(_focusedAt[index]!)}',
      );
      _onChanged();
    }
  }

  Future<void> retry({
    required int index,
    required List<Drop> drops,
    required int currentIndex,
    required bool shouldPlayCurrent,
  }) async {
    _videoErrors.remove(index);
    await disposeIndex(index);
    await initialize(index: index, drops: drops);
  }

  Future<void> pauseIndex(int index) async {
    await _controllers[index]?.pause();
  }

  Future<void> pauseAll() async {
    for (final controller in _controllers.values) {
      await controller.pause();
    }
  }

  Future<void> suppressPlayback() async {
    if (_isDisposed) return;
    _isPlaybackSuppressed = true;
    await _applyPlaybackState();
  }

  Future<void> resumePlayback() async {
    if (_isDisposed) return;
    _isPlaybackSuppressed = false;
    await _applyPlaybackState();
  }

  Future<void> disposeIndex(int index) async {
    _generations[index] = (_generations[index] ?? 0) + 1;
    _initializing.remove(index);
    _initializeTimers.remove(index);
    _initializeCompletedAt.remove(index);
    _focusedAt.remove(index);
    _loggedPlayFocusAt.remove(index);
    final controller = _controllers.remove(index);
    _dropIds.remove(index);
    _videoErrors.remove(index);
    if (controller == null) return;
    try {
      await controller.pause();
    } catch (_) {
      // Ignore platform races while a controller is initializing or closing.
    }
    try {
      await controller.dispose();
    } catch (_) {
      // Ignore platform races while a controller is initializing or closing.
    }
    _debug('disposed index=$index remaining=${_controllers.keys.join(',')}');
    _onChanged();
  }

  Future<void> disposeAll() async {
    _isDisposed = true;
    final indexes = _controllers.keys.toList();
    for (final index in indexes) {
      await disposeIndex(index);
    }
    _controllers.clear();
    _initializing.clear();
    _videoErrors.clear();
    _generations.clear();
    _dropIds.clear();
    _currentIndex = null;
    _shouldPlayCurrent = false;
  }

  bool _shouldPlayIndex(int index) {
    return index == _currentIndex &&
        _shouldPlayCurrent &&
        _lifecycleAllowsPlayback &&
        !_isPlaybackSuppressed;
  }

  Future<void> _applyPlaybackState() async {
    if (_isDisposed) return;
    for (final entry in _controllers.entries.toList()) {
      final controller = entry.value;
      if (!controller.value.isInitialized) continue;
      if (_shouldPlayIndex(entry.key)) {
        await _playController(entry.key, controller, reason: 'apply');
      } else {
        await controller.pause();
      }
    }
  }

  Future<void> _playController(
    int index,
    VideoPlayerController controller, {
    required String reason,
  }) async {
    await controller.play();
    final focusedAt = _focusedAt[index];
    if (focusedAt == null || _loggedPlayFocusAt[index] == focusedAt) return;
    _loggedPlayFocusAt[index] = focusedAt;
    _debug(
      'first play index=$index reason=$reason '
      'focusToPlayMs=${DateTime.now().difference(focusedAt).inMilliseconds}',
    );
  }

  void _debugFocused({required int index, required List<Drop> drops}) {
    if (index < 0 || index >= drops.length) return;
    final now = DateTime.now();
    _focusedAt[index] = now;
    final controller = _controllers[index];
    final initializedAt = _initializeCompletedAt[index];
    _debug(
      'focus index=$index reused=${controller != null} '
      'initialized=${controller?.value.isInitialized ?? false} '
      'initializing=${_initializing.contains(index)} '
      'preloadedBeforeSwipe=${initializedAt != null && initializedAt.isBefore(now)} '
      'metadata=${_metadataSummary(drops[index])}',
    );
  }

  Uri _playbackUriFor(Drop drop) {
    final original = Uri.parse(drop.playbackUrl);
    final optimized = _cloudinaryOptimizedUri(original);
    return optimized ?? original;
  }

  Uri? _cloudinaryOptimizedUri(Uri uri) {
    if (uri.host != 'res.cloudinary.com') return null;
    final segments = uri.pathSegments;
    final uploadIndex = segments.indexOf('upload');
    if (uploadIndex < 0 || uploadIndex + 1 >= segments.length) return null;
    final alreadyTransformed =
        uploadIndex + 1 < segments.length &&
        !segments[uploadIndex + 1].startsWith('v');
    if (alreadyTransformed) return null;

    final transformedSegments = <String>[
      ...segments.take(uploadIndex + 1),
      _cloudinaryPlaybackTransform,
      ...segments.skip(uploadIndex + 1),
    ];
    return uri.replace(pathSegments: transformedSegments);
  }

  String _cloudinaryUrlKind(String originalUrl, Uri playbackUri) {
    final original = Uri.tryParse(originalUrl);
    if (original?.host != 'res.cloudinary.com') return 'non-cloudinary';
    if (original.toString() == playbackUri.toString()) {
      return 'cloudinary-original';
    }
    return 'cloudinary-optimized';
  }

  String _maskedUrl(Uri uri) {
    final segments = uri.pathSegments
        .map(
          (segment) =>
              segment.length > 28 ? '${segment.substring(0, 12)}...' : segment,
        )
        .toList();
    return uri
        .replace(pathSegments: segments, query: uri.hasQuery ? '...' : null)
        .toString();
  }

  String _metadataSummary(Drop drop) {
    final mb = drop.bytes / (1024 * 1024);
    final bitrateMbps = drop.durationSeconds > 0
        ? (drop.bytes * 8 / drop.durationSeconds) / (1000 * 1000)
        : 0.0;
    return 'bytes=${mb.toStringAsFixed(1)}MB '
        'duration=${drop.durationSeconds.toStringAsFixed(1)}s '
        'bitrate=${bitrateMbps.toStringAsFixed(1)}Mbps '
        'size=${drop.width ?? '?'}x${drop.height ?? '?'} '
        'format=${drop.format}';
  }

  void _debug(String message) {
    if (!kDebugMode) return;
    debugPrint('[DropVideoWindow] $message');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lifecycleAllowsPlayback = true;
      unawaited(_applyPlaybackState());
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _lifecycleAllowsPlayback = false;
      unawaited(_applyPlaybackState());
    }
  }
}

class DropVideoPlayerItem extends StatefulWidget {
  final Drop drop;
  final bool isFocused;
  final VideoPlayerController? controller;
  final bool isInitializing;
  final Object? videoError;
  final bool showBackButton;
  final VoidCallback onRetryVideo;
  final Function(Drop updatedDrop) onDropUpdated;
  final Future<void> Function(String dropId)? onToggleProps;
  final void Function(String dropId, int count)? onCommentsCountUpdated;
  final Future<void> Function()? onPauseForOverlay;
  final Future<void> Function()? onResumeAfterOverlay;

  const DropVideoPlayerItem({
    super.key,
    required this.drop,
    required this.isFocused,
    required this.controller,
    required this.isInitializing,
    required this.videoError,
    this.showBackButton = true,
    required this.onRetryVideo,
    required this.onDropUpdated,
    this.onToggleProps,
    this.onCommentsCountUpdated,
    this.onPauseForOverlay,
    this.onResumeAfterOverlay,
  });

  @override
  State<DropVideoPlayerItem> createState() => _DropVideoPlayerItemState();
}

class _DropVideoPlayerItemState extends State<DropVideoPlayerItem> {
  bool _showPlayPauseIcon = false;
  bool _isPropBusy = false;
  bool _isShortlistBusy = false;
  bool _showFireOverlay = false;

  void _togglePlayPause() {
    final controller = widget.controller;
    if (!widget.isFocused ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _showPlayPauseIcon = true;
    });

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
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
      final rollbackDrop = widget.drop.copyWith(
        hasPropped: originalHasPropped,
        propsCount: originalPropsCount,
      );
      widget.onDropUpdated(rollbackDrop);
    } finally {
      _isPropBusy = false;
    }
  }

  Future<void> _showComments() async {
    await widget.onPauseForOverlay?.call();
    if (!mounted) return;
    await showModalBottomSheet(
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
    if (!mounted) return;
    await widget.onResumeAfterOverlay?.call();
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
    final controller = widget.controller;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          if (controller != null)
            _DropVideoSurface(controller: controller, drop: widget.drop)
          else if (widget.videoError != null)
            _DropVideoError(onRetry: widget.onRetryVideo)
          else
            _DropPoster(drop: widget.drop, showLoader: widget.isInitializing),
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
          if (_showPlayPauseIcon && controller != null)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          if (widget.showBackButton)
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
          Positioned(
            bottom: 30,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    if (widget.drop.user != null) {
                      await widget.onPauseForOverlay?.call();
                      if (!context.mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicProfileScreen(userId: widget.drop.userId),
                        ),
                      );
                      if (!context.mounted) return;
                      await widget.onResumeAfterOverlay?.call();
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
                if (widget.drop.caption != null &&
                    widget.drop.caption!.isNotEmpty)
                  Text(
                    widget.drop.caption!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                const SizedBox(height: 8),
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
          Positioned(
            bottom: 40,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                _buildSideAction(
                  icon: Icons.comment_rounded,
                  color: Colors.white,
                  label: '${widget.drop.commentsCount}',
                  onTap: _showComments,
                ),
                const SizedBox(height: 20),
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

class _DropVideoSurface extends StatelessWidget {
  final VideoPlayerController controller;
  final Drop drop;

  const _DropVideoSurface({required this.controller, required this.drop});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final isReady = value.isInitialized;
        final showPoster =
            !isReady || value.isBuffering || value.position == Duration.zero;

        return Stack(
          fit: StackFit.expand,
          children: [
            _DropPoster(drop: drop, showLoader: false),
            if (isReady && value.size.width > 0 && value.size.height > 0)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: value.size.width,
                    height: value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            if (showPoster)
              _DropPoster(
                drop: drop,
                showLoader: !isReady || value.isBuffering,
              ),
          ],
        );
      },
    );
  }
}

class _DropPoster extends StatelessWidget {
  final Drop drop;
  final bool showLoader;

  const _DropPoster({required this.drop, required this.showLoader});

  @override
  Widget build(BuildContext context) {
    final posterUrl =
        drop.thumbnailUrl ?? _thumbnailUrlFromPlaybackUrl(drop.playbackUrl);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (posterUrl != null)
          Image.network(
            posterUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (showLoader) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  String? _thumbnailUrlFromPlaybackUrl(String playbackUrl) {
    final uri = Uri.tryParse(playbackUrl);
    if (uri == null || uri.host != 'res.cloudinary.com') return null;
    return playbackUrl.replaceFirst(
      RegExp(r'\.(mp4|mov|webm)(\?.*)?$', caseSensitive: false),
      '.jpg',
    );
  }
}

class _DropVideoError extends StatelessWidget {
  final VoidCallback onRetry;

  const _DropVideoError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
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
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('RETRY'),
          ),
        ],
      ),
    );
  }
}
