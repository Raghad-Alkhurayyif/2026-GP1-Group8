import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gemini_preference.dart';

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
            'use_gemini': GeminiPreference.enabled.value,
          }),
        )
        .timeout(const Duration(seconds: 15));

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
        .timeout(const Duration(seconds: 15));

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

  /// Moves symptoms that the assessed person's [age] rules out into
  /// 'age_set_aside', so the review screen can ask about them.
  Future<Map<String, dynamic>> applyAge(
    Map<String, dynamic> result,
    int age,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/apply-age'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'result': result,
            'age': age,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        body is Map
            ? body['detail'] ?? 'Applying the age rules failed.'
            : 'Applying the age rules failed.',
      );
    }

    return Map<String, dynamic>.from(body);
  }
}
