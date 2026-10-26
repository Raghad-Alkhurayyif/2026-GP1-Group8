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

  /// Keeps only the findings of the person the assessment is for.
  /// [subject] is 'self' or 'other'.
  Future<Map<String, dynamic>> assignSubject(
    Map<String, dynamic> result,
    String subject,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/assign-subject'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'result': result,
            'subject': subject,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final body = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        body is Map
            ? body['detail'] ?? 'Updating the symptoms failed.'
            : 'Updating the symptoms failed.',
      );
    }

    return Map<String, dynamic>.from(body);
  }
}