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
import 'package:forma/presentation/screens/auth/login_screen.dart';
import 'package:forma/presentation/screens/auth/otp_screen.dart';
import 'package:forma/presentation/screens/auth/forgot_password_screen.dart';
import 'package:forma/presentation/screens/auth/reset_password_screen.dart';
import 'package:forma/presentation/screens/dashboard_screen.dart';
import 'package:forma/presentation/screens/profile/edit_profile_screen.dart';
import 'package:forma/presentation/screens/profile/profile_form_screen.dart';
import 'dart:io';

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
        apiClient: ApiClient(),
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
        FormaApp(
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
      find.widgetWithText(TextFormField, 'Email Address'),
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
      FormaApp(
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
      FormaApp(
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
      FormaApp(
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
}
