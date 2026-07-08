import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
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
    return http.ByteStream(
      byteStream.map((data) {
        bytesSent += data.length;
        onProgress(bytesSent, total);
        return data;
      }),
    );
  }
}

class DropRepositoryImpl implements DropRepository {
  final ApiClient _apiClient;
  final http.Client _httpClient;

  DropRepositoryImpl(this._apiClient, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  @override
  Future<Map<String, dynamic>> getUploadSignature() async {
    _debugCheckpoint('request signature');
    final response = await _apiClient
        .post('/drops/upload-signature')
        .timeout(const Duration(seconds: 15));
    return response as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> uploadToCloudinary({
    required XFile file,
    required Map<String, dynamic> signatureData,
    required Function(double progress) onProgress,
  }) async {
    final cloudName = signatureData['cloud_name'] as String;
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
    );

    final request = MultipartRequestWithProgress(
      'POST',
      url,
      onProgress: (bytes, total) {
        if (total > 0) {
          onProgress(bytes / total);
        }
      },
    );

    // Add fields
    request.fields['api_key'] = signatureData['api_key'] as String;
    request.fields['timestamp'] = signatureData['timestamp'].toString();
    request.fields['signature'] = signatureData['signature'] as String;
    request.fields['upload_preset'] = signatureData['upload_preset'] as String;
    request.fields['folder'] = signatureData['folder'] as String;
    request.fields['overwrite'] = signatureData['overwrite'] as String;
    request.fields['unique_filename'] =
        signatureData['unique_filename'] as String;

    final multipartFile = await _multipartFileFromXFile(file);
    request.files.add(multipartFile);

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw NetworkException(
        'Upload timed out. Check your connection and try again.',
      );
    } on SocketException {
      throw NetworkException(
        'Cloudinary upload failed. Check your connection and try again.',
      );
    }
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        throw ApiException('Cloudinary returned an invalid upload response.');
      }
      _validateCloudinaryResponse(json);
      _debugCloudinaryResponse(json);
      return json;
    }

    throw ApiException(
      _parseCloudinaryError(response.body, response.statusCode),
    );
  }

  Future<http.MultipartFile> _multipartFileFromXFile(XFile file) async {
    if (kIsWeb) {
      return http.MultipartFile.fromBytes(
        'file',
        await file.readAsBytes(),
        filename: file.name.isNotEmpty ? file.name : 'drop_upload',
        contentType: _mediaTypeFor(file),
      );
    }

    final sourceFile = File(file.path);
    final filename = file.name.isNotEmpty
        ? file.name
        : file.path.split('/').last;
    return http.MultipartFile(
      'file',
      http.ByteStream(sourceFile.openRead()),
      await sourceFile.length(),
      filename: filename,
      contentType: _mediaTypeFor(file),
    );
  }

  MediaType? _mediaTypeFor(XFile file) {
    final mimeType = file.mimeType;
    if (mimeType == null || mimeType.trim().isEmpty) return null;
    try {
      return MediaType.parse(mimeType);
    } catch (_) {
      return null;
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
    String? sportId,
    String? categoryId,
    String? caption,
    String visibility = 'public',
    String? audience,
    String? location,
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
      'audience': audience,
      'location': location,
    };
    _debugCheckpoint('POST /drops start');
    _debugPostDropsPayload(payload);
    try {
      final response = await _apiClient.post(
        '/drops',
        body: payload,
        timeout: const Duration(seconds: 20),
      );
      if (response is! Map<String, dynamic>) {
        throw ApiException(
          'Drop created, but the server response was invalid.',
        );
      }
      _debugPostDropsResponse(response);
      DropModel drop;
      try {
        drop = DropModel.fromJson(response);
      } catch (error) {
        _debugCheckpoint(
          'POST /drops parse failed: ${error.runtimeType}: $error',
        );
        rethrow;
      }
      _debugCreatedDrop(drop);
      return drop;
    } catch (error) {
      if (error is ApiException) {
        _debugCheckpoint(
          'POST /drops error: '
          'status=${error.statusCode ?? 'unknown'} '
          'exception=${error.runtimeType} '
          'message=${error.message} '
          'body=${error.responseBody ?? ''}',
        );
      } else {
        _debugCheckpoint('POST /drops error: ${error.runtimeType}: $error');
      }
      rethrow;
    }
  }

  @override
  Future<List<Drop>> getUserDrops(String userId) async {
    final response = await _apiClient.get('/users/$userId/drops');
    if (response is List) {
      return response
          .map((json) => DropModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<DropFeedPage> getDropsFeed({
    String? cursor,
    int limit = 10,
    String? sportId,
  }) async {
    final query = <String>[
      'limit=$limit',
      if (cursor != null) 'cursor=${Uri.encodeQueryComponent(cursor)}',
      if (sportId != null) 'sport_id=${Uri.encodeQueryComponent(sportId)}',
    ].join('&');
    final response = await _apiClient.get('/drops/feed?$query');
    if (response is Map<String, dynamic>) {
      final items = response['items'] as List? ?? [];
      return DropFeedPage(
        items: items
            .map((json) => DropModel.fromJson(json as Map<String, dynamic>))
            .toList(),
        nextCursor: response['next_cursor'] as String?,
      );
    }
    if (response is List) {
      return DropFeedPage(
        items: response
            .map((json) => DropModel.fromJson(json as Map<String, dynamic>))
            .toList(),
      );
    }
    return const DropFeedPage(items: []);
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
      return response
          .map(
            (json) => DropCommentModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }

  @override
  Future<DropComment> postComment(String dropId, String body) async {
    final payload = {'body': body};
    final response = await _apiClient.post(
      '/drops/$dropId/comments',
      body: payload,
    );
    return DropCommentModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> deleteComment(String dropId, String commentId) async {
    await _apiClient.delete('/drops/$dropId/comments/$commentId');
  }

  void _validateCloudinaryResponse(Map<String, dynamic> json) {
    final error = json['error'];
    if (error != null) {
      throw ApiException(_cloudinaryErrorMessage(error));
    }

    final missingFields = <String>[];
    for (final field in [
      'asset_id',
      'public_id',
      'resource_type',
      'secure_url',
      'format',
      'bytes',
      'duration',
    ]) {
      if (json[field] == null) missingFields.add(field);
    }
    if (missingFields.isNotEmpty) {
      throw ApiException(
        'Cloudinary upload response was missing: ${missingFields.join(', ')}.',
      );
    }

    if (json['resource_type'] != 'video') {
      throw ApiException(
        'Cloudinary rejected the upload: asset is not a video.',
      );
    }

    if (json['asset_id'] is! String ||
        (json['asset_id'] as String).isEmpty ||
        json['public_id'] is! String ||
        (json['public_id'] as String).isEmpty ||
        json['secure_url'] is! String ||
        (json['secure_url'] as String).isEmpty ||
        json['format'] is! String ||
        (json['format'] as String).isEmpty ||
        json['bytes'] is! num ||
        json['duration'] is! num) {
      throw ApiException('Cloudinary returned malformed upload metadata.');
    }
  }

  String _parseCloudinaryError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['error'] != null) {
        return _cloudinaryErrorMessage(decoded['error']);
      }
    } catch (_) {
      // Fall through to generic message.
    }
    return 'Cloudinary upload failed ($statusCode). Try again.';
  }

  String _cloudinaryErrorMessage(Object error) {
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return 'Cloudinary rejected the upload: ${message.trim()}';
      }
    }
    return 'Cloudinary rejected the upload. Try again.';
  }

  void _debugCheckpoint(String checkpoint) {
    if (kDebugMode) {
      debugPrint('[DropUploadRepository] $checkpoint');
    }
  }

  void _debugCloudinaryResponse(Map<String, dynamic> json) {
    if (!kDebugMode) return;
    debugPrint(
      '[DropUploadRepository] cloudinary accepted keys=${json.keys.toList()} '
      'resource_type=${json['resource_type'] == null ? 'null' : 'present'} '
      'duration=${json['duration'] == null ? 'null' : 'present'} '
      'bytes=${json['bytes'] == null ? 'null' : 'present'} '
      'format=${json['format'] == null ? 'null' : 'present'}',
    );
  }

  void _debugPostDropsPayload(Map<String, dynamic> payload) {
    if (!kDebugMode) return;
    debugPrint(
      '[DropUploadRepository] POST /drops payload keys: ${payload.keys.toList()}',
    );
  }

  void _debugCreatedDrop(Drop drop) {
    if (!kDebugMode) return;
    debugPrint(
      '[DropUploadRepository] POST /drops created: '
      'moderation_status=${drop.moderationStatus} '
      'visibility=${drop.visibility}',
    );
  }

  void _debugPostDropsResponse(Map<String, dynamic> json) {
    if (!kDebugMode) return;
    debugPrint(
      '[DropUploadRepository] POST /drops response keys: ${json.keys.toList()}',
    );
  }
}
