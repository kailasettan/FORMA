import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/player_profile.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/public_athlete_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../api_client.dart';
import '../models/player_profile_model.dart';
import '../models/user_model.dart';
import '../models/public_athlete_profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient _apiClient;
  final http.Client _httpClient;

  ProfileRepositoryImpl(this._apiClient, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  @override
  Future<List<PlayerProfile>> fetchPlayerProfiles(String userId) async {
    final response = await _apiClient.get('/users/$userId/player-profiles');
    if (response is List) {
      return response
          .map(
            (item) => PlayerProfileModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }

  @override
  Future<PlayerProfile> createPlayerProfile({
    required String sportId,
    String? roleOrDiscipline,
    required String skillLevel,
  }) async {
    final response = await _apiClient.post(
      '/player-profiles',
      body: {
        'sport_id': sportId,
        'role_or_discipline': ?roleOrDiscipline,
        'skill_level': skillLevel,
      },
    );
    return PlayerProfileModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(
    String profileId, {
    String? roleOrDiscipline,
    String? skillLevel,
  }) async {
    final response = await _apiClient.patch(
      '/player-profiles/$profileId',
      body: {
        'role_or_discipline': ?roleOrDiscipline,
        'skill_level': ?skillLevel,
      },
    );
    return PlayerProfileModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> deletePlayerProfile(String profileId) async {
    await _apiClient.delete('/player-profiles/$profileId');
  }

  @override
  Future<Map<String, dynamic>> getProfilePhotoUploadSignature() async {
    final response = await _apiClient
        .post('/uploads/profile-photo/signature')
        .timeout(const Duration(seconds: 15));
    return response as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> uploadProfilePhotoToCloudinary({
    required File file,
    required Map<String, dynamic> signatureData,
  }) async {
    final cloudName = signatureData['cloud_name'] as String;
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', url)
      ..fields['api_key'] = signatureData['api_key'] as String
      ..fields['timestamp'] = signatureData['timestamp'].toString()
      ..fields['signature'] = signatureData['signature'] as String
      ..fields['upload_preset'] = signatureData['upload_preset'] as String
      ..fields['folder'] = signatureData['folder'] as String
      ..fields['overwrite'] = signatureData['overwrite'] as String
      ..fields['unique_filename'] = signatureData['unique_filename'] as String;

    final length = await file.length();
    request.files.add(
      http.MultipartFile(
        'file',
        http.ByteStream(file.openRead()),
        length,
        filename: file.path.split('/').last,
      ),
    );

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw NetworkException(
        'Profile photo upload timed out. Check your connection and try again.',
      );
    } on SocketException {
      throw NetworkException(
        'Profile photo upload failed. Check your connection and try again.',
      );
    }

    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        throw ApiException('Cloudinary returned an invalid image response.');
      }
      _validateProfilePhotoCloudinaryResponse(json);
      return json;
    }

    throw ApiException(
      _parseCloudinaryError(response.body, response.statusCode),
    );
  }

  @override
  Future<User> updateMe({
    String? username,
    String? fullName,
    int? age,
    String? city,
    String? profilePhotoUrl,
    String? headline,
    String? bio,
    String? location,
    String? availability,
    List<String>? preferredOpportunityTypes,
    String? focusedSportId,
  }) async {
    final body = {
      'username': ?username,
      'full_name': ?fullName,
      'age': ?age,
      'city': ?city,
      'profile_photo_url': ?profilePhotoUrl,
      'headline': ?headline,
      'bio': ?bio,
      'location': ?location,
      'availability': ?availability,
      'preferred_opportunity_types': ?preferredOpportunityTypes,
      'focused_sport_id': focusedSportId, // always set (can be null)
    };
    final response = await _apiClient.patch('/users/me', body: body);
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PublicAthleteProfile> fetchPublicAthleteProfile(String userId) async {
    final response = await _apiClient.get('/users/$userId/public-profile');
    return PublicAthleteProfileModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PublicAthleteProfile> fetchPublicAthleteProfileByUsername(
    String username,
  ) async {
    final response = await _apiClient.get(
      '/users/by-username/$username/public-profile',
    );
    return PublicAthleteProfileModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<User>> searchAthletes(String query) async {
    final response = await _apiClient.get(
      '/users/search?q=${Uri.encodeQueryComponent(query)}',
    );
    if (response is List) {
      return response
          .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  void _validateProfilePhotoCloudinaryResponse(Map<String, dynamic> json) {
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
    ]) {
      if (json[field] == null) missingFields.add(field);
    }
    if (missingFields.isNotEmpty) {
      throw ApiException(
        'Cloudinary image response was missing: ${missingFields.join(', ')}.',
      );
    }

    final format = (json['format'] as String).toLowerCase();
    if (json['resource_type'] != 'image' ||
        !['jpg', 'jpeg', 'png', 'webp'].contains(format) ||
        json['secure_url'] is! String ||
        (json['secure_url'] as String).isEmpty ||
        json['public_id'] is! String ||
        (json['public_id'] as String).isEmpty) {
      throw ApiException('Cloudinary returned malformed image metadata.');
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
    return 'Profile photo upload failed ($statusCode). Try again.';
  }

  String _cloudinaryErrorMessage(Object error) {
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return 'Cloudinary rejected the image: ${message.trim()}';
      }
    }
    return 'Cloudinary rejected the image. Try again.';
  }
}
