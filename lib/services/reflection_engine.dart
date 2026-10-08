abstract class ReflectionEngine {
  Future<String> reflect(String entry);
}

class ReflectionException implements Exception {
  ReflectionException(this.message);
  final String message;

  @override
  String toString() => message;
}