import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma/main.dart';
import 'package:forma/data/api_client.dart';
import 'package:forma/domain/entities/user.dart';
import 'package:forma/domain/entities/sport.dart';
import 'package:forma/domain/entities/sport_category.dart';
import 'package:forma/domain/entities/drop.dart';
import 'package:forma/domain/entities/drop_comment.dart';
import 'package:forma/domain/entities/scout_shortlist.dart';
import 'package:forma/domain/entities/public_athlete_profile.dart';
import 'package:forma/domain/entities/signup_result.dart';
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
import 'package:forma/presentation/cubits/theme_cubit.dart';
import 'package:forma/presentation/screens/auth/signup_screen.dart';
import 'package:forma/presentation/screens/auth/login_screen.dart';
import 'package:forma/presentation/screens/auth/otp_screen.dart';
import 'package:forma/presentation/screens/auth/forgot_password_screen.dart';
import 'package:forma/presentation/screens/auth/reset_password_screen.dart';
import 'package:forma/presentation/screens/dashboard_screen.dart';
import 'package:forma/presentation/screens/profile/edit_profile_screen.dart';
import 'package:forma/presentation/screens/profile/profile_form_screen.dart';
import 'package:forma/presentation/screens/settings/settings_screen.dart';
import 'package:forma/presentation/cubits/drop_feed_cubit.dart';
import 'package:forma/presentation/screens/drops/drops_feed_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthRepository implements AuthRepository {
  String? lastSignupRole;
  String? lastSignupUsername;
  String? lastSignupEmail;
  String? lastSignupFullName;
  User? checkAuthUser;
  bool loggedOut = false;
  String? lastVerifiedEmail;
  String? lastVerifiedOtp;
  String? lastResentEmail;
  String? lastForgotPasswordEmail;
  String? lastResetEmail;
  String? lastResetOtp;
  String? lastNewPassword;
  String? lastConfirmPassword;

  String? lastLoginIdentifier;
  String? lastLoginPassword;
  bool signupVerificationRequired = true;

  @override
  Future<User> login({
    required String identifier,
    required String password,
  }) async {
    lastLoginIdentifier = identifier;
    lastLoginPassword = password;
    throw UnimplementedError();
  }

  @override
  Future<SignupResult> signUp({
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
    final user = User(
      id: 'signup-user',
      username: username,
      email: email,
      fullName: fullName,
      role: role,
      emailVerified: !signupVerificationRequired,
      createdAt: DateTime(2026),
    );
    return SignupResult(
      user: user,
      verificationRequired: signupVerificationRequired,
    );
  }

  @override
  Future<User?> checkAuth() async => checkAuthUser;

  @override
  Future<void> healthCheck() async {}

  @override
  Future<void> logout() async {
    loggedOut = true;
  }

  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> verifyOtp({required String email, required String otp}) async {
    lastVerifiedEmail = email;
    lastVerifiedOtp = otp;
  }

  @override
  Future<void> resendOtp({required String email}) async {
    lastResentEmail = email;
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    lastForgotPasswordEmail = email;
  }

  @override
  Future<void> resendPasswordResetOtp({required String email}) async {
    lastResentEmail = email;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    lastResetEmail = email;
    lastResetOtp = otp;
    lastNewPassword = newPassword;
    lastConfirmPassword = confirmPassword;
  }

  bool deleteAccountCalled = false;
  String? lastDeleteAccountPassword;

  @override
  Future<void> deleteAccount({required String password}) async {
    deleteAccountCalled = true;
    lastDeleteAccountPassword = password;
  }
}

class FakeProfileRepository implements ProfileRepository {
  String? lastFocusedSportId;
  String? lastProfilePhotoUrl;
  String? lastUsername;
  String? lastFullName;
  String? lastBio;
  String? lastLocation;

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
    lastUsername = username;
    lastFullName = fullName;
    lastBio = bio;
    lastLocation = location;
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
    required XFile file,
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
    String? sportId,
    String? categoryId,
    String? caption,
    String visibility = 'public',
    String? audience,
    String? location,
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
  testWidgets('renders GETSA login shell on startup when unauthenticated', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();
    final profileRepo = FakeProfileRepository();
    final statsRepo = FakeStatsRepository();
    final catalogRepo = FakeCatalogRepository();
    final dropRepo = FakeDropRepository();
    final scoutRepo = FakeScoutRepository();

    await tester.pumpWidget(
      GetsaApp(
        apiClient: ApiClient(),
        authRepository: authRepo,
        profileRepository: profileRepo,
        statsRepository: statsRepo,
        catalogRepository: catalogRepo,
        dropRepository: dropRepo,
        scoutRepository: scoutRepo,
      ),
    );

    expect(find.text('GETSA'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text('GETSA'), findsOneWidget);
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
        routes: {
          '/otp-verification': (_) => const Scaffold(body: Text('OTP Screen')),
        },
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
      '  betauser  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Address'),
      '  Beta@Example.com  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'password123',
    );
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(authRepo.lastSignupRole, 'athlete');
    expect(authRepo.lastSignupUsername, 'betauser');
    expect(authRepo.lastSignupEmail, 'beta@example.com');
    expect(find.text('OTP Screen'), findsOneWidget);
  });

  testWidgets('signup skips OTP screen when verification is not required', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository()..signupVerificationRequired = false;

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/dashboard': (_) => const Scaffold(body: Text('Dashboard Screen')),
          '/otp-verification': (_) => const Scaffold(body: Text('OTP Screen')),
        },
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
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'password123',
    );

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(authRepo.lastSignupUsername, 'betauser');
    expect(find.text('Dashboard Screen'), findsOneWidget);
    expect(find.text('OTP Screen'), findsNothing);
  });

  testWidgets('signup lowercases and removes username spaces', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/otp-verification': (_) => const Scaffold(body: Text('OTP Screen')),
        },
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
      'Kai Las 07',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Address'),
      'beta@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'password123',
    );

    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Username'))
          .controller!
          .text,
      'kailas07',
    );

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(authRepo.lastSignupUsername, 'kailas07');
    expect(find.text('OTP Screen'), findsOneWidget);
  });

  testWidgets('signup rejects invalid username before submit', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
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
      '.kailas',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Address'),
      'beta@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'password123',
    );

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(authRepo.lastSignupUsername, isNull);
    expect(
      find.text(
        'Username can only use lowercase letters, numbers, dots, and underscores.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'edit profile renders simplified social-only fields and updates',
    (WidgetTester tester) async {
      final profileRepo = FakeProfileRepository();
      final user = User(
        id: 'user-1',
        username: 'athlete',
        email: 'athlete@example.com',
        fullName: 'Athlete One',
        role: 'athlete',
        focusedSportId: 'missing-sport-id',
        createdAt: DateTime(2026),
        headline: 'Old Headline',
        availability: 'Open to trials',
        bio: 'Old Bio',
        location: 'Old Location',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<ProfileRepository>.value(
            value: profileRepo,
            child: MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => AuthCubit(FakeAuthRepository())),
                BlocProvider(
                  create: (_) => CatalogCubit(FakeCatalogRepository()),
                ),
              ],
              child: EditProfileScreen(user: user),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);

      // Check social fields are present
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Bio'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Change photo'), findsOneWidget);

      // Check sports fields are NOT present
      expect(find.text('Focused Sport'), findsNothing);
      expect(find.text('Availability Status'), findsNothing);
      expect(
        find.text('Preferred Opportunities (comma separated)'),
        findsNothing,
      );
      expect(
        find.text('Headline (e.g. Badminton Singles Player)'),
        findsNothing,
      );

      // Verify fields contain existing user values
      expect(find.widgetWithText(TextFormField, 'Athlete One'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'athlete'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Old Bio'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Old Location'),
        findsOneWidget,
      );

      // Make edits and save
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Athlete One'),
        'New Name',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'athlete'),
        'newusername',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Old Bio'),
        'New Bio',
      );
      await tester.ensureVisible(find.text('SAVE PROFILE'));
      await tester.tap(find.text('SAVE PROFILE'));
      await tester.pump();

      // Verify updateMe was called on repository
      expect(profileRepo.lastFullName, 'New Name');
      expect(profileRepo.lastUsername, 'newusername');
      expect(profileRepo.lastBio, 'New Bio');
    },
  );

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

  testWidgets(
    'logged-in user logs out, auth state becomes unauthenticated, login screen is shown',
    (WidgetTester tester) async {
      final authRepo = FakeAuthRepository();
      // Simulate authenticated state initially
      authRepo.checkAuthUser = User(
        id: 'user-123',
        username: 'testuser',
        email: 'test@example.com',
        fullName: 'Test User',
        role: 'athlete',
        createdAt: DateTime(2026),
        emailVerified: true,
      );

      final profileRepo = FakeProfileRepository();
      final statsRepo = FakeStatsRepository();
      final catalogRepo = FakeCatalogRepository();
      final dropRepo = FakeDropRepository();
      final scoutRepo = FakeScoutRepository();

      await tester.pumpWidget(
        GetsaApp(
          apiClient: ApiClient(),
          authRepository: authRepo,
          profileRepository: profileRepo,
          statsRepository: statsRepo,
          catalogRepository: catalogRepo,
          dropRepository: dropRepo,
          scoutRepository: scoutRepo,
        ),
      );

      // Initial load: splash screen is shown
      await tester.pump();
      // Finish splash onComplete delay (3 seconds in SplashScreen)
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Confirm that the auth state became authenticated and AuthGate rendered the Dashboard
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      // Get the AuthCubit from the context and call logout
      final authCubit = tester
          .element(find.byType(DashboardScreen))
          .read<AuthCubit>();
      await authCubit.logout();
      await tester.pumpAndSettle();

      // Verify that checkAuth / logout was called on the repo, and the screen transitioned to LoginScreen
      expect(authRepo.loggedOut, isTrue);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets('signup rejects weak password', (WidgetTester tester) async {
    final authRepo = FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthCubit(authRepo),
          child: const SignupScreen(),
        ),
      ),
    );

    // Enter a weak password (no numbers)
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
      'weakpass',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'weakpass',
    );

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    // Verify repository was not called
    expect(authRepo.lastSignupUsername, isNull);
    // Verify validation error message is shown
    expect(
      find.text(
        'Password must be at least 8 characters and include a letter and a number.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('signup rejects confirm password mismatch', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
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
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'different123',
    );

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    // Verify repository was not called
    expect(authRepo.lastSignupUsername, isNull);
    // Verify validation error message is shown
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('password visibility toggle works', (WidgetTester tester) async {
    final authRepo = FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthCubit(authRepo),
          child: const LoginScreen(),
        ),
      ),
    );

    final passwordFieldFinder = find.widgetWithText(TextFormField, 'Password');
    final passwordTextFieldFinder = find.descendant(
      of: passwordFieldFinder,
      matching: find.byType(TextField),
    );
    TextField passwordTextField = tester.widget<TextField>(
      passwordTextFieldFinder,
    );
    expect(passwordTextField.obscureText, isTrue);

    // Tap visibility toggle suffix icon
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    passwordTextField = tester.widget<TextField>(passwordTextFieldFinder);
    expect(passwordTextField.obscureText, isFalse);
  });

  testWidgets('login and signup buttons disabled while loading', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();
    final cubit = AuthCubit(authRepo);
    cubit.emit(AuthLoading());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const LoginScreen()),
      ),
    );
    await tester.pump();

    final loginButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(loginButton.onPressed, isNull);

    // Now test signup screen
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const SignupScreen()),
      ),
    );
    await tester.pump();

    final signupButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(signupButton.onPressed, isNull);
  });

  testWidgets('keyboard submit triggers login', (WidgetTester tester) async {
    final authRepo = FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthCubit(authRepo),
          child: const LoginScreen(),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or username'),
      'test@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );

    final passwordFieldFinder = find.widgetWithText(TextFormField, 'Password');
    final textField = tester.widget<TextField>(
      find.descendant(
        of: passwordFieldFinder,
        matching: find.byType(TextField),
      ),
    );
    textField.onSubmitted?.call('password123');
    await tester.pumpAndSettle();

    final authCubit = tester
        .element(find.byType(LoginScreen))
        .read<AuthCubit>();
    expect(authCubit.state, isA<AuthError>());
  });

  testWidgets('app clears expired session and redirects to login', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();
    authRepo.checkAuthUser = User(
      id: 'user-123',
      username: 'testuser',
      email: 'test@example.com',
      fullName: 'Test User',
      role: 'athlete',
      createdAt: DateTime(2026),
      emailVerified: true,
    );

    final profileRepo = FakeProfileRepository();
    final statsRepo = FakeStatsRepository();
    final catalogRepo = FakeCatalogRepository();
    final dropRepo = FakeDropRepository();
    final scoutRepo = FakeScoutRepository();

    final apiClient = ApiClient();

    await tester.pumpWidget(
      GetsaApp(
        apiClient: apiClient,
        authRepository: authRepo,
        profileRepository: profileRepo,
        statsRepository: statsRepo,
        catalogRepository: catalogRepo,
        dropRepository: dropRepo,
        scoutRepository: scoutRepo,
      ),
    );

    // Initial load: splash screen
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(DashboardScreen), findsOneWidget);

    // Simulate session expired call on apiClient
    apiClient.onSessionExpired?.call();
    await tester.pumpAndSettle();

    // Verify redirected to LoginScreen and show friendly session expired message
    expect(find.byType(DashboardScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Session expired. Please log in again.'), findsOneWidget);
  });

  testWidgets('OtpScreen renders and handles submit and resend', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<AuthRepository>.value(
          value: authRepo,
          child: BlocProvider(
            create: (_) => AuthCubit(authRepo),
            child: const OtpScreen(email: 'test@example.com'),
          ),
        ),
      ),
    );

    expect(find.text('Verify Email'), findsOneWidget);
    expect(find.textContaining('test@example.com'), findsOneWidget);
    expect(find.text('VERIFY EMAIL'), findsOneWidget);
    expect(find.textContaining('Resend in 60s'), findsOneWidget);

    // Enter invalid short code
    await tester.enterText(find.byType(TextFormField), '123');
    await tester.tap(find.text('VERIFY EMAIL'));
    await tester.pump();
    expect(find.text('Verification code must be 6 digits'), findsOneWidget);

    // Enter correct length code
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('VERIFY EMAIL'));
    await tester.pump();

    expect(authRepo.lastVerifiedEmail, 'test@example.com');
    expect(authRepo.lastVerifiedOtp, '123456');
  });

  testWidgets('ForgotPasswordScreen submits email and opens reset screen', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/reset-password': (_) =>
              const Scaffold(body: Text('Reset Password Route')),
        },
        home: BlocProvider(
          create: (_) => AuthCubit(authRepo),
          child: const ForgotPasswordScreen(),
        ),
      ),
    );

    expect(find.text('Forgot Password'), findsOneWidget);
    expect(find.text('SEND RESET CODE'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Address'),
      '  Reset@Example.com  ',
    );
    await tester.tap(find.text('SEND RESET CODE'));
    await tester.pumpAndSettle();

    expect(authRepo.lastForgotPasswordEmail, 'reset@example.com');
    expect(find.text('Reset Password Route'), findsOneWidget);
  });

  testWidgets('ResetPasswordScreen validates and submits reset password', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/login': (_) => const Scaffold(body: Text('Login Route'))},
        home: RepositoryProvider<AuthRepository>.value(
          value: authRepo,
          child: BlocProvider(
            create: (_) => AuthCubit(authRepo),
            child: const ResetPasswordScreen(email: 'reset@example.com'),
          ),
        ),
      ),
    );

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.textContaining('reset@example.com'), findsOneWidget);
    expect(find.text('RESET PASSWORD'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'New Password'),
      'weakpass',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'weakpass',
    );
    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.tap(find.text('RESET PASSWORD'));
    await tester.pump();
    expect(
      find.text(
        'Password must be at least 8 characters and include a letter and a number.',
      ),
      findsOneWidget,
    );
    expect(authRepo.lastResetEmail, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'New Password'),
      'newpass123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'different123',
    );
    await tester.tap(find.text('RESET PASSWORD'));
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(authRepo.lastResetEmail, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'newpass123',
    );
    await tester.tap(find.text('RESET PASSWORD'));
    await tester.pumpAndSettle();

    expect(authRepo.lastResetEmail, 'reset@example.com');
    expect(authRepo.lastResetOtp, '123456');
    expect(authRepo.lastNewPassword, 'newpass123');
    expect(authRepo.lastConfirmPassword, 'newpass123');
    expect(find.text('Login Route'), findsOneWidget);
  });

  testWidgets('unverified authenticated user is sent to OtpScreen', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();
    authRepo.checkAuthUser = User(
      id: 'user-123',
      username: 'testuser',
      email: 'test@example.com',
      fullName: 'Test User',
      role: 'athlete',
      createdAt: DateTime(2026),
      emailVerified: false,
    );

    final profileRepo = FakeProfileRepository();
    final statsRepo = FakeStatsRepository();
    final catalogRepo = FakeCatalogRepository();
    final dropRepo = FakeDropRepository();
    final scoutRepo = FakeScoutRepository();

    await tester.pumpWidget(
      GetsaApp(
        apiClient: ApiClient(),
        authRepository: authRepo,
        profileRepository: profileRepo,
        statsRepository: statsRepo,
        catalogRepository: catalogRepo,
        dropRepository: dropRepo,
        scoutRepository: scoutRepo,
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(OtpScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('verified authenticated user goes directly to DashboardScreen', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();
    authRepo.checkAuthUser = User(
      id: 'user-123',
      username: 'testuser',
      email: 'test@example.com',
      fullName: 'Test User',
      role: 'athlete',
      createdAt: DateTime(2026),
      emailVerified: true,
    );

    final profileRepo = FakeProfileRepository();
    final statsRepo = FakeStatsRepository();
    final catalogRepo = FakeCatalogRepository();
    final dropRepo = FakeDropRepository();
    final scoutRepo = FakeScoutRepository();

    await tester.pumpWidget(
      GetsaApp(
        apiClient: ApiClient(),
        authRepository: authRepo,
        profileRepository: profileRepo,
        statsRepository: statsRepo,
        catalogRepository: catalogRepo,
        dropRepository: dropRepo,
        scoutRepository: scoutRepo,
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(OtpScreen), findsNothing);
  });

  testWidgets('LoginScreen allows and validates email and username formats', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthCubit(authRepo),
          child: const LoginScreen(),
        ),
      ),
    );

    // Enter empty value
    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    expect(find.text('Please enter your email or username'), findsOneWidget);

    // Enter invalid email address
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or username'),
      'invalid_email@',
    );
    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    expect(find.text('Please enter a valid email address'), findsOneWidget);

    // Enter invalid short username
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or username'),
      'ab',
    );
    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    expect(find.text('Username must be at least 3 characters'), findsOneWidget);

    // Enter valid username
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or username'),
      '  MyUsername  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.text('LOG IN'));
    await tester.pump();

    // Verify identifier is trimmed and converted to lowercase
    expect(authRepo.lastLoginIdentifier, 'myusername');
  });

  testWidgets('SettingsScreen appearance switching and persistence', (
    WidgetTester tester,
  ) async {
    final storage = FakeSecureStorage();
    final themeCubit = ThemeCubit(secureStorage: storage);

    // Initial state should be system
    expect(themeCubit.state, ThemeMode.system);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ThemeCubit>.value(
          value: themeCubit,
          child: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify settings shows "Appearance"
    expect(find.text('Appearance'), findsWidgets);
    expect(find.text('System default'), findsOneWidget);

    // Open bottom sheet
    await tester.tap(find.text('Appearance').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify all three options exist in the sheet
    expect(find.text('System default'), findsWidgets);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    // Select Light theme
    await tester.tap(find.text('Light'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify ThemeCubit updated to Light
    expect(themeCubit.state, ThemeMode.light);

    // Verify persistent storage saved it
    expect(storage._data[ThemeCubit.themeKey], 'light');

    // Verify new ThemeCubit picks up the persisted choice
    final newCubit = ThemeCubit(secureStorage: storage);
    await tester.idle();
    expect(newCubit.state, ThemeMode.light);

    await themeCubit.close();
    await newCubit.close();
  });

  testWidgets('DropsFeedScreen triggers loadInitial on AuthAuthenticated', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();
    final dropRepo = FakeDropRepository();
    final catalogRepo = FakeCatalogRepository();

    final authCubit = AuthCubit(authRepo);
    final dropFeedCubit = DropFeedCubit(dropRepo);
    final catalogCubit = CatalogCubit(catalogRepo);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<DropFeedCubit>.value(value: dropFeedCubit),
          BlocProvider<CatalogCubit>.value(value: catalogCubit),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DropsFeedScreen(isActive: true)),
        ),
      ),
    );

    // Initial state: not authenticated, drops should not load
    await tester.pump();
    expect(dropFeedCubit.state.hasAttemptedLoad, isFalse);

    // Now emit AuthAuthenticated
    final testUser = User(
      id: 'user-123',
      username: 'testuser',
      email: 'test@example.com',
      fullName: 'Test User',
      role: 'athlete',
      createdAt: DateTime(2026),
      emailVerified: true,
    );
    authCubit.emit(AuthAuthenticated(testUser));
    await tester.pump();

    // Verify it triggered loadInitial
    expect(dropFeedCubit.state.hasAttemptedLoad, isTrue);

    await authCubit.close();
    await dropFeedCubit.close();
    await catalogCubit.close();
  });

  testWidgets('SettingsScreen delete account flow double confirmation', (
    WidgetTester tester,
  ) async {
    final authRepo = FakeAuthRepository();
    final authCubit = AuthCubit(authRepo);
    final themeCubit = ThemeCubit(secureStorage: FakeSecureStorage());

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<ThemeCubit>.value(value: themeCubit),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    // Verify Delete Account button is visible
    expect(find.text('Delete Account'), findsOneWidget);

    // Tap Delete Account
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    // Verify first dialog is shown
    expect(find.text('Delete account?'), findsOneWidget);
    expect(
      find.text(
        'This will permanently remove your access to Getsa and hide your profile. This action cannot be undone.',
      ),
      findsOneWidget,
    );

    // Tap Cancel in first dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsNothing);
    expect(authRepo.deleteAccountCalled, isFalse);

    // Tap Delete Account again to trigger second flow
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    // Tap Continue in first dialog
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify second dialog is shown
    expect(find.text('Are you absolutely sure?'), findsOneWidget);
    expect(
      find.text(
        'Your account will be disabled, your profile will be hidden, and you will be logged out.',
      ),
      findsOneWidget,
    );

    // Tap Cancel in second dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Are you absolutely sure?'), findsNothing);
    expect(authRepo.deleteAccountCalled, isFalse);

    // Tap Delete Account, Continue, then confirm in second dialog to open password confirmation dialog
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Delete Account').last,
    ); // The action button in the second dialog is 'Delete Account'
    await tester.pumpAndSettle();

    // Verify third dialog "Confirm Password" is shown
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(
      find.text('Enter your password to verify account deletion.'),
      findsOneWidget,
    );

    // Enter password and test cancel first
    await tester.enterText(find.byType(TextField), 'password123');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Password'), findsNothing);
    expect(authRepo.deleteAccountCalled, isFalse);

    // Open it again to perform successful deletion
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Account').last);
    await tester.pumpAndSettle();

    // Enter password
    await tester.enterText(find.byType(TextField), 'password123');

    // Test toggle visibility
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Tap Confirm to delete
    await tester.tap(find.text('Confirm'));
    await tester.pump();

    // Verify deleteAccountCalled is true and password is passed correctly
    expect(authRepo.deleteAccountCalled, isTrue);
    expect(authRepo.lastDeleteAccountPassword, 'password123');

    await authCubit.close();
    await themeCubit.close();
  });
}
