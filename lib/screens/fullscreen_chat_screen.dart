import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:provider/provider.dart';
import '../models/policy_model.dart';
import '../services/groq_service.dart';
import '../services/chat_history_service.dart';

class FullscreenChatScreen extends StatefulWidget {
  final PolicyModel? policy;
  final String sessionId;

  const FullscreenChatScreen({
    super.key,
    this.policy,
    required this.sessionId,
  });

  @override
  State<FullscreenChatScreen> createState() => _FullscreenChatScreenState();
}

class _FullscreenChatScreenState extends State<FullscreenChatScreen> {
  final List<types.Message> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final GroqService _groqService = GroqService();
  bool _isLoadingResponse = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _loadChatHistory() {
    final chatHistoryService = Provider.of<ChatHistoryService>(context, listen: false);
    final chatMessages = chatHistoryService.getSessionMessages(widget.sessionId);
    
    setState(() {
      _messages.clear();
      for (final chatMessage in chatMessages) {
        _messages.add(types.TextMessage(
          id: chatMessage.id,
          text: chatMessage.text,
          author: types.User(
            id: chatMessage.isUser ? 'user' : 'bot',
            firstName: chatMessage.isUser ? 'You' : 'Policy Assistant',
          ),
          createdAt: chatMessage.timestamp.millisecondsSinceEpoch,
        ));
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Add user message
    final userMessage = types.TextMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      author: const types.User(
        id: 'user',
        firstName: 'You',
      ),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.add(userMessage);
      _isLoadingResponse = true;
    });

    _messageController.clear();

    // Save to chat history
    final chatHistoryService = Provider.of<ChatHistoryService>(context, listen: false);
    chatHistoryService.addMessage(text, true, policy: widget.policy);

    // Get response from Gemini
    try {
      String response;
      
      if (widget.policy != null) {
        // Policy-specific chat
        if (text.toLowerCase().contains('hello') || text.toLowerCase().contains('hi')) {
          response = 'Hello! I\'m here to help you understand "${widget.policy!.title}". You can ask me any questions about this policy.';
        } else {
          response = await _groqService.askQuestion(text, widget.policy!.content) ?? 
                    'Sorry, I could not process your question. Please try again.';
        }
      } else {
        // Global chat
        response = await _groqService.askQuestion(text, '') ?? 
                  'Sorry, I could not process your question. Please try again.';
      }

      final botMessage = types.TextMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: response,
        author: const types.User(
          id: 'bot',
          firstName: 'Policy Assistant',
        ),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      if (mounted) {
        setState(() {
          _messages.add(botMessage);
          _isLoadingResponse = false;
        });
        
        // Save bot response to chat history
        chatHistoryService.addMessage(response, false, policy: widget.policy);
      }
    } catch (e) {
      final errorMessage = types.TextMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: 'Sorry, there was an error processing your question. Please try again.',
        author: const types.User(
          id: 'bot',
          firstName: 'Policy Assistant',
        ),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      if (mounted) {
        setState(() {
          _messages.add(errorMessage);
          _isLoadingResponse = false;
        });
        
        chatHistoryService.addMessage('Sorry, there was an error processing your question. Please try again.', false, policy: widget.policy);
      }
      debugPrint('Error asking question to Gemini: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.policy?.title ?? 'Policy Assistant'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.archive),
            onPressed: () {
              final chatHistoryService = Provider.of<ChatHistoryService>(context, listen: false);
              chatHistoryService.archiveSession(widget.sessionId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat archived successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop();
            },
            tooltip: 'Archive Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Policy info banner (if policy-specific chat)
          if (widget.policy != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chatting about: ${widget.policy!.title}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.policy!.description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          
          // Chat messages
          Expanded(
            child: Chat(
              messages: _messages,
              onSendPressed: (message) {
                if (message is types.TextMessage) {
                  _messageController.text = message.text;
                  _sendMessage();
                }
              },
              user: const types.User(
                id: 'user',
                firstName: 'You',
              ),
              showUserAvatars: true,
              showUserNames: true,
              theme: DefaultChatTheme(
                primaryColor: Colors.blue[600]!,
                inputBackgroundColor: Colors.grey[100]!,
                inputTextColor: Colors.black,
                inputBorderRadius: BorderRadius.circular(20),
                userAvatarNameColors: [Colors.blue[600]!],
              ),
            ),
          ),
          
          // Loading indicator
          if (_isLoadingResponse)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Policy Assistant is typing...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
