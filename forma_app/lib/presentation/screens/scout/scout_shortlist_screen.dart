import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/scout_shortlist_cubit.dart';
import '../../theme.dart';
import '../profile/public_profile_screen.dart';

class ScoutShortlistScreen extends StatefulWidget {
  const ScoutShortlistScreen({super.key});

  @override
  State<ScoutShortlistScreen> createState() => _ScoutShortlistScreenState();
}

class _ScoutShortlistScreenState extends State<ScoutShortlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScoutShortlistCubit>().loadShortlist();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Shortlisted Athletes'),
      ),
      body: BlocBuilder<ScoutShortlistCubit, ScoutShortlistState>(
        builder: (context, state) {
          if (state is ScoutShortlistLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ScoutShortlistError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ScoutShortlistCubit>().loadShortlist();
                      },
                      child: const Text('RETRY'),
                    )
                  ],
                ),
              ),
            );
          }

          if (state is ScoutShortlistLoaded) {
            final shortlist = state.shortlist;

            if (shortlist.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmarks_outlined,
                      size: 64,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No athletes shortlisted yet',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        'Go to Find Athletes to search for players and add them to your private list.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await context.read<ScoutShortlistCubit>().loadShortlist();
              },
              child: ListView.builder(
                itemCount: shortlist.length,
                padding: const EdgeInsets.all(16.0),
                itemBuilder: (context, index) {
                  final item = shortlist[index];
                  final athlete = item.athlete;

                  if (athlete == null) return const SizedBox.shrink();

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: athlete.profilePhotoUrl != null
                                ? NetworkImage(athlete.profilePhotoUrl!)
                                : null,
                            child: athlete.profilePhotoUrl == null
                                ? const Icon(Icons.person_rounded)
                                : null,
                          ),
                          title: Text(
                            athlete.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@${athlete.username}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                              if (athlete.headline != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  athlete.headline!,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.bookmark_remove_rounded, color: AppTheme.error),
                            onPressed: () {
                              context.read<ScoutShortlistCubit>().removeShortlist(athlete.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Removed from shortlist'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            },
                          ),
                          onTap: () {
                            final scoutCubit = context.read<ScoutShortlistCubit>();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PublicProfileScreen(userId: athlete.id),
                              ),
                            ).then((_) {
                              scoutCubit.loadShortlist();
                            });
                          },
                        ),
                        // Private note banner if exists
                        if (item.privateNote != null && item.privateNote!.isNotEmpty) ...[
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.note_alt_outlined, size: 16, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'PRIVATE NOTE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.privateNote!,
                                          style: const TextStyle(fontSize: 12, height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
