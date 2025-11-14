class AppConfig {
  // Firebase defaults are provided by firebase_options.dart. These values are
  // only used where explicit overrides are required.
  static const String firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
  static const String firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');

  // Groq API Configuration
  static const String groqApiKey = 'your_key_here';

 

  static const String backendBaseUrl =
      String.fromEnvironment('BACKEND_BASE_URL', defaultValue: 'http://localhost:3000');

  
 
  

  static const String appName = 'PolicyMitra';
  static const String appVersion = '1.0.0';

  static const List<String> categories = [
    'Agriculture',
    'Education',
    'Healthcare',
    'Housing',
    'Social Welfare',
  ];
}
