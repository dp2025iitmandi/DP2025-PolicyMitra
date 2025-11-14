# PolicyMitra

PolicyMitra is a Flutter-based assistant that helps citizens discover, compare, and understand government schemes. The app combines a curated policy database with AI-powered chat and video explanations so users can quickly find programs that fit their needs.

## Highlights
- Supabase-backed authentication, favorites, and policy content
- Firebase Storage for rich media assets
- Groq-powered AI chat for answering policy questions and generating summaries
- HeyGen integration for optional explainer videos
- Responsive Flutter UI targeting Android, iOS, desktop, and web

## Usage
1. **Browse policies:** Launch the app to see featured schemes, categories, and personalized recommendations.
2. **Search & filter:** Use the search bar or category filters to drill down to a specific scheme.
3. **Save favorites:** Tap the bookmark icon to save policies for quick access later (requires Supabase login).
4. **Ask questions:** Open the chat screen, type a question, and the Groq assistant will answer using the policy context.
5. **Watch explainers:** Where available, tap “Generate video” to trigger the HeyGen-based explainer workflow.
6. **Language support:** Switch to Hindi (or other configured languages) for translated content via the language toggle.

## Setup

### Prerequisites
- Flutter 3.24+ with Dart SDK
- Supabase project (URL + anon key)
- Firebase project configured via FlutterFire CLI
- Groq API key
- Optional: HeyGen API key and backend webhook server

### 1. Clone and install
```bash
git clone https://github.com/dp2025iitmandi/DP2025-PolicyMitra.git
cd policymitra
flutter pub get
```

### 2. Provide secrets
Secrets stay out of version control. Copy the example files and fill in your keys:
1. `cp lib/config/app_config.example.dart lib/config/app_config.dart`
2. `cp lib/config/supabase_config.example.dart lib/config/supabase_config.dart`
3. `cp lib/firebase_options.example.dart lib/firebase_options.dart`

Then fill in:
- `AppConfig.groqApiKey` with your Groq key (or use `String.fromEnvironment` values).
- Supabase `supabaseUrl` and `supabaseAnonKey`.
- Platform-specific Firebase API keys/app IDs from the Firebase console.
- Optional HeyGen API key or backend default URLs.

Alternatively, set the corresponding environment variables when running:
```
flutter run --dart-define=GROQ_API_KEY=<key> --dart-define=HEYGEN_API_KEY=<key> ...
```

### 3. Supabase
- Run the SQL in `supabase_setup` scripts to create tables (users, policies, favorites).
- Configure Row Level Security policies per your needs.

### 4. Firebase
- Run `flutterfire configure` to regenerate `firebase_options.dart` for your project.
- Enable required services (Auth, Storage) in the Firebase console.

### 5. Optional HeyGen backend
- Copy `server/.env.example` to `.env` and set `HEYGEN_CALLBACK_URL`.
- Install Node deps: `cd server && npm install`.
- Start the webhook server: `npm run dev` (or deploy to your hosting provider).

### 6. Run the app
```bash
flutter run -d <device>
```
Pass any needed `--dart-define` flags for secrets if you didn’t hardcode them.

### 7. Build for release
```bash
flutter build apk   # Android
flutter build ipa   # iOS (requires Xcode & macOS)
flutter build web
```
Follow the standard Flutter platform release guides for signing and store submission.

---

Contributions and feature requests are welcome! Open an issue or submit a PR to help improve PolicyMitra.

