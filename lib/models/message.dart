class Message {
  final int? id;
  final int sessionId;
  final String sender;
  final String content;
  final DateTime createdAt;

  const Message({
    this.id,
    required this.sessionId,
    required this.sender,
    required this.content,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'sender': sender,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, Object?> map) {
    return Message(
      id: map['id'] as int,
      sessionId: map['session_id'] as int,
      sender: map['sender'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
