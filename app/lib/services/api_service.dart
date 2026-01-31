import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sms_request.dart';

class ApiService {
  final String baseUrl;
  final String? apiKey;

  ApiService(this.baseUrl, {this.apiKey});

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (apiKey != null) {
      headers['X-API-Key'] = apiKey!;
    }
    return headers;
  }

  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required String deviceName,
    String? phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?request=register-device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': deviceId,
          'device_name': deviceName,
          'phone_number': phoneNumber,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Sunucu hatası: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Bağlantı hatası: $e',
      };
    }
  }

  Future<List<SmsRequest>> getPendingMessages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?request=pending'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List messages = data['messages'] ?? [];
          return messages.map((m) => SmsRequest.fromJson(m)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  Future<bool> updateMessageStatus({
    required int requestId,
    required String status,
    String? errorMessage,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?request=update-status'),
        headers: _getHeaders(),
        body: jsonEncode({
          'request_id': requestId,
          'status': status,
          'error_message': errorMessage,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error updating status: $e');
      return false;
    }
  }
}
