class ChatMessage {
  final String? id;
  final String role; // 'user' or 'assistant'
  String content; // mutable for streaming
  final DateTime timestamp;

  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String) 
          : null,
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
