import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminService extends ChangeNotifier {
  bool _isAdmin = false;
  String? _error;
  SharedPreferences? _prefs;

  bool get isAdmin => _isAdmin;
  String? get error => _error;

  // Admin credentials (in production, these should be stored securely)
  static const String _adminUsername = 'admin';
  static const String _adminPassword = 'admin123';
  static const String _adminSessionKey = 'admin_session';

  AdminService() {
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadAdminSession();
  }

  // Method to ensure initialization is complete before video player setup
  Future<void> ensureInitialized() async {
    if (_prefs == null) {
      await _initializePrefs();
    }
  }

  Future<void> _loadAdminSession() async {
    if (_prefs != null) {
      _isAdmin = _prefs!.getBool(_adminSessionKey) ?? false;
      notifyListeners();
    }
  }

  Future<void> _saveAdminSession(bool isAdmin) async {
    if (_prefs != null) {
      await _prefs!.setBool(_adminSessionKey, isAdmin);
    }
  }

  Future<bool> authenticateAdmin(String username, String password) async {
    _error = null;
    
    if (username == _adminUsername && password == _adminPassword) {
      _isAdmin = true;
      await _saveAdminSession(true);
      notifyListeners();
      return true;
    } else {
      _error = 'Invalid username or password';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isAdmin = false;
    _error = null;
    await _saveAdminSession(false);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
