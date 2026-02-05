// lib/models/evaluation_request.dart
import 'package:json_annotation/json_annotation.dart';

part 'evaluation_request.g.dart';

@JsonSerializable()
class EvaluationRequest {
  final String id;
  final String clientId;
  final String currentTrainerId;
  final String purpose; // 'evaluation'
  final String status; // 'pending', 'accepted', 'rejected', 'completed'
  final String? preferredTime;
  final String? notes;
  final String requestDate;
  final String? scheduledDate;
  final String? rejectionReason;
  final Map<String, dynamic>? clients; // Relación con Client

  EvaluationRequest({
    required this.id,
    required this.clientId,
    required this.currentTrainerId,
    required this.purpose,
    required this.status,
    this.preferredTime,
    this.notes,
    required this.requestDate,
    this.scheduledDate,
    this.rejectionReason,
    this.clients,
  });

  factory EvaluationRequest.fromJson(Map<String, dynamic> json) =>
      _$EvaluationRequestFromJson(json);
  Map<String, dynamic> toJson() => _$EvaluationRequestToJson(this);
}
