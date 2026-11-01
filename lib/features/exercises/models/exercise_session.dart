import 'dart:convert';

/// One run of an exercise. In progress sessions can be resumed or discarded
/// (FR-44); completed ones are the Exercise Progress list (FR-45).
class ExerciseSession {
  ExerciseSession({
    this.id,
    required this.exerciseId,
    this.status = inProgress,
    this.entryId,
    Map<String, dynamic>? data,
    this.balancedThought,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
  })  : data = data ?? <String, dynamic>{},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static const inProgress = 'in_progress';
  static const completed = 'completed';

  int? id;
  final String exerciseId;
  String status;

  /// The journal entry this exercise is related to, if any (FR-47, FR-48).
  final int? entryId;
  final Map<String, dynamic> data;

  /// The optional balanced thought written after the exercise (FR-48).
  String? balancedThought;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? completedAt;

  bool get isCompleted => status == completed;

  Map<String, Object?> toRow() => {
        'exercise_id': exerciseId,
        'status': status,
        'entry_id': entryId,
        'data_json': jsonEncode(data),
        'balanced_thought': balancedThought,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  static ExerciseSession fromRow(Map<String, Object?> r) {
    Map<String, dynamic> data;
    try {
      final d = jsonDecode('${r['data_json']}');
      data = d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    } catch (_) {
      data = <String, dynamic>{};
    }
    return ExerciseSession(
      id: r['id'] as int?,
      exerciseId: '${r['exercise_id']}',
      status: '${r['status']}',
      entryId: r['entry_id'] as int?,
      data: data,
      balancedThought: r['balanced_thought'] as String?,
      createdAt: DateTime.tryParse('${r['created_at']}'),
      updatedAt: DateTime.tryParse('${r['updated_at']}'),
      completedAt: DateTime.tryParse('${r['completed_at']}'),
    );
  }
}
