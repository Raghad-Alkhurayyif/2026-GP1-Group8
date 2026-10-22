import 'dart:convert';

import 'package:http/http.dart' as http;

class SymptomApiService {
  static const String _baseUrl = 'http://10.0.2.2:8000';

  Future<Map<String, dynamic>> extractSymptoms(
    String text,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/extract'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'text': text,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final body = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        body is Map
            ? body['detail'] ?? 'Symptom extraction failed.'
            : 'Symptom extraction failed.',
      );
    }

    return Map<String, dynamic>.from(body);
  }
}