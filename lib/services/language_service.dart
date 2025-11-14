import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'groq_service.dart';
import 'dart:convert';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  
  String _currentLanguage = 'en'; // 'en' for English, 'hi' for Hindi
  final GroqService? _groqService;
  
  // Cache for translations to avoid repeated API calls
  final Map<String, String> _translationCache = {};
  
  // Static translations for common UI elements (fallback and performance)
  Map<String, Map<String, String>> _staticTranslations = {};
  
  LanguageService({GroqService? groqService}) 
      : _groqService = groqService {
    _loadStaticTranslations();
  }
  
  String get currentLanguage => _currentLanguage;
  bool get isHindi => _currentLanguage == 'hi';
  bool get isEnglish => _currentLanguage == 'en';
  
  // Load saved language preference
  Future<void> loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);
      if (savedLanguage != null && (savedLanguage == 'en' || savedLanguage == 'hi')) {
        _currentLanguage = savedLanguage;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading language preference: $e');
    }
  }
  
  // Change language
  Future<void> setLanguage(String language) async {
    if (language != 'en' && language != 'hi') {
      debugPrint('Invalid language code: $language');
      return;
    }
    
    if (_currentLanguage == language) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, language);
      _currentLanguage = language;
      // Don't clear cache when switching - keep translations
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }
  
  // Toggle between English and Hindi
  Future<void> toggleLanguage() async {
    await setLanguage(_currentLanguage == 'en' ? 'hi' : 'en');
  }
  
  // Load static translations
  void _loadStaticTranslations() {
    _staticTranslations = {
      'en': {
        'app_name': 'PolicyMitra',
        'find_schemes': 'Find Schemes for You',
        'personalized_recommendations': 'Get personalized recommendations',
        'browse_by_category': 'Browse by Category',
        'view_all_policies': 'View All Policies',
        'view_policies': 'View Policies',
        'settings': 'Settings',
        'logout': 'Logout',
        'favorites': 'Favorites',
        'admin_login': 'Admin Login',
        'upload_policy': 'Upload Policy',
        'logout_admin': 'Logout Admin',
        'cancel': 'Cancel',
        'yes_logout': 'Yes, Logout',
        'logout_confirmation': 'Are you sure you want to logout?',
        'close': 'Close',
        'save': 'Save',
        'delete': 'Delete',
        'edit': 'Edit',
        'search': 'Search',
        'loading': 'Loading...',
        'error': 'Error',
        'success': 'Success',
        'no_data': 'No data available',
        'language': 'Language',
        'english': 'English',
        'hindi': 'Hindi',
        'select_language': 'Select Language',
        'policy_title': 'Policy Title',
        'policy_details': 'Policy Details',
        'description': 'Description',
        'content': 'Content',
        'documents_required': 'Documents Required',
        'category': 'Category',
        'all': 'All',
        'agriculture': 'Agriculture',
        'education': 'Education',
        'healthcare': 'Healthcare',
        'housing': 'Housing',
        'social_welfare': 'Social Welfare',
      },
      'hi': {
        'app_name': 'पॉलिसी मित्र',
        'find_schemes': 'आपके लिए योजनाएं खोजें',
        'personalized_recommendations': 'व्यक्तिगत सुझाव प्राप्त करें',
        'browse_by_category': 'श्रेणी के अनुसार ब्राउज़ करें',
        'view_all_policies': 'सभी नीतियां देखें',
        'view_policies': 'नीतियां देखें',
        'settings': 'सेटिंग्स',
        'logout': 'लॉग आउट',
        'favorites': 'पसंदीदा',
        'admin_login': 'एडमिन लॉगिन',
        'upload_policy': 'नीति अपलोड करें',
        'logout_admin': 'एडमिन लॉग आउट',
        'cancel': 'रद्द करें',
        'yes_logout': 'हाँ, लॉग आउट करें',
        'logout_confirmation': 'क्या आप वाकई लॉग आउट करना चाहते हैं?',
        'close': 'बंद करें',
        'save': 'सहेजें',
        'delete': 'हटाएं',
        'edit': 'संपादित करें',
        'search': 'खोजें',
        'loading': 'लोड हो रहा है...',
        'error': 'त्रुटि',
        'success': 'सफल',
        'no_data': 'कोई डेटा उपलब्ध नहीं',
        'language': 'भाषा',
        'english': 'अंग्रेजी',
        'hindi': 'हिंदी',
        'select_language': 'भाषा चुनें',
        'policy_title': 'नीति शीर्षक',
        'policy_details': 'नीति विवरण',
        'description': 'विवरण',
        'content': 'सामग्री',
        'documents_required': 'आवश्यक दस्तावेज़',
        'category': 'श्रेणी',
        'all': 'सभी',
        'agriculture': 'कृषि',
        'education': 'शिक्षा',
        'healthcare': 'स्वास्थ्य सेवा',
        'housing': 'आवास',
        'social_welfare': 'सामाजिक कल्याण',
      },
    };
  }
  
  // Get static translation (fast, no API call)
  String translate(String key, {Map<String, String>? params}) {
    if (_currentLanguage == 'en') {
      return _staticTranslations['en']?[key] ?? key;
    }
    
    final translated = _staticTranslations['hi']?[key] ?? _staticTranslations['en']?[key] ?? key;
    
    // Replace parameters if provided
    if (params != null) {
      var result = translated;
      params.forEach((paramKey, value) {
        result = result.replaceAll('{$paramKey}', value);
      });
      return result;
    }
    
    return translated;
  }
  
  // Translate dynamic content using Groq (cached)
  Future<String> translateText(String text, {bool forceTranslate = false}) async {
    // Return original if already in target language or if English is selected
    if (_currentLanguage == 'en') {
      return text;
    }
    
    // Check cache first
    final cacheKey = '${_currentLanguage}_$text';
    if (!forceTranslate && _translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }
    
    // Empty text returns empty
    if (text.trim().isEmpty) {
      return text;
    }
    
    // Skip translation for numbers, dates, URLs
    if (_shouldSkipTranslation(text)) {
      return text;
    }
    
    try {
      // Use Groq to translate
      if (_groqService != null) {
        final translated = await _groqService!.translateToHindi(text);
        
        if (translated != null && translated.isNotEmpty && translated != text) {
          // Cache the translation
          _translationCache[cacheKey] = translated;
          return translated;
        }
      }
    } catch (e) {
      debugPrint('Error translating text: $e');
    }
    
    // Return original text if translation fails
    return text;
  }
  
  // Check if text should skip translation (numbers, URLs, etc.)
  bool _shouldSkipTranslation(String text) {
    final trimmed = text.trim();
    
    // Check if it's a number
    if (RegExp(r'^[\d\s\.,₹$€£¥\-+%]+$').hasMatch(trimmed)) {
      return true;
    }
    
    // Check if it's a URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('www.')) {
      return true;
    }
    
    // Check if it's an email
    if (trimmed.contains('@') && trimmed.contains('.')) {
      return true;
    }
    
    return false;
  }
  
  // Translate policy content (title, description, content, etc.) - optimized
  Future<Map<String, String>> translatePolicyContent({
    required String title,
    required String description,
    required String content,
    String? documentsRequired,
  }) async {
    if (_currentLanguage == 'en') {
      return {
        'title': title,
        'description': description,
        'content': content,
        'documentsRequired': documentsRequired ?? '',
      };
    }
    
    try {
      // Translate all fields together for consistency and efficiency
      if (_groqService != null) {
        final translated = await _groqService!.translatePolicyContent(
          title: title,
          description: description,
          content: content,
          documentsRequired: documentsRequired,
        );
        
        if (translated != null) {
          return translated;
        }
      }
    } catch (e) {
      debugPrint('Error translating policy content: $e');
    }
    
    // Return original if translation fails
    return {
      'title': title,
      'description': description,
      'content': content,
      'documentsRequired': documentsRequired ?? '',
    };
  }
  
  // Clear translation cache
  void clearCache() {
    _translationCache.clear();
  }
  
  // Get cached translation
  String? getCachedTranslation(String text) {
    if (_currentLanguage == 'en') return null;
    final cacheKey = '${_currentLanguage}_$text';
    return _translationCache[cacheKey];
  }
}
