import 'equipment.dart';

class User {
  final String inn;
  final String companyName;
  final String password;
  final List<Equipment> equipment;

  User({
    required this.inn,
    required this.companyName,
    required this.password,
    List<Equipment>? equipment,
  }) : equipment = equipment ?? <Equipment>[];
} 