import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../services/firebase_firestore_service.dart';
import '../services/admin_service.dart';
import '../services/category_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_favorites_service.dart';
import '../services/recommendation_service.dart';
import '../models/policy_model.dart';
import '../models/user_profile_model.dart';
import 'policy_detail_screen.dart';
import 'admin_upload_screen.dart';
import 'admin_login_dialog.dart';
import 'chat_screen.dart';
import 'category_policies_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import 'user_questionnaire_screen.dart';
import 'scheme_results_screen.dart';
import 'auth_screen.dart';
import '../widgets/translated_text.dart';
import '../services/language_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Cache for policy counts by category
  Map<String, int> _categoryCounts = {};
  
  @override
  void initState() {
    super.initState();
    // Refresh policies first, then load counts
    _refreshPoliciesAndCounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh counts when screen becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPoliciesAndCounts();
    });
  }
  
  // Refresh policies and then load category counts
  Future<void> _refreshPoliciesAndCounts() async {
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
    
    // First, ensure policies are fetched from database
    await firestoreService.fetchPolicies();
    
    // Wait a bit for policies to be loaded
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Now load counts
    await _loadCategoryCounts();
  }
  
  // Load policy counts for each category
  Future<void> _loadCategoryCounts() async {
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
    final policies = firestoreService.policies;
    
    // Count policies by category
    final Map<String, int> counts = {};
    
    // Initialize all categories with 0
    final categoryService = Provider.of<CategoryService>(context, listen: false);
    for (final category in categoryService.categories) {
      if (category == 'All') {
        counts[category] = policies.length;
      } else {
        counts[category] = policies.where((p) => p.category == category).length;
      }
    }
    
    if (mounted) {
      setState(() {
        _categoryCounts = counts;
      });
    }
  }
  
  // Get count for a specific category
  int _getCategoryCount(String category) {
    if (category == 'All') {
      final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
      return firestoreService.policies.length;
    }
    return _categoryCounts[category] ?? 0;
  }



  Future<void> _openQuestionnaire() async {
    // Navigate to questionnaire - it will navigate to results screen on completion
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserQuestionnaireScreen(),
      ),
    );
  }

  Future<void> _logoutAdmin() async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    await adminService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _logoutUser() async {
    final authService = Provider.of<SupabaseAuthService>(context, listen: false);
    await authService.signOut();
    // Navigate to auth screen after logout
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: TranslatedText(
          'logout',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TranslatedText(
          'logout_confirmation',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: TranslatedText(
              'cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[400]!, Colors.red[600]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logoutUser();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: TranslatedText('yes_logout'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    // Refresh policies if needed
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
    await firestoreService.fetchPolicies();
    
    // Refresh category counts
    await _loadCategoryCounts();
    
    // Refresh favorites
    final favoritesService = Provider.of<SupabaseFavoritesService>(context, listen: false);
    await favoritesService.loadFavorites();
  }

  Future<void> _navigateToAdminUpload() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminUploadScreen(),
      ),
    );
    
    if (result == true && mounted) {
      // Refresh policies if a new one was uploaded
      final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
      await firestoreService.fetchPolicies();
    }
  }

  Future<void> _checkAdminAndNavigate() async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    if (adminService.isAdmin) {
      await _navigateToAdminUpload();
    } else {
      _showAdminLoginDialog();
    }
  }

  void _showAdminLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => const AdminLoginDialog(),
    );
  }

  void _navigateToCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryPoliciesScreen(category: category),
      ),
    );
  }

  Future<void> _showDeleteCategoryDialog(String category) async {
    final categoryService = Provider.of<CategoryService>(context, listen: false);
    final canDelete = await categoryService.canDeleteCategory(category);
    
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete default categories')),
      );
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('What would you like to do with policies in "$category"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('delete_all'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All Policies'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('keep_policies'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Keep Policies'),
          ),
        ],
      ),
    );

    if (result != null && result != 'cancel') {
      final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
      bool success = false;

      if (result == 'delete_all') {
        success = await firestoreService.deletePoliciesInCategory(category);
      } else if (result == 'keep_policies') {
        success = await firestoreService.movePoliciesToAll(category);
      }

      if (success) {
        await categoryService.removeCategory(category);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result == 'delete_all' 
                  ? 'Category and all policies deleted'
                  : 'Category deleted, policies moved to All with Misc tag'
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete category')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          'app_name',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue[600]!,
                Colors.purple[600]!,
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Favorites button
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoritesScreen(),
                ),
              );
            },
              tooltip: Provider.of<LanguageService>(context, listen: false).translate('favorites'),
          ),
          // User menu button
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            color: Colors.black87,
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              } else if (value == 'logout') {
                _showLogoutConfirmation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.white),
                    SizedBox(width: 8),
                    TranslatedText('settings', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.white),
                    SizedBox(width: 8),
                    TranslatedText('logout', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          Consumer<AdminService>(
            builder: (context, adminService, child) {
              if (adminService.isAdmin) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.admin_panel_settings),
                  onSelected: (value) {
                    if (value == 'upload') {
                      _navigateToAdminUpload();
                    } else if (value == 'logout') {
                      _logoutAdmin();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'upload',
                      child: Row(
                        children: [
                          Icon(Icons.upload),
                          SizedBox(width: 8),
                          TranslatedText('upload_policy'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout),
                          SizedBox(width: 8),
                          TranslatedText('logout_admin'),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.admin_panel_settings),
                  onPressed: _checkAdminAndNavigate,
                  tooltip: Provider.of<LanguageService>(context, listen: false).translate('admin_login'),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Consumer<CategoryService>(
          builder: (context, categoryService, child) {
            final categories = categoryService.categories;
            
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Find Schemes for You Button
                  _buildFindSchemesButton(),
                  const SizedBox(height: 24),
                  // Category Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: TranslatedText(
                      'browse_by_category',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Categories
                  Consumer<FirebaseFirestoreService>(
                    builder: (context, firestoreService, _) {
                      // Refresh counts when policies change
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _loadCategoryCounts();
                      });
                      
                      return Column(
                        children: categories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: SizedBox(
                              height: 120,
                              child: _buildCategoryCard(category, isHorizontal: true),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[600]!,
              Colors.purple[600]!,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatScreen(),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.chat, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFindSchemesButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple[400]!,
            Colors.pink[400]!,
            Colors.orange[400]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openQuestionnaire,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TranslatedText(
                        'find_schemes',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      TranslatedText(
                        'personalized_recommendations',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Color _getCategoryColor(String category) {
    switch (category) {
      case 'All':
        return Colors.blue;
      case 'Agriculture':
        return Colors.green;
      case 'Education':
        return Colors.orange;
      case 'Healthcare':
        return Colors.red;
      case 'Housing':
        return Colors.purple;
      case 'Social Welfare':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCategoryCard(String category, {bool isHorizontal = false}) {
    IconData categoryIcon;
    List<Color> categoryGradientColors;
    
    switch (category) {
      case 'All':
        categoryIcon = Icons.apps;
        categoryGradientColors = [Colors.blue[400]!, Colors.blue[600]!];
        break;
      case 'Agriculture':
        categoryIcon = Icons.agriculture;
        categoryGradientColors = [Colors.green[400]!, Colors.green[600]!];
        break;
      case 'Education':
        categoryIcon = Icons.school;
        categoryGradientColors = [Colors.orange[400]!, Colors.orange[600]!];
        break;
      case 'Healthcare':
        categoryIcon = Icons.health_and_safety;
        categoryGradientColors = [Colors.red[400]!, Colors.red[600]!];
        break;
      case 'Housing':
        categoryIcon = Icons.home;
        categoryGradientColors = [Colors.purple[400]!, Colors.purple[600]!];
        break;
      case 'Social Welfare':
        categoryIcon = Icons.favorite;
        categoryGradientColors = [Colors.pink[400]!, Colors.pink[600]!];
        break;
      default:
        categoryIcon = Icons.category;
        categoryGradientColors = [Colors.grey[400]!, Colors.grey[600]!];
        break;
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: () => _navigateToCategory(category),
        onLongPress: () => _showDeleteCategoryDialog(category),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: categoryGradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: categoryGradientColors[0].withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isHorizontal
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          categoryIcon,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    category,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${_getCategoryCount(category)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            TranslatedText(
                              category == 'All' ? 'view_all_policies' : 'view_policies',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.8),
                        size: 18,
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          categoryIcon,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${_getCategoryCount(category)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TranslatedText(
                        'view_policies',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}