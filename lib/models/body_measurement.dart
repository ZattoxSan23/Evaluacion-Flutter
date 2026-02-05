import 'package:json_annotation/json_annotation.dart';

part 'body_measurement.g.dart';

@JsonSerializable()
class BodyMeasurement {
  final String id;
  final String clientId;
  final String trainerId;
  final int age;
  final String gender; // 'male', 'female'
  final double height;
  final double weight;
  final double? neck;
  final double? shoulders;
  final double? chest;
  final double? arms;
  final double? waist;
  final double? glutes;
  final double? legs;
  final double? calves;
  final String? injuries;
  final String measurementDate;
  final double bmi;
  final double bodyFat;
  final int metabolicAge;
  final double muscleMass;
  final double waterPercentage;
  final double boneMass;
  final int visceralFat;
  final Map<String, dynamic>? trainers; // {full_name: String}

  BodyMeasurement({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    this.neck,
    this.shoulders,
    this.chest,
    this.arms,
    this.waist,
    this.glutes,
    this.legs,
    this.calves,
    this.injuries,
    required this.measurementDate,
    required this.bmi,
    required this.bodyFat,
    required this.metabolicAge,
    required this.muscleMass,
    required this.waterPercentage,
    required this.boneMass,
    required this.visceralFat,
    this.trainers,
  });

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) =>
      _$BodyMeasurementFromJson(json);
  Map<String, dynamic> toJson() => _$BodyMeasurementToJson(this);
}
