import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/drop_comment.dart';
import '../../domain/repositories/drop_repository.dart';

abstract class CommentsState extends Equatable {
  const CommentsState();
  @override
  List<Object?> get props => [];
}

class CommentsInitial extends CommentsState {}

class CommentsLoading extends CommentsState {}

class CommentsLoaded extends CommentsState {
  final List<DropComment> comments;
  const CommentsLoaded(this.comments);

  @override
  List<Object?> get props => [comments];
}

class CommentsPosting extends CommentsState {
  final List<DropComment> comments;
  const CommentsPosting(this.comments);

  @override
  List<Object?> get props => [comments];
}

class CommentsError extends CommentsState {
  final String message;
  const CommentsError(this.message);

  @override
  List<Object?> get props => [message];
}

class CommentsCubit extends Cubit<CommentsState> {
  final DropRepository _dropRepository;

  CommentsCubit(this._dropRepository) : super(CommentsInitial());

  Future<void> loadComments(String dropId) async {
    try {
      emit(CommentsLoading());
      final comments = await _dropRepository.getComments(dropId);
      emit(CommentsLoaded(comments));
    } catch (e) {
      emit(CommentsError(e.toString()));
    }
  }

  Future<void> addComment(String dropId, String body) async {
    final currentComments = state is CommentsLoaded
        ? (state as CommentsLoaded).comments
        : state is CommentsPosting
            ? (state as CommentsPosting).comments
            : <DropComment>[];
            
    try {
      emit(CommentsPosting(currentComments));
      final newComment = await _dropRepository.postComment(dropId, body);
      emit(CommentsLoaded([...currentComments, newComment]));
    } catch (e) {
      emit(CommentsError(e.toString()));
    }
  }

  Future<void> deleteComment(String dropId, String commentId) async {
    final currentComments = state is CommentsLoaded
        ? (state as CommentsLoaded).comments
        : <DropComment>[];

    try {
      emit(CommentsLoading());
      await _dropRepository.deleteComment(dropId, commentId);
      final updatedComments = currentComments.where((c) => c.id != commentId).toList();
      emit(CommentsLoaded(updatedComments));
    } catch (e) {
      emit(CommentsError(e.toString()));
    }
  }
}
