import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_firestore_service.dart';
import '../services/supabase_favorites_service.dart';
import '../services/speech_service.dart';
import '../models/policy_model.dart';
import 'policy_detail_screen.dart';
import 'chat_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
    });
  }

  void _loadFavorites() {
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
    firestoreService.fetchPolicies();
  }

  Future<void> _refreshFavorites() async {
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
    await firestoreService.fetchPolicies();
    
    final favoritesService = Provider.of<SupabaseFavoritesService>(context, listen: false);
    await favoritesService.loadFavorites();
  }

  void _searchFavorites(String keyword) {
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
    if (keyword.isEmpty) {
      _loadFavorites();
    } else {
      firestoreService.searchPolicies(keyword);
    }
  }


  Future<void> _toggleFavorite(PolicyModel policy) async {
    final favoritesService = Provider.of<SupabaseFavoritesService>(context, listen: false);
    await favoritesService.toggleFavorite(policy.id);
    
    if (mounted) {
      final isFavorite = favoritesService.isFavorite(policy.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite ? 'Added to favorites' : 'Removed from favorites',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[600],
            child: TextField(
              controller: _searchController,
              maxLines: null,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search favorites...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _searchFavorites('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
              onChanged: (value) {
                setState(() {});
                _searchFavorites(value);
              },
              onSubmitted: (value) {
                _searchFavorites(value);
              },
            ),
          ),
          // Favorites List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshFavorites,
              child: Consumer2<FirebaseFirestoreService, SupabaseFavoritesService>(
                builder: (context, firestoreService, favoritesService, child) {
                if (firestoreService.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (firestoreService.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${firestoreService.error}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadFavorites,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                // Filter policies to show only favorites
                final allPolicies = firestoreService.policies;
                final favoritePolicies = allPolicies.where((policy) {
                  return favoritesService.isFavorite(policy.id);
                }).toList();

                if (favoritePolicies.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star_border,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No favorites yet'
                              : 'No favorites found matching "${_searchController.text}"',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: favoritePolicies.length,
                  itemBuilder: (context, index) {
                    final policy = favoritePolicies[index];
                    return _buildPolicyCard(policy);
                  },
                );
              },
            ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChatScreen(),
            ),
          );
        },
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  Widget _buildPolicyCard(PolicyModel policy) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PolicyDetailScreen(policy: policy),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title, video icon, and star
              Row(
                children: [
                  // Video icon if video exists
                  if (policy.videoUrl != null && policy.videoUrl!.isNotEmpty)
                    const Icon(
                      Icons.videocam,
                      color: Colors.red,
                      size: 20,
                    ),
                  if (policy.videoUrl != null && policy.videoUrl!.isNotEmpty)
                    const SizedBox(width: 8),
                  // Title
                  Expanded(
                    child: Text(
                      policy.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Star button
                  Consumer<SupabaseFavoritesService>(
                    builder: (context, favoritesService, child) {
                      final isFavorite = favoritesService.isFavorite(policy.id);
                      return IconButton(
                        onPressed: () => _toggleFavorite(policy),
                        icon: Icon(
                          isFavorite ? Icons.star : Icons.star_border,
                          color: isFavorite ? Colors.amber : Colors.grey,
                        ),
                        tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Policy Description
              Text(
                policy.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCategoryColor(policy.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  policy.category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _getCategoryColor(policy.category),
                  ),
                ),
              ),
            ],
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
