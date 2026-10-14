import 'auth_service.dart';
import 'reflection_engine.dart';

class CloudReflectionEngine implements ReflectionEngine {
  CloudReflectionEngine();

  @override
  Future<ReflectionResult> reflect(String entry) async {
    try {
      final response = await AuthService.instance
          .authorizedPost('/reflect', {'text': entry})
          .timeout(const Duration(seconds: 60));
      final data = decodeJson(response.body);

      if (response.statusCode == 200) {
        final text = (data['reflection'] as String)
            .replaceAll('**', '')
            .replaceAll('*', '')
            .trim();
        if (data['safety'] == true) {
          return ReflectionResult(text: text, safety: true);
        }
        final structured = data['structured'];
        return ReflectionResult(
          text: text,
          pattern: structured is Map ? structured['thinkingPattern'] as String? : null,
          serverId: data['reflectionId'] as String?,
        );
      }
      throw ReflectionException(problemMessage(data));
    } on SessionExpiredException {
      rethrow;
    } on ReflectionException {
      rethrow;
    } catch (_) {
      throw ReflectionException(
        'Could not reach MindPal. Check your connection and try again.',
      );
    }
  }
}