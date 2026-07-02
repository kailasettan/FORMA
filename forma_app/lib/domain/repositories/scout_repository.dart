import '../entities/scout_shortlist.dart';

abstract class ScoutRepository {
  Future<ScoutShortlist> shortlistAthlete({
    required String athleteUserId,
    String? dropId,
    String? privateNote,
  });
  
  Future<void> removeShortlist(String athleteUserId);
  Future<List<ScoutShortlist>> getShortlist();
}
