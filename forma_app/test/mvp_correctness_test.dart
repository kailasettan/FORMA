import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:forma/data/api_client.dart';
import 'package:forma/data/models/match_stat_model.dart';
import 'package:forma/data/repositories/auth_repository_impl.dart';
import 'package:forma/presentation/cubits/auth_cubit.dart';
import 'package:forma/presentation/cubits/stats_cubit.dart';
import 'package:forma/presentation/screens/auth/login_screen.dart';
import 'package:forma/presentation/screens/stats/match_stat_form_screen.dart';
import 'package:forma/domain/repositories/stats_repository.dart';
import 'package:forma/domain/repositories/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:forma/domain/entities/signup_result.dart';
import 'package:forma/domain/entities/user.dart';
import 'package:forma/domain/entities/match_stat.dart';
import 'package:forma/domain/entities/aggregated_stats.dart';

// Reuse FakeSecureStorage from api_client_test
class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

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
    return _storage[key];
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
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    _storage.remove(key);
  }
}

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    final bodyBytes = response.bodyBytes;
    return http.StreamedResponse(
      Stream.value(bodyBytes),
      response.statusCode,
      contentLength: bodyBytes.length,
      headers: response.headers,
      request: request,
    );
  }
}

class FakeStatsRepository implements StatsRepository {
  int fetchCallCount = 0;
  int aggregateCallCount = 0;
  int addCallCount = 0;
  int deleteCallCount = 0;

  @override
  Future<List<MatchStat>> fetchMatchStats(String userId) async {
    fetchCallCount++;
    return [];
  }

  @override
  Future<MatchStat> createMatchStat({
    required String sport,
    required DateTime date,
    required String opponent,
    required Map<String, int> stats,
  }) async {
    addCallCount++;
    return MatchStat(
      id: 'stat_123',
      userId: 'user_123',
      sport: sport,
      date: date,
      opponent: opponent,
      stats: stats,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteMatchStat(String statId) async {
    deleteCallCount++;
  }

  @override
  Future<AggregatedStats> fetchAggregatedStats(
    String userId,
    String sport,
  ) async {
    aggregateCallCount++;
    return const AggregatedStats(matchesPlayed: 0, stats: {});
  }
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<User> login({
    required String identifier,
    required String password,
  }) async {
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
    throw UnimplementedError();
  }

  @override
  Future<User?> checkAuth() async => null;

  @override
  Future<void> healthCheck() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> verifyOtp({required String email, required String otp}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> resendOtp({required String email}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<void> resendPasswordResetOtp({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {}
}

void main() {
  group('MVP Correctness Tests', () {
    late FakeSecureStorage fakeSecureStorage;
    late User testUser;

    setUp(() {
      fakeSecureStorage = FakeSecureStorage();
      testUser = User(
        id: 'user_123',
        username: 'testuser',
        email: 'test@example.com',
        fullName: 'Test User',
        createdAt: DateTime.parse('2026-07-02T12:00:00Z'),
      );
    });

    test(
      '401 response deletes the token from secure storage during checkAuth',
      () async {
        await fakeSecureStorage.write(
          key: ApiClient.tokenKey,
          value: 'expired_jwt_token',
        );

        final mockClient = MockHttpClient((request) async {
          return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
        });

        final apiClient = ApiClient(
          client: mockClient,
          secureStorage: fakeSecureStorage,
        );
        final authRepository = AuthRepositoryImpl(apiClient);

        final userResult = await authRepository.checkAuth();

        expect(userResult, isNull);
        final storedToken = await fakeSecureStorage.read(
          key: ApiClient.tokenKey,
        );
        expect(storedToken, isNull);
      },
    );

    test('session restoration success returns User', () async {
      await fakeSecureStorage.write(
        key: ApiClient.tokenKey,
        value: 'valid_jwt_token',
      );

      final mockClient = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 'user_123',
            'username': 'testuser',
            'email': 'test@example.com',
            'full_name': 'Test User',
            'age': null,
            'city': null,
            'profile_photo_url': null,
            'created_at': '2026-07-02T12:00:00Z',
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        client: mockClient,
        secureStorage: fakeSecureStorage,
      );
      final authRepository = AuthRepositoryImpl(apiClient);

      final userResult = await authRepository.checkAuth();

      expect(userResult, isNotNull);
      expect(userResult!.username, 'testuser');
      final storedToken = await fakeSecureStorage.read(key: ApiClient.tokenKey);
      expect(storedToken, 'valid_jwt_token');
    });

    test('session restoration failure clears token and returns null', () async {
      await fakeSecureStorage.write(
        key: ApiClient.tokenKey,
        value: 'invalid_jwt_token',
      );

      final mockClient = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Invalid token signature'}),
          403,
        );
      });

      final apiClient = ApiClient(
        client: mockClient,
        secureStorage: fakeSecureStorage,
      );
      final authRepository = AuthRepositoryImpl(apiClient);

      final userResult = await authRepository.checkAuth();

      expect(userResult, isNull);
      final storedToken = await fakeSecureStorage.read(key: ApiClient.tokenKey);
      expect(storedToken, isNull);
    });

    test('YYYY-MM-DD date serialization in MatchStatModel', () {
      final matchStat = MatchStatModel(
        id: '123',
        userId: '456',
        sport: 'football',
        date: DateTime(2026, 7, 2),
        opponent: 'Real Madrid',
        stats: const {'goals': 2, 'assists': 1},
        createdAt: DateTime.now(),
      );

      final json = matchStat.toJson();
      expect(json['date'], '2026-07-02');
    });

    test('aggregate refresh after add or delete at Cubit level', () async {
      final fakeStatsRepo = FakeStatsRepository();
      final statsCubit = StatsCubit(fakeStatsRepo);

      // Verify initial counts
      expect(fakeStatsRepo.fetchCallCount, 0);
      expect(fakeStatsRepo.aggregateCallCount, 0);

      // Execute addMatchStat
      await statsCubit.addMatchStat(
        sport: 'football',
        date: DateTime.now(),
        opponent: 'Opponent',
        stats: const {'goals': 1},
        userId: 'user_123',
      );

      // Verify that after add, stats list and aggregation are refreshed
      expect(fakeStatsRepo.addCallCount, 1);
      expect(fakeStatsRepo.fetchCallCount, 1);
      expect(fakeStatsRepo.aggregateCallCount, 1);

      // Execute deleteMatchStat
      await statsCubit.deleteMatchStat(
        statId: 'stat_123',
        userId: 'user_123',
        sport: 'football',
      );

      // Verify that after delete, stats list and aggregation are refreshed
      expect(fakeStatsRepo.deleteCallCount, 1);
      expect(fakeStatsRepo.fetchCallCount, 2);
      expect(fakeStatsRepo.aggregateCallCount, 2);
    });

    testWidgets(
      'duplicate login submission prevention (button disabled during load)',
      (tester) async {
        final authRepo = FakeAuthRepository();
        final authCubit = AuthCubit(authRepo);

        // Transition cubit to AuthLoading state
        authCubit.emit(AuthLoading());

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<AuthCubit>.value(
              value: authCubit,
              child: const Scaffold(body: LoginScreen()),
            ),
          ),
        );

        // Verify that the login button is disabled (its onPressed is null)
        final loginBtnFinder = find.byType(ElevatedButton);
        expect(loginBtnFinder, findsOneWidget);
        final ElevatedButton loginBtn = tester.widget(loginBtnFinder);
        expect(
          loginBtn.onPressed,
          isNull,
        ); // Disabled because state is AuthLoading
      },
    );

    testWidgets(
      'duplicate match submission prevention (button disabled during submit)',
      (tester) async {
        final statsRepo = FakeStatsRepository();
        final statsCubit = StatsCubit(statsRepo);
        final authRepo = FakeAuthRepository();
        final authCubit = AuthCubit(authRepo);

        authCubit.emit(AuthAuthenticated(testUser));
        // Transition cubit to StatsSubmitting state
        statsCubit.emit(StatsSubmitting());

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider<AuthCubit>.value(value: authCubit),
                BlocProvider<StatsCubit>.value(value: statsCubit),
              ],
              child: const Scaffold(body: MatchStatFormScreen()),
            ),
          ),
        );

        // Verify that the submit button is disabled (its onPressed is null)
        final submitBtnFinder = find.byType(ElevatedButton);
        expect(submitBtnFinder, findsOneWidget);
        final ElevatedButton submitBtn = tester.widget(submitBtnFinder);
        expect(
          submitBtn.onPressed,
          isNull,
        ); // Disabled because state is StatsSubmitting
      },
    );

    testWidgets('invalid negative football values rejected by validator', (
      tester,
    ) async {
      final statsRepo = FakeStatsRepository();
      final statsCubit = StatsCubit(statsRepo);
      final authRepo = FakeAuthRepository();
      final authCubit = AuthCubit(authRepo);

      authCubit.emit(AuthAuthenticated(testUser));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthCubit>.value(value: authCubit),
              BlocProvider<StatsCubit>.value(value: statsCubit),
            ],
            child: const Scaffold(body: MatchStatFormScreen()),
          ),
        ),
      );

      // Find the goals input field and type a negative value
      final goalsFinder = find.widgetWithText(TextFormField, 'Goals Scored');
      expect(goalsFinder, findsOneWidget);

      // Access the TextFormField's state and validate a negative value
      final TextFormField textFormField = tester.widget(goalsFinder);
      final validator = textFormField.validator;
      expect(validator, isNotNull);

      final validationResult = validator!('-5');
      expect(validationResult, 'Cannot be negative');
    });
  });
}
