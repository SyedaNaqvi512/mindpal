import '../../auth/services/auth_service.dart';

/// AI-processing consent (SRS FR-17, FR-33). The server is the authority:
/// it records the consent with a timestamp and refuses /reflect without it.
class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  /// Must match ConsentPolicy.CurrentVersion on the server.
  static const policyVersion = '1.0';

  bool _granted = false; // memory cache, only ever true after a server answer

  void clear() => _granted = false;

  Future<bool> isGranted({bool refresh = false}) async {
    if (_granted && !refresh) return true;
    try {
      final r = await AuthService.instance
          .authorizedGet('/me/consents')
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) {
        throw AuthException(problemMessage(decodeJson(r.body)));
      }
      final list = decodeJson(r.body)['consents'];
      var granted = false;
      if (list is List) {
        for (final c in list) {
          if (c is Map && c['type'] == 'ai_processing') {
            granted = c['granted'] == true;
          }
        }
      }
      _granted = granted;
      return granted;
    } on SessionExpiredException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(
          'Could not reach MindPal. Check your connection and try again.');
    }
  }

  Future<void> grant() async {
    try {
      final r = await AuthService.instance
          .authorizedPut('/me/consents/ai_processing',
              {'policyVersion': policyVersion})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) {
        throw AuthException(problemMessage(decodeJson(r.body)));
      }
      _granted = true;
    } on SessionExpiredException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(
          'Could not reach MindPal. Check your connection and try again.');
    }
  }

  Future<void> revoke() async {
    try {
      final r = await AuthService.instance
          .authorizedDelete('/me/consents/ai_processing')
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 204 && r.statusCode != 200) {
        throw AuthException(problemMessage(decodeJson(r.body)));
      }
      _granted = false;
    } on SessionExpiredException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(
          'Could not reach MindPal. Check your connection and try again.');
    }
  }
}
