// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Routine _$RoutineFromJson(Map<String, dynamic> json) => Routine(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      trainerId: json['trainerId'] as String,
      templateId: json['templateId'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      startDate: json['startDate'] as String,
      status: json['status'] as String,
      routineExercises: (json['routineExercises'] as List<dynamic>?)
              ?.map((e) => RoutineExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      trainers: json['trainers'] as Map<String, dynamic>?,
      lastUpdatedAt: json['lastUpdatedAt'] as String,
    );

Map<String, dynamic> _$RoutineToJson(Routine instance) => <String, dynamic>{
      'id': instance.id,
      'clientId': instance.clientId,
      'trainerId': instance.trainerId,
      'templateId': instance.templateId,
      'name': instance.name,
      'description': instance.description,
      'startDate': instance.startDate,
      'status': instance.status,
      'routineExercises': instance.routineExercises,
      'trainers': instance.trainers,
      'lastUpdatedAt': instance.lastUpdatedAt,
    };
