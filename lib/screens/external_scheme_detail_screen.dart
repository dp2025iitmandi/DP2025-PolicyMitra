import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_firestore_service.dart';
import '../services/groq_service.dart';
import '../models/policy_model.dart';
import '../models/user_profile_model.dart';

class ExternalSchemeDetailScreen extends StatefulWidget {
  final String schemeName;
  final UserProfile? userProfile;

  const ExternalSchemeDetailScreen({
    super.key,
    required this.schemeName,
    this.userProfile,
  });

  @override
  State<ExternalSchemeDetailScreen> createState() => _ExternalSchemeDetailScreenState();
}

class _ExternalSchemeDetailScreenState extends State<ExternalSchemeDetailScreen> {
  String? _schemeDescription;
  String? _schemeContent;
  String? _schemeCategory;
  String? _schemeLink;
  bool _isLoading = true;
  bool _isAdding = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.schemeName;
    _loadSchemeDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadSchemeDetails() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Use Groq to generate scheme details
      final groqService = Provider.of<GroqService>(context, listen: false);
      final details = await groqService.generateSchemeFromName(
        widget.schemeName,
        suggestedCategory: widget.userProfile?.category,
      );

      if (mounted && details != null) {
        setState(() {
          _schemeDescription = details['description'] ?? 'No description available.';
          _schemeContent = details['content'] ?? 'No detailed information available.';
          _schemeCategory = details['category'] ?? 'All';
          _schemeLink = details['link'];
          
          // Update title if different from scheme name
          if (details['title'] != null && details['title'] != widget.schemeName) {
            _titleController.text = details['title'];
          }
          
          _descriptionController.text = _schemeDescription!;
          _contentController.text = _schemeContent!;
          _selectedCategory = _schemeCategory!;
          if (_schemeLink != null && _schemeLink != 'No link available') {
            _linkController.text = _schemeLink!;
          }
          
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _schemeDescription = 'Unable to load scheme details. Please fill in manually.';
          _schemeContent = 'Please provide detailed information about this scheme.';
          _schemeCategory = 'All';
          _descriptionController.text = _schemeDescription!;
          _contentController.text = _schemeContent!;
          _selectedCategory = _schemeCategory!;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading scheme details: $e');
      if (mounted) {
        setState(() {
          _schemeDescription = 'Unable to load scheme details. Please fill in manually.';
          _schemeContent = 'Please provide detailed information about this scheme.';
          _schemeCategory = 'All';
          _descriptionController.text = _schemeDescription!;
          _contentController.text = _schemeContent!;
          _selectedCategory = _schemeCategory!;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addToDatabase() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a scheme title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      final policy = PolicyModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        link: _linkController.text.trim().isNotEmpty ? _linkController.text.trim() : null,
        content: _contentController.text.trim(),
        createdAt: DateTime.now(),
      );

      final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
      final success = await firestoreService.createPolicy(policy);

      if (success) {
        // Re-index all policies
        await firestoreService.reindexAllPolicies();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scheme added to database successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(firestoreService.error ?? 'Failed to add scheme'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding scheme: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheme Details'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple[600]!,
                Colors.pink[600]!,
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Scheme Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.title),
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(value: 'Agriculture', child: Text('Agriculture')),
                      DropdownMenuItem(value: 'Education', child: Text('Education')),
                      DropdownMenuItem(value: 'Healthcare', child: Text('Healthcare')),
                      DropdownMenuItem(value: 'Housing', child: Text('Housing')),
                      DropdownMenuItem(value: 'Social Welfare', child: Text('Social Welfare')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value ?? 'All';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Content
                  TextField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      labelText: 'Detailed Content',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.article),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 10,
                  ),
                  const SizedBox(height: 16),
                  
                  // Link
                  TextField(
                    controller: _linkController,
                    decoration: InputDecoration(
                      labelText: 'Official Link (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.link),
                      hintText: 'https://example.com',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 24),
                  
                  // Add to Database Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isAdding ? null : _addToDatabase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isAdding
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline),
                                SizedBox(width: 8),
                                Text(
                                  'Add to Database',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

