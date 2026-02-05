// lib/models/routine_exercise.dart
import 'package:json_annotation/json_annotation.dart';

part 'routine_exercise.g.dart';

@JsonSerializable()
class RoutineExercise {
  final String id;
  final String routineId;
  final String exerciseId;
  final int sets;
  final String reps;
  final int restTime; // segundos
  final String dayOfWeek; // 'monday', etc.
  final Map<String, dynamic>? exercises; // {name: String, video_url: String?}

  RoutineExercise({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.restTime,
    required this.dayOfWeek,
    this.exercises,
  });

  factory RoutineExercise.fromJson(Map<String, dynamic> json) =>
      _$RoutineExerciseFromJson(json);
  Map<String, dynamic> toJson() => _$RoutineExerciseToJson(this);
}
