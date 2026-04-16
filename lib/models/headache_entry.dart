class HeadacheEntry {
  const HeadacheEntry({
    required this.id,
    required this.timestamp,
    required this.intensity,
    this.note,
  });

  final String id;
  final DateTime timestamp;
  final int intensity;
  final String? note;

  HeadacheEntry copyWith({
    String? id,
    DateTime? timestamp,
    int? intensity,
    String? note,
    bool clearNote = false,
  }) {
    return HeadacheEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      intensity: intensity ?? this.intensity,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'intensity': intensity,
      'note': note,
    };
  }

  factory HeadacheEntry.fromMap(Map<String, Object?> map) {
    return HeadacheEntry(
      id: map['id']! as String,
      timestamp: DateTime.parse(map['timestamp']! as String),
      intensity: map['intensity']! as int,
      note: map['note'] as String?,
    );
  }
}
