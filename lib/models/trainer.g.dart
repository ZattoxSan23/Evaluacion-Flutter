// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trainer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Trainer _$TrainerFromJson(Map<String, dynamic> json) => Trainer(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      role: json['role'] as String,
      clientCount: (json['clientCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$TrainerToJson(Trainer instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'fullName': instance.fullName,
      'role': instance.role,
      'clientCount': instance.clientCount,
    };
