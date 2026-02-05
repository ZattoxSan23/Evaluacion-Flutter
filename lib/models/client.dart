// lib/models/client.dart
import 'package:json_annotation/json_annotation.dart';
import 'user.dart'; // Importa si necesitas

part 'client.g.dart';

@JsonSerializable()
class Client {
  final String id;
  final String userId;
  final String? trainerId;
  final String membershipType; // 'basic', 'premium', etc.
  final String branchId;
  final String status; // 'active', 'inactive'
  final User? profiles; // Relación con User (perfil)
  final Map<String, dynamic>? branches; // {name: String}

  Client({
    required this.id,
    required this.userId,
    this.trainerId,
    required this.membershipType,
    required this.branchId,
    required this.status,
    this.profiles,
    this.branches,
  });

  factory Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);
  Map<String, dynamic> toJson() => _$ClientToJson(this);
}
