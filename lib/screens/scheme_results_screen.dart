import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/policy_model.dart';
import '../models/user_profile_model.dart';
import '../services/recommendation_service.dart';
import '../services/firebase_firestore_service.dart';
import '../services/groq_service.dart';
import 'policy_detail_screen.dart';

class SchemeResultsScreen extends StatefulWidget {
  final UserProfile userProfile;

  const SchemeResultsScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<SchemeResultsScreen> createState() => _SchemeResultsScreenState();
}

class _SchemeResultsScreenState extends State<SchemeResultsScreen> {
  List<PolicyModel> _recommendedSchemes = [];
  List<PolicyModel> _externalSchemePolicies = []; // Temporary policies from external schemes
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final recommendationService = Provider.of<RecommendationService>(context, listen: false);
      final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
      
      recommendationService.setFirestoreService(firestoreService);
      recommendationService.setUserProfile(widget.userProfile);
      
      // Get recommendations from database
      final recommendations = await recommendationService.getRecommendations(widget.userProfile);
      debugPrint('Loaded ${recommendations.length} recommendations from database');
      
      // Generate external schemes (schemes not in database) and convert to PolicyModel
      final externalSchemeNames = _generateExternalSchemes(widget.userProfile);
      debugPrint('Generated ${externalSchemeNames.length} external scheme names');
      final externalPolicies = await _loadExternalSchemesAsPolicies(externalSchemeNames);
      debugPrint('Loaded ${externalPolicies.length} external scheme policies');
      
      if (mounted) {
        setState(() {
          _recommendedSchemes = recommendations;
          _externalSchemePolicies = externalPolicies;
          _isLoading = false;
        });
        debugPrint('Total schemes to display: ${recommendations.length} from DB, ${externalPolicies.length} external');
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load external schemes as PolicyModel objects (temporary, in-memory only)
  Future<List<PolicyModel>> _loadExternalSchemesAsPolicies(List<String> schemeNames) async {
    final List<PolicyModel> policies = [];
    
    if (schemeNames.isEmpty) {
      debugPrint('No external scheme names generated');
      return policies;
    }
    
    debugPrint('Loading ${schemeNames.length} external schemes...');
    final groqService = Provider.of<GroqService>(context, listen: false);
    
    for (final schemeName in schemeNames) {
      try {
        debugPrint('Loading details for: $schemeName');
        final details = await groqService.generateSchemeFromName(
          schemeName,
          suggestedCategory: widget.userProfile.category,
        ).timeout(
          const Duration(seconds: 30),
        );
        
        if (details != null) {
          final policy = PolicyModel(
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}_${schemeName.hashCode}',
            title: details['title'] ?? schemeName,
            description: details['description'] ?? 'No description available.',
            category: details['category'] ?? 'All',
            link: details['link'] != null && details['link'] != 'No link available' 
                ? details['link'] 
                : null,
            content: details['content'] ?? 'No detailed information available.',
            documentsRequired: details['documentsRequired'],
            createdAt: DateTime.now(),
          );
          policies.add(policy);
          debugPrint('Successfully loaded: $schemeName');
        } else {
          // Create a basic policy if Gemini returns null
          debugPrint('Creating fallback policy for: $schemeName');
          final policy = PolicyModel(
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}_${schemeName.hashCode}',
            title: schemeName,
            description: 'Scheme details available through government portals.',
            category: 'All',
            content: 'Please visit official government websites for detailed information about this scheme.',
            createdAt: DateTime.now(),
          );
          policies.add(policy);
        }
      } catch (e, stackTrace) {
        debugPrint('Error loading external scheme $schemeName: $e');
        debugPrint('Stack trace: $stackTrace');
        // Create a basic policy even if Gemini fails or times out
        final policy = PolicyModel(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}_${schemeName.hashCode}',
          title: schemeName,
          description: 'Scheme details available through government portals.',
          category: 'All',
          content: 'Please visit official government websites for detailed information about this scheme.',
          createdAt: DateTime.now(),
        );
        policies.add(policy);
        debugPrint('Created fallback policy for: $schemeName');
      }
    }
    
    debugPrint('Loaded ${policies.length} external scheme policies');
    return policies;
  }

  // Generate external schemes based on user profile (schemes not in database)
  // Returns top 5 most relevant schemes - improved to always generate schemes
  List<String> _generateExternalSchemes(UserProfile profile) {
    final schemes = <String>[];
    
    // Priority order: Category > State > Disability > Student > BPL > Minority > Age > Gender > Area
    
    // Category-specific schemes (highest priority)
    if (profile.category != null) {
      final category = profile.category!.toUpperCase();
      if (category == 'SC') {
        schemes.add('National Scheduled Caste Scholarship Scheme');
        schemes.add('Post Matric Scholarship for SC Students');
        schemes.add('Pre-Matric Scholarship for SC Students');
      } else if (category == 'ST') {
        schemes.add('National Scheduled Tribe Scholarship Scheme');
        schemes.add('Pre-Matric Scholarship for ST Students');
        schemes.add('Post Matric Scholarship for ST Students');
      } else if (category == 'OBC') {
        schemes.add('Post Matric Scholarship for OBC Students');
        schemes.add('National Fellowship for OBC Students');
        schemes.add('Pre-Matric Scholarship for OBC Students');
      } else if (category == 'DNT') {
        schemes.add('Denotified Nomadic and Semi-Nomadic Tribes Welfare Scheme');
      } else if (category == 'PVTG') {
        schemes.add('Primitive Vulnerable Tribal Groups Development Scheme');
      }
    }
    
    // Disability-specific (high priority)
    if (profile.hasDisability == true) {
      schemes.add('Disability Pension Scheme');
      schemes.add('Divyang Scholarship Scheme');
    }
    
    // Student-specific
    if (profile.isStudent == true) {
      schemes.add('Merit Scholarship for Students');
      schemes.add('National Education Scholarship');
    }
    
    // BPL-specific
    if (profile.isBPL == true) {
      schemes.add('Below Poverty Line (BPL) Ration Card Scheme');
      schemes.add('BPL Housing Scheme');
    }
    
    // Minority-specific
    if (profile.isMinority == true) {
      schemes.add('Minority Scholarship Scheme');
      schemes.add('Pre-Matric Scholarship for Minorities');
    }
    
    // Age-specific
    if (profile.age != null) {
      if (profile.age! >= 60) {
        schemes.add('Old Age Pension Scheme');
        schemes.add('Senior Citizen Welfare Scheme');
      } else if (profile.age! >= 18 && profile.age! <= 35) {
        schemes.add('Youth Employment Scheme');
        schemes.add('Skill Development Training Scheme');
      } else if (profile.age! < 18) {
        schemes.add('Child Education Scholarship');
        schemes.add('Mid-Day Meal Scheme');
      }
    }
    
    // Gender-specific
    if (profile.gender == 'female') {
      schemes.add('Beti Bachao Beti Padhao Scheme');
      schemes.add('Women Empowerment Scheme');
    }
    
    // State-specific (fill remaining slots)
    if (profile.state != null) {
      schemes.add('${profile.state} State Government Welfare Schemes');
    }
    
    // Area-specific
    if (profile.areaOfResidence == 'rural') {
      schemes.add('Rural Development Schemes');
      schemes.add('Pradhan Mantri Gramin Awaas Yojana');
    } else if (profile.areaOfResidence == 'urban') {
      schemes.add('Urban Development Schemes');
      schemes.add('Pradhan Mantri Awas Yojana Urban');
    }
    
    // If no schemes generated yet, add general schemes
    if (schemes.isEmpty) {
      schemes.add('Pradhan Mantri Awas Yojana');
      schemes.add('Pradhan Mantri Jan Dhan Yojana');
      schemes.add('Ayushman Bharat Scheme');
    }
    
    // Return top 5 schemes (increased from 3)
    return schemes.take(5).toList();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Recommended Schemes',
          style: TextStyle(
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
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadRecommendations,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // External Schemes Section (Moved to Top) - Displayed as Policy Cards
                    if (_externalSchemePolicies.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Other Recommended Schemes',
                        Icons.explore,
                        Colors.purple,
                        _externalSchemePolicies.length,
                      ),
                      const SizedBox(height: 12),
                      ..._externalSchemePolicies.map((scheme) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildSchemeCard(scheme, isInApp: false),
                          )),
                      const SizedBox(height: 24),
                    ],
                    
                    // Schemes in App Section
                    if (_recommendedSchemes.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Schemes in App',
                        Icons.library_books,
                        Colors.blue,
                        _recommendedSchemes.length,
                      ),
                      const SizedBox(height: 12),
                      ..._recommendedSchemes.map((scheme) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildSchemeCard(scheme, isInApp: true),
                          )),
                    ],
                    
                    // Empty state
                    if (_recommendedSchemes.isEmpty && _externalSchemePolicies.isEmpty)
                      _buildEmptyState(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$count scheme${count > 1 ? 's' : ''} found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemeCard(PolicyModel scheme, {required bool isInApp}) {
    final categoryColor = _getCategoryColor(scheme.category);
    final isTemporary = scheme.id.startsWith('temp_');
    
    return Card(
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
            colors: [
              categoryColor.withOpacity(0.1),
              categoryColor.withOpacity(0.05),
            ],
          ),
          border: isTemporary 
              ? Border.all(color: Colors.purple.withOpacity(0.3), width: 1)
              : null,
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PolicyDetailScreen(policy: scheme),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isTemporary)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.purple,
                          size: 18,
                        ),
                      ),
                    if (isTemporary)
                      const SizedBox(width: 8),
                    if (scheme.videoUrl != null && scheme.videoUrl!.isNotEmpty)
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
                    if (scheme.videoUrl != null && scheme.videoUrl!.isNotEmpty)
                      const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        scheme.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  scheme.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        scheme.category,
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


  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Schemes Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your profile details',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
}

