import 'dart:convert';

import 'package:http/http.dart' as http;

import 'reflection_engine.dart';

class CloudReflectionEngine implements ReflectionEngine {
  CloudReflectionEngine({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:5141',
            ),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<String> reflect(String entry) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/reflect'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': entry}),
          )
          .timeout(const Duration(seconds: 60));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
                return (data['reflection'] as String)
            .replaceAll('**', '')
            .replaceAll('*', '')
            .trim();
      }
      throw ReflectionException(
        (data['error'] as String?) ?? 'Something went wrong. Please try again.',
      );
    } on ReflectionException {
      rethrow;
    } catch (_) {
      throw ReflectionException(
        'Could not reach MindPal. Check your connection and try again.',
      );
    }
  }
}