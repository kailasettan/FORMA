import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/sport.dart';
import '../../cubits/catalog_cubit.dart';
import '../../cubits/drop_feed_cubit.dart';
import '../../theme.dart';
import 'drop_viewer_screen.dart';

class DropsFeedScreen extends StatefulWidget {
  final bool isActive;

  const DropsFeedScreen({super.key, required this.isActive});

  @override
  State<DropsFeedScreen> createState() => _DropsFeedScreenState();
}

class _DropsFeedScreenState extends State<DropsFeedScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  int _focusedIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogCubit>().loadSportsAndCategories();
      context.read<DropFeedCubit>().loadInitial();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectSport(String? sportId) {
    setState(() {
      _focusedIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    context.read<DropFeedCubit>().loadInitial(sportId: sportId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        BlocBuilder<DropFeedCubit, DropFeedState>(
          builder: (context, state) {
            if (state.isLoading && state.drops.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.error != null && state.drops.isEmpty) {
              return _FeedMessage(
                icon: Icons.wifi_off_rounded,
                message: state.error!,
                actionLabel: 'RETRY',
                onAction: () => context.read<DropFeedCubit>().loadInitial(
                  sportId: state.selectedSportId,
                ),
              );
            }

            if (state.drops.isEmpty) {
              return const _FeedMessage(
                icon: Icons.video_library_outlined,
                message: 'No Drops yet.',
              );
            }

            return PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: state.drops.length + (state.isLoadingMore ? 1 : 0),
              onPageChanged: (index) {
                setState(() {
                  _focusedIndex = index;
                });
                if (index >= state.drops.length - 3) {
                  context.read<DropFeedCubit>().loadMore();
                }
              },
              itemBuilder: (context, index) {
                if (index >= state.drops.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                final drop = state.drops[index];
                return DropVideoPlayerItem(
                  drop: drop,
                  isFocused: widget.isActive && index == _focusedIndex,
                  onDropUpdated: (_) {},
                  onToggleProps: (dropId) =>
                      context.read<DropFeedCubit>().toggleProps(dropId),
                  onCommentsCountUpdated: (dropId, count) => context
                      .read<DropFeedCubit>()
                      .updateCommentCount(dropId, count),
                );
              },
            );
          },
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: _SportFilter(
            selectedSportId: context.select(
              (DropFeedCubit cubit) => cubit.state.selectedSportId,
            ),
            onSelected: _selectSport,
          ),
        ),
      ],
    );
  }
}

class _SportFilter extends StatelessWidget {
  final String? selectedSportId;
  final ValueChanged<String?> onSelected;

  const _SportFilter({required this.selectedSportId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogCubit, CatalogState>(
      builder: (context, state) {
        final sports = state is CatalogLoaded ? state.sports : <Sport>[];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All Sports',
                isSelected: selectedSportId == null,
                onTap: () => onSelected(null),
              ),
              ...sports.map(
                (sport) => _FilterChip(
                  label: sport.name,
                  isSelected: selectedSportId == sport.id,
                  onTap: () => onSelected(sport.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.black54,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _FeedMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
