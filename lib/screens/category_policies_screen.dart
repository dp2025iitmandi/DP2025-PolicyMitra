import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_firestore_service.dart';
import '../services/admin_service.dart';
import '../services/supabase_favorites_service.dart';
import '../models/policy_model.dart';
import 'policy_detail_screen.dart';
import 'chat_screen.dart';

class CategoryPoliciesScreen extends StatefulWidget {
  final String category;

  const CategoryPoliciesScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryPoliciesScreen> createState() => _CategoryPoliciesScreenState();
}

enum SortOrder { newestFirst, oldestFirst }

class _CategoryPoliciesScreenState extends State<CategoryPoliciesScreen> {
  final TextEditingController _searchController = TextEditingController();
  SortOrder _sortOrder = SortOrder.newestFirst;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPolicies();
    });
  }

  void _loadPolicies() {
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
    if (widget.category == 'All') {
      firestoreService.fetchPolicies();
    } else {
      firestoreService.filterPoliciesByCategory(widget.category);
    }
  }

  void _applySorting() {
    // Trigger rebuild to apply sorting
    setState(() {});
  }

  Future<void> _refreshPolicies() async {
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
    if (widget.category == 'All') {
      await firestoreService.fetchPolicies();
    } else {
      await firestoreService.filterPoliciesByCategory(widget.category);
    }
    
    // Also refresh favorites
    final favoritesService = Provider.of<SupabaseFavoritesService>(context, listen: false);
    await favoritesService.loadFavorites();
  }

  void _searchPolicies(String keyword) {
    final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
    if (keyword.isEmpty) {
      _loadPolicies();
    } else {
      firestoreService.searchPoliciesInCategory(keyword, widget.category);
    }
  }


  Future<void> _deletePolicy(PolicyModel policy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Policy'),
        content: Text('Are you sure you want to delete "${policy.title}"?\n\nThis will also delete the associated video if any.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleting policy...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      final success = await firestoreService.deletePolicy(policy.id);
      
      if (success && mounted) {
        // Re-filter by category to maintain category view
        await _refreshPolicies();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Policy and associated video deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete policy'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        title: Text(
          widget.category,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
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
          // Sort dropdown button
          PopupMenuButton<SortOrder>(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: 'Sort Policies',
            onSelected: (SortOrder order) {
              setState(() {
                _sortOrder = order;
              });
              _applySorting();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOrder>>[
              PopupMenuItem<SortOrder>(
                value: SortOrder.newestFirst,
                child: Row(
                  children: [
                    Icon(
                      _sortOrder == SortOrder.newestFirst ? Icons.check : null,
                      color: _sortOrder == SortOrder.newestFirst ? Colors.blue : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Uploaded Last (Newest First)'),
                  ],
                ),
              ),
              PopupMenuItem<SortOrder>(
                value: SortOrder.oldestFirst,
                child: Row(
                  children: [
                    Icon(
                      _sortOrder == SortOrder.oldestFirst ? Icons.check : null,
                      color: _sortOrder == SortOrder.oldestFirst ? Colors.blue : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Uploaded First (Oldest First)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
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
            child: TextField(
              controller: _searchController,
              maxLines: 1,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search policies in ${widget.category}...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _searchPolicies('');
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
                _searchPolicies(value);
              },
              onSubmitted: (value) {
                _searchPolicies(value);
              },
            ),
          ),
          // Policies List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPolicies,
              child: Consumer<FirebaseFirestoreService>(
                builder: (context, firestoreService, child) {
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
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[400]!, Colors.blue[600]!],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: _loadPolicies,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                List<PolicyModel> policies = List.from(firestoreService.policies);
                
                // Apply sorting
                policies.sort((a, b) {
                  if (a.createdAt == null && b.createdAt == null) return 0;
                  if (a.createdAt == null) return 1;
                  if (b.createdAt == null) return -1;
                  
                  if (_sortOrder == SortOrder.newestFirst) {
                    // Newest first (descending)
                    return b.createdAt!.compareTo(a.createdAt!);
                  } else {
                    // Oldest first (ascending)
                    return a.createdAt!.compareTo(b.createdAt!);
                  }
                });
                
                if (policies.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No policies found in ${widget.category}'
                              : 'No policies found matching "${_searchController.text}"',
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
                  itemCount: policies.length,
                  itemBuilder: (context, index) {
                    final policy = policies[index];
                    return _buildPolicyCard(policy);
                  },
                );
              },
            ),
            ),
          ),
        ],
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

  Widget _buildPolicyCard(PolicyModel policy) {
    final categoryColor = _getCategoryColor(policy.category);
    final gradientColors = [
      categoryColor.withOpacity(0.1),
      categoryColor.withOpacity(0.05),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
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
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title, video icon, star, and delete button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video icon if video exists
                    if (policy.videoUrl != null && policy.videoUrl!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.videocam,
                          color: Colors.red,
                          size: 18,
                        ),
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
                            size: 24,
                          ),
                          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Delete button (admin only)
                    Consumer<AdminService>(
                      builder: (context, adminService, child) {
                        if (adminService.isAdmin) {
                          return IconButton(
                            onPressed: () => _deletePolicy(policy),
                            icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                            tooltip: 'Delete Policy',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Policy Description
                Text(
                  policy.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Category Badge with arrow
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        policy.category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: categoryColor,
                      size: 16,
                    ),
                  ],
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
