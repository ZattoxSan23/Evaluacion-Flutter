// lib/models/nutrition_plan.dart
import 'package:json_annotation/json_annotation.dart';

part 'nutrition_plan.g.dart';

@JsonSerializable()
class NutritionPlan {
  final String id;
  final String clientId;
  final String trainerId;
  final String name;
  final String? description;
  final int dailyCalories;
  final String startDate;
  final String status; // 'active'
  final List<Map<String, dynamic>> meals; // [{meal_type, name, calories, etc.}]

  NutritionPlan({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.name,
    this.description,
    required this.dailyCalories,
    required this.startDate,
    required this.status,
    this.meals = const [],
  });

  factory NutritionPlan.fromJson(Map<String, dynamic> json) =>
      _$NutritionPlanFromJson(json);
  Map<String, dynamic> toJson() => _$NutritionPlanToJson(this);
}
