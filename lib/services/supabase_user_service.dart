import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseUserService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SupabaseUserService() {
    if (SupabaseConfig.bypassAuth) {
      _initializeBypassMode();
    }
  }

  void _initializeBypassMode() {
    // In bypass mode, create a dummy profile
    _userProfile = {
      'id': 'bypass-user',
      'email': 'test@example.com',
      'full_name': 'Test User',
    };
    notifyListeners();
  }

  Future<void> loadUserProfile() async {
    if (SupabaseConfig.bypassAuth) {
      _initializeBypassMode();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = _supabase.auth.currentUser;
      if (user == null) {
        _userProfile = null;
        notifyListeners();
        return;
      }

      final response = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('user_id', user.id)
          .single();

      _userProfile = response;
      debugPrint('Loaded user profile: ${_userProfile?['email']}');
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading user profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createUserProfile({
    required String userId,
    required String email,
    String? fullName,
  }) async {
    if (SupabaseConfig.bypassAuth) {
      _userProfile = {
        'id': userId,
        'email': email,
        'full_name': fullName ?? 'User',
      };
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase
          .from('user_profiles')
          .insert({
            'user_id': userId,
            'email': email,
            'full_name': fullName,
          })
          .select()
          .single();

      _userProfile = response;
      debugPrint('Created user profile: ${_userProfile?['email']}');
    } catch (e) {
      _error = e.toString();
      debugPrint('Error creating user profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserProfile({
    String? fullName,
  }) async {
    if (SupabaseConfig.bypassAuth) {
      if (_userProfile != null) {
        _userProfile!['full_name'] = fullName ?? _userProfile!['full_name'];
        notifyListeners();
      }
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null || _userProfile == null) {
        return;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase
          .from('user_profiles')
          .update({
            if (fullName != null) 'full_name': fullName,
          })
          .eq('user_id', user.id)
          .select()
          .single();

      _userProfile = response;
      debugPrint('Updated user profile: ${_userProfile?['email']}');
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating user profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearUserProfile() async {
    _userProfile = null;
    _error = null;
    notifyListeners();
  }

  String? get userEmail => _userProfile?['email'];
  String? get userFullName => _userProfile?['full_name'];
  String? get userId => _userProfile?['user_id'];

  @override
  void dispose() {
    super.dispose();
  }
}
