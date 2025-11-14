import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

// Request queue entry to store request parameters
class _QueueEntry {
  final Completer<String?> completer;
  final String userInput;
  final List<Map<String, String>>? conversationHistory;
  
  _QueueEntry({
    required this.completer,
    required this.userInput,
    this.conversationHistory,
  });
}

class AdminSchemeService {
  static const String _modelName = 'llama-3.3-70b-versatile';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  // Get API key from config
  String get _apiKey => AppConfig.groqApiKey;
  
  // Request queue to handle concurrent API calls sequentially
  final Queue<_QueueEntry> _requestQueue = Queue<_QueueEntry>();
  bool _isProcessingQueue = false;
  
  // Cache for normalized inputs to avoid duplicate processing
  String? _lastNormalizedInput;
  String? _lastInput;
  
  static const String _systemInstruction = '''
You are a specialized scheme generation assistant for Indian Central Government Schemes. Your task is to provide REAL, CURRENT, and ACCURATE government scheme information based on the user's input format.

**CRITICAL REQUIREMENTS FOR ACCURACY:**

1. **REAL SCHEMES ONLY:** You MUST provide only REAL, ACTUAL Indian Central Government schemes that exist. Do NOT make up or invent scheme names, details, or information.

2. **ACCURATE INFORMATION:** All scheme details (description, benefits, eligibility, documents) must be ACCURATE and FACTUAL based on actual government scheme documentation. Provide specific, real information, not generic placeholder text.

3. **CURRENT SCHEMES:** Provide only CURRENT, ACTIVE schemes that are still running. Do not include expired, discontinued, or old schemes.

4. **SPECIFIC DETAILS:** Include specific details like:
   - Exact ministry/department name
   - Actual benefit amounts or percentages (if applicable)
   - Real eligibility criteria with specific income limits, age limits, etc.
   - Actual document names and requirements
   - Official scheme launch dates (if known)

5. **VERIFIED LINKS:** Provide ONLY real, working official government website links. Use actual URLs from government portals like:
   - pmindia.gov.in
   - india.gov.in
   - Ministry-specific websites
   - Official scheme portals
   If you cannot provide a real, verified link, state "No link available" instead of making up URLs.

**STRICT RULES AND CONSTRAINTS:**

1. **Input Format is Mandatory:** The user's input will ALWAYS be in the exact format: 'number of schemes, category'.

2. **Output Format is Mandatory:** Every scheme generated MUST STRICTLY adhere to the detailed structure provided below.

3. **Scheme Amount:** You must strictly provide the exact number of schemes requested. Provide ALL requested schemes in a single response.

4. **Category Names:** The category must strictly be one of the following five names: 'agriculture', 'education', 'healthcare', 'housing', 'social welfare'. Do not use variations.

5. **Scheme Status:** All schemes must be current, unexpired, and Central Government schemes of India.

6. **Ordering:** Schemes must be ordered in descending order of popularity/reach.

7. **NO DUPLICATES (CRITICAL):** You must never provide a scheme that has already been generated in this conversation. Use the chat history to enforce this non-duplication rule strictly.

8. **Do Not Ask Questions:** Never ask any clarifying questions, repeat instructions, or ask for the next step.

9. **LINK REQUIREMENTS (MANDATORY - CRITICAL):**
   - **MANDATORY:** You MUST provide a working, verified official government link for EVERY scheme
   - **PRIORITY 1:** Direct link to the specific policy/scheme official webpage on government websites
   - **PRIORITY 2:** Official PDF document link from government websites
   - **PRIORITY 3:** If no official link exists, write: "No link available"
   - The link MUST be a complete, valid URL starting with http:// or https://
   - DO NOT provide broken links, homepages, or generic pages
   - DO NOT make up or invent URLs
   - Always provide REAL, VERIFIED government website links only

**MANDATORY OUTPUT SCHEME STRUCTURE:**

Each scheme must be presented using the following Markdown/text template. Use clean formatting with minimal asterisks. Use **bold** only for section headings. Provide REAL, ACCURATE information for each field.

---

## [Number]. [Real Scheme Name]

### Policy Details

**Description:**
[REAL, detailed policy description including ministry name, launch year, objectives, and actual scheme details. Use specific, factual information.]

**Benefits:**
[Numbered list of at least 4 REAL benefits with specific details, amounts, or percentages where applicable. Use actual scheme benefits, not generic text.]

**Eligibility:**
[Numbered list with REAL, specific eligibility criteria including actual income limits, age requirements, status requirements, exclusions, etc. Use factual eligibility criteria from the actual scheme.]

### Documents Required

[Bulleted list with REAL documents required (e.g., Aadhaar Card, Income Certificate, Bank Account Details, etc.). List actual documents needed for the scheme.]

**Related Link:**
[If real official link exists: [Link Text](REAL_OFFICIAL_URL)]
[If no real link: No link available]

-----
''';

  // Build enhanced system instruction with uniqueness requirements and deeper content
  String _buildEnhancedInstruction(List<Map<String, String>>? conversationHistory) {
    // Extract already generated scheme names from conversation history
    final Set<String> existingSchemeNames = {};
    if (conversationHistory != null) {
      for (var entry in conversationHistory) {
        final content = entry['content'] ?? '';
        // Extract scheme names from previous responses (looking for "## [Number]. [Scheme Name]")
        final schemePattern = RegExp(r'^##\s*\d+\.\s*(.+)$', multiLine: true);
        final matches = schemePattern.allMatches(content);
        for (var match in matches) {
          if (match.groupCount >= 1) {
            final schemeName = match.group(1)?.trim().toLowerCase() ?? '';
            if (schemeName.isNotEmpty) {
              existingSchemeNames.add(schemeName);
            }
          }
        }
      }
    }
    
    final existingSchemesList = existingSchemeNames.isNotEmpty
        ? '\n\n**ALREADY GENERATED SCHEMES IN THIS CONVERSATION (DO NOT REPEAT - CRITICAL):**\n${existingSchemeNames.map((name) => '- $name').join('\n')}\n\n**ABSOLUTE REQUIREMENT:** You MUST generate schemes that are COMPLETELY DIFFERENT from all schemes listed above. Check each scheme name carefully before generating.'
        : '';
    
    return '''
$_systemInstruction

**CRITICAL: UNIQUENESS REQUIREMENT - NO REPEATS**
${existingSchemesList.isNotEmpty ? existingSchemesList : 'No schemes have been generated yet in this conversation. Generate unique schemes.'}

**ABSOLUTE RULES FOR UNIQUENESS:**
1. **NO DUPLICATES:** You MUST NEVER generate any scheme that matches an already generated scheme name (case-insensitive, ignoring punctuation).
2. **CHECK CAREFULLY:** Before generating each scheme, check if a similar scheme name exists in the list above.
3. **COMPLETE UNIQUENESS:** Each scheme name must be COMPLETELY UNIQUE and DISTINCT from all previously generated schemes.
4. **NO VARIATIONS:** Do NOT generate variations of the same scheme (e.g., "PM-KISAN", "PM KISAN", "Pradhan Mantri Kisan Samman Nidhi" are the SAME scheme - only generate once).
5. **DIFFERENT SCHEMES:** If you run out of unique schemes in a category, generate the most relevant and important schemes that haven't been generated yet, even if they are less popular.

**DEEP RESEARCH AND COMPREHENSIVE CONTENT REQUIREMENTS:**

You MUST provide DEEP, COMPREHENSIVE, FACTUAL information about each scheme. Research thoroughly and provide:

1. **DETAILED DESCRIPTION (200-300 words minimum):**
   - Exact ministry/department name (e.g., "Ministry of Agriculture and Farmers' Welfare")
   - Official launch date (year and month if known)
   - Scheme objectives and goals
   - Target beneficiaries (specific groups)
   - Implementation mechanism
   - Current status and recent updates
   - Budget allocation (if known)
   - Coverage and reach

2. **COMPREHENSIVE BENEFITS (8-10 benefits minimum):**
   - Exact benefit amounts (e.g., "₹6,000 per year in three installments")
   - Specific percentages or figures (e.g., "50% subsidy up to ₹2.5 lakhs")
   - Real impact details (e.g., "Covers 12 crore farmers")
   - Number of beneficiaries (if known)
   - Financial assistance details
   - Non-financial benefits
   - Long-term benefits

3. **DETAILED ELIGIBILITY CRITERIA (10-15 points minimum):**
   - Exact income limits (e.g., "Annual income less than ₹3 lakhs")
   - Age requirements (e.g., "18-60 years")
   - Status requirements (BPL, APL, SC, ST, OBC, General)
   - Geographic restrictions (e.g., "Rural areas only", "Specific states")
   - Caste/category requirements
   - Landholding limits (for agriculture schemes)
   - Family size requirements
   - Educational qualifications (if applicable)
   - Employment status (if applicable)
   - All exclusion criteria (who is NOT eligible)
   - Income certificate requirements
   - Residency requirements

4. **COMPLETE DOCUMENTS LIST (10-15 documents minimum):**
   - Identity documents: Aadhaar Card, PAN Card, Voter ID, Driving License
   - Address proof: Residence certificate, Utility bills, Rent agreement
   - Income certificates: Income certificate, BPL card, APL card
   - Bank account details: Bank passbook, Canceled cheque, Account statement
   - Caste certificates: SC/ST certificate, OBC certificate (if applicable)
   - Land records: Land ownership documents, Land lease documents (for agriculture)
   - Photos: Passport size photos (specify number)
   - Family details: Family certificate, Ration card
   - Employment documents: Employment certificate, Business license (if applicable)
   - Educational documents: Educational certificates (if applicable)
   - Any other specific documents required

5. **APPLICATION PROCESS (Detailed steps):**
   - How to apply: Online/Offline/Both
   - Application portal URLs: Official website links
   - Step-by-step application process
   - Required documents checklist
   - Application fees (if any)
   - Processing time
   - Contact information: Helpline numbers, email, offices
   - How to track application status

6. **RELATED LINK (REAL, VERIFIED ONLY):**
   - Provide ONLY real, working official government website links
   - Do NOT make up or invent URLs
   - Use actual URLs from: pmindia.gov.in, india.gov.in, ministry websites, official scheme portals
   - Verify that the link is accessible and points to the specific scheme
   - If no real link exists, write: "No link available"

**ENHANCED FORMATTING REQUIREMENTS:**

Use clean, professional formatting:
- Use **bold** for section headings ONLY (Description:, Benefits:, Eligibility:, etc.)
- Use numbered lists (1., 2., 3.) for benefits and eligibility
- Use bulleted lists (- or *) for documents
- Use proper spacing between sections
- Make content comprehensive but readable
- Use clear, concise language
- Include specific numbers, dates, and figures
- Format links properly: [Link Text](URL)

**OUTPUT FORMAT:**

## [Number]. [Real Scheme Name - Full Official Name]

### Policy Details

**Description:**
[200-300 words: REAL, detailed description with ministry name, launch date, objectives, target beneficiaries, implementation, current status, budget, coverage]

**Benefits:**
1. [Specific benefit with exact amount/percentage]
2. [Specific benefit with exact amount/percentage]
3. [Specific benefit with exact amount/percentage]
... (8-10 benefits minimum)

**Eligibility:**
1. [Specific eligibility criteria with exact requirements]
2. [Specific eligibility criteria with exact requirements]
3. [Specific eligibility criteria with exact requirements]
... (10-15 eligibility points minimum)

### Documents Required

- [Document 1: Specific requirement]
- [Document 2: Specific requirement]
- [Document 3: Specific requirement]
... (10-15 documents minimum)

### Application Process

[Detailed application process with steps, portal URLs, contact information, processing time]

**Related Link:**
[Real official link: [Link Text](REAL_URL)] OR [No link available]

-----

**NOW GENERATE UNIQUE, COMPREHENSIVE, ACCURATE SCHEMES FOLLOWING ALL REQUIREMENTS ABOVE.**
''';
  }

  // Send message to Groq with admin system instruction (with queue)
  Future<String?> generateSchemes(String userInput, {List<Map<String, String>>? conversationHistory}) async {
    // Add request to queue
    final completer = Completer<String?>();
    _requestQueue.add(_QueueEntry(
      completer: completer,
      userInput: userInput,
      conversationHistory: conversationHistory,
    ));
    
    // Start processing queue if not already processing
    if (!_isProcessingQueue) {
      _processQueue();
    }
    
    // Wait for this request to be processed
    return completer.future;
  }
  
  // Process requests in queue sequentially
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _requestQueue.isEmpty) {
      return;
    }
    
    _isProcessingQueue = true;
    
    while (_requestQueue.isNotEmpty) {
      final entry = _requestQueue.removeFirst();
      
      try {
        debugPrint('[ADMIN_SCHEME_QUEUE] Processing request: ${entry.userInput} (Queue size: ${_requestQueue.length})');
        final result = await _generateSchemesWithRetry(entry.userInput, entry.conversationHistory);
        entry.completer.complete(result);
      } catch (e) {
        debugPrint('[ADMIN_SCHEME_QUEUE] Error processing request: $e');
        entry.completer.complete('Error: Failed to generate schemes. Please try again later.');
      }
      
      // Small delay between requests to avoid overwhelming the API
      if (_requestQueue.isNotEmpty) {
        debugPrint('[ADMIN_SCHEME_QUEUE] Waiting 500ms before next request...');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    _isProcessingQueue = false;
    debugPrint('[ADMIN_SCHEME_QUEUE] Queue processing completed');
  }
  
  // Actual generation with retry logic (private method)
  Future<String?> _generateSchemesWithRetry(String userInput, List<Map<String, String>>? conversationHistory) async {
    const maxRetries = 5;
    const maxBackoffSeconds = 30;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Normalize input (auto-correct category) - cache to avoid duplicate calls
        final normalizedInput = (userInput == _lastInput && _lastNormalizedInput != null) 
            ? _lastNormalizedInput! 
            : normalizeInput(userInput);
        _lastInput = userInput;
        _lastNormalizedInput = normalizedInput;
        debugPrint('[ADMIN_SCHEME] Original input: $userInput');
        debugPrint('[ADMIN_SCHEME] Normalized input: $normalizedInput');
        
        // Build messages for Groq API
        List<Map<String, String>> messages = [];
        
        // Build enhanced system instruction with uniqueness requirements
        final enhancedInstruction = _buildEnhancedInstruction(conversationHistory);
        
        messages.add({
          'role': 'system',
          'content': enhancedInstruction,
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
        
        // Add current user input
        messages.add({
          'role': 'user',
          'content': normalizedInput,
        });

        final requestBody = {
          'model': _modelName,
          'messages': messages,
          'temperature': 0.2, // Lower temperature for more consistent, factual responses
          'max_tokens': 25000, // Increased for more detailed scheme responses
          'top_p': 0.9,
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

        debugPrint('Admin Scheme API ($_modelName) Response Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // Extract and log token usage
          if (data['usage'] != null) {
            final usage = data['usage'];
            final promptTokens = usage['prompt_tokens'] ?? 0;
            final completionTokens = usage['completion_tokens'] ?? 0;
            final totalTokens = usage['total_tokens'] ?? 0;
            debugPrint('[ADMIN_SCHEME_TOKEN_USAGE] Prompt: $promptTokens, Completion: $completionTokens, Total: $totalTokens');
          }
          
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            final choice = data['choices'][0];
            if (choice['message'] != null && 
                choice['message']['content'] != null) {
              return choice['message']['content'];
            }
          }
          // Check for error in response
          if (data['error'] != null) {
            final errorMsg = data['error']['message'] ?? '';
            debugPrint('API returned error: $errorMsg');
            if (_isOverloadError(errorMsg)) {
              if (attempt < maxRetries - 1) {
                final backoffSeconds = _calculateBackoff(attempt, maxBackoffSeconds);
                debugPrint('Model overloaded, retrying after ${backoffSeconds}s...');
                await Future.delayed(Duration(seconds: backoffSeconds));
                continue;
              }
            }
          }
        } else if (response.statusCode == 429 || response.statusCode == 503) {
          // Rate limit or service unavailable - retry with backoff
          if (attempt < maxRetries - 1) {
            final backoffSeconds = _calculateBackoff(attempt, maxBackoffSeconds);
            debugPrint('Rate limit/service unavailable, retrying after ${backoffSeconds}s...');
            await Future.delayed(Duration(seconds: backoffSeconds));
            continue;
          }
        } else {
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
          
          debugPrint('Admin Scheme API error: ${response.statusCode} - ${response.body} (attempt ${attempt + 1})');
        }
        
        // If we get here and it's the last attempt, return error
        if (attempt == maxRetries - 1) {
          return 'Error: Failed to generate schemes after multiple attempts. The service might be temporarily unavailable. Please try again later.';
        }
        
      } catch (e) {
        debugPrint('Error calling Groq API ($_modelName, attempt ${attempt + 1}): $e');
        
        if (e is TimeoutException) {
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(seconds: (attempt + 1) * 2));
            continue;
          }
        }
        
        // For other errors, wait before retry
        if (attempt < maxRetries - 1) {
          final backoffSeconds = _calculateBackoff(attempt, maxBackoffSeconds);
          await Future.delayed(Duration(seconds: backoffSeconds));
        } else {
          return 'Error: Failed to generate schemes. Please try again later.';
        }
      }
    }
    
    return 'Error: Failed to generate schemes after all retries. Please try again later.';
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

  // Calculate exponential backoff with jitter
  // Exponential backoff: 2s, 4s, 8s, 16s for 503 errors
  int _calculateBackoff(int attempt, int maxSeconds) {
    // For 503 errors: exact exponential backoff (2, 4, 8, 16, 32)
    if (attempt < 4) {
      return (1 << (attempt + 1)); // 2, 4, 8, 16
    }
    // Cap at maxSeconds for attempt 4+
    return maxSeconds;
  }

  // Parse the Groq response and extract schemes
  List<Map<String, dynamic>> parseSchemes(String response) {
    final List<Map<String, dynamic>> schemes = [];
    
    try {
      // Split by scheme separator "---"
      final schemeBlocks = response.split('---');
      
      for (final block in schemeBlocks) {
        if (block.trim().isEmpty) continue;
        
        try {
          final scheme = _parseSingleScheme(block.trim());
          if (scheme != null && scheme['title'] != null && scheme['title']!.toString().isNotEmpty) {
            schemes.add(scheme);
          }
        } catch (e) {
          debugPrint('Error parsing scheme block: $e');
        }
      }
      
      debugPrint('Parsed ${schemes.length} schemes from response');
    } catch (e) {
      debugPrint('Error parsing schemes: $e');
    }
    
    return schemes;
  }

  Map<String, dynamic>? _parseSingleScheme(String block) {
    try {
      final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      
      String? title;
      String? category;
      String description = '';
      String benefits = '';
      String eligibility = '';
      String documentsRequired = '';
      String? link;
      
      String currentSection = '';
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        
        // Extract title from "## [Number]. [Scheme Name]"
        if (line.startsWith('##')) {
          final titleMatch = RegExp(r'##\s*\d+\.\s*(.+)').firstMatch(line);
          if (titleMatch != null) {
            title = titleMatch.group(1)?.trim();
          }
        }
        
        // Extract category from title or determine from context
        // (This will be set by the user input, we'll need to pass it)
        
        // Section headers
        if (line.toLowerCase().contains('policy details')) {
          currentSection = 'policy';
          continue;
        }
        
        if (line.toLowerCase().contains('description')) {
          currentSection = 'description';
          continue;
        }
        
        if (line.toLowerCase().contains('benefits')) {
          currentSection = 'benefits';
          continue;
        }
        
        if (line.toLowerCase().contains('detailed eligibility criteria') || 
            line.toLowerCase().contains('eligibility criteria')) {
          currentSection = 'eligibility';
          continue;
        }
        
        if (line.toLowerCase().contains('documents required')) {
          currentSection = 'documents';
          continue;
        }
        
        if (line.toLowerCase().contains('related link')) {
          currentSection = 'link';
          continue;
        }
        
        // Extract link from markdown format [Link Text](URL)
        if (line.contains('[') && line.contains('](') && line.contains(')')) {
          final linkMatch = RegExp(r'\[([^\]]+)\]\(([^\)]+)\)').firstMatch(line);
          if (linkMatch != null) {
            link = linkMatch.group(2)?.trim();
          }
          continue;
        }
        
        // Accumulate content based on current section
        if (currentSection == 'description' && !line.toLowerCase().contains('description')) {
          if (description.isNotEmpty) description += '\n';
          description += line;
        } else if (currentSection == 'benefits' && !line.toLowerCase().contains('benefits')) {
          if (benefits.isNotEmpty) benefits += '\n';
          benefits += line;
        } else if (currentSection == 'eligibility' && !line.toLowerCase().contains('eligibility')) {
          if (eligibility.isNotEmpty) eligibility += '\n';
          eligibility += line;
        } else if (currentSection == 'documents' && !line.toLowerCase().contains('documents')) {
          if (documentsRequired.isNotEmpty) documentsRequired += '\n';
          documentsRequired += line;
        }
      }
      
      // Combine description, benefits, and eligibility into content
      String content = '';
      if (benefits.isNotEmpty) {
        content += '*Benefits*\n$benefits\n\n';
      }
      if (eligibility.isNotEmpty) {
        content += '*Eligibility*\n$eligibility';
      }
      
      if (title == null || title.isEmpty) {
        return null;
      }
      
      return {
        'title': title,
        'description': description.isNotEmpty ? description : 'No description available.',
        'content': content.isNotEmpty ? content : 'No policy details available.',
        'documentsRequired': documentsRequired.isNotEmpty ? documentsRequired : 'No documents specified.',
        'link': link ?? '',
      };
    } catch (e) {
      debugPrint('Error parsing single scheme: $e');
      return null;
    }
  }

  // Map to exact database category names (capitalized as they exist in database)
  static const Map<String, String> _categoryMapping = {
    // Exact database category names
    'Agriculture': 'Agriculture',
    'Education': 'Education',
    'Healthcare': 'Healthcare',
    'Housing': 'Housing',
    'Social Welfare': 'Social Welfare',
    // Lowercase variations
    'agriculture': 'Agriculture',
    'education': 'Education',
    'healthcare': 'Healthcare',
    'housing': 'Housing',
    'social welfare': 'Social Welfare',
  };

  // Valid categories with their variations (comprehensive mapping for all common variations)
  static const Map<String, List<String>> _categoryVariations = {
    'Agriculture': ['agriculture', 'agricultural', 'farming', 'farm', 'agri', 'agr', 'crop', 'crops', 'farmer', 'farmers', 'cultivation'],
    'Education': ['education', 'educational', 'school', 'study', 'learn', 'learning', 'student', 'students', 'university', 'college', 'teach', 'teaching'],
    'Healthcare': ['healthcare', 'health', 'medical', 'medicine', 'health care', 'med', 'hospital', 'hospitals', 'treatment', 'clinic', 'doctor'],
    'Housing': ['housing', 'house', 'home', 'residence', 'shelter', 'residential', 'dwelling', 'property', 'accommodation', 'flat', 'apartment'],
    'Social Welfare': ['social welfare', 'socialwelfare', 'welfare', 'social', 'social-wellfare', 'benefits', 'scheme', 'schemes', 'aid', 'assistance', 'support']
  };

  // Extract and normalize category from user input (format: "number, category")
  // Returns the exact database category name (capitalized)
  String? extractCategoryFromInput(String userInput) {
    try {
      final parts = userInput.split(',').map((p) => p.trim()).toList();
      if (parts.length >= 2) {
        String category = parts[1].toLowerCase().trim();
        
        // First check direct mapping (exact match)
        final normalizedInput = parts[1].trim();
        if (_categoryMapping.containsKey(normalizedInput)) {
          return _categoryMapping[normalizedInput];
        }
        
        // Check lowercase mapping
        if (_categoryMapping.containsKey(category)) {
          return _categoryMapping[category];
        }
        
        // Check variations and map to exact database category
        for (final entry in _categoryVariations.entries) {
          final dbCategoryName = entry.key; // This is the exact database name
          final variations = entry.value;
          
          // Check exact match with variations (lowercase)
          if (variations.contains(category)) {
            return dbCategoryName; // Return exact database category name
          }
          
          // Check if category contains any variation or vice versa
          for (final variation in variations) {
            if (category.contains(variation) || variation.contains(category)) {
              return dbCategoryName; // Return exact database category name
            }
          }
          
          // Check similarity (simple string matching)
          if (_isSimilar(category, dbCategoryName.toLowerCase()) || 
              variations.any((v) => _isSimilar(category, v))) {
            return dbCategoryName; // Return exact database category name
          }
        }
        
        // Last resort: partial matching
        for (final entry in _categoryVariations.entries) {
          final dbCategoryName = entry.key;
          final dbCategoryLower = dbCategoryName.toLowerCase();
          
          if (dbCategoryLower.startsWith(category.substring(0, category.length > 3 ? 3 : category.length)) ||
              category.startsWith(dbCategoryLower.substring(0, dbCategoryLower.length > 3 ? 3 : dbCategoryLower.length))) {
            return dbCategoryName; // Return exact database category name
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting category: $e');
    }
    return null;
  }

  // Simple similarity check (for common typos)
  bool _isSimilar(String str1, String str2) {
    if (str1.length == str2.length) {
      int differences = 0;
      for (int i = 0; i < str1.length; i++) {
        if (str1[i] != str2[i]) {
          differences++;
        }
      }
      // Allow 1-2 character differences for typos
      return differences <= 2;
    }
    
    // Check if one contains the other (allowing missing characters)
    if (str1.length >= str2.length - 2 && str1.length <= str2.length + 2) {
      return str1.contains(str2.substring(0, str2.length > 4 ? 4 : str2.length)) ||
             str2.contains(str1.substring(0, str1.length > 4 ? 4 : str1.length));
    }
    
    return false;
  }

  // Normalize user input before sending to Groq
  // Maps common variations to standard category names (e.g., "house" → "housing")
  String normalizeInput(String userInput) {
    try {
      final parts = userInput.split(',').map((p) => p.trim()).toList();
      if (parts.length >= 2) {
        final number = parts[0].trim();
        String originalCategory = parts[1].trim();
        String category = originalCategory.toLowerCase().trim();
        
        // Map to lowercase standard form for Groq using exact DB category name
        final dbCategory = extractCategoryFromInput(userInput);
        if (dbCategory != null) {
          // Use lowercase for Groq prompt, but remember the exact DB name
          category = dbCategory.toLowerCase();
          debugPrint('[NORMALIZE] Mapped "$originalCategory" → "$category" (DB: $dbCategory)');
        } else {
          debugPrint('[NORMALIZE] Could not map category: "$originalCategory"');
        }
        
        return '$number, $category';
      }
    } catch (e) {
      debugPrint('Error normalizing input: $e');
    }
    return userInput; // Return original if normalization fails
  }
}

