// lib/models/exercise.dart
import 'package:json_annotation/json_annotation.dart';

part 'exercise.g.dart';

@JsonSerializable()
class Exercise {
  final String id;
  final String name;
  final String? description;
  final String? videoUrl;
  final String? muscleGroup;
  final String createdBy;

  Exercise({
    required this.id,
    required this.name,
    this.description,
    this.videoUrl,
    this.muscleGroup,
    required this.createdBy,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      _$ExerciseFromJson(json);
  Map<String, dynamic> toJson() => _$ExerciseToJson(this);
}
