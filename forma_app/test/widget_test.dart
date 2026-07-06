import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma/main.dart';
import 'package:forma/domain/entities/user.dart';
import 'package:forma/domain/entities/sport.dart';
import 'package:forma/domain/entities/sport_category.dart';
import 'package:forma/domain/entities/drop.dart';
import 'package:forma/domain/entities/drop_comment.dart';
import 'package:forma/domain/entities/scout_shortlist.dart';
import 'package:forma/domain/entities/public_athlete_profile.dart';
import 'package:forma/domain/repositories/auth_repository.dart';
import 'package:forma/domain/repositories/profile_repository.dart';
import 'package:forma/domain/repositories/stats_repository.dart';
import 'package:forma/domain/repositories/catalog_repository.dart';
import 'package:forma/domain/repositories/drop_repository.dart';
import 'package:forma/domain/repositories/scout_repository.dart';
import 'package:forma/domain/entities/player_profile.dart';
import 'package:forma/domain/entities/match_stat.dart';
import 'package:forma/domain/entities/aggregated_stats.dart';
import 'package:forma/presentation/cubits/auth_cubit.dart';
import 'package:forma/presentation/cubits/catalog_cubit.dart';
import 'package:forma/presentation/cubits/profile_cubit.dart';
import 'package:forma/presentation/screens/auth/signup_screen.dart';
import 'package:forma/presentation/screens/profile/edit_profile_screen.dart';
import 'package:forma/presentation/screens/profile/profile_form_screen.dart';
import 'dart:io';

class FakeAuthRepository implements AuthRepository {
  String? lastSignupRole;
  String? lastSignupUsername;
  String? lastSignupEmail;
  String? lastSignupFullName;

  @override
  Future<User> login({required String email, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<User> signUp({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String role = 'athlete',
  }) async {
    lastSignupRole = role;
    lastSignupUsername = username;
    lastSignupEmail = email;
    lastSignupFullName = fullName;
    return User(
      id: 'signup-user',
      username: username,
      email: email,
      fullName: fullName,
      role: role,
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<User?> checkAuth() async => null;

  @override
  Future<void> healthCheck() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<String?> getToken() async => null;
}

class FakeProfileRepository implements ProfileRepository {
  String? lastFocusedSportId;
  String? lastProfilePhotoUrl;

  @override
  Future<List<PlayerProfile>> fetchPlayerProfiles(String userId) async => [];

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
  Future<void> deletePlayerProfile(String profileId) async {}

  @override
  Future<Map<String, dynamic>> getProfilePhotoUploadSignature() async => {
    'signature': 'sig',
    'timestamp': 1,
    'api_key': 'key',
    'upload_preset': 'forma_profile_photos',
    'folder': 'forma/profile_photos',
    'overwrite': 'false',
    'unique_filename': 'true',
    'cloud_name': 'demo',
  };

  @override
  Future<Map<String, dynamic>> uploadProfilePhotoToCloudinary({
    required File file,
    required Map<String, dynamic> signatureData,
  }) async => {
    'asset_id': 'asset-profile',
    'public_id': 'forma/profile_photos/profile_1',
    'resource_type': 'image',
    'secure_url': 'https://res.cloudinary.com/demo/image/upload/profile_1.jpg',
    'format': 'jpg',
  };

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
    lastFocusedSportId = focusedSportId;
    lastProfilePhotoUrl = profilePhotoUrl;
    return User(
      id: 'user-1',
      username: username ?? 'athlete',
      email: 'athlete@example.com',
      fullName: fullName ?? 'Athlete One',
      role: 'athlete',
      createdAt: DateTime(2026),
      focusedSportId: focusedSportId,
    );
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
  Future<List<User>> searchAthletes(String query) async => [];
}

class FakeStatsRepository implements StatsRepository {
  @override
  Future<List<MatchStat>> fetchMatchStats(String userId) async => [];

  @override
  Future<MatchStat> createMatchStat({
    required String sport,
    required DateTime date,
    required String opponent,
    required Map<String, int> stats,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMatchStat(String statId) async {}

  @override
  Future<AggregatedStats> fetchAggregatedStats(
    String userId,
    String sport,
  ) async {
    return const AggregatedStats(matchesPlayed: 0, stats: {});
  }
}

class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({this.sports = const []});

  final List<Sport> sports;

  @override
  Future<List<Sport>> getSports() async => sports;

  @override
  Future<List<SportCategory>> getCategories(String sportId) async => [];
}

class FakeDropRepository implements DropRepository {
  @override
  Future<Map<String, dynamic>> getUploadSignature() async => {};

  @override
  Future<Map<String, dynamic>> uploadToCloudinary({
    required File file,
    required Map<String, dynamic> signatureData,
    required Function(double progress) onProgress,
  }) async => {};

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
    throw UnimplementedError();
  }

  @override
  Future<List<Drop>> getUserDrops(String userId) async => [];

  @override
  Future<DropFeedPage> getDropsFeed({
    String? cursor,
    int limit = 10,
    String? sportId,
  }) async {
    return const DropFeedPage(items: []);
  }

  @override
  Future<Drop> getDropDetails(String dropId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteDrop(String dropId) async {}

  @override
  Future<void> giveProps(String dropId) async {}

  @override
  Future<void> removeProps(String dropId) async {}

  @override
  Future<List<DropComment>> getComments(String dropId) async => [];

  @override
  Future<DropComment> postComment(String dropId, String body) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteComment(String dropId, String commentId) async {}
}

class FakeScoutRepository implements ScoutRepository {
  @override
  Future<ScoutShortlist> shortlistAthlete({
    required String athleteUserId,
    String? dropId,
    String? privateNote,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> removeShortlist(String athleteUserId) async {}

  @override
  Future<List<ScoutShortlist>> getShortlist() async => [];
}

void main() {
  final football = Sport(
    id: 'sport-1',
    name: 'Football',
    slug: 'football',
    isActive: true,
    createdAt: DateTime(2026),
  );

  testWidgets('renders FORMA login shell on startup when unauthenticated', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();
    final profileRepo = FakeProfileRepository();
    final statsRepo = FakeStatsRepository();
    final catalogRepo = FakeCatalogRepository();
    final dropRepo = FakeDropRepository();
    final scoutRepo = FakeScoutRepository();

    await tester.pumpWidget(
      FormaApp(
        authRepository: authRepo,
        profileRepository: profileRepo,
        statsRepository: statsRepo,
        catalogRepository: catalogRepo,
        dropRepository: dropRepo,
        scoutRepository: scoutRepo,
      ),
    );

    expect(find.text('FORMA'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text('FORMA'), findsOneWidget);
  });

  testWidgets('signup screen hides Athlete and Scout role choices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthCubit(FakeAuthRepository()),
          child: const SignupScreen(),
        ),
      ),
    );

    expect(find.text('I want to join as'), findsNothing);
    expect(find.text('ATHLETE'), findsNothing);
    expect(find.text('SCOUT'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('signup submits successfully with default athlete role', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/dashboard': (_) => const Scaffold(body: Text('Dashboard'))},
        home: BlocProvider(
          create: (_) => AuthCubit(authRepo),
          child: const SignupScreen(),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full Name'),
      'Beta User',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'betauser',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Address'),
      'beta@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(authRepo.lastSignupRole, 'athlete');
    expect(authRepo.lastSignupUsername, 'betauser');
    expect(authRepo.lastSignupEmail, 'beta@example.com');
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('edit profile opens with stale focused sport id', (
    WidgetTester tester,
  ) async {
    final profileRepo = FakeProfileRepository();
    final user = User(
      id: 'user-1',
      username: 'athlete',
      email: 'athlete@example.com',
      fullName: 'Athlete One',
      role: 'athlete',
      focusedSportId: 'missing-sport-id',
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<ProfileRepository>.value(
          value: profileRepo,
          child: BlocProvider(
            create: (_) =>
                CatalogCubit(FakeCatalogRepository(sports: [football])),
            child: EditProfileScreen(user: user),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Focused Sport'), findsOneWidget);
    expect(find.text('Profile Photo URL'), findsNothing);
    expect(find.text('Change photo'), findsOneWidget);
  });

  testWidgets('edit profile dedupes duplicate focused sport item values', (
    WidgetTester tester,
  ) async {
    final duplicateFootball = Sport(
      id: football.id,
      name: 'Football Duplicate',
      slug: 'football-duplicate',
      isActive: true,
      createdAt: DateTime(2026),
    );
    final user = User(
      id: 'user-1',
      username: 'athlete',
      email: 'athlete@example.com',
      fullName: 'Athlete One',
      role: 'athlete',
      focusedSportId: football.id,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<ProfileRepository>.value(
          value: FakeProfileRepository(),
          child: BlocProvider(
            create: (_) => CatalogCubit(
              FakeCatalogRepository(sports: [football, duplicateFootball]),
            ),
            child: EditProfileScreen(user: user),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('FOOTBALL'), findsOneWidget);
  });

  testWidgets('specialization form opens with empty catalog and stale skill', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();
    final profileRepo = FakeProfileRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => AuthCubit(authRepo)),
            BlocProvider(create: (_) => ProfileCubit(profileRepo)),
            BlocProvider(create: (_) => CatalogCubit(FakeCatalogRepository())),
          ],
          child: const ProfileFormScreen(
            profile: PlayerProfile(
              id: 'profile-1',
              userId: 'user-1',
              sport: 'missing',
              sportId: 'missing-sport-id',
              skillLevel: 'expert',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Skill Level'), findsOneWidget);
  });
}
