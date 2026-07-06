import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:forma/data/api_client.dart';
import 'package:forma/data/repositories/profile_repository_impl.dart';
import 'package:forma/presentation/screens/profile/profile_photo_validation.dart';

void main() {
  group('profile photo validation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('profile_photo_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'accepts jpg, png, and webp files under 5 MB with valid signatures',
      () async {
        final jpg = await _writeTempFile(tempDir, 'photo.jpg', [
          0xFF,
          0xD8,
          0xFF,
          0xE0,
        ]);
        final png = await _writeTempFile(tempDir, 'photo.png', [
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]);
        final webp = await _writeTempFile(tempDir, 'photo.webp', [
          0x52,
          0x49,
          0x46,
          0x46,
          0x00,
          0x00,
          0x00,
          0x00,
          0x57,
          0x45,
          0x42,
          0x50,
        ]);

        expect(await isValidProfilePhotoFile(jpg), isTrue);
        expect(await isValidProfilePhotoFile(png), isTrue);
        expect(await isValidProfilePhotoFile(webp), isTrue);
      },
    );

    test('rejects blocked extensions before upload', () async {
      for (final extension in [
        'svg',
        'pdf',
        'js',
        'zip',
        'apk',
        'gif',
        'html',
        'txt',
        'xml',
        'heic',
        'heif',
      ]) {
        final file = await _writeTempFile(tempDir, 'photo.$extension', [
          0xFF,
          0xD8,
          0xFF,
        ]);

        expect(await isValidProfilePhotoFile(file), isFalse, reason: extension);
      }
    });

    test(
      'rejects spoofed files with allowed extension but invalid bytes',
      () async {
        final svgAsJpg = await _writeTempFile(
          tempDir,
          'script.jpg',
          '<svg><script>alert(1)</script></svg>'.codeUnits,
        );

        expect(await isValidProfilePhotoFile(svgAsJpg), isFalse);
      },
    );

    test('rejects files over 5 MB', () async {
      final oversized = File('${tempDir.path}/large.jpg');
      final sink = oversized.openWrite();
      sink.add([0xFF, 0xD8, 0xFF]);
      sink.add(List<int>.filled(maxProfilePhotoBytes + 1, 0));
      await sink.close();

      expect(await isValidProfilePhotoFile(oversized), isFalse);
    });
  });

  test('profile Cloudinary upload does not send upload preset', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'profile_upload_test_',
    );
    try {
      final file = await _writeTempFile(tempDir, 'photo.jpg', [
        0xFF,
        0xD8,
        0xFF,
      ]);
      final client = _CapturingClient();
      final repository = ProfileRepositoryImpl(ApiClient(), httpClient: client);

      await repository.uploadProfilePhotoToCloudinary(
        file: file,
        signatureData: {
          'signature': 'sig',
          'timestamp': 123,
          'api_key': 'key',
          'upload_preset': 'stale_missing_preset',
          'folder': 'forma/profile_photos',
          'overwrite': 'true',
          'unique_filename': 'false',
          'public_id': 'profile_user_1',
          'allowed_formats': 'jpg,jpeg,png,webp',
          'cloud_name': 'demo',
        },
      );

      expect(client.fields['upload_preset'], isNull);
      expect(client.fields['public_id'], 'profile_user_1');
      expect(client.fields['allowed_formats'], 'jpg,jpeg,png,webp');
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}

Future<File> _writeTempFile(
  Directory directory,
  String name,
  List<int> bytes,
) async {
  final file = File('${directory.path}/$name');
  return file.writeAsBytes(bytes);
}

class _CapturingClient extends http.BaseClient {
  Map<String, String> fields = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.MultipartRequest) {
      fields = Map<String, String>.from(request.fields);
    }
    final body = jsonEncode({
      'asset_id': 'asset-profile',
      'public_id': 'forma/profile_photos/profile_user_1',
      'resource_type': 'image',
      'secure_url':
          'https://res.cloudinary.com/demo/image/upload/profile_user_1.jpg',
      'format': 'jpg',
    });
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
    );
  }
}
