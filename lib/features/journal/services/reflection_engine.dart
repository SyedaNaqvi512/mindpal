import 'dart:convert';

/// The five parts of a reflection (FR-20).
class ReflectionParts {
  const ReflectionParts({
    required this.acknowledgement,
    this.pattern,
    this.patternNote,
    this.questions = const [],
    required this.balanced,
    required this.nextStep,
  });

  final String acknowledgement;
  final String? pattern; // id from the fixed list, or null
  final String? patternNote; // short plain-language explanation, optional
  final List<String> questions;
  final String balanced;
  final String nextStep;

  Map<String, dynamic> toJson() => {
        'ack': acknowledgement,
        'pattern': pattern,
        'note': patternNote,
        'questions': questions,
        'balanced': balanced,
        'next': nextStep,
      };

  String encode() => jsonEncode(toJson());

  static ReflectionParts? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final q = j['questions'];
      return ReflectionParts(
        acknowledgement: (j['ack'] as String?) ?? '',
        pattern: j['pattern'] as String?,
        patternNote: j['note'] as String?,
        questions: q is List ? q.whereType<String>().toList() : const [],
        balanced: (j['balanced'] as String?) ?? '',
        nextStep: (j['next'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// What every reflection engine (cloud or on-device) returns.
class ReflectionResult {
  const ReflectionResult({
    required this.text,
    this.pattern,
    this.serverId,
    this.safety = false,
    this.parts,
  });

  final String text;
  final String? pattern;     // thinking pattern, e.g. catastrophizing
  final String? serverId;    // reflectionId from the server usage record
  final bool safety;         // true = support message instead of a reflection
  final ReflectionParts? parts; // the five parts, when the engine can give them
}

abstract class ReflectionEngine {
  Future<ReflectionResult> reflect(String entry);
}

enum ReflectionErrorKind { offline, slow, unavailable, rateLimited, other }

class ReflectionException implements Exception {
  ReflectionException(this.message, {this.kind = ReflectionErrorKind.other});

  /// Friendly, specific messages (FR-25). The entry is always kept.
  factory ReflectionException.of(ReflectionErrorKind kind, [String? detail]) {
    switch (kind) {
      case ReflectionErrorKind.offline:
        return ReflectionException(
          'Could not reach MindPal. Check your connection. Your entry is '
          'saved, and you can try again.',
          kind: kind,
        );
      case ReflectionErrorKind.slow:
        return ReflectionException(
          'The AI is taking longer than usual. Your entry is saved, and you '
          'can try again in a moment.',
          kind: kind,
        );
      case ReflectionErrorKind.unavailable:
        return ReflectionException(
          'The AI service is not available right now. Your entry is saved. '
          'You can try again, or get a quick reflection on this phone.',
          kind: kind,
        );
      case ReflectionErrorKind.rateLimited:
        return ReflectionException(
          'You have reached the reflection limit for now. Your entry is '
          'saved. Please try again later.',
          kind: kind,
        );
      case ReflectionErrorKind.other:
        return ReflectionException(
          detail ?? 'Something went wrong. Your entry is saved. Please try again.',
          kind: kind,
        );
    }
  }

  final String message;
  final ReflectionErrorKind kind;

  /// Trying again right away makes sense (not for a rate limit).
  bool get canRetry => kind != ReflectionErrorKind.rateLimited;

  @override
  String toString() => message;
}

/// The server refused because AI consent is missing (FR-17).
class ConsentRequiredException extends ReflectionException {
  ConsentRequiredException()
      : super('Please allow AI reflections to continue.');
}
