import 'dart:io';
import '../entities/drop.dart';
import '../entities/drop_comment.dart';

abstract class DropRepository {
  Future<Map<String, dynamic>> getUploadSignature();

  Future<Map<String, dynamic>> uploadToCloudinary({
    required File file,
    required Map<String, dynamic> signatureData,
    required Function(double progress) onProgress,
  });

  Future<Drop> registerDrop({
    required String providerAssetId,
    required String publicId,
    required String playbackUrl,
    String? thumbnailUrl,
    required double durationSeconds,
    int? width,
    int? height,
    required String format,
    required int bytes,
    required String sportId,
    String? categoryId,
    String? caption,
    String visibility,
  });

  Future<List<Drop>> getUserDrops(String userId);
  Future<DropFeedPage> getDropsFeed({
    String? cursor,
    int limit = 10,
    String? sportId,
  });
  Future<Drop> getDropDetails(String dropId);
  Future<void> deleteDrop(String dropId);

  Future<void> giveProps(String dropId);
  Future<void> removeProps(String dropId);

  Future<List<DropComment>> getComments(String dropId);
  Future<DropComment> postComment(String dropId, String body);
  Future<void> deleteComment(String dropId, String commentId);
}

class DropFeedPage {
  final List<Drop> items;
  final String? nextCursor;

  const DropFeedPage({required this.items, this.nextCursor});
}
