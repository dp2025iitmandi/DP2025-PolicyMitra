import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryService extends ChangeNotifier {
  static const String _categoriesKey = 'custom_categories';
  
  List<String> _categories = [
    'All',
    'Agriculture',
    'Education',
    'Healthcare',
    'Housing',
    'Social Welfare',
  ];
  
  List<String> get categories => List.from(_categories);
  
  CategoryService() {
    _loadCategories();
  }
  
  Future<void> _loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCategories = prefs.getStringList(_categoriesKey);
      if (savedCategories != null && savedCategories.isNotEmpty) {
        // Merge saved categories with default ones, avoiding duplicates
        final defaultCategories = ['All', 'Agriculture', 'Education', 'Healthcare', 'Housing', 'Social Welfare'];
        final customCategories = savedCategories.where((cat) => !defaultCategories.contains(cat)).toList();
        _categories = [...defaultCategories, ...customCategories];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }
  
  Future<void> addCategory(String category) async {
    if (category.trim().isEmpty || _categories.contains(category.trim())) {
      return;
    }
    
    _categories.add(category.trim());
    await _saveCategories();
    notifyListeners();
  }
  
  Future<void> removeCategory(String category) async {
    // Don't allow removing default categories
    const defaultCategories = ['All', 'Agriculture', 'Education', 'Healthcare', 'Housing', 'Social Welfare'];
    if (defaultCategories.contains(category)) {
      return;
    }
    
    _categories.remove(category);
    await _saveCategories();
    notifyListeners();
  }

  Future<bool> canDeleteCategory(String category) async {
    // Don't allow deleting default categories
    const defaultCategories = ['All', 'Agriculture', 'Education', 'Healthcare', 'Housing', 'Social Welfare'];
    return !defaultCategories.contains(category);
  }
  
  Future<void> _saveCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save only custom categories (exclude default ones)
      const defaultCategories = ['All', 'Agriculture', 'Education', 'Healthcare', 'Housing', 'Social Welfare'];
      final customCategories = _categories.where((cat) => !defaultCategories.contains(cat)).toList();
      await prefs.setStringList(_categoriesKey, customCategories);
    } catch (e) {
      debugPrint('Error saving categories: $e');
    }
  }
}
