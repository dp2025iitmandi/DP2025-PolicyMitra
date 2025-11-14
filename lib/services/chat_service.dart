import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class ChatService {
  static const String _modelName = 'llama-3.3-70b-versatile';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  // Get API key from config
  String get _apiKey => AppConfig.groqApiKey;

  // Send a general chat message to Groq with conversation history
  Future<String?> sendMessage(String message, {List<Map<String, String>>? conversationHistory}) async {
    return await _sendMessageWithRetry(message, conversationHistory);
  }

  // Send message with retry logic
  Future<String?> _sendMessageWithRetry(String message, List<Map<String, String>>? conversationHistory) async {
    const maxRetries = 5;
    const maxBackoffSeconds = 30;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Build conversation messages for Groq
        List<Map<String, String>> messages = [];
        
        // Add system message with strict policy/scheme focus
        messages.add({
          'role': 'system',
          'content': '''You are "PolicyBot", a specialized AI assistant for the Policy App. You STRICTLY answer questions ONLY related to:
- Government policies and schemes
- Policy benefits, eligibility, and application processes
- Government programs and initiatives
- Policy discussions and explanations

CRITICAL RULES:
1. You MUST ONLY respond to questions about government policies, schemes, and related topics
2. If a question is NOT related to policies/schemes (e.g., general knowledge, math, weather, personal advice, entertainment, etc.), you MUST politely decline and redirect:
   "I'm PolicyBot, and I specialize in government policies and schemes. I can only help with questions related to government policies, schemes, benefits, eligibility, and applications. Could you please ask something related to policies or schemes?"

3. Be friendly, helpful, and provide accurate information when the question IS policy/scheme-related
4. If unsure whether a question is policy-related, err on the side of asking for clarification

Examples of topics you CAN answer:
✓ "What are the latest agriculture policies?"
✓ "How do I apply for education scholarships?"
✓ "Tell me about housing loan policies"
✓ "What are the benefits of PM-KISAN?"

Examples of topics you MUST decline:
✗ "What's the weather today?"
✗ "Solve this math problem: 2+2"
✗ "Tell me a joke"
✗ "What's the capital of France?"
✗ "How to cook pasta?"''',
        });
        
        // Add conversation history
        if (conversationHistory != null && conversationHistory.isNotEmpty) {
          for (var entry in conversationHistory) {
            messages.add({
              'role': entry['role'] ?? 'user',
              'content': entry['content'] ?? '',
            });
          }
        }
        
        // Add current message
        messages.add({
          'role': 'user',
          'content': message,
        });

        final requestBody = {
          'model': _modelName,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 8000,
        };

        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(requestBody),
        ).timeout(
          const Duration(seconds: 90),
          onTimeout: () {
            throw TimeoutException('Request timed out');
          },
        );

        debugPrint('Groq API ($_modelName) Response Status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // Extract and log token usage
          if (data['usage'] != null) {
            final usage = data['usage'];
            final promptTokens = usage['prompt_tokens'] ?? 0;
            final completionTokens = usage['completion_tokens'] ?? 0;
            final totalTokens = usage['total_tokens'] ?? 0;
            debugPrint('[CHAT_TOKEN_USAGE] Prompt: $promptTokens, Completion: $completionTokens, Total: $totalTokens');
          }
          
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            final choice = data['choices'][0];
            if (choice['message'] != null && 
                choice['message']['content'] != null) {
              return choice['message']['content'];
            }
          }
        } 
        
        // Handle specific status codes
        if (response.statusCode == 429 || response.statusCode == 503) {
          // Rate limit or service unavailable - retry with backoff
          if (attempt < maxRetries - 1) {
            final backoffSeconds = _calculateBackoff(attempt, maxBackoffSeconds);
            debugPrint('Rate limit/service unavailable, retrying after ${backoffSeconds}s...');
            await Future.delayed(Duration(seconds: backoffSeconds));
            continue;
          }
        }
        
        // Check response body for error details
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error']?['message'] ?? '';
          
          if (_isOverloadError(errorMessage) && attempt < maxRetries - 1) {
            final backoffSeconds = _calculateBackoff(attempt, maxBackoffSeconds);
            debugPrint('Model overloaded (error message), retrying after ${backoffSeconds}s...');
            await Future.delayed(Duration(seconds: backoffSeconds));
            continue;
          }
        } catch (e) {
          // Not JSON or can't parse
        }
        
        // If we get here and it's the last attempt, return error
        if (attempt == maxRetries - 1) {
          return 'I\'m having trouble connecting to the AI service right now. This might be due to high demand. Please wait a moment and try again.';
        }
        
      } catch (e) {
        debugPrint('Error calling Groq API ($_modelName, attempt ${attempt + 1}): $e');
        
        if (e is TimeoutException) {
          // For timeout, retry with shorter backoff
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(seconds: (attempt + 1) * 2));
            continue;
          }
        }
        
        // For other errors, wait before retry
        if (attempt < maxRetries - 1) {
          final backoffSeconds = _calculateBackoff(attempt, maxBackoffSeconds);
          await Future.delayed(Duration(seconds: backoffSeconds));
        }
      }
    }
    
    // All retries failed
    return 'I\'m having trouble connecting to the AI service right now. This might be due to high demand. Please wait a moment and try again.';
  }

  // Check if error message indicates overload
  bool _isOverloadError(String errorMessage) {
    final lowerMsg = errorMessage.toLowerCase();
    return lowerMsg.contains('overload') ||
           lowerMsg.contains('quota') ||
           lowerMsg.contains('rate limit') ||
           lowerMsg.contains('resource exhausted') ||
           lowerMsg.contains('too many requests') ||
           lowerMsg.contains('model is overloaded') ||
           lowerMsg.contains('service unavailable') ||
           lowerMsg.contains('unavailable');
  }

  // Calculate exponential backoff
  // Exponential backoff: 2s, 4s, 8s, 16s for 503 errors
  int _calculateBackoff(int attempt, int maxSeconds) {
    // For 503 errors: exact exponential backoff (2, 4, 8, 16, 32)
    if (attempt < 4) {
      return (1 << (attempt + 1)); // 2, 4, 8, 16
    }
    // Cap at maxSeconds for attempt 4+
    return maxSeconds;
  }

  // Get a welcome message for new users
  String getWelcomeMessage() {
    return '''👋 Hello! I'm PolicyBot, your AI assistant for government policies.

I can help you with:
• Understanding various government schemes
• Finding information about policies
• Explaining policy benefits and eligibility
• General guidance on government services

What would you like to know about today?''';
  }

  // Get suggested questions
  List<String> getSuggestedQuestions() {
    return [
      'What are the latest agriculture policies?',
      'How do I apply for education scholarships?',
      'What healthcare schemes are available?',
      'Tell me about housing loan policies',
      'What social welfare programs exist?',
    ];
  }
}
