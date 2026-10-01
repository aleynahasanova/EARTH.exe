class TeachingSession {
  final int? id;
  final String domain;
  final String concept;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String status;

  const TeachingSession({
    this.id,
    required this.domain,
    required this.concept,
    required this.startedAt,
    this.completedAt,
    this.status = 'active',
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'domain': domain,
      'concept': concept,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'status': status,
    };
  }

  factory TeachingSession.fromMap(Map<String, Object?> map) {
    return TeachingSession(
      id: map['id'] as int,
      domain: map['domain'] as String,
      concept: map['concept'] as String,
      startedAt: DateTime.parse(map['started_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      status: map['status'] as String,
    );
  }
}
