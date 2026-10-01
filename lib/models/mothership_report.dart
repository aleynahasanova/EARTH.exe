class MothershipReport {
  final int? id;
  final int sessionId;
  final String reportContent;
  final String? studentCorrection;
  final bool verified;
  final DateTime createdAt;

  const MothershipReport({
    this.id,
    required this.sessionId,
    required this.reportContent,
    this.studentCorrection,
    this.verified = false,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'report_content': reportContent,
      'student_correction': studentCorrection,
      'verified': verified ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MothershipReport.fromMap(Map<String, Object?> map) {
    return MothershipReport(
      id: map['id'] as int,
      sessionId: map['session_id'] as int,
      reportContent: map['report_content'] as String,
      studentCorrection: map['student_correction'] as String?,
      verified: (map['verified'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
