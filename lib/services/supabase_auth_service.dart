import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';

class SupabaseAuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  SupabaseAuthService() {
    if (SupabaseConfig.bypassAuth) {
      // Create a dummy user for bypass mode
      _user = User(
        id: 'bypass-user',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
    } else {
      _initializeAuth();
    }
  }

  Future<void> ensureInitialized() async {
    if (!SupabaseConfig.bypassAuth) {
      await _loadSavedSession();
    }
  }

  void _initializeAuth() {
    _user = _supabase.auth.currentUser;
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        _saveSession(_user!);
      } else {
        _clearSession();
      }
      notifyListeners();
    });
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString('supabase_session');
      if (sessionData != null) {
        // Check if session is still valid
        final session = _supabase.auth.currentSession;
        if (session != null) {
          // Validate that the user exists in our database
          final isValidUser = await _validateUserInDatabase(session.user.id);
          if (isValidUser) {
            _user = session.user;
            debugPrint('Loaded saved session for user: ${_user?.email}');
            notifyListeners();
          } else {
            debugPrint('User not found in database, clearing session');
            await _clearSession();
            _user = null;
            notifyListeners();
          }
        } else {
          await _clearSession();
          _user = null;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading saved session: $e');
      await _clearSession();
      _user = null;
      notifyListeners();
    }
  }

  Future<bool> _validateUserInDatabase(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      debugPrint('Error validating user in database: $e');
      return false;
    }
  }

  Future<void> _saveSession(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supabase_session', user.id);
      debugPrint('Session saved for user: ${user.email}');
      
      // Notify favorites service to load user's favorites
      _notifyFavoritesService();
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('supabase_session');
      debugPrint('Session cleared');
      
      // Notify favorites service to clear user's favorites
      _notifyFavoritesService();
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (SupabaseConfig.bypassAuth) {
      // Bypass mode - simulate successful signup
      _isLoading = true;
      notifyListeners();
      
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      
      _user = User(
        id: 'bypass-user-${DateTime.now().millisecondsSinceEpoch}',
        appMetadata: {},
        userMetadata: {'full_name': fullName ?? 'User'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();


      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
      );

      if (response.user != null) {
        _user = response.user;
        debugPrint('Sign up successful: ${_user?.email}');
        
        // Create user profile (this will be handled by the database trigger)
        // The trigger will automatically create a user profile
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Sign up error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (SupabaseConfig.bypassAuth) {
      // Bypass mode - simulate successful signin
      _isLoading = true;
      notifyListeners();
      
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      
      _user = User(
        id: 'bypass-user-${DateTime.now().millisecondsSinceEpoch}',
        appMetadata: {},
        userMetadata: {'email': email},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Validate that the user exists in our database
        final isValidUser = await _validateUserInDatabase(response.user!.id);
        if (isValidUser) {
          _user = response.user;
          debugPrint('Sign in successful: ${_user?.email}');
        } else {
          // User doesn't exist in our database, sign them out
          await _supabase.auth.signOut();
          _error = 'Login credentials invalid. Please create a new account.';
          debugPrint('User not found in database during sign in');
        }
      }
    } catch (e) {
      _error = 'Login credentials invalid. Please check your email and password.';
      debugPrint('Sign in error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (SupabaseConfig.bypassAuth) {
      // Bypass mode - just clear the user
      _user = null;
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.auth.signOut();
      await _clearSession();
      _user = null;
      debugPrint('Sign out successful');
    } catch (e) {
      _error = e.toString();
      debugPrint('Sign out error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearAllLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _supabase.auth.signOut();
      _user = null;
      debugPrint('All local data cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing local data: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'policymitra://reset-password',
      );
      debugPrint('Password reset email sent to: $email');
    } catch (e) {
      _error = e.toString();
      debugPrint('Password reset error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePasswordFromReset(String newPassword) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      debugPrint('Password updated successfully');
    } catch (e) {
      _error = e.toString();
      debugPrint('Password update error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      debugPrint('Password updated successfully');
    } catch (e) {
      _error = e.toString();
      debugPrint('Password update error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  void _notifyFavoritesService() {
    // This will be used to notify the favorites service about auth state changes
    // The actual implementation will be handled by the main app's provider system
  }
}
