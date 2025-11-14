import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseFavoritesService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  Set<String> _favoritePolicyIds = {};
  bool _isLoading = false;
  String? _error;

  Set<String> get favoritePolicyIds => _favoritePolicyIds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SupabaseFavoritesService() {
    if (SupabaseConfig.bypassAuth) {
      _initializeBypassMode();
    } else {
      // Load favorites when service is created
      loadFavorites();
    }
  }

  void _initializeBypassMode() {
    // In bypass mode, use local storage as fallback
    _loadFromLocalStorage();
  }

  Future<void> _loadFromLocalStorage() async {
    try {
      // This would be used as fallback in bypass mode
      // For now, just initialize empty set
      _favoritePolicyIds = {};
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites from local storage: $e');
    }
  }

  Future<void> loadFavorites() async {
    if (SupabaseConfig.bypassAuth) {
      await _loadFromLocalStorage();
      return;
    }

    // Prevent multiple simultaneous calls
    if (_isLoading) {
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = _supabase.auth.currentUser;
      if (user == null) {
        _favoritePolicyIds = {};
        notifyListeners();
        return;
      }

      final response = await _supabase
          .from('user_favorites')
          .select('policy_id')
          .eq('user_id', user.id);

      _favoritePolicyIds = response
          .map<String>((row) => row['policy_id'] as String)
          .toSet();

      debugPrint('Loaded ${_favoritePolicyIds.length} favorites for user ${user.id}');
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading favorites: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isFavorite(String policyId) {
    return _favoritePolicyIds.contains(policyId);
  }

  Future<void> toggleFavorite(String policyId) async {
    if (SupabaseConfig.bypassAuth) {
      await _toggleFavoriteLocal(policyId);
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('Cannot toggle favorite: User not authenticated');
        return;
      }

      final isCurrentlyFavorite = _favoritePolicyIds.contains(policyId);

      if (isCurrentlyFavorite) {
        // Remove from favorites
        await _supabase
            .from('user_favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('policy_id', policyId);
        
        _favoritePolicyIds.remove(policyId);
        debugPrint('Removed policy $policyId from favorites');
      } else {
        // Add to favorites
        await _supabase
            .from('user_favorites')
            .insert({
              'user_id': user.id,
              'policy_id': policyId,
              'created_at': DateTime.now().toIso8601String(),
            });
        
        _favoritePolicyIds.add(policyId);
        debugPrint('Added policy $policyId to favorites');
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error toggling favorite: $e');
      notifyListeners();
    }
  }

  Future<void> _toggleFavoriteLocal(String policyId) async {
    // Local fallback for bypass mode
    if (_favoritePolicyIds.contains(policyId)) {
      _favoritePolicyIds.remove(policyId);
    } else {
      _favoritePolicyIds.add(policyId);
    }
    notifyListeners();
  }

  Future<void> clearFavorites() async {
    if (SupabaseConfig.bypassAuth) {
      _favoritePolicyIds.clear();
      notifyListeners();
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('Cannot clear favorites: User not authenticated');
        return;
      }

      await _supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', user.id);

      _favoritePolicyIds.clear();
      debugPrint('Cleared all favorites for user ${user.id}');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error clearing favorites: $e');
      notifyListeners();
    }
  }

  Future<void> syncFavoritesOnLogin() async {
    if (SupabaseConfig.bypassAuth) {
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user != null) {
      await loadFavorites();
    }
  }

  Future<void> clearFavoritesOnLogout() async {
    _favoritePolicyIds.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
