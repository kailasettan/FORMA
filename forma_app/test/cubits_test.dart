import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forma/data/api_client.dart';
import 'package:forma/presentation/cubits/drop_feed_cubit.dart';
import 'package:forma/presentation/cubits/auth_cubit.dart';
import 'package:forma/presentation/cubits/drop_upload_cubit.dart';
import 'package:forma/presentation/cubits/profile_cubit.dart';
import 'package:forma/domain/entities/drop.dart';
import 'package:forma/domain/entities/drop_comment.dart';
import 'package:forma/domain/entities/player_profile.dart';
import 'package:forma/domain/entities/public_athlete_profile.dart';
import 'package:forma/domain/entities/user.dart';
import 'package:forma/domain/repositories/auth_repository.dart';
import 'package:forma/domain/repositories/drop_repository.dart';
import 'package:forma/domain/repositories/profile_repository.dart';

class FakeAuthRepository implements AuthRepository {
  User? mockUser;
  bool shouldThrow = false;
  bool shouldFailHealth = false;
  String? savedToken;

  @override
  Future<User> login({required String email, required String password}) async {
    if (shouldThrow) throw Exception('Invalid credentials');
    return mockUser!;
  }

  @override
  Future<User> signUp({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String role = 'athlete',
  }) async {
    if (shouldThrow) throw Exception('Signup failed');
    return mockUser!;
  }

  @override
  Future<User?> checkAuth() async {
    if (shouldThrow) throw Exception('Network error');
    if (savedToken == null) return null;
    return mockUser;
  }

  @override
  Future<void> healthCheck() async {
    if (shouldFailHealth) throw Exception('Network error');
  }

  @override
  Future<void> logout() async {
    savedToken = null;
  }

  @override
  Future<String?> getToken() async => savedToken;
}

class FakeDropRepository implements DropRepository {
  int uploadCount = 0;
  int publishCount = 0;
  Object? uploadError;
  Object? publishError;
  Map<String, dynamic>? cloudinaryResponse;
  Drop drop = makeDrop();

  @override
  Future<Map<String, dynamic>> getUploadSignature() async => {
    'signature': 'sig',
    'timestamp': 123,
    'api_key': 'key',
    'upload_preset': 'preset',
    'folder': 'folder',
    'overwrite': 'false',
    'unique_filename': 'true',
    'cloud_name': 'cloud',
  };

  @override
  Future<Map<String, dynamic>> uploadToCloudinary({
    required File file,
    required Map<String, dynamic> signatureData,
    required Function(double progress) onProgress,
  }) async {
    uploadCount++;
    onProgress(0.4);
    if (uploadError != null) throw uploadError!;
    onProgress(1);
    return cloudinaryResponse ?? cloudinarySuccess();
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
    publishCount++;
    if (publishError != null) throw publishError!;
    return drop;
  }

  @override
  Future<void> deleteComment(String dropId, String commentId) async {}

  @override
  Future<void> deleteDrop(String dropId) async {}

  @override
  Future<List<DropComment>> getComments(String dropId) async => [];

  @override
  Future<Drop> getDropDetails(String dropId) async => drop;

  @override
  Future<DropFeedPage> getDropsFeed({
    String? cursor,
    int limit = 10,
    String? sportId,
  }) async => DropFeedPage(items: [drop]);

  @override
  Future<List<Drop>> getUserDrops(String userId) async => [drop];

  @override
  Future<void> giveProps(String dropId) async {}

  @override
  Future<DropComment> postComment(String dropId, String body) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeProps(String dropId) async {}
}

class FakeProfileRepository implements ProfileRepository {
  List<PlayerProfile> profiles = [];
  bool shouldThrowOnDelete = false;
  String? deletedProfileId;

  @override
  Future<List<PlayerProfile>> fetchPlayerProfiles(String userId) async {
    return profiles;
  }

  @override
  Future<PlayerProfile> createPlayerProfile({
    required String sportId,
    String? roleOrDiscipline,
    required String skillLevel,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(
    String profileId, {
    String? roleOrDiscipline,
    String? skillLevel,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deletePlayerProfile(String profileId) async {
    if (shouldThrowOnDelete) throw Exception('delete failed');
    deletedProfileId = profileId;
    profiles = profiles.where((profile) => profile.id != profileId).toList();
  }

  @override
  Future<Map<String, dynamic>> getProfilePhotoUploadSignature() async => {};

  @override
  Future<Map<String, dynamic>> uploadProfilePhotoToCloudinary({
    required File file,
    required Map<String, dynamic> signatureData,
  }) async => {};

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
    throw UnimplementedError();
  }

  @override
  Future<PublicAthleteProfile> fetchPublicAthleteProfile(String userId) async {
    throw UnimplementedError();
  }

  @override
  Future<PublicAthleteProfile> fetchPublicAthleteProfileByUsername(
    String username,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<List<User>> searchAthletes(String query) async {
    return [];
  }
}

Map<String, dynamic> cloudinarySuccess() => {
  'asset_id': 'asset_123',
  'public_id': 'forma/skill_clips/drop_123',
  'resource_type': 'video',
  'secure_url': 'https://res.cloudinary.com/demo/video/upload/drop_123.mp4',
  'format': 'mp4',
  'bytes': 1024,
  'duration': 12.3,
  'width': 1080,
  'height': 1920,
};

Drop makeDrop() {
  final now = DateTime.utc(2026, 7, 3);
  return Drop(
    id: 'drop_1',
    userId: 'user_1',
    sportId: 'sport_1',
    provider: 'cloudinary',
    providerAssetId: 'asset_123',
    publicId: 'forma/skill_clips/drop_123',
    playbackUrl: 'https://res.cloudinary.com/demo/video/upload/drop_123.mp4',
    thumbnailUrl: 'https://res.cloudinary.com/demo/video/upload/drop_123.jpg',
    durationSeconds: 12.3,
    format: 'mp4',
    bytes: 1024,
    moderationStatus: 'approved',
    visibility: 'public',
    createdAt: now,
    updatedAt: now,
  );
}

Drop makeDropWith({
  String id = 'drop_1',
  String sportId = 'sport_1',
  String visibility = 'public',
  String moderationStatus = 'approved',
}) {
  final drop = makeDrop();
  return Drop(
    id: id,
    userId: drop.userId,
    sportId: sportId,
    provider: drop.provider,
    providerAssetId: '${drop.providerAssetId}_$id',
    publicId: '${drop.publicId}_$id',
    playbackUrl: drop.playbackUrl,
    thumbnailUrl: drop.thumbnailUrl,
    durationSeconds: drop.durationSeconds,
    format: drop.format,
    bytes: drop.bytes,
    moderationStatus: moderationStatus,
    visibility: visibility,
    createdAt: drop.createdAt,
    updatedAt: drop.updatedAt,
  );
}

void main() {
  group('AuthCubit State Transitions', () {
    late FakeAuthRepository fakeAuthRepository;
    late User testUser;

    setUp(() {
      fakeAuthRepository = FakeAuthRepository();
      testUser = User(
        id: '123',
        username: 'test',
        email: 'test@example.com',
        fullName: 'Test User',
        createdAt: DateTime.now(),
      );
      fakeAuthRepository.mockUser = testUser;
    });

    test('initial state should be AuthInitial', () {
      final cubit = AuthCubit(fakeAuthRepository);
      expect(cubit.state, equals(AuthInitial()));
    });

    test(
      'login success should transition to AuthLoading then AuthAuthenticated',
      () async {
        final cubit = AuthCubit(fakeAuthRepository);
        final List<AuthState> states = [];
        cubit.stream.listen((state) => states.add(state));

        await cubit.login('test@example.com', 'password');
        await pumpEventQueue();

        expect(states, [AuthLoading(), AuthAuthenticated(testUser)]);
      },
    );

    test(
      'login failure should transition to AuthLoading then AuthError',
      () async {
        fakeAuthRepository.shouldThrow = true;
        final cubit = AuthCubit(fakeAuthRepository);
        final List<AuthState> states = [];
        cubit.stream.listen((state) => states.add(state));

        await cubit.login('test@example.com', 'password');
        await pumpEventQueue();

        expect(states, [
          AuthLoading(),
          const AuthError('Exception: Invalid credentials'),
        ]);
      },
    );

    test('checkAuth should restore session if token exists', () async {
      fakeAuthRepository.savedToken = 'valid_token';
      final cubit = AuthCubit(fakeAuthRepository);
      final List<AuthState> states = [];
      cubit.stream.listen((state) => states.add(state));

      await cubit.checkAuth();
      await pumpEventQueue();

      expect(states, [AuthLoading(), AuthAuthenticated(testUser)]);
    });

    test(
      'checkAuth should emit AuthUnauthenticated if token is missing',
      () async {
        fakeAuthRepository.savedToken = null;
        final cubit = AuthCubit(fakeAuthRepository);
        final List<AuthState> states = [];
        cubit.stream.listen((state) => states.add(state));

        await cubit.checkAuth();
        await pumpEventQueue();

        expect(states, [AuthLoading(), AuthUnauthenticated()]);
      },
    );

    test(
      'logout should clear session and transition to AuthUnauthenticated',
      () async {
        final cubit = AuthCubit(fakeAuthRepository);
        final List<AuthState> states = [];
        cubit.stream.listen((state) => states.add(state));

        await cubit.logout();
        await pumpEventQueue();

        expect(states, [AuthLoading(), AuthUnauthenticated()]);
      },
    );
  });

  group('ProfileCubit Specialization Removal', () {
    test(
      'deleteProfile removes specialization and reloads empty profile list',
      () async {
        final repository = FakeProfileRepository()
          ..profiles = const [
            PlayerProfile(
              id: 'profile-1',
              userId: 'user-1',
              sport: 'football',
              skillLevel: 'advanced',
              sportId: 'sport-1',
              roleOrDiscipline: 'Striker',
            ),
          ];
        final cubit = ProfileCubit(repository);
        final List<ProfileState> states = [];
        cubit.stream.listen(states.add);

        final removed = await cubit.deleteProfile(
          profileId: 'profile-1',
          userId: 'user-1',
        );
        await pumpEventQueue();

        expect(removed, isTrue);
        expect(repository.deletedProfileId, 'profile-1');
        expect(states, [
          ProfileSubmitting(),
          ProfileSuccess(),
          ProfileLoading(),
          const ProfileLoaded([]),
        ]);
      },
    );

    test(
      'deleteProfile reports failure and keeps existing profile list',
      () async {
        final repository = FakeProfileRepository()
          ..shouldThrowOnDelete = true
          ..profiles = const [
            PlayerProfile(
              id: 'profile-1',
              userId: 'user-1',
              sport: 'football',
              skillLevel: 'advanced',
              sportId: 'sport-1',
              roleOrDiscipline: 'Striker',
            ),
          ];
        final cubit = ProfileCubit(repository);
        final List<ProfileState> states = [];
        cubit.stream.listen(states.add);

        final removed = await cubit.deleteProfile(
          profileId: 'profile-1',
          userId: 'user-1',
        );
        await pumpEventQueue();

        expect(removed, isFalse);
        expect(repository.profiles, hasLength(1));
        expect(states, [
          ProfileSubmitting(),
          const ProfileError('Exception: delete failed'),
        ]);
      },
    );
  });

  group('DropUploadCubit State Machine', () {
    late File tempVideo;

    setUp(() {
      tempVideo = File('${Directory.systemTemp.path}/forma_test_upload.mp4');
      tempVideo.writeAsBytesSync([1, 2, 3]);
    });

    tearDown(() {
      if (tempVideo.existsSync()) tempVideo.deleteSync();
    });

    test('Cloudinary success and backend success emits success Drop', () async {
      final repository = FakeDropRepository();
      final cubit = DropUploadCubit(repository);

      await cubit.uploadDrop(
        file: tempVideo,
        sportId: 'sport_1',
        visibility: 'public',
      );

      expect(repository.uploadCount, 1);
      expect(repository.publishCount, 1);
      expect(cubit.state, isA<DropUploadSuccess>());
    });

    test('Cloudinary timeout exits loading state with retry upload', () async {
      final repository = FakeDropRepository()
        ..uploadError = TimeoutException('timed out');
      final cubit = DropUploadCubit(repository);

      await cubit.uploadDrop(
        file: tempVideo,
        sportId: 'sport_1',
        visibility: 'public',
      );

      final state = cubit.state as DropUploadError;
      expect(
        state.message,
        'Upload timed out. Check your connection and try again.',
      );
      expect(state.retryAction, DropUploadRetryAction.upload);
      expect(repository.publishCount, 0);
    });

    test('malformed Cloudinary response does not publish Drop', () async {
      final repository = FakeDropRepository()
        ..cloudinaryResponse = {
          'asset_id': 'asset_123',
          'public_id': 'forma/skill_clips/drop_123',
        };
      final cubit = DropUploadCubit(repository);

      await cubit.uploadDrop(
        file: tempVideo,
        sportId: 'sport_1',
        visibility: 'public',
      );

      expect(cubit.state, isA<DropUploadError>());
      expect(repository.publishCount, 0);
    });

    test('retry publish does not upload video twice', () async {
      final repository = FakeDropRepository()
        ..publishError = Exception('server failed');
      final cubit = DropUploadCubit(repository);

      await cubit.uploadDrop(
        file: tempVideo,
        sportId: 'sport_1',
        visibility: 'public',
      );

      final failure = cubit.state as DropUploadError;
      expect(failure.retryAction, DropUploadRetryAction.publish);
      expect(repository.uploadCount, 1);
      expect(repository.publishCount, 1);

      repository.publishError = null;
      await cubit.retryPublish();

      expect(repository.uploadCount, 1);
      expect(repository.publishCount, 2);
      expect(cubit.state, isA<DropUploadSuccess>());
    });

    test('publish failure shows safe backend error', () async {
      final repository = FakeDropRepository()
        ..publishError = ValidationException(
          'Invalid request: sport_id: Sport not found',
          statusCode: 422,
          responseBody:
              '{"detail":"Invalid request: sport_id: Sport not found"}',
        );
      final cubit = DropUploadCubit(repository);

      await cubit.uploadDrop(
        file: tempVideo,
        sportId: 'missing_sport',
        visibility: 'public',
      );

      final failure = cubit.state as DropUploadError;
      expect(failure.retryAction, DropUploadRetryAction.publish);
      expect(failure.message, 'Invalid request: sport_id: Sport not found');
      expect(repository.uploadCount, 1);
      expect(repository.publishCount, 1);
    });
  });

  group('DropFeedCubit New Drop Insertion', () {
    test(
      'newly created public approved Drop clears sport filter and appears',
      () async {
        final repository = FakeDropRepository();
        final cubit = DropFeedCubit(repository);
        await cubit.loadInitial(sportId: 'different_sport');
        final drop = makeDropWith(sportId: 'sport_1');

        cubit.insertNewlyCreatedDrop(drop);

        expect(cubit.state.selectedSportId, isNull);
        expect(cubit.state.drops, [drop]);
      },
    );

    test('newly created private Drop is not inserted into public feed', () {
      final repository = FakeDropRepository();
      final cubit = DropFeedCubit(repository);
      final drop = makeDropWith(visibility: 'private');

      cubit.insertNewlyCreatedDrop(drop);

      expect(cubit.state.drops, isEmpty);
    });
  });
}
