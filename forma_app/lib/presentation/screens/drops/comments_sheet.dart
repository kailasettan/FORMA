import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/auth_cubit.dart';
import '../../cubits/comments_cubit.dart';
import '../../theme.dart';
import '../../widgets/avatar_image.dart';

class CommentsSheet extends StatefulWidget {
  final String dropId;
  final Function(int count) onCommentsCountUpdated;

  const CommentsSheet({
    super.key,
    required this.dropId,
    required this.onCommentsCountUpdated,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommentsCubit>().loadComments(widget.dropId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    context.read<CommentsCubit>().addComment(widget.dropId, text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final String? loggedInUserId = authState is AuthAuthenticated
        ? authState.user.id
        : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Column(
        children: [
          // Sheet Handle & Header
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Comments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),

          // Comments List
          Expanded(
            child: BlocConsumer<CommentsCubit, CommentsState>(
              listener: (context, state) {
                if (state is CommentsLoaded) {
                  widget.onCommentsCountUpdated(state.comments.length);
                }
              },
              builder: (context, state) {
                if (state is CommentsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is CommentsError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        state.message,
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    ),
                  );
                }

                if (state is CommentsLoaded || state is CommentsPosting) {
                  final comments = state is CommentsLoaded
                      ? state.comments
                      : (state as CommentsPosting).comments;

                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        'Be the first to comment!',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: comments.length,
                    padding: const EdgeInsets.all(16.0),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final isAuthor = loggedInUserId == comment.userId;
                      final profilePhoto = avatarImageProvider(
                        comment.user?.profilePhotoUrl,
                      );

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: profilePhoto,
                              child: profilePhoto == null
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.user?.fullName ?? 'Athlete',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        comment.user?.username != null
                                            ? '@${comment.user!.username}'
                                            : '',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comment.body,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            if (isAuthor)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () {
                                  context.read<CommentsCubit>().deleteComment(
                                    widget.dropId,
                                    comment.id,
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          // Message Input Field
          SafeArea(
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                top: 12,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.cardBg,
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AppTheme.primary,
                    ),
                    onPressed: _submitComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
