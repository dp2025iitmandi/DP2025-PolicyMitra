import 'package:flutter/foundation.dart';
import '../models/policy_model.dart';
import '../models/user_profile_model.dart';
import 'firebase_firestore_service.dart';

class RecommendationService extends ChangeNotifier {
  FirebaseFirestoreService? _firestoreService;
  
  UserProfile? _userProfile;
  List<PolicyModel> _recommendedPolicies = [];
  bool _isLoading = false;

  UserProfile? get userProfile => _userProfile;
  List<PolicyModel> get recommendedPolicies => _recommendedPolicies;
  bool get isLoading => _isLoading;

  RecommendationService();

  // Set firestore service
  void setFirestoreService(FirebaseFirestoreService service) {
    _firestoreService = service;
  }

  // Set user profile
  void setUserProfile(UserProfile profile) {
    _userProfile = profile;
    notifyListeners();
  }

  // Get recommendations based on user profile
  Future<List<PolicyModel>> getRecommendations(UserProfile profile) async {
    try {
      if (_firestoreService == null) {
        debugPrint('FirestoreService not set in RecommendationService');
        return [];
      }

      _isLoading = true;
      notifyListeners();

      // Fetch all policies
      await _firestoreService!.fetchPolicies();
      final allPolicies = _firestoreService!.policies;

      if (allPolicies.isEmpty) {
        _recommendedPolicies = [];
        _isLoading = false;
        notifyListeners();
        return [];
      }

      // Score each policy based on user profile (normalized 0.0 to 1.0)
      final scoredPolicies = allPolicies.map((policy) {
        final relevanceScore = _calculateRelevanceScore(policy, profile);
        // Apply business logic bonuses (like video bonus)
        var finalScore = relevanceScore;
        if (policy.videoUrl != null && policy.videoUrl!.isNotEmpty) {
          finalScore += 0.1; // 10% boost for having a video
        }
        return MapEntry(policy, MapEntry(relevanceScore, finalScore));
      }).toList();

      // Filter by relevance threshold (50% match minimum) - ensure high quality recommendations
      const relevanceThreshold = 0.5;
      var filteredPolicies = scoredPolicies
          .where((entry) => entry.value.key >= relevanceThreshold)
          .toList();
      
      // If no policies meet threshold, show top 10 highest scored anyway to ensure user sees results
      if (filteredPolicies.isEmpty && scoredPolicies.isNotEmpty) {
        // Sort all policies by score and take top 10
        final sortedAll = scoredPolicies.toList()
          ..sort((a, b) => b.value.value.compareTo(a.value.value));
        filteredPolicies = sortedAll.take(10).toList();
      }

      // Sort by final score (highest first)
      filteredPolicies.sort((a, b) => b.value.value.compareTo(a.value.value));

      // Return top 20 most relevant policies
      _recommendedPolicies = filteredPolicies
          .take(20)
          .map((entry) => entry.key)
          .toList();

      _isLoading = false;
      notifyListeners();
      
      debugPrint('Found ${_recommendedPolicies.length} recommended policies');
      return _recommendedPolicies;
    } catch (e) {
      debugPrint('Error getting recommendations: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // Calculate normalized relevance score (0.0 to 1.0) for a policy based on user profile
  double _calculateRelevanceScore(PolicyModel policy, UserProfile profile) {
    double score = 0.0;
    double maxPossibleScore = 0.0;
    
    // Base score for all policies to ensure minimum 50% relevance for matching policies
    double baseScore = 20.0;
    score += baseScore;
    maxPossibleScore += baseScore;
    
    final policyContent = policy.content.toLowerCase();
    final policyTitle = policy.title.toLowerCase();
    final policyDescription = policy.description.toLowerCase();
    final combinedText = '$policyTitle $policyDescription $policyContent';
    
    // 1. Category Match (80 points max)
    if (profile.category != null) {
      maxPossibleScore += 80.0;
      final categoryLower = profile.category!.toLowerCase();
      bool categoryMatched = false;
      
      // Enhanced matching for categories with better keyword detection
      if (categoryLower == 'sc') {
        if (combinedText.contains('schedule caste') || 
            combinedText.contains('scheduled caste') ||
            combinedText.contains('sc category') ||
            combinedText.contains('sc/') ||
            (combinedText.contains('sc') && (combinedText.contains('category') || combinedText.contains('eligible')))) {
          score += 80.0;
          categoryMatched = true;
        } else {
          // Penalty for wrong category
          if (combinedText.contains('st category') || combinedText.contains('obc category') || 
              combinedText.contains('general only') || combinedText.contains('not for sc')) {
            score -= 30.0;
          }
        }
      } else if (categoryLower == 'st') {
        if (combinedText.contains('schedule tribe') || 
            combinedText.contains('scheduled tribe') ||
            combinedText.contains('st category') ||
            combinedText.contains('st/') ||
            (combinedText.contains('st') && (combinedText.contains('category') || combinedText.contains('eligible')))) {
          score += 80.0;
          categoryMatched = true;
        } else {
          if (combinedText.contains('sc category') || combinedText.contains('obc category') || 
              combinedText.contains('general only') || combinedText.contains('not for st')) {
            score -= 30.0;
          }
        }
      } else if (categoryLower == 'obc') {
        if (combinedText.contains('other backward') || 
            combinedText.contains('obc') ||
            combinedText.contains('backward class') ||
            combinedText.contains('obc category')) {
          score += 80.0;
          categoryMatched = true;
        } else {
          if (combinedText.contains('sc category') || combinedText.contains('st category') || 
              combinedText.contains('general only') || combinedText.contains('not for obc')) {
            score -= 30.0;
          }
        }
      } else if (categoryLower == 'dnt') {
        if (combinedText.contains('denotified') || 
            combinedText.contains('dnt') || 
            combinedText.contains('nomadic') ||
            combinedText.contains('vjnt')) {
          score += 80.0;
          categoryMatched = true;
        }
      } else if (categoryLower == 'pvtg') {
        if (combinedText.contains('primitive') || 
            combinedText.contains('pvtg') || 
            combinedText.contains('tribal group') ||
            combinedText.contains('particularly vulnerable')) {
          score += 80.0;
          categoryMatched = true;
        }
      } else if (categoryLower == 'general') {
        // General category - schemes that don't specify any category or explicitly say "all"
        if (combinedText.contains('all categories') ||
            combinedText.contains('open to all') ||
            combinedText.contains('general category') ||
            (!combinedText.contains('sc') && !combinedText.contains('st') && 
             !combinedText.contains('obc') && !combinedText.contains('dnt') &&
             !combinedText.contains('schedule caste') && !combinedText.contains('schedule tribe') &&
             !combinedText.contains('category'))) {
          score += 80.0; // Increased from 50 to match other categories
          categoryMatched = true;
        } else {
          // Even if not explicitly general, give some points for general schemes
          score += 30.0;
        }
      }
      
      // If category criteria exists but doesn't match, reduce max score
      if (!categoryMatched && combinedText.contains('category')) {
        maxPossibleScore -= 30.0; // Adjust max score if category mismatch
      }
    }

    // 2. State Match (50 points max)
    if (profile.state != null) {
      maxPossibleScore += 50.0;
      final stateLower = profile.state!.toLowerCase();
      if (combinedText.contains(stateLower) ||
          combinedText.contains('${stateLower} state') ||
          combinedText.contains('${stateLower} government') ||
          combinedText.contains('${stateLower} residents')) {
        score += 50.0;
      }
    }

    // 3. Area of Residence (30 points max)
    if (profile.areaOfResidence != null) {
      maxPossibleScore += 30.0;
      final areaLower = profile.areaOfResidence!.toLowerCase();
      if (combinedText.contains(areaLower) ||
          (areaLower == 'rural' && combinedText.contains('village')) ||
          (areaLower == 'urban' && combinedText.contains('city'))) {
        score += 30.0;
      }
    }

    // 4. Disability (40 points max)
    if (profile.hasDisability == true) {
      maxPossibleScore += 40.0;
      if (combinedText.contains('disability') ||
          combinedText.contains('disabled') ||
          combinedText.contains('handicap') ||
          combinedText.contains('divyang')) {
        score += 40.0;
      }
    }

    // 5. Minority (35 points max)
    if (profile.isMinority == true) {
      maxPossibleScore += 35.0;
      if (combinedText.contains('minority') ||
          combinedText.contains('muslim') ||
          combinedText.contains('christian') ||
          combinedText.contains('sikh') ||
          combinedText.contains('jain') ||
          combinedText.contains('buddhist') ||
          combinedText.contains('parsi')) {
        score += 35.0;
      }
    }

    // 6. Student (35 points max)
    if (profile.isStudent == true) {
      maxPossibleScore += 35.0;
      if (combinedText.contains('student') ||
          combinedText.contains('education') ||
          combinedText.contains('scholarship') ||
          combinedText.contains('tuition') ||
          combinedText.contains('school') ||
          combinedText.contains('college') ||
          combinedText.contains('university')) {
        score += 35.0;
      }
    }

    // 7. BPL (40 points max)
    if (profile.isBPL == true) {
      maxPossibleScore += 40.0;
      if (combinedText.contains('bpl') ||
          combinedText.contains('below poverty') ||
          combinedText.contains('poverty line') ||
          combinedText.contains('poor') ||
          combinedText.contains('economically weaker')) {
        score += 40.0;
        
        // Income-based matching (additional points)
        if (profile.annualIncome != null) {
          if (profile.annualIncome! < 50000) {
            if (combinedText.contains('50') || combinedText.contains('fifty thousand')) {
              score += 20.0;
              maxPossibleScore += 20.0;
            }
          } else if (profile.annualIncome! < 100000) {
            if (combinedText.contains('100') || combinedText.contains('one lakh')) {
              score += 15.0;
              maxPossibleScore += 15.0;
            }
          }
        }
      }
    }

    // 8. Age-based (25-30 points max)
    if (profile.age != null) {
      if (profile.age! >= 60) {
        maxPossibleScore += 30.0;
        if (combinedText.contains('senior') ||
            combinedText.contains('elderly') ||
            combinedText.contains('60') ||
            combinedText.contains('pension')) {
          score += 30.0;
        }
      } else if (profile.age! >= 18 && profile.age! <= 35) {
        maxPossibleScore += 25.0;
        if (combinedText.contains('youth') ||
            combinedText.contains('young') ||
            combinedText.contains('employment') ||
            combinedText.contains('skill')) {
          score += 25.0;
        }
      } else if (profile.age! < 18) {
        maxPossibleScore += 25.0;
        if (combinedText.contains('child') ||
            combinedText.contains('kid') ||
            combinedText.contains('education') ||
            combinedText.contains('school')) {
          score += 25.0;
        }
      }
    }

    // 9. Gender (30 points max)
    if (profile.gender != null) {
      maxPossibleScore += 30.0;
      final genderLower = profile.gender!.toLowerCase();
      if (genderLower == 'female') {
        if (combinedText.contains('women') ||
            combinedText.contains('female') ||
            combinedText.contains('girl') ||
            combinedText.contains('ladies') ||
            combinedText.contains('mahila')) {
          score += 30.0;
        }
      }
    }

    // 10. Category Boosts (30 points max)
    if (policy.category.toLowerCase() == 'education' && profile.isStudent == true) {
      maxPossibleScore += 30.0;
      score += 30.0;
    }
    if (policy.category.toLowerCase() == 'social welfare' && profile.isBPL == true) {
      maxPossibleScore += 30.0;
      score += 30.0;
    }
    if (policy.category.toLowerCase() == 'healthcare' && profile.hasDisability == true) {
      maxPossibleScore += 30.0;
      score += 30.0;
    }
    if (policy.category.toLowerCase() == 'agriculture' && profile.areaOfResidence == 'rural') {
      maxPossibleScore += 25.0;
      score += 25.0;
    }
    if (policy.category.toLowerCase() == 'housing' && profile.isBPL == true) {
      maxPossibleScore += 25.0;
      score += 25.0;
    }

    // Ensure score is non-negative
    score = score < 0 ? 0.0 : score;
    
    // Normalize to 0.0 to 1.0
    if (maxPossibleScore == 0) {
      // If no profile data at all, return base score of 50%
      return 0.5; // 50% base relevance
    }
    
    final normalizedScore = score / maxPossibleScore;
    
    // Ensure minimum score of 0.5 (50%) for any policy that has some match
    // Policies with at least one matching criteria should reach 50%
    if (score > baseScore) {
      // If policy has any match beyond base score, ensure at least 50%
      return normalizedScore < 0.5 ? 0.5 : normalizedScore;
    }
    
    // If no matches, return actual normalized score (will be filtered out by threshold)
    return normalizedScore;
  }

  // Refresh recommendations
  Future<void> refreshRecommendations() async {
    if (_userProfile != null) {
      await getRecommendations(_userProfile!);
    }
  }
}

