// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Client _$ClientFromJson(Map<String, dynamic> json) => Client(
      id: json['id'] as String,
      userId: json['userId'] as String,
      trainerId: json['trainerId'] as String?,
      membershipType: json['membershipType'] as String,
      branchId: json['branchId'] as String,
      status: json['status'] as String,
      profiles: json['profiles'] == null
          ? null
          : User.fromJson(json['profiles'] as Map<String, dynamic>),
      branches: json['branches'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ClientToJson(Client instance) => <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'trainerId': instance.trainerId,
      'membershipType': instance.membershipType,
      'branchId': instance.branchId,
      'status': instance.status,
      'profiles': instance.profiles,
      'branches': instance.branches,
    };
