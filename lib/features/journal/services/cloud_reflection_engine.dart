import 'dart:async';

import '../../auth/services/auth_service.dart';
import 'reflection_engine.dart';

class CloudReflectionEngine implements ReflectionEngine {
  CloudReflectionEngine();

  static List<String> _strings(Object? v) =>
      v is List ? v.whereType<String>().map((s) => s.trim()).toList() : const [];

  static String _clean(String s) => s.replaceAll('**', '').replaceAll('*', '').trim();

  @override
  Future<ReflectionResult> reflect(String entry) async {
    try {
      final response = await AuthService.instance
          .authorizedPost('/reflect', {'text': entry})
          .timeout(const Duration(seconds: 60));
      final data = decodeJson(response.body);

      if (response.statusCode == 200) {
        final text = _clean(data['reflection'] as String);
        if (data['safety'] == true) {
          return ReflectionResult(text: text, safety: true);
        }
        final s = data['structured'];
        ReflectionParts? parts;
        String? pattern;
        if (s is Map) {
          final p = s['thinkingPattern'] as String?;
          pattern = (p == null || p == 'none') ? null : p;
          parts = ReflectionParts(
            acknowledgement: _clean((s['acknowledgement'] as String?) ?? ''),
            pattern: pattern,
            questions: _strings(s['questions']).map(_clean).toList(),
            balanced: _clean((s['balancedThought'] as String?) ?? ''),
            nextStep: _clean((s['nextStep'] as String?) ?? ''),
          );
        }
        return ReflectionResult(
          text: text,
          pattern: pattern,
          serverId: data['reflectionId'] as String?,
          parts: parts,
        );
      }

      final code = data['code'];
      final status = response.statusCode;
      if (status == 403 && code == 'consent_required') {
        throw ConsentRequiredException();
      }
      if (status == 429) {
        throw ReflectionException.of(ReflectionErrorKind.rateLimited);
      }
      if (status == 504 || code == 'ai_timeout') {
        throw ReflectionException.of(ReflectionErrorKind.slow);
      }
      if (status == 502 || status == 503 || code == 'ai_unavailable') {
        throw ReflectionException.of(ReflectionErrorKind.unavailable);
      }
      throw ReflectionException.of(
          ReflectionErrorKind.other, problemMessage(data));
    } on SessionExpiredException {
      rethrow;
    } on ReflectionException {
      rethrow;
    } on TimeoutException {
      throw ReflectionException.of(ReflectionErrorKind.slow);
    } catch (_) {
      throw ReflectionException.of(ReflectionErrorKind.offline);
    }
  }
}
