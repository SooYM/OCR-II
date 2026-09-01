/// AI Health Assistant Conversational Domain Models.
///
/// This module provides models for conversational threads ([ChatSession]) and
/// individual conversational turns ([ChatMessage]) exchanged with the LLM.
///
/// ### Simple Example:
/// ```dart
/// // Instantiating a user message
/// final message = ChatMessage(role: 'user', content: 'What is my HbA1c level?');
/// ```
///
/// ### Advanced Example:
/// ```dart
/// // Appending streaming tokens to an assistant message in real time
/// final assistantMsg = ChatMessage(role: 'assistant', content: '');
/// stream.listen((token) {
///   assistantMsg.content += token;
/// });
/// ```
library chat_models;

/// Represents a single message within a conversational AI session.
class ChatMessage {
  /// Unique identifier of the message record (UUID in Supabase), or null for transient messages.
  final String? id;

  /// Sender role: `'user'` for patient queries, `'assistant'` for AI responses.
  final String role;

  /// The markdown text content of the message.
  ///
  /// Note: [content] is mutable to allow in-place concatenation during SSE token streaming.
  String content;

  /// Timestamp when the message was sent or received.
  final DateTime timestamp;

  /// Constructs a [ChatMessage].
  ///
  /// * [id]: Optional persistence identifier.
  /// * [role]: Message author (`'user'` or `'assistant'`).
  /// * [content]: The initial message string.
  /// * [timestamp]: Creation time (defaults to [DateTime.now]).
  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Factory constructor to deserialize a [ChatMessage] from a JSON map.
  ///
  /// * [json]: A decoded JSON object from the `/api/chat/sessions/{id}/messages` endpoint.
  /// * Returns: A typed [ChatMessage] instance.
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

/// Represents an ongoing conversational thread/session between a patient and the AI assistant.
class ChatSession {
  /// Unique thread identifier (UUID).
  final String id;

  /// Human-readable title summarizing the topic of discussion.
  final String title;

  /// Creation timestamp of the chat session.
  final DateTime createdAt;

  /// Constructs a [ChatSession].
  ///
  /// * [id]: Session identifier.
  /// * [title]: Topic heading.
  /// * [createdAt]: Session instantiation timestamp.
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  /// Factory constructor to deserialize a [ChatSession] from a JSON map.
  ///
  /// * [json]: A decoded JSON object from the `/api/chat/sessions` endpoint.
  /// * Returns: A typed [ChatSession] instance.
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
