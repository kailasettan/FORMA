import 'package:equatable/equatable.dart';
import 'user.dart';

class ScoutShortlist extends Equatable {
  final String id;
  final String scoutUserId;
  final String athleteUserId;
  final String? dropId;
  final String? privateNote;
  final DateTime createdAt;
  final User? athlete;

  const ScoutShortlist({
    required this.id,
    required this.scoutUserId,
    required this.athleteUserId,
    this.dropId,
    this.privateNote,
    required this.createdAt,
    this.athlete,
  });

  @override
  List<Object?> get props => [
    id,
    scoutUserId,
    athleteUserId,
    dropId,
    privateNote,
    createdAt,
    athlete,
  ];
}
