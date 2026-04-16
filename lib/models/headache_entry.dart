import 'dart:convert';

class HeadacheEntry {
  const HeadacheEntry({
    required this.id,
    required this.timestamp,
    required this.intensity,
    this.causes = const <String>[],
    this.note,
  });

  final String id;
  final DateTime timestamp;
  final int intensity;
  final List<String> causes;
  final String? note;

  HeadacheEntry copyWith({
    String? id,
    DateTime? timestamp,
    int? intensity,
    List<String>? causes,
    String? note,
    bool clearNote = false,
  }) {
    return HeadacheEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      intensity: intensity ?? this.intensity,
      causes: causes ?? this.causes,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'intensity': intensity,
      'causes': jsonEncode(causes),
      'note': note,
    };
  }

  factory HeadacheEntry.fromMap(Map<String, Object?> map) {
    final rawCauses = map['causes'] as String?;
    return HeadacheEntry(
      id: map['id']! as String,
      timestamp: DateTime.parse(map['timestamp']! as String),
      intensity: map['intensity']! as int,
      causes: rawCauses == null || rawCauses.isEmpty
          ? const <String>[]
          : List<String>.from(jsonDecode(rawCauses) as List<dynamic>),
      note: map['note'] as String?,
    );
  }
}
