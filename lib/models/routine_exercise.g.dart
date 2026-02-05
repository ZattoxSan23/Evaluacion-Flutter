// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_exercise.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoutineExercise _$RoutineExerciseFromJson(Map<String, dynamic> json) =>
    RoutineExercise(
      id: json['id'] as String,
      routineId: json['routineId'] as String,
      exerciseId: json['exerciseId'] as String,
      sets: (json['sets'] as num).toInt(),
      reps: json['reps'] as String,
      restTime: (json['restTime'] as num).toInt(),
      dayOfWeek: json['dayOfWeek'] as String,
      exercises: json['exercises'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$RoutineExerciseToJson(RoutineExercise instance) =>
    <String, dynamic>{
      'id': instance.id,
      'routineId': instance.routineId,
      'exerciseId': instance.exerciseId,
      'sets': instance.sets,
      'reps': instance.reps,
      'restTime': instance.restTime,
      'dayOfWeek': instance.dayOfWeek,
      'exercises': instance.exercises,
    };
