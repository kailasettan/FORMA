import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../domain/entities/drop.dart';
import '../../domain/entities/drop_comment.dart';
import '../../domain/repositories/drop_repository.dart';
import '../api_client.dart';
import '../models/drop_model.dart';
import '../models/drop_comment_model.dart';

class MultipartRequestWithProgress extends http.MultipartRequest {
  final Function(int bytes, int total) onProgress;
  
  MultipartRequestWithProgress(
    super.method,
    super.url, {
    required this.onProgress,
  });

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    int bytesSent = 0;
    final total = contentLength;
    return http.ByteStream(byteStream.map((data) {
      bytesSent += data.length;
      onProgress(bytesSent, total);
      return data;
    }));
  }
}

class DropRepositoryImpl implements DropRepository {
  final ApiClient _apiClient;
  final http.Client _httpClient;

  DropRepositoryImpl(this._apiClient, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  @override
  Future<Map<String, dynamic>> getUploadSignature() async {
    final response = await _apiClient.post('/drops/upload-signature');
    return response as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> uploadToCloudinary({
    required File file,
    required Map<String, dynamic> signatureData,
    required Function(double progress) onProgress,
  }) async {
    final cloudName = signatureData['cloud_name'] as String;
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');

    final request = MultipartRequestWithProgress('POST', url, onProgress: (bytes, total) {
      if (total > 0) {
        onProgress(bytes / total);
      }
    });

    // Add fields
    request.fields['api_key'] = signatureData['api_key'] as String;
    request.fields['timestamp'] = signatureData['timestamp'].toString();
    request.fields['signature'] = signatureData['signature'] as String;
    request.fields['upload_preset'] = signatureData['upload_preset'] as String;
    request.fields['folder'] = signatureData['folder'] as String;
    request.fields['overwrite'] = signatureData['overwrite'] as String;
    request.fields['unique_filename'] = signatureData['unique_filename'] as String;

    // Add file
    final fileStream = http.ByteStream(file.openRead());
    final length = await file.length();
    final multipartFile = http.MultipartFile(
      'file',
      fileStream,
      length,
      filename: file.path.split('/').last,
    );
    request.files.add(multipartFile);

    final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException(
        'Cloudinary direct upload failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  @override
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
    String visibility = 'public',
  }) async {
    final payload = {
      'provider_asset_id': providerAssetId,
      'public_id': publicId,
      'playback_url': playbackUrl,
      'thumbnail_url': thumbnailUrl,
      'duration_seconds': durationSeconds,
      'width': width,
      'height': height,
      'format': format,
      'bytes': bytes,
      'sport_id': sportId,
      'category_id': categoryId,
      'caption': caption,
      'visibility': visibility,
    };
    final response = await _apiClient.post('/drops', body: payload);
    return DropModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<Drop>> getUserDrops(String userId) async {
    final response = await _apiClient.get('/users/$userId/drops');
    if (response is List) {
      return response.map((json) => DropModel.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  Future<Drop> getDropDetails(String dropId) async {
    final response = await _apiClient.get('/drops/$dropId');
    return DropModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> deleteDrop(String dropId) async {
    await _apiClient.delete('/drops/$dropId');
  }

  @override
  Future<void> giveProps(String dropId) async {
    await _apiClient.post('/drops/$dropId/props');
  }

  @override
  Future<void> removeProps(String dropId) async {
    await _apiClient.delete('/drops/$dropId/props');
  }

  @override
  Future<List<DropComment>> getComments(String dropId) async {
    final response = await _apiClient.get('/drops/$dropId/comments');
    if (response is List) {
      return response.map((json) => DropCommentModel.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  Future<DropComment> postComment(String dropId, String body) async {
    final payload = {'body': body};
    final response = await _apiClient.post('/drops/$dropId/comments', body: payload);
    return DropCommentModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> deleteComment(String dropId, String commentId) async {
    await _apiClient.delete('/drops/$dropId/comments/$commentId');
  }
}
