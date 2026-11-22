import '../../auth/services/auth_service.dart';

/// FR-61: tells the server that an exercise was completed. Only the exercise
/// type is sent: no text, no answers, no time spent. It is fire-and-forget, so
/// a missing network never affects the exercise.
class ExerciseTelemetry {
  ExerciseTelemetry._();

  static Future<void> completed(String exerciseId) async {
    try {
      await AuthService.instance
          .authorizedPost('/telemetry/exercise', {'type': exerciseId})
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Ignored on purpose.
    }
  }
}
