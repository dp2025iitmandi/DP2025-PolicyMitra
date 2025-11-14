import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import 'config/supabase_config.dart';
import 'services/firebase_firestore_service.dart';
import 'services/admin_service.dart';
import 'services/speech_service.dart';
import 'services/category_service.dart';
import 'services/supabase_favorites_service.dart';
import 'services/supabase_user_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/recommendation_service.dart';
import 'services/groq_service.dart';
import 'services/language_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/password_reset_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  // Initialize AdminService
  final adminService = AdminService();
  await adminService.ensureInitialized();
  
  // Initialize AuthService
  final authService = SupabaseAuthService();
  await authService.ensureInitialized();
  
  // Initialize FavoritesService
  final favoritesService = SupabaseFavoritesService();
  await favoritesService.loadFavorites();
  
  // Initialize LanguageService
  final languageService = LanguageService(groqService: GroqService());
  await languageService.loadLanguage();
  
  // One-time initialization: Clear old data if needed
  await _performOneTimeInitialization();
  
  // Initialize Deep Link Service (will be initialized after app starts)
  
  runApp(MyApp(
    adminService: adminService, 
    authService: authService, 
    favoritesService: favoritesService,
    languageService: languageService,
  ));
}

Future<void> _performOneTimeInitialization() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final hasInitialized = prefs.getBool('app_initialized') ?? false;
    
    if (!hasInitialized) {
      // Clear any old session data
      await prefs.clear();
      await prefs.setBool('app_initialized', true);
      debugPrint('App initialized for the first time - old data cleared');
    }
  } catch (e) {
    debugPrint('Error during one-time initialization: $e');
  }
}

class MyApp extends StatelessWidget {
  final AdminService adminService;
  final SupabaseAuthService authService;
  final SupabaseFavoritesService favoritesService;
  final LanguageService languageService;
  
  MyApp({
    super.key, 
    required this.adminService, 
    required this.authService, 
    required this.favoritesService,
    required this.languageService,
  });

  @override
  Widget build(BuildContext context) {
    
    return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => FirebaseFirestoreService()),
            ChangeNotifierProvider.value(value: adminService),
            ChangeNotifierProvider.value(value: authService),
            ChangeNotifierProvider(create: (_) => SpeechService()),
            ChangeNotifierProvider(create: (_) => CategoryService()),
            ChangeNotifierProvider.value(value: favoritesService),
            ChangeNotifierProvider(create: (_) => SupabaseUserService()),
            ChangeNotifierProvider(create: (_) => RecommendationService()),
            Provider(create: (_) => GroqService()),
            ChangeNotifierProvider.value(value: languageService),
          ],
          child: Consumer<SupabaseAuthService>(
            builder: (context, authService, child) {
              return MaterialApp(
                title: 'PolicyMitra',
                theme: _buildLightTheme(),
                themeMode: ThemeMode.light,
                home: (SupabaseConfig.bypassAuth || authService.isAuthenticated) 
                    ? const HomeScreen() 
                    : const AuthScreen(),
                routes: {
                  '/password-reset': (context) => const PasswordResetScreen(),
                },
                debugShowCheckedModeBanner: false,
              );
            },
          ),
        );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      brightness: Brightness.light,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

}