// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NutritionPlan _$NutritionPlanFromJson(Map<String, dynamic> json) =>
    NutritionPlan(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      trainerId: json['trainerId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      dailyCalories: (json['dailyCalories'] as num).toInt(),
      startDate: json['startDate'] as String,
      status: json['status'] as String,
      meals: (json['meals'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$NutritionPlanToJson(NutritionPlan instance) =>
    <String, dynamic>{
      'id': instance.id,
      'clientId': instance.clientId,
      'trainerId': instance.trainerId,
      'name': instance.name,
      'description': instance.description,
      'dailyCalories': instance.dailyCalories,
      'startDate': instance.startDate,
      'status': instance.status,
      'meals': instance.meals,
    };
