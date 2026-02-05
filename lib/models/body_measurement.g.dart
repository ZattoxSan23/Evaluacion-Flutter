// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'body_measurement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BodyMeasurement _$BodyMeasurementFromJson(Map<String, dynamic> json) =>
    BodyMeasurement(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      trainerId: json['trainerId'] as String,
      age: (json['age'] as num).toInt(),
      gender: json['gender'] as String,
      height: (json['height'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      neck: (json['neck'] as num?)?.toDouble(),
      shoulders: (json['shoulders'] as num?)?.toDouble(),
      chest: (json['chest'] as num?)?.toDouble(),
      arms: (json['arms'] as num?)?.toDouble(),
      waist: (json['waist'] as num?)?.toDouble(),
      glutes: (json['glutes'] as num?)?.toDouble(),
      legs: (json['legs'] as num?)?.toDouble(),
      calves: (json['calves'] as num?)?.toDouble(),
      injuries: json['injuries'] as String?,
      measurementDate: json['measurementDate'] as String,
      bmi: (json['bmi'] as num).toDouble(),
      bodyFat: (json['bodyFat'] as num).toDouble(),
      metabolicAge: (json['metabolicAge'] as num).toInt(),
      muscleMass: (json['muscleMass'] as num).toDouble(),
      waterPercentage: (json['waterPercentage'] as num).toDouble(),
      boneMass: (json['boneMass'] as num).toDouble(),
      visceralFat: (json['visceralFat'] as num).toInt(),
      trainers: json['trainers'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$BodyMeasurementToJson(BodyMeasurement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'clientId': instance.clientId,
      'trainerId': instance.trainerId,
      'age': instance.age,
      'gender': instance.gender,
      'height': instance.height,
      'weight': instance.weight,
      'neck': instance.neck,
      'shoulders': instance.shoulders,
      'chest': instance.chest,
      'arms': instance.arms,
      'waist': instance.waist,
      'glutes': instance.glutes,
      'legs': instance.legs,
      'calves': instance.calves,
      'injuries': instance.injuries,
      'measurementDate': instance.measurementDate,
      'bmi': instance.bmi,
      'bodyFat': instance.bodyFat,
      'metabolicAge': instance.metabolicAge,
      'muscleMass': instance.muscleMass,
      'waterPercentage': instance.waterPercentage,
      'boneMass': instance.boneMass,
      'visceralFat': instance.visceralFat,
      'trainers': instance.trainers,
    };
