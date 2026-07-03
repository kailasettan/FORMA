import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'dart:io';

class FakeAuthRepository implements AuthRepository {
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
}

class FakeProfileRepository implements ProfileRepository {
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
  @override
  Future<List<Sport>> getSports() async => [];

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

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('FORMA'), findsOneWidget);
  });
}
