import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/policy_model.dart';
import 'firebase_storage_service.dart';

class FirebaseFirestoreService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorageService _storageService = FirebaseStorageService();
  
  List<PolicyModel> _policies = [];
  bool _isLoading = false;
  String? _error;

  List<PolicyModel> get policies => _policies;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch all policies
  Future<void> fetchPolicies() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final QuerySnapshot snapshot = await _firestore
          .collection('policies')
          .orderBy('createdAt', descending: true)
          .get();

      _policies = snapshot.docs
          .map((doc) => PolicyModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching policies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Enhanced search with multiple fields - fetch all and filter locally for better results
  Future<void> searchPolicies(String keyword) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('Searching for keyword: $keyword');

      // First, fetch all policies to ensure we have the latest data
      final QuerySnapshot snapshot = await _firestore
          .collection('policies')
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint('Fetched ${snapshot.docs.length} policies for search');

      // Convert to PolicyModel list
      final List<PolicyModel> allPolicies = snapshot.docs
          .map((doc) => PolicyModel.fromFirestore(doc))
          .toList();

      // Filter policies locally for better search results - ONLY TITLE MATCHES
      final List<PolicyModel> searchResults = allPolicies.where((policy) {
        final keywordLower = keyword.toLowerCase();
        return policy.title.toLowerCase().contains(keywordLower);
      }).toList();

      // Sort by relevance (exact title matches first, then partial matches)
      searchResults.sort((a, b) {
        final keywordLower = keyword.toLowerCase();
        final aTitle = a.title.toLowerCase();
        final bTitle = b.title.toLowerCase();
        
        // Exact title match has highest priority
        final aExactMatch = aTitle == keywordLower;
        final bExactMatch = bTitle == keywordLower;
        if (aExactMatch && !bExactMatch) return -1;
        if (!aExactMatch && bExactMatch) return 1;
        
        // Title starts with keyword has second priority
        final aStartsWith = aTitle.startsWith(keywordLower);
        final bStartsWith = bTitle.startsWith(keywordLower);
        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;
        
        // Then sort by creation date (newest first)
        if (a.createdAt != null && b.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return 0;
      });

      _policies = searchResults;
      debugPrint('Found ${searchResults.length} matching policies');
    } catch (e) {
      _error = e.toString();
      debugPrint('Error searching policies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search policies within a specific category
  Future<void> searchPoliciesInCategory(String keyword, String category) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('Searching for keyword: $keyword in category: $category');

      // Fetch all policies first (without complex queries that need indexes)
      final QuerySnapshot snapshot = await _firestore
          .collection('policies')
          .get();

      // Convert to PolicyModel list
      final List<PolicyModel> allPolicies = snapshot.docs
          .map((doc) => PolicyModel.fromFirestore(doc))
          .toList();

      debugPrint('Fetched ${allPolicies.length} total policies');

      // Filter by category first (if not 'All')
      List<PolicyModel> categoryPolicies;
      if (category == 'All') {
        categoryPolicies = allPolicies;
      } else {
        categoryPolicies = allPolicies.where((policy) => 
          policy.category.toLowerCase() == category.toLowerCase()
        ).toList();
      }

      debugPrint('Filtered to ${categoryPolicies.length} policies in category: $category');

      // Then filter by search keyword within the category - ONLY TITLE MATCHES
      final List<PolicyModel> searchResults = categoryPolicies.where((policy) {
        final keywordLower = keyword.toLowerCase();
        return policy.title.toLowerCase().contains(keywordLower);
      }).toList();

      // Sort by relevance (exact title matches first, then partial matches)
      searchResults.sort((a, b) {
        final keywordLower = keyword.toLowerCase();
        final aTitle = a.title.toLowerCase();
        final bTitle = b.title.toLowerCase();
        
        // Exact title match has highest priority
        final aExactMatch = aTitle == keywordLower;
        final bExactMatch = bTitle == keywordLower;
        if (aExactMatch && !bExactMatch) return -1;
        if (!aExactMatch && bExactMatch) return 1;
        
        // Title starts with keyword has second priority
        final aStartsWith = aTitle.startsWith(keywordLower);
        final bStartsWith = bTitle.startsWith(keywordLower);
        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;
        
        // Then sort by creation date (newest first)
        if (a.createdAt != null && b.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return 0;
      });

      _policies = searchResults;
      debugPrint('Found ${searchResults.length} matching policies in category: $category');
    } catch (e) {
      _error = e.toString();
      debugPrint('Error searching policies in category: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filter policies by category
  Future<void> filterPoliciesByCategory(String category) async {
    try {
      debugPrint('Filtering policies by category: $category');
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Simple query without orderBy to avoid index requirement
      final QuerySnapshot snapshot = await _firestore
          .collection('policies')
          .where('category', isEqualTo: category)
          .get();

      debugPrint('Found ${snapshot.docs.length} policies for category: $category');
      
      _policies = snapshot.docs
          .map((doc) {
            final policy = PolicyModel.fromFirestore(doc);
            debugPrint('Policy: ${policy.title} - Category: ${policy.category}');
            return policy;
          })
          .toList();
          
      // Sort by createdAt locally
      _policies.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
          
      debugPrint('Final policies list length: ${_policies.length}');
    } catch (e) {
      _error = e.toString();
      debugPrint('Error filtering policies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get policy by ID
  Future<PolicyModel?> getPolicyById(String id) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('policies')
          .doc(id)
          .get();

      if (doc.exists) {
        return PolicyModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching policy: $e');
      return null;
    }
  }

  // Category variations mapping (same as admin_scheme_service)
  static const Map<String, List<String>> _categoryVariations = {
    'Agriculture': ['agriculture', 'agricultural', 'farming', 'farm', 'agri', 'agr', 'crop', 'crops', 'farmer', 'farmers', 'cultivation'],
    'Education': ['education', 'educational', 'school', 'study', 'learn', 'learning', 'student', 'students', 'university', 'college', 'teach', 'teaching'],
    'Healthcare': ['healthcare', 'health', 'medical', 'medicine', 'health care', 'med', 'hospital', 'hospitals', 'treatment', 'clinic', 'doctor'],
    'Housing': ['housing', 'house', 'home', 'residence', 'shelter', 'residential', 'dwelling', 'property', 'accommodation', 'flat', 'apartment'],
    'Social Welfare': ['social welfare', 'socialwelfare', 'welfare', 'social', 'social-wellfare', 'benefits', 'scheme', 'schemes', 'aid', 'assistance', 'support']
  };

  // Cache for normalized categories to avoid duplicate processing
  static final Map<String, String> _categoryNormalizationCache = {};

  // Normalize category to standard database format (case-insensitive)
  // Maps variations like "agri", "agriculture", "Agriculture" all to "Agriculture"
  String _normalizeCategory(String category) {
    final categoryLower = category.trim().toLowerCase();
    
    // Check cache first
    if (_categoryNormalizationCache.containsKey(categoryLower)) {
      return _categoryNormalizationCache[categoryLower]!;
    }
    
    String? normalized;
    
    // Check exact matches first
    for (final dbCategory in _categoryVariations.keys) {
      if (dbCategory.toLowerCase() == categoryLower) {
        normalized = dbCategory;
        break;
      }
    }
    
    // Check variations if not found
    if (normalized == null) {
      for (final entry in _categoryVariations.entries) {
        final dbCategoryName = entry.key;
        final variations = entry.value;
        
        // Check if category matches any variation
        if (variations.any((v) => v.toLowerCase() == categoryLower)) {
          normalized = dbCategoryName;
          break;
        }
        
        // Check if category contains variation or vice versa
        for (final variation in variations) {
          if (categoryLower.contains(variation.toLowerCase()) || 
              variation.toLowerCase().contains(categoryLower)) {
            normalized = dbCategoryName;
            break;
          }
        }
        if (normalized != null) break;
      }
    }
    
    // If no match found, return original with first letter capitalized
    if (normalized == null) {
      if (category.isEmpty) {
        normalized = category;
      } else {
        normalized = category[0].toUpperCase() + category.substring(1).toLowerCase();
      }
    }
    
    // Cache the result
    _categoryNormalizationCache[categoryLower] = normalized;
    return normalized;
  }

  // Check for duplicate policy (same title or description in same category)
  // Categories are compared case-insensitively (e.g., "Agriculture", "agriculture", "agri" are same)
  Future<bool> isDuplicatePolicy(String title, String? description, String category) async {
    try {
      final titleLower = title.trim().toLowerCase();
      final descriptionLower = (description ?? '').trim().toLowerCase();
      final categoryNormalized = _normalizeCategory(category);
      
      debugPrint('[DUPLICATE_CHECK] Checking for duplicate: "$title" in category "$category" (normalized: "$categoryNormalized")');
      
      // Query policies with same normalized category
      final QuerySnapshot snapshot = await _firestore
          .collection('policies')
          .where('category', isEqualTo: categoryNormalized)
          .get();

      // Check if any policy has the same title OR description (case-insensitive)
      for (var doc in snapshot.docs) {
        final policyData = doc.data() as Map<String, dynamic>;
        final existingTitle = (policyData['title'] as String? ?? '').trim().toLowerCase();
        final existingDescription = (policyData['description'] as String? ?? '').trim().toLowerCase();
        final existingCategory = policyData['category'] as String? ?? '';
        
        // Normalize existing category for comparison
        final existingCategoryNormalized = _normalizeCategory(existingCategory);
        
        // Check for duplicate title or description
        if ((existingTitle == titleLower || 
             (descriptionLower.isNotEmpty && existingDescription == descriptionLower)) && 
            existingCategoryNormalized == categoryNormalized) {
          debugPrint('[DUPLICATE_CHECK] Duplicate found: "$title" (title match: ${existingTitle == titleLower}, desc match: ${descriptionLower.isNotEmpty && existingDescription == descriptionLower})');
          return true;
        }
      }
      
      debugPrint('[DUPLICATE_CHECK] No duplicate found for "$title" in category "$categoryNormalized"');
      return false;
    } catch (e) {
      debugPrint('[DUPLICATE_CHECK] Error checking for duplicate policy: $e');
      // On error, allow the policy to be created (fail open)
      return false;
    }
  }

  Future<bool> createPolicy(PolicyModel policy) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Check for duplicate policy (same title or description in same category)
      final isDuplicate = await isDuplicatePolicy(policy.title, policy.description, policy.category);
      if (isDuplicate) {
        _error = 'A policy with the same title or description already exists in this category. Please use a different title or description.';
        debugPrint('Policy creation rejected: Duplicate policy');
        return false;
      }

      // Ensure policy has proper indexing fields
      final policyData = policy.toFirestore();
      policyData['searchKeywords'] = _generateSearchKeywords(policy);
      policyData['lastUpdated'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('policies')
          .doc(policy.id)
          .set(policyData);

      debugPrint('Policy created with ID: ${policy.id}');
      
      // Refresh policies list
      await fetchPolicies();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error creating policy: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Generate search keywords for better indexing
  List<String> _generateSearchKeywords(PolicyModel policy) {
    final keywords = <String>{};
    
    // Add individual words from title
    keywords.addAll(policy.title.toLowerCase().split(' '));
    
    // Add individual words from description
    keywords.addAll(policy.description.toLowerCase().split(' '));
    
    // Add individual words from content (first 500 chars to avoid too many keywords)
    final contentWords = policy.content.length > 500 
        ? policy.content.substring(0, 500).toLowerCase().split(' ')
        : policy.content.toLowerCase().split(' ');
    keywords.addAll(contentWords);
    
    // Add category
    keywords.add(policy.category.toLowerCase());
    
    // Remove empty strings and duplicates
    return keywords.where((word) => word.isNotEmpty && word.length > 2).toList();
  }

  // Re-index all policies for better search
  Future<void> reindexAllPolicies() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('Starting re-indexing of all policies...');
      
      // Fetch all policies
      final QuerySnapshot snapshot = await _firestore
          .collection('policies')
          .get();

      debugPrint('Found ${snapshot.docs.length} policies to re-index');

      // Update each policy with search keywords
      final batch = _firestore.batch();
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final policy = PolicyModel.fromFirestore(doc);
          final searchKeywords = _generateSearchKeywords(policy);
          
          batch.update(doc.reference, {
            'searchKeywords': searchKeywords,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          
          updatedCount++;
        } catch (e) {
          debugPrint('Error processing policy ${doc.id}: $e');
        }
      }

      // Commit the batch update
      await batch.commit();
      
      debugPrint('Successfully re-indexed $updatedCount policies');
      
      // Refresh the policies list
      await fetchPolicies();
      
    } catch (e) {
      _error = e.toString();
      debugPrint('Error re-indexing policies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update policy (Admin only)
  Future<bool> updatePolicy(PolicyModel policy) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore
          .collection('policies')
          .doc(policy.id)
          .update(policy.toFirestore());

      // Refresh policies list
      await fetchPolicies();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating policy: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete policy (Admin only)
  Future<bool> deletePolicy(String id) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get policy first to check for video URL
      final policyDoc = await _firestore.collection('policies').doc(id).get();
      if (policyDoc.exists) {
        final policyData = policyDoc.data();
        final videoUrl = policyData?['videoUrl'] as String?;
        
        // Delete video from Firebase Storage if it exists
        if (videoUrl != null && videoUrl.isNotEmpty) {
          try {
            await _storageService.deleteVideo(videoUrl);
            debugPrint('Video deleted successfully: $videoUrl');
          } catch (e) {
            debugPrint('Error deleting video: $e (continuing with policy deletion)');
            // Continue with policy deletion even if video deletion fails
          }
        }
      }

      // Delete policy from Firestore
      await _firestore
          .collection('policies')
          .doc(id)
          .delete();

      // Remove from current list immediately to prevent showing deleted policy
      _policies.removeWhere((policy) => policy.id == id);
      notifyListeners();

      // Note: We don't call fetchPolicies() here automatically
      // The caller should refresh with appropriate filter (e.g., category) to maintain view state
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting policy: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete all policies in a category
  Future<bool> deletePoliciesInCategory(String category) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('Deleting all policies in category: $category');

      // Fetch policies in category
      final QuerySnapshot snapshot = await _firestore
          .collection('policies')
          .where('category', isEqualTo: category)
          .get();

      final List<String> policyIds = snapshot.docs.map((doc) => doc.id).toList();
      
      debugPrint('Found ${policyIds.length} policies to delete in category: $category');

      // Delete all policies
      final WriteBatch batch = _firestore.batch();
      for (final policyId in policyIds) {
        batch.delete(_firestore.collection('policies').doc(policyId));
      }
      await batch.commit();

      // Remove from current list
      _policies.removeWhere((policy) => policy.category == category);
      
      debugPrint('Successfully deleted ${policyIds.length} policies from category: $category');
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting policies in category: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Move policies to "All" category with "Misc" tag
  Future<bool> movePoliciesToAll(String category) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('Moving policies from category $category to All with Misc tag');

      // Fetch policies in category
      final QuerySnapshot snapshot = await _firestore
          .collection('policies')
          .where('category', isEqualTo: category)
          .get();

      final List<DocumentSnapshot> policies = snapshot.docs;
      
      debugPrint('Found ${policies.length} policies to move from category: $category');

      // Update all policies
      final WriteBatch batch = _firestore.batch();
      for (final doc in policies) {
        batch.update(doc.reference, {
          'category': 'All',
          'tags': FieldValue.arrayUnion(['Misc']),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Refresh policies list
      await fetchPolicies();
      
      debugPrint('Successfully moved ${policies.length} policies to All category with Misc tag');
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error moving policies to All: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
