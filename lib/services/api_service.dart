import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/equipment.dart';

class ApiService {
  static const String baseUrl = 'https://api.t-company-service.com'; // Replace with your actual API URL

  // Equipment endpoints
  Future<List<Equipment>> getEquipment() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/equipment'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Equipment.fromJson(json)).toList();
      }
      throw Exception('Failed to load equipment');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> addEquipment(Equipment equipment) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/equipment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(equipment.toJson()),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to add equipment');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Spare parts endpoints
  Future<List<Map<String, dynamic>>> getSpareParts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/spare-parts'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      throw Exception('Failed to load spare parts');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> orderSparePart(String partId, int quantity) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/spare-parts/order'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'partId': partId,
          'quantity': quantity,
        }),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to order spare part');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Service request endpoints
  Future<void> submitServiceRequest({
    required String description,
    required String address,
    required String phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/service-requests'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'description': description,
          'address': address,
          'phone': phone,
        }),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to submit service request');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
} 