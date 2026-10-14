/// What every reflection engine (cloud or on-device) returns.
class ReflectionResult {
  const ReflectionResult({
    required this.text,
    this.pattern,
    this.serverId,
    this.safety = false,
  });

  final String text;
  final String? pattern;     // thinking pattern, e.g. catastrophizing
  final String? serverId;    // reflectionId from the server usage record
  final bool safety;         // true = support message instead of a reflection
}

abstract class ReflectionEngine {
  Future<ReflectionResult> reflect(String entry);
}

class ReflectionException implements Exception {
  ReflectionException(this.message);
  final String message;

  @override
  String toString() => message;
}