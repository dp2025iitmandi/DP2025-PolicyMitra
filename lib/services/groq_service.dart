import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class GroqService {
  static const String _modelName = 'llama-3.3-70b-versatile';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  // Get API key from config
  String get _apiKey => AppConfig.groqApiKey;

  // Send question with policy content to Groq API
  Future<String?> askQuestion(String question, String policyContent) async {
    return await _askQuestionWithRetry(question, policyContent);
  }

  // Ask question with retry logic
  Future<String?> _askQuestionWithRetry(String question, String policyContent) async {
    const maxRetries = 5;
    const maxBackoffSeconds = 30;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final prompt = '''
You are a helpful assistant that answers questions about government policies. 
Please provide accurate and helpful information based on the policy content provided.

Policy Content:
${policyContent}

Question: ${question}

Please provide a clear and concise answer based on the policy information above. If the question cannot be answered from the provided policy content, please state that clearly.
''';

        final requestBody = {
          'model': _modelName,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
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
            debugPrint('[GROQ_TOKEN_USAGE] Prompt: $promptTokens, Completion: $completionTokens, Total: $totalTokens');
          }
          
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            final choice = data['choices'][0];
            if (choice['message'] != null && 
                choice['message']['content'] != null) {
              return choice['message']['content'];
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
          
          debugPrint('Groq API error: ${response.statusCode} - ${response.body} (attempt ${attempt + 1})');
          // If last attempt failed, return error message
          if (attempt == maxRetries - 1) {
            return 'I\'m having trouble connecting to the AI service right now. This might be due to high demand. Please wait a moment and try again.';
          }
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
          return 'I\'m having trouble connecting to the AI service right now. This might be due to high demand. Please wait a moment and try again.';
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
        lowerMsg.contains('rate limit') ||
        lowerMsg.contains('quota') ||
        lowerMsg.contains('too many requests') ||
        lowerMsg.contains('service unavailable') ||
        lowerMsg.contains('unavailable');
  }

  // Exponential backoff: 2s, 4s, 8s, 16s for 503 errors
  int _calculateBackoff(int attempt, int maxSeconds) {
    // For 503 errors: exact exponential backoff (2, 4, 8, 16, 32)
    if (attempt < 4) {
      return (1 << (attempt + 1)); // 2, 4, 8, 16
    }
    // Cap at maxSeconds for attempt 4+
    return maxSeconds;
  }

  // Generate a summary of the policy content
  Future<String?> generatePolicySummary(String policyContent) async {
    const maxRetries = 3;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final prompt = '''
Please provide a concise summary of the following policy content. 
Focus on the key points, benefits, and important details that users should know.

Policy Content:
$policyContent

Please provide a clear and well-structured summary.
''';

        final requestBody = {
          'model': _modelName,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.3,
          'max_tokens': 10000,
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

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            final choice = data['choices'][0];
            if (choice['message'] != null && 
                choice['message']['content'] != null) {
              return choice['message']['content'];
            }
          }
        } else if (response.statusCode == 429 || response.statusCode == 503) {
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(seconds: (attempt + 1) * 2));
            continue;
          }
        }
      } catch (e) {
        debugPrint('Error generating policy summary (attempt ${attempt + 1}): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        }
      }
    }
    
    return null;
  }

  // Generate video script from policy data
  Future<String?> generateVideoScriptFromPolicy(Map<String, dynamic> policyData) async {
    if (_apiKey.isEmpty) {
      debugPrint('[GroqService] GROQ_API_KEY not provided. Skipping video script generation.');
      return null;
    }

    final prompt = _buildVideoScriptPrompt(policyData);
    return generateVideoScript(prompt);
  }

  // Build video script prompt
  String _buildVideoScriptPrompt(Map<String, dynamic> policyData) {
    final title = policyData['title']?.toString() ?? '';
    final description = policyData['description']?.toString() ?? '';
    final category = policyData['category']?.toString() ?? '';
    
    String eligibilityText = '';
    final eligibility = policyData['eligibility'];
    if (eligibility is List) {
      eligibilityText = eligibility.join(', ');
    } else if (eligibility != null) {
      eligibilityText = eligibility.toString();
    }
    
    String documentsText = '';
    final documents = policyData['documentsRequired'];
    if (documents is List) {
      documentsText = documents.join(', ');
    } else if (documents != null) {
      documentsText = documents.toString();
    }
    
    String benefitsText = '';
    final benefits = policyData['benefits'];
    if (benefits is List) {
      benefitsText = benefits.join(', ');
    } else if (benefits != null) {
      benefitsText = benefits.toString();
    }

    return '''
You are a professional script writer for Indian government policy explanation videos. Create a clear, engaging Hindi narration script for an AI avatar video.

POLICY DETAILS:

Title: $title
Category: $category
Description: $description
Eligibility: $eligibilityText
Required Documents: $documentsText
Benefits: $benefitsText

REQUIREMENTS:

1. Write in Hindi (Devanagari script)
2. Length: EXACTLY 200-250 words
3. Tone: Professional, warm, and encouraging
4. Structure:
   - Opening (2-3 sentences): Greet and introduce the scheme name
   - Body (4-6 sentences): Explain eligibility, benefits, and application process
   - Closing (1-2 sentences): Motivational statement encouraging citizens to apply
5. Use simple, conversational language suitable for all education levels
6. NO bullet points, NO markdown, NO stage directions, NO English words
7. Output ONLY the Hindi narration script - nothing else

Generate the complete Hindi narration script now:
''';
  }

  // Generate video script
  Future<String?> generateVideoScript(String prompt) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final requestBody = {
          'model': _modelName,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.7,
          'max_tokens': 10000,
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

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            final choice = data['choices'][0];
            if (choice['message'] != null && 
                choice['message']['content'] != null) {
              return choice['message']['content'];
            }
          }
        } else if (response.statusCode == 503) {
          if (attempt < 2) {
            await Future.delayed(Duration(seconds: (attempt + 1) * 2));
            continue;
          }
        }
      } catch (e) {
        debugPrint('Error generating video script (attempt ${attempt + 1}): $e');
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        }
      }
    }
    
    return null;
  }

  // Generate scheme from scheme name
  Future<Map<String, dynamic>?> generateSchemeFromName(String schemeName, {String? suggestedCategory}) async {
    try {
      final prompt = '''
You are a specialized scheme generation assistant. Generate a comprehensive Central Government Scheme based on the scheme name provided.

**SCHEME NAME**: $schemeName
${suggestedCategory != null ? '**SUGGESTED CATEGORY**: $suggestedCategory' : ''}

**REQUIREMENTS**:
1. Provide comprehensive and detailed information
2. Include working, specific links (webpage > PDF > "No link available")
3. Verify all links are valid and working
4. Be detailed in all sections

**MANDATORY OUTPUT SCHEME STRUCTURE:**

---

## Policy Details

*Description*
[Comprehensive description of the scheme, ministry, and objectives.]

*Benefits*
1. [Detailed benefit 1]
2. [Detailed benefit 2]
[Continue with more benefits]

*Eligibility*
1. [Detailed eligibility criterion 1]
2. [Detailed eligibility criterion 2]
[Continue with more criteria]

### Documents Required
- [Document 1]
- [Document 2]
[Continue with more documents]

*Related Link*
[Full URL if available, or "No link available"]

---

Generate the scheme now:
''';

      final requestBody = {
        'model': _modelName,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.7,
        'max_tokens': 10000,
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw TimeoutException('Groq API request timed out after 2 minutes');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final choice = data['choices'][0];
          if (choice['message'] != null && 
              choice['message']['content'] != null) {
            final responseText = choice['message']['content'];
            return _parseSchemeResponse(responseText, schemeName, suggestedCategory);
          }
        }
      } else {
        debugPrint('Groq API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error generating scheme from name: $e');
    }
    
    return null;
  }

  // Parse scheme response
  Map<String, dynamic>? _parseSchemeResponse(String response, String originalSchemeName, String? suggestedCategory) {
    try {
      final lines = response.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      
      String? title;
      String description = '';
      String benefits = '';
      String eligibility = '';
      String documentsRequired = '';
      String? link;
      
      String currentSection = '';
      bool inPolicyDetails = false;
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        
        if (line.startsWith('##')) {
          final titleMatch = RegExp(r'##\s*\d+\.\s*(.+)').firstMatch(line);
          if (titleMatch != null) {
            title = titleMatch.group(1)?.trim();
          }
          continue;
        }
        
        if (line.toLowerCase().contains('policy details')) {
          inPolicyDetails = true;
          currentSection = '';
          continue;
        }
        
        if (line.toLowerCase().contains('description') && inPolicyDetails) {
          currentSection = 'description';
          continue;
        }
        
        if (line.toLowerCase().contains('benefits') && inPolicyDetails) {
          currentSection = 'benefits';
          continue;
        }
        
        if ((line.toLowerCase().contains('detailed eligibility criteria') || 
             line.toLowerCase().contains('eligibility criteria')) && inPolicyDetails) {
          currentSection = 'eligibility';
          continue;
        }
        
        if (line.toLowerCase().contains('documents required') && inPolicyDetails) {
          currentSection = 'documents';
          continue;
        }
        
        if (line.toLowerCase().contains('related link') && inPolicyDetails) {
          currentSection = 'link';
          continue;
        }
        
        // Extract content based on current section
        if (inPolicyDetails && line.isNotEmpty) {
          if (currentSection == 'description') {
            description += (description.isNotEmpty ? '\n' : '') + line;
          } else if (currentSection == 'benefits') {
            benefits += (benefits.isNotEmpty ? '\n' : '') + line;
          } else if (currentSection == 'eligibility') {
            eligibility += (eligibility.isNotEmpty ? '\n' : '') + line;
          } else if (currentSection == 'documents') {
            documentsRequired += (documentsRequired.isNotEmpty ? '\n' : '') + line;
          } else if (currentSection == 'link') {
            if (line.startsWith('http://') || line.startsWith('https://')) {
              link = line.trim();
            } else if (line.toLowerCase().contains('no link available')) {
              link = null;
            }
          }
        }
      }
      
      if (title == null || title.isEmpty) {
        title = originalSchemeName;
      }
      
      return {
        'title': title,
        'description': description.isNotEmpty ? description : 'No description available',
        'benefits': benefits.isNotEmpty ? benefits : 'No benefits listed',
        'eligibility': eligibility.isNotEmpty ? eligibility : 'No eligibility criteria listed',
        'documentsRequired': documentsRequired.isNotEmpty ? documentsRequired : 'No documents listed',
        'link': link,
      };
    } catch (e) {
      debugPrint('Error parsing scheme response: $e');
      return null;
    }
  }

  // Translate text to Hindi
  Future<String?> translateToHindi(String text, {bool preserveNumbers = true}) async {
    if (_apiKey.isEmpty) {
      debugPrint('[GroqService] GROQ_API_KEY not provided. Skipping translation.');
      return null;
    }
    
    if (text.isEmpty) return text;
    
    try {
      final preserveInstruction = preserveNumbers 
          ? 'Keep all numbers, dates, currency symbols (₹, \$, etc.), and URLs unchanged.'
          : '';
      
      final prompt = '''
Translate the following text from English to Hindi (Devanagari script).
$preserveInstruction

Text to translate:
$text

Provide only the translated text, nothing else.
''';

      final requestBody = {
        'model': _modelName,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.3,
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
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Translation request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final choice = data['choices'][0];
          if (choice['message'] != null && 
              choice['message']['content'] != null) {
            final translated = choice['message']['content'].trim();
            return translated.isNotEmpty ? translated : text;
          }
        }
      } else {
        debugPrint('Groq translation error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error translating to Hindi: $e');
    }
    
    return null;
  }
  
  // Translate policy content (all fields together for consistency)
  Future<Map<String, String>?> translatePolicyContent({
    required String title,
    required String description,
    required String content,
    String? documentsRequired,
  }) async {
    if (_apiKey.isEmpty) {
      return null;
    }
    
    try {
      final prompt = '''
Translate the following policy content from English to Hindi (Devanagari script).
IMPORTANT RULES:
1. Translate accurately preserving the exact meaning
2. Keep all numbers, dates, currency symbols (₹, \$, etc.), percentages unchanged
3. Keep URLs, email addresses unchanged
4. Use natural, conversational Hindi suitable for government policy information
5. Maintain the structure and format
6. Return ONLY valid JSON with keys: "title", "description", "content", "documentsRequired"

Policy Content:
Title: ${title}
Description: ${description}
Content: ${content}
Documents Required: ${documentsRequired ?? 'Not specified'}

Return the translation as JSON:''';

      final requestBody = {
        'model': _modelName,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.3,
        'max_tokens': 8000,
        'response_format': {'type': 'json_object'},
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Policy translation request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final choice = data['choices'][0];
          if (choice['message'] != null && 
              choice['message']['content'] != null) {
            final responseText = choice['message']['content'].trim();
            
            try {
              // Try to parse as JSON
              final jsonData = jsonDecode(responseText);
              return {
                'title': jsonData['title']?.toString() ?? title,
                'description': jsonData['description']?.toString() ?? description,
                'content': jsonData['content']?.toString() ?? content,
                'documentsRequired': jsonData['documentsRequired']?.toString() ?? documentsRequired ?? '',
              };
            } catch (e) {
              // If JSON parsing fails, try to translate each field separately
              debugPrint('Failed to parse JSON response, translating fields separately');
              final translatedTitle = await translateToHindi(title);
              final translatedDesc = await translateToHindi(description);
              final translatedContent = await translateToHindi(content);
              final translatedDocs = documentsRequired != null ? await translateToHindi(documentsRequired) : null;
              
              return {
                'title': translatedTitle ?? title,
                'description': translatedDesc ?? description,
                'content': translatedContent ?? content,
                'documentsRequired': translatedDocs ?? documentsRequired ?? '',
              };
            }
          }
        }
      } else {
        debugPrint('Groq policy translation error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error translating policy content: $e');
    }
    
    return null;
  }
}

