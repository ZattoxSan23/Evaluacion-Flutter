// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Exercise _$ExerciseFromJson(Map<String, dynamic> json) => Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      videoUrl: json['videoUrl'] as String?,
      muscleGroup: json['muscleGroup'] as String?,
      createdBy: json['createdBy'] as String,
    );

Map<String, dynamic> _$ExerciseToJson(Exercise instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'videoUrl': instance.videoUrl,
      'muscleGroup': instance.muscleGroup,
      'createdBy': instance.createdBy,
    };
