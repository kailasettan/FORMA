import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'data/api_client.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/profile_repository_impl.dart';
import 'data/repositories/stats_repository_impl.dart';
import 'data/repositories/catalog_repository_impl.dart';
import 'data/repositories/drop_repository_impl.dart';
import 'data/repositories/scout_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/profile_repository.dart';
import 'domain/repositories/stats_repository.dart';
import 'domain/repositories/catalog_repository.dart';
import 'domain/repositories/drop_repository.dart';
import 'domain/repositories/scout_repository.dart';
import 'presentation/cubits/auth_cubit.dart';
import 'presentation/cubits/profile_cubit.dart';
import 'presentation/cubits/stats_cubit.dart';
import 'presentation/cubits/catalog_cubit.dart';
import 'presentation/cubits/drop_cubit.dart';
import 'presentation/cubits/drop_upload_cubit.dart';
import 'presentation/cubits/comments_cubit.dart';
import 'presentation/cubits/public_profile_cubit.dart';
import 'presentation/cubits/user_search_cubit.dart';
import 'presentation/cubits/scout_shortlist_cubit.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/theme.dart';
import 'presentation/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final authRepository = AuthRepositoryImpl(apiClient);
  final profileRepository = ProfileRepositoryImpl(apiClient);
  final statsRepository = StatsRepositoryImpl(apiClient);
  final catalogRepository = CatalogRepositoryImpl(apiClient);
  final dropRepository = DropRepositoryImpl(apiClient);
  final scoutRepository = ScoutRepositoryImpl(apiClient);

  runApp(
    FormaApp(
      authRepository: authRepository,
      profileRepository: profileRepository,
      statsRepository: statsRepository,
      catalogRepository: catalogRepository,
      dropRepository: dropRepository,
      scoutRepository: scoutRepository,
    ),
  );
}

class FormaApp extends StatelessWidget {
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final StatsRepository statsRepository;
  final CatalogRepository catalogRepository;
  final DropRepository dropRepository;
  final ScoutRepository scoutRepository;

  const FormaApp({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.statsRepository,
    required this.catalogRepository,
    required this.dropRepository,
    required this.scoutRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<ProfileRepository>.value(value: profileRepository),
        RepositoryProvider<StatsRepository>.value(value: statsRepository),
        RepositoryProvider<CatalogRepository>.value(value: catalogRepository),
        RepositoryProvider<DropRepository>.value(value: dropRepository),
        RepositoryProvider<ScoutRepository>.value(value: scoutRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (context) => AuthCubit(authRepository),
          ),
          BlocProvider<ProfileCubit>(
            create: (context) => ProfileCubit(profileRepository),
          ),
          BlocProvider<StatsCubit>(
            create: (context) => StatsCubit(statsRepository),
          ),
          BlocProvider<CatalogCubit>(
            create: (context) => CatalogCubit(catalogRepository),
          ),
          BlocProvider<DropCubit>(
            create: (context) => DropCubit(dropRepository),
          ),
          BlocProvider<DropUploadCubit>(
            create: (context) => DropUploadCubit(dropRepository),
          ),
          BlocProvider<CommentsCubit>(
            create: (context) => CommentsCubit(dropRepository),
          ),
          BlocProvider<PublicProfileCubit>(
            create: (context) => PublicProfileCubit(
              profileRepository,
              dropRepository,
              scoutRepository,
            ),
          ),
          BlocProvider<UserSearchCubit>(
            create: (context) => UserSearchCubit(profileRepository),
          ),
          BlocProvider<ScoutShortlistCubit>(
            create: (context) => ScoutShortlistCubit(scoutRepository),
          ),
        ],
        child: MaterialApp(
          title: 'FORMA',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          onGenerateRoute: AppRouter.generateRoute,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const DashboardScreen();
        } else if (state is AuthUnauthenticated) {
          return const LoginScreen();
        } else if (state is AuthError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 64,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Connection Error',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            context.read<AuthCubit>().checkAuth();
                          },
                          child: const Text('RETRY'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            context.read<AuthCubit>().logout();
                          },
                          child: const Text('GO TO LOGIN'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  size: 64,
                  color: AppTheme.primary,
                ),
                SizedBox(height: 24),
                CircularProgressIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }
}
