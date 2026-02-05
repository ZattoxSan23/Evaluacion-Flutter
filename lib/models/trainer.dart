// lib/models/trainer.dart
import 'package:json_annotation/json_annotation.dart';
import 'user.dart'; // Si es extensión de User

part 'trainer.g.dart';

@JsonSerializable()
class Trainer extends User {
  // Puede extender User si es similar
  final int clientCount; // Número de clientes asignados

  Trainer({
    required String id,
    required String email,
    required String fullName,
    required String role,
    this.clientCount = 0,
  }) : super(id: id, email: email, fullName: fullName, role: role);

  factory Trainer.fromJson(Map<String, dynamic> json) =>
      _$TrainerFromJson(json);
  Map<String, dynamic> toJson() => _$TrainerToJson(this);
}
