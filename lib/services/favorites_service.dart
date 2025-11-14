import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService extends ChangeNotifier {
  static const String _favoritesKey = 'favorite_policies';
  
  Set<String> _favoritePolicyIds = {};
  
  Set<String> get favoritePolicyIds => Set.from(_favoritePolicyIds);
  
  FavoritesService() {
    _loadFavorites();
  }
  
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFavorites = prefs.getStringList(_favoritesKey);
      if (savedFavorites != null) {
        _favoritePolicyIds = savedFavorites.toSet();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }
  
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favoritePolicyIds.toList());
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }
  
  bool isFavorite(String policyId) {
    return _favoritePolicyIds.contains(policyId);
  }
  
  Future<void> toggleFavorite(String policyId) async {
    if (_favoritePolicyIds.contains(policyId)) {
      _favoritePolicyIds.remove(policyId);
    } else {
      _favoritePolicyIds.add(policyId);
    }
    await _saveFavorites();
    notifyListeners();
  }
  
  Future<void> addToFavorites(String policyId) async {
    if (!_favoritePolicyIds.contains(policyId)) {
      _favoritePolicyIds.add(policyId);
      await _saveFavorites();
      notifyListeners();
    }
  }
  
  Future<void> removeFromFavorites(String policyId) async {
    if (_favoritePolicyIds.contains(policyId)) {
      _favoritePolicyIds.remove(policyId);
      await _saveFavorites();
      notifyListeners();
    }
  }
}
