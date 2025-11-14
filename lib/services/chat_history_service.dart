import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';
import '../models/policy_model.dart';

/// Service to save and load chat history per user
class ChatHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save a chat message for a user
  Future<void> saveMessage(String userId, ChatMessageModel message) async {
    try {
      if (userId.isEmpty || userId == 'anonymous') {
        debugPrint('[CHAT_HISTORY] Skipping save for anonymous user');
        return;
      }

      if (message.id.isEmpty || message.text.isEmpty) {
        debugPrint('[CHAT_HISTORY] Invalid message, skipping save');
        return;
      }

      await _firestore
          .collection('chat_history')
          .doc(userId)
          .collection('messages')
          .doc(message.id)
          .set({
        'text': message.text,
        'isUser': message.isUser,
        'timestamp': Timestamp.fromDate(message.timestamp),
      });
      
      debugPrint('[CHAT_HISTORY] Saved message for user: $userId (id: ${message.id})');
    } catch (e) {
      debugPrint('[CHAT_HISTORY] Error saving chat message: $e');
      // Don't throw - saving is non-critical, app should continue working
    }
  }

  /// Load all chat messages for a user
  Future<List<ChatMessageModel>> loadMessages(String userId) async {
    try {
      if (userId.isEmpty || userId == 'anonymous') {
        debugPrint('[CHAT_HISTORY] Skipping history load for anonymous user');
        return [];
      }

      final snapshot = await _firestore
          .collection('chat_history')
          .doc(userId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .limit(100) // Limit to last 100 messages to avoid performance issues
          .get();

      final messages = snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          return ChatMessageModel(
            id: doc.id,
            text: data['text']?.toString() ?? '',
            isUser: data['isUser'] == true,
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        } catch (e) {
          debugPrint('[CHAT_HISTORY] Error parsing message ${doc.id}: $e');
          return null;
        }
      }).whereType<ChatMessageModel>().toList(); // Filter out null values

      debugPrint('[CHAT_HISTORY] Loaded ${messages.length} chat messages for user: $userId');
      return messages;
    } catch (e) {
      debugPrint('[CHAT_HISTORY] Error loading chat messages: $e');
      // Return empty list on error - app should still work without history
      return [];
    }
  }

  /// Clear all chat history for a user
  Future<void> clearHistory(String userId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('chat_history')
          .doc(userId)
          .collection('messages')
          .get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Chat history cleared for user: $userId');
    } catch (e) {
      debugPrint('Error clearing chat history: $e');
    }
  }

  /// Delete a specific message
  Future<void> deleteMessage(String userId, String messageId) async {
    try {
      await _firestore
          .collection('chat_history')
          .doc(userId)
          .collection('messages')
          .doc(messageId)
          .delete();
      debugPrint('Chat message deleted: $messageId');
    } catch (e) {
      debugPrint('Error deleting chat message: $e');
    }
  }

  /// Get messages for a specific session (for fullscreen chat)
  List<ChatMessageModel> getSessionMessages(String sessionId) {
    // For now, return empty list - session-based chat needs implementation
    // This is a placeholder to fix compilation errors
    debugPrint('[CHAT_HISTORY] getSessionMessages called for session: $sessionId');
    return [];
  }

  /// Add a message to chat history (simplified version for fullscreen chat)
  Future<void> addMessage(String text, bool isUser, {PolicyModel? policy}) async {
    try {
      // Create a message model
      final message = ChatMessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
      );
      
      // For now, use a default userId - in production, get from auth
      const userId = 'default_user';
      await saveMessage(userId, message);
      debugPrint('[CHAT_HISTORY] Added message via addMessage: $text');
    } catch (e) {
      debugPrint('[CHAT_HISTORY] Error in addMessage: $e');
    }
  }

  /// Archive a chat session
  Future<void> archiveSession(String sessionId) async {
    try {
      // Placeholder implementation - mark session as archived
      debugPrint('[CHAT_HISTORY] Archive session called for: $sessionId');
      // In production, you would update a sessions collection
      // For now, just log it
    } catch (e) {
      debugPrint('[CHAT_HISTORY] Error archiving session: $e');
    }
  }
}
