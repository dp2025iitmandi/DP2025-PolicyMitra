import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../services/speech_service.dart';
import '../services/chat_history_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/admin_service.dart';
import '../services/admin_scheme_service.dart';
import '../services/firebase_firestore_service.dart';
import '../services/rate_limiter_service.dart';
import '../models/chat_message_model.dart';
import '../models/policy_model.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? id; // For database storage

  ChatMessage({
    this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  ChatMessageModel toModel() {
    return ChatMessageModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: isUser,
      timestamp: timestamp,
    );
  }

  factory ChatMessage.fromModel(ChatMessageModel model) {
    return ChatMessage(
      id: model.id,
      text: model.text,
      isUser: model.isUser,
      timestamp: model.timestamp,
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final ChatService _chatService = ChatService();
  final AdminSchemeService _adminSchemeService = AdminSchemeService();
  final ChatHistoryService _chatHistoryService = ChatHistoryService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingHistory = false;
  bool _isAdmin = false;
  String? _currentUserId;
  List<String> _uploadedSchemeIds = []; // Track uploaded schemes to prevent duplicates
  
  // Debouncing for message sending
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 500);
  
  // Batch chat history saves
  final List<ChatMessageModel> _pendingChatHistorySaves = [];
  Timer? _batchSaveTimer;
  static const Duration _batchSaveDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    // Delay initialization to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    if (!mounted) return;
    
    // Check if user is admin
    final adminService = Provider.of<AdminService>(context, listen: false);
    _isAdmin = adminService.isAdmin;
    
    // Get current user ID
    final authService = Provider.of<SupabaseAuthService>(context, listen: false);
    final userId = authService.user?.id;
    
    if (userId == null || userId.isEmpty) {
      debugPrint('[CHAT] No authenticated user, using anonymous mode');
      _currentUserId = 'anonymous';
      // Show welcome message for anonymous users
      if (mounted) {
        _addWelcomeMessage();
      }
      return;
    }

    _currentUserId = userId;
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      // Load chat history for this user
      await _loadChatHistory();
    } catch (e) {
      debugPrint('[CHAT] Error during initialization: $e');
    }

    if (!mounted) return;

    setState(() {
      _isLoadingHistory = false;
    });

    // Add welcome message only if no history exists
    if (_messages.isEmpty && mounted) {
      _addWelcomeMessage();
    } else if (mounted) {
      // Scroll to bottom after loading history
      await Future.delayed(const Duration(milliseconds: 200));
      _scrollToBottom();
    }
  }

  Future<void> _loadChatHistory() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint('[CHAT] No user ID available, skipping history load');
      return;
    }

    try {
      debugPrint('[CHAT] Loading chat history for user: $_currentUserId');
      final savedMessages = await _chatHistoryService.loadMessages(_currentUserId!);
      
      if (mounted) {
        if (savedMessages.isNotEmpty) {
          debugPrint('[CHAT] Loaded ${savedMessages.length} messages from history');
          setState(() {
            _messages.clear();
            _messages.addAll(savedMessages.map((m) => ChatMessage.fromModel(m)));
          });
          // Wait a bit for UI to update, then scroll
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            _scrollToBottom();
          }
        } else {
          debugPrint('[CHAT] No previous chat history found');
        }
      }
    } catch (e) {
      debugPrint('[CHAT] Error loading chat history: $e');
      // Don't show error to user, just continue without history
    }
  }

  // Clear chat history for current user
  Future<void> _clearChatHistory() async {
    if (_currentUserId == null || _currentUserId!.isEmpty || _currentUserId == 'anonymous') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No chat history to clear'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to clear all chat history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      // Clear from database
      await _chatHistoryService.clearHistory(_currentUserId!);
      
      // Clear local messages
      if (mounted) {
        setState(() {
          _messages.clear();
        });
        
        // Add welcome message back
        _addWelcomeMessage();
        
        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat history cleared successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[CHAT] Error clearing chat history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing chat history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _batchSaveTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    // Save any pending chat history before disposing
    _savePendingChatHistory();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    final speechService = Provider.of<SpeechService>(context, listen: false);
    
    if (speechService.isListening) {
      // Stop listening
      await speechService.stopListening();
    } else {
      // Start listening
      if (!speechService.isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Clear previous message
      _messageController.clear();
      
      // Start listening
      await speechService.startListening(
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      );

      // Listen for speech results
      speechService.addListener(_onVoiceInputResult);
    }
  }

  void _onVoiceInputResult() {
    final speechService = Provider.of<SpeechService>(context, listen: false);
    
    if (speechService.lastWords.isNotEmpty) {
      _messageController.text = speechService.lastWords;
      
      // Stop listening after getting results
      speechService.stopListening();
      speechService.removeListener(_onVoiceInputResult);
      speechService.clearLastWords();
    }
  }

  void _addWelcomeMessage() {
    String welcomeText;
    if (_isAdmin) {
      welcomeText = '''🔐 **Admin Mode - Scheme Generator**

You can generate government schemes by entering the format:
**"number of schemes, category"**

Example: "4, agriculture" or "10, education"

The schemes will be automatically uploaded to the database.

Available categories: agriculture, education, healthcare, housing, social welfare''';
    } else {
      welcomeText = _chatService.getWelcomeMessage();
    }
    
    final welcomeMessage = ChatMessage(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      text: welcomeText,
      isUser: false,
      timestamp: DateTime.now(),
    );
    
    _addMessage(welcomeMessage);
  }

  void _addMessage(ChatMessage message) {
    if (!mounted) return;
    
    // Check for duplicate messages (same id or same text + timestamp)
    final isDuplicate = _messages.any((m) => 
      (m.id != null && message.id != null && m.id == message.id) ||
      (m.text == message.text && 
       m.isUser == message.isUser && 
       (m.timestamp.difference(message.timestamp).inSeconds.abs() < 2))
    );
    
    if (isDuplicate) {
      debugPrint('[CHAT] Duplicate message detected, skipping: ${message.id}');
      return;
    }
    
    if (!mounted) return;
    setState(() {
      _messages.add(message);
    });
    
    // Force UI update and scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToBottom();
      }
    });

    // Batch save message to database (skip welcome/system messages)
    if (_currentUserId != null && 
        _currentUserId!.isNotEmpty && 
        _currentUserId != 'anonymous' &&
        message.id != null && 
        !message.id!.startsWith('welcome_') &&
        !message.id!.startsWith('warning_') &&
        !message.id!.startsWith('error_') &&
        !message.id!.startsWith('ratelimit_') &&
        !message.id!.startsWith('loading_')) {
      _scheduleBatchSave(message);
    }
  }

  // Schedule batch save for chat history
  void _scheduleBatchSave(ChatMessage message) {
    final messageModel = message.toModel();
    _pendingChatHistorySaves.add(messageModel);
    
    // Cancel existing timer
    _batchSaveTimer?.cancel();
    
    // Start new timer (2 second delay for batching)
    _batchSaveTimer = Timer(_batchSaveDelay, () {
      _savePendingChatHistory();
    });
  }

  // Save pending chat history in batch
  Future<void> _savePendingChatHistory() async {
    if (_pendingChatHistorySaves.isEmpty || 
        _currentUserId == null || 
        _currentUserId!.isEmpty ||
        _currentUserId == 'anonymous') {
      return;
    }
    
    final messagesToSave = List<ChatMessageModel>.from(_pendingChatHistorySaves);
    _pendingChatHistorySaves.clear();
    
    try {
      // Save all messages in batch
      for (final messageModel in messagesToSave) {
        await _chatHistoryService.saveMessage(_currentUserId!, messageModel);
      }
      debugPrint('[CHAT] Batch saved ${messagesToSave.length} message(s) to history');
    } catch (e) {
      debugPrint('[CHAT] Error batch saving messages to history: $e');
      // Re-add failed messages to retry
      _pendingChatHistorySaves.addAll(messagesToSave);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Check rate limiting
    final rateLimiter = RateLimiterService();
    if (!rateLimiter.canMakeRequest()) {
      _addMessage(ChatMessage(
        id: 'ratelimit_${DateTime.now().millisecondsSinceEpoch}',
        text: '⏱️ Too many requests. Please wait a moment before sending another message.',
        isUser: false,
        timestamp: DateTime.now(),
      ));
      return;
    }

    // Cancel any pending debounce
    _debounceTimer?.cancel();

    // Debounce message sending (500ms delay)
    _debounceTimer = Timer(_debounceDelay, () async {
      final userMessage = ChatMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      );

      _addMessage(userMessage);
      _messageController.clear();

      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });
      
      // Record API request
      rateLimiter.recordRequest();

      try {
        // Check if admin mode and input format matches scheme generation
        if (_isAdmin && _isSchemeGenerationFormat(text)) {
          await _handleAdminSchemeGeneration(text);
        } else {
          // Regular chat
          // Build conversation history for context
          List<Map<String, String>> conversationHistory = [];
          
          // Add recent conversation history (last 10 messages to avoid token limits)
          int startIndex = _messages.length > 20 ? _messages.length - 20 : 0;
          for (int i = startIndex; i < _messages.length; i++) {
            conversationHistory.add({
              'role': _messages[i].isUser ? 'user' : 'assistant',
              'content': _messages[i].text,
            });
          }
          
          final response = await _chatService.sendMessage(text, conversationHistory: conversationHistory);
          
          // Check if response indicates the question was not policy-related
          // The AI should include keywords like "I specialize in" or "policy-related" when declining
          final botMessage = ChatMessage(
            id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
            text: response ?? 'Sorry, I encountered an error. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
          );
          _addMessage(botMessage);
        }
      } catch (e) {
        debugPrint('[CHAT] Error sending message: $e');
        if (mounted) {
          _addMessage(ChatMessage(
            id: 'error_${DateTime.now().millisecondsSinceEpoch}',
            text: '❌ Error: ${e.toString()}',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  bool _isSchemeGenerationFormat(String input) {
    // Check if input matches format: "number, category"
    final pattern = RegExp(r'^\d+\s*,\s*\w+', caseSensitive: false);
    return pattern.hasMatch(input);
  }

  Future<void> _handleAdminSchemeGeneration(String input) async {
    try {
      // Normalize input before processing
      final normalizedInput = _adminSchemeService.normalizeInput(input);
      final category = _adminSchemeService.extractCategoryFromInput(normalizedInput);
      
      if (category == null) {
        final errorMessage = ChatMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          text: '⚠️ Could not recognize category. Please use one of: agriculture, education, healthcare, housing, social welfare\n\nExample: "4, agriculture" or "10, education"',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _addMessage(errorMessage);
        return;
      }
      
      // Show loading message with corrected category
      final loadingMessage = ChatMessage(
        id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
        text: '🔧 Generating schemes for "$category" category... This may take a moment.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _addMessage(loadingMessage);

      // Build conversation history
      List<Map<String, String>> conversationHistory = [];
      int startIndex = _messages.length > 20 ? _messages.length - 20 : 0;
      for (int i = startIndex; i < _messages.length; i++) {
        conversationHistory.add({
          'role': _messages[i].isUser ? 'user' : 'assistant',
          'content': _messages[i].text,
        });
      }

      // Generate schemes using admin service with normalized input
      final response = await _adminSchemeService.generateSchemes(normalizedInput, conversationHistory: conversationHistory);
      
      if (response == null || response.isEmpty) {
        final errorMessage = ChatMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          text: '❌ Failed to generate schemes. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _addMessage(errorMessage);
        return;
      }

      // Add response message
      final responseMessage = ChatMessage(
        id: 'response_${DateTime.now().millisecondsSinceEpoch}',
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      _addMessage(responseMessage);

      // Extract number of schemes requested
      final numberMatch = RegExp(r'^(\d+)').firstMatch(input);
      final requestedCount = numberMatch != null ? int.tryParse(numberMatch.group(1) ?? '0') ?? 0 : 0;
      
      if (requestedCount <= 0) {
        final errorMessage = ChatMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          text: '⚠️ Could not determine number of schemes requested. Please use format: "number, category"',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _addMessage(errorMessage);
        return;
      }

      // Parse and upload schemes with retry for duplicates
      debugPrint('[ADMIN_CHAT] Parsing schemes from response...');
      final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
      final exactCategory = category ?? 'Other';
      
      int uploadedCount = 0;
      int retryAttempts = 0;
      final maxRetries = requestedCount * 3; // Allow 3x retries per scheme
      
      // Track uploaded titles and descriptions to avoid duplicates in same batch
      final Set<String> uploadedTitles = {};
      final Set<String> uploadedDescriptions = {};
      
      // Get all existing policies in this category to avoid duplicates
      await firestoreService.filterPoliciesByCategory(exactCategory);
      final existingPolicies = firestoreService.policies;
      final Set<String> existingTitles = existingPolicies.map((p) => 
        p.title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim()
      ).toSet();
      final Set<String> existingDescriptions = existingPolicies.where((p) => 
        p.description != null && p.description!.isNotEmpty
      ).map((p) => 
        p.description!.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim()
      ).toSet();
      
      debugPrint('[ADMIN_CHAT] Found ${existingPolicies.length} existing policies in category "$exactCategory"');
      debugPrint('[ADMIN_CHAT] Existing scheme titles: ${existingTitles.take(5).join(", ")}...');
      
      while (uploadedCount < requestedCount && retryAttempts < maxRetries) {
        // Parse schemes from response
        List<Map<String, dynamic>> schemes = [];
        if (retryAttempts == 0) {
          // First attempt: use the response we already got
          schemes = _adminSchemeService.parseSchemes(response);
        } else {
          // Retry: generate new schemes to replace duplicates
          debugPrint('[ADMIN_CHAT] Retry attempt $retryAttempts: Generating replacement schemes for duplicates...');
          // Include existing schemes in conversation history to avoid repeats
          final enhancedHistory = List<Map<String, String>>.from(conversationHistory ?? []);
          if (existingTitles.isNotEmpty && retryAttempts > 0) {
            // Add a note about existing schemes
            enhancedHistory.add({
              'role': 'system',
              'content': 'NOTE: The following schemes already exist in the database and MUST NOT be generated: ${existingTitles.take(10).join(", ")}. Generate completely different, unique schemes.',
            });
          }
          final retryResponse = await _adminSchemeService.generateSchemes(
            '$requestedCount, ${exactCategory.toLowerCase()}',
            conversationHistory: enhancedHistory,
          );
          if (retryResponse != null && retryResponse.isNotEmpty) {
            schemes = _adminSchemeService.parseSchemes(retryResponse);
          }
        }
        
        if (schemes.isEmpty) {
          if (retryAttempts == 0) {
            debugPrint('[ADMIN_CHAT] ⚠️ No schemes parsed from response');
            final warningMessage = ChatMessage(
              id: 'warning_${DateTime.now().millisecondsSinceEpoch}',
              text: '⚠️ Could not parse schemes from response. Please check the format.',
              isUser: false,
              timestamp: DateTime.now(),
            );
            _addMessage(warningMessage);
          }
          retryAttempts++;
          continue;
        }
        
        // Filter out duplicates from database before processing
        final uniqueSchemes = <Map<String, dynamic>>[];
        for (final schemeData in schemes) {
          final title = schemeData['title']?.toString() ?? '';
          final description = schemeData['description']?.toString() ?? '';
          
          if (title.isEmpty) continue;
          
          // Normalize title for comparison
          final normalizedTitle = title.toLowerCase()
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          
          final normalizedDesc = description.isNotEmpty 
              ? description.toLowerCase()
                  .replaceAll(RegExp(r'[^\w\s]'), '')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim()
              : '';
          
          // Check against existing database schemes
          bool isDuplicate = existingTitles.contains(normalizedTitle);
          if (!isDuplicate && normalizedDesc.isNotEmpty && existingDescriptions.contains(normalizedDesc)) {
            isDuplicate = true;
          }
          
          // Check against already uploaded in this batch
          if (!isDuplicate) {
            isDuplicate = uploadedTitles.contains(normalizedTitle) ||
                (normalizedDesc.isNotEmpty && uploadedDescriptions.contains(normalizedDesc));
          }
          
          if (isDuplicate) {
            debugPrint('[ADMIN_CHAT] ⚠️ Skipping duplicate scheme: "$title"');
            continue;
          }
          
          uniqueSchemes.add(schemeData);
        }
        
        if (uniqueSchemes.isEmpty) {
          debugPrint('[ADMIN_CHAT] ⚠️ All schemes were duplicates, retrying...');
          retryAttempts++;
          if (retryAttempts >= maxRetries) {
            break;
          }
          continue;
        }
        
        // Try to upload each unique scheme
        for (final schemeData in uniqueSchemes) {
          if (uploadedCount >= requestedCount) break;
          
          try {
            final title = schemeData['title']?.toString() ?? 'Untitled Scheme';
            final description = schemeData['description']?.toString() ?? '';
            
            // Normalize for tracking
            final titleLower = title.trim().toLowerCase()
                .replaceAll(RegExp(r'[^\w\s]'), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            final descLower = description.trim().toLowerCase()
                .replaceAll(RegExp(r'[^\w\s]'), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            
            // Create PolicyModel from parsed scheme
            final policy = PolicyModel(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '_${uploadedCount}_${retryAttempts}',
              title: title,
              description: description,
              category: exactCategory,
              link: schemeData['link']?.toString(),
              content: schemeData['content']?.toString() ?? '',
              documentsRequired: schemeData['documentsRequired']?.toString(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Double-check for duplicate in database before uploading
            final isDuplicate = await firestoreService.isDuplicatePolicy(
              policy.title,
              policy.description,
              policy.category,
            );
            
            if (isDuplicate) {
              debugPrint('[ADMIN_CHAT] ⚠️ Duplicate policy rejected: "${policy.title}" - will retry with different scheme');
              // Add to existing sets to avoid retrying
              existingTitles.add(titleLower);
              if (descLower.isNotEmpty) {
                existingDescriptions.add(descLower);
              }
              retryAttempts++;
              continue; // Skip this one, will generate new ones in next iteration
            }

            // Upload to Firestore
            final success = await firestoreService.createPolicy(policy);
            if (success) {
              uploadedCount++;
              _uploadedSchemeIds.add(policy.id);
              uploadedTitles.add(titleLower);
              existingTitles.add(titleLower); // Also add to existing to prevent future duplicates
              if (descLower.isNotEmpty) {
                uploadedDescriptions.add(descLower);
                existingDescriptions.add(descLower);
              }
              debugPrint('[ADMIN_CHAT] ✅ Successfully uploaded scheme: ${policy.title} ($uploadedCount/$requestedCount)');
            } else {
              final errorMsg = firestoreService.error ?? 'Unknown error';
              debugPrint('[ADMIN_CHAT] ❌ Failed to upload scheme "${policy.title}": $errorMsg');
              if (errorMsg.toLowerCase().contains('duplicate')) {
                // Mark as duplicate to avoid retrying
                existingTitles.add(titleLower);
                if (descLower.isNotEmpty) {
                  existingDescriptions.add(descLower);
                }
              }
              retryAttempts++;
            }
          } catch (e, stackTrace) {
            debugPrint('[ADMIN_CHAT] ❌ Exception uploading scheme: $e');
            debugPrint('[ADMIN_CHAT] Stack trace: $stackTrace');
            retryAttempts++;
          }
        }
        
        // If we haven't uploaded enough, continue retry loop
        if (uploadedCount < requestedCount) {
          retryAttempts++;
          if (retryAttempts >= maxRetries) {
            debugPrint('[ADMIN_CHAT] ⚠️ Max retries reached. Uploaded $uploadedCount/$requestedCount schemes.');
            break;
          }
        }
      }

      // Show upload summary
      debugPrint('[ADMIN_CHAT] Upload complete: $uploadedCount out of $requestedCount requested schemes uploaded');
      if (uploadedCount == 0) {
        final summaryMessage = ChatMessage(
          id: 'summary_${DateTime.now().millisecondsSinceEpoch}',
          text: '⚠️ No schemes were uploaded. This might be due to duplicates or errors. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _addMessage(summaryMessage);
      } else if (uploadedCount < requestedCount) {
        final summaryMessage = ChatMessage(
          id: 'summary_${DateTime.now().millisecondsSinceEpoch}',
          text: '⚠️ Successfully uploaded $uploadedCount out of $requestedCount requested schemes. Some schemes were skipped due to duplicates. Please try generating more if needed.',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _addMessage(summaryMessage);
      } else {
        final summaryMessage = ChatMessage(
          id: 'summary_${DateTime.now().millisecondsSinceEpoch}',
          text: '✅ Successfully uploaded all $uploadedCount requested schemes!',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _addMessage(summaryMessage);
      }

      // Refresh policies list
      await firestoreService.fetchPolicies();
      
    } catch (e) {
      debugPrint('[ADMIN_CHAT] Error in scheme generation: $e');
      final errorMessage = ChatMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        text: '❌ Error generating schemes: $e',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _addMessage(errorMessage);
    }
  }

  void _showSuggestedQuestions() {
    final questions = _chatService.getSuggestedQuestions();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Suggested Questions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final question = questions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(question),
                      leading: Icon(
                        Icons.lightbulb_outline,
                        color: Colors.blue[600],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _messageController.text = question;
                        _sendMessage();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PolicyBot Chat'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _clearChatHistory,
          tooltip: 'Clear Chat History',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: _showSuggestedQuestions,
            tooltip: 'Suggested Questions',
          ),
        ],
      ),
      body: Column(
        children: [
          // PolicyBot info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.grey[800] 
                : Colors.blue[50],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue[600],
                  child: const Icon(
                    Icons.smart_toy,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PolicyBot is here to help you with government policies and schemes',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.blue[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Messages
          Expanded(
            child: _isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        // Loading indicator for response
                        return Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.blue[600],
                                child: const Icon(
                                  Icons.smart_toy,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.grey[700] 
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          
          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[850] 
                  : Colors.white,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey[700]! 
                      : Colors.grey[300]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[700] 
                          : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      suffixIcon: Consumer<SpeechService>(
                        builder: (context, speechService, child) {
                          return IconButton(
                            icon: Icon(
                              speechService.isListening ? Icons.mic : Icons.mic_none,
                              color: speechService.isListening ? Colors.red : Colors.grey,
                            ),
                            onPressed: () => _toggleVoiceInput(),
                            tooltip: 'Voice Input',
                          );
                        },
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  backgroundColor: Colors.blue[600],
                  mini: true,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[600],
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Colors.blue[600]
                    : (Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey[700] 
                        : Colors.grey[200]),
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: message.isUser 
                      ? const Radius.circular(20) 
                      : const Radius.circular(4),
                  bottomRight: message.isUser 
                      ? const Radius.circular(4) 
                      : const Radius.circular(20),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser 
                      ? Colors.white 
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[400],
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
