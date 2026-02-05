// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evaluation_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EvaluationRequest _$EvaluationRequestFromJson(Map<String, dynamic> json) =>
    EvaluationRequest(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      currentTrainerId: json['currentTrainerId'] as String,
      purpose: json['purpose'] as String,
      status: json['status'] as String,
      preferredTime: json['preferredTime'] as String?,
      notes: json['notes'] as String?,
      requestDate: json['requestDate'] as String,
      scheduledDate: json['scheduledDate'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      clients: json['clients'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$EvaluationRequestToJson(EvaluationRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'clientId': instance.clientId,
      'currentTrainerId': instance.currentTrainerId,
      'purpose': instance.purpose,
      'status': instance.status,
      'preferredTime': instance.preferredTime,
      'notes': instance.notes,
      'requestDate': instance.requestDate,
      'scheduledDate': instance.scheduledDate,
      'rejectionReason': instance.rejectionReason,
      'clients': instance.clients,
    };
