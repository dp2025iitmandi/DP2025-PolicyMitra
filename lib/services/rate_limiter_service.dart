import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Rate limiter service to prevent API overload
class RateLimiterService {
  static final RateLimiterService _instance = RateLimiterService._internal();
  factory RateLimiterService() => _instance;
  RateLimiterService._internal();

  // Rate limiting: Max requests per minute
  static const int maxRequestsPerMinute = 10;
  static const int maxRequestsPerHour = 100;
  
  // Track request timestamps
  final Queue<DateTime> _requestHistory = Queue<DateTime>();
  final Queue<DateTime> _hourlyHistory = Queue<DateTime>();
  
  // Response cache
  final Map<String, _CachedResponse> _responseCache = {};
  static const Duration cacheExpiry = Duration(minutes: 5);
  
  // Track rate limit status
  bool _isRateLimited = false;
  DateTime? _rateLimitUntil;

  /// Check if request can be made (rate limit check)
  bool canMakeRequest() {
    final now = DateTime.now();
    
    // Check if currently rate limited
    if (_isRateLimited && _rateLimitUntil != null) {
      if (now.isBefore(_rateLimitUntil!)) {
        final remainingSeconds = _rateLimitUntil!.difference(now).inSeconds;
        debugPrint('[RATE_LIMITER] Rate limited. Try again in ${remainingSeconds}s');
        return false;
      } else {
        _isRateLimited = false;
        _rateLimitUntil = null;
      }
    }
    
    // Clean old history
    _cleanOldHistory(now);
    
    // Check per-minute limit
    if (_requestHistory.length >= maxRequestsPerMinute) {
      _isRateLimited = true;
      _rateLimitUntil = now.add(const Duration(minutes: 1));
      debugPrint('[RATE_LIMITER] Rate limit reached: ${maxRequestsPerMinute} requests/minute');
      return false;
    }
    
    // Check per-hour limit
    if (_hourlyHistory.length >= maxRequestsPerHour) {
      _isRateLimited = true;
      _rateLimitUntil = now.add(const Duration(hours: 1));
      debugPrint('[RATE_LIMITER] Hourly rate limit reached: ${maxRequestsPerHour} requests/hour');
      return false;
    }
    
    return true;
  }

  /// Record a request
  void recordRequest() {
    final now = DateTime.now();
    _requestHistory.add(now);
    _hourlyHistory.add(now);
    debugPrint('[RATE_LIMITER] Request recorded. Current: ${_requestHistory.length}/min, ${_hourlyHistory.length}/hour');
  }

  /// Clean old history
  void _cleanOldHistory(DateTime now) {
    // Remove requests older than 1 minute
    while (_requestHistory.isNotEmpty && 
           now.difference(_requestHistory.first).inMinutes >= 1) {
      _requestHistory.removeFirst();
    }
    
    // Remove requests older than 1 hour
    while (_hourlyHistory.isNotEmpty && 
           now.difference(_hourlyHistory.first).inHours >= 1) {
      _hourlyHistory.removeFirst();
    }
  }

  /// Get cached response if available
  String? getCachedResponse(String cacheKey) {
    final cached = _responseCache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiry)) {
      debugPrint('[RATE_LIMITER] Cache HIT for key: $cacheKey');
      return cached.response;
    } else if (cached != null) {
      _responseCache.remove(cacheKey);
      debugPrint('[RATE_LIMITER] Cache EXPIRED for key: $cacheKey');
    }
    return null;
  }

  /// Cache a response
  void cacheResponse(String cacheKey, String response) {
    _responseCache[cacheKey] = _CachedResponse(
      response: response,
      expiry: DateTime.now().add(cacheExpiry),
    );
    debugPrint('[RATE_LIMITER] Response cached for key: $cacheKey');
    
    // Clean expired cache entries periodically
    _cleanExpiredCache();
  }

  /// Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    _responseCache.removeWhere((key, value) => now.isAfter(value.expiry));
  }

  /// Clear all cache
  void clearCache() {
    _responseCache.clear();
    debugPrint('[RATE_LIMITER] Cache cleared');
  }

  /// Handle rate limit error
  void handleRateLimitError() {
    _isRateLimited = true;
    _rateLimitUntil = DateTime.now().add(const Duration(minutes: 2));
    debugPrint('[RATE_LIMITER] Rate limit error detected. Blocking requests for 2 minutes');
  }

  /// Generate cache key from request parameters
  static String generateCacheKey(String input, String? category) {
    return '${input.toLowerCase().trim()}_${category ?? 'none'}';
  }
}

class _CachedResponse {
  final String response;
  final DateTime expiry;

  _CachedResponse({
    required this.response,
    required this.expiry,
  });
}

