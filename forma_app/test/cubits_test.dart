import 'package:flutter_test/flutter_test.dart';
import 'package:forma/presentation/cubits/auth_cubit.dart';
import 'package:forma/domain/entities/user.dart';
import 'package:forma/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  User? mockUser;
  bool shouldThrow = false;
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
  Future<void> logout() async {
    savedToken = null;
  }

  @override
  Future<String?> getToken() async => savedToken;
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
}
