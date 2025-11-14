import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final types.User author;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.author,
  });

  factory ChatMessage.fromTextMessage(types.TextMessage message) {
    return ChatMessage(
      id: message.id,
      text: message.text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(message.createdAt ?? 0),
      author: message.author,
    );
  }

  types.TextMessage toTextMessage() {
    return types.TextMessage(
      id: id,
      text: text,
      author: author,
      createdAt: timestamp.millisecondsSinceEpoch,
    );
  }
}
