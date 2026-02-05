// lib/models/routine.dart
import 'package:json_annotation/json_annotation.dart';
import 'routine_exercise.dart';

part 'routine.g.dart';

@JsonSerializable()
class Routine {
  final String id;
  final String clientId;
  final String trainerId;
  final String? templateId;
  final String name;
  final String? description;
  final String startDate;
  final String status; // 'active', 'completed'
  final List<RoutineExercise> routineExercises;
  final Map<String, dynamic>? trainers; // {full_name: String}
  final String lastUpdatedAt; // Nueva propiedad para tracking de ediciones

  Routine({
    required this.id,
    required this.clientId,
    required this.trainerId,
    this.templateId,
    required this.name,
    this.description,
    required this.startDate,
    required this.status,
    this.routineExercises = const [],
    this.trainers,
    required this.lastUpdatedAt,
  });

  factory Routine.fromJson(Map<String, dynamic> json) =>
      _$RoutineFromJson(json);
  Map<String, dynamic> toJson() => _$RoutineToJson(this);
}
