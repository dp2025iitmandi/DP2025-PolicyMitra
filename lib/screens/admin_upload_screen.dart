import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/firebase_firestore_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/admin_service.dart';
import '../services/category_service.dart';
import '../models/policy_model.dart';

class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _contentController = TextEditingController();
  final _documentsRequiredController = TextEditingController();
  final _videoWidthController = TextEditingController();
  final _videoHeightController = TextEditingController();
  
  String _selectedCategory = 'Agriculture';
  String? _selectedVideoPath;
  String? _videoUrl;
  bool _isUploading = false;
  bool _isUploadingVideo = false;
  
  final TextEditingController _newCategoryController = TextEditingController();

  final FirebaseStorageService _firebaseStorageService = FirebaseStorageService();

  @override
  void initState() {
    super.initState();
    // Admin access check removed
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _contentController.dispose();
    _documentsRequiredController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _logoutAdmin() async {
    final adminService = Provider.of<AdminService>(context, listen: false);
    await adminService.signOut();
    
    if (mounted) {
      Navigator.of(context).pop(); // Go back to home screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin logged out successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Admin access check removed

  Future<void> _selectVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedVideoPath = result.files.first.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadVideo() async {
    if (_selectedVideoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a video first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploadingVideo = true;
    });

    try {
      final file = File(_selectedVideoPath!);
      final url = await _firebaseStorageService.uploadVideo(file);
      
      if (url != null) {
        setState(() {
          _videoUrl = url;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploadingVideo = false;
      });
    }
  }

  Future<void> _uploadPolicy() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final policy = PolicyModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        link: _linkController.text.trim().isNotEmpty ? _linkController.text.trim() : null,
        content: _contentController.text.trim(),
        documentsRequired: _documentsRequiredController.text.trim().isNotEmpty ? _documentsRequiredController.text.trim() : null,
        videoUrl: _videoUrl,
        createdAt: DateTime.now(),
      );

      final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
      final success = await firestoreService.createPolicy(policy);

      if (success) {
        // Automatically re-index all policies
        final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
        await firestoreService.reindexAllPolicies();
        
        // Show success splash screen
        _showSuccessSplash();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(firestoreService.error ?? 'Failed to upload policy'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading policy: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Policy'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logoutAdmin,
            tooltip: 'Logout Admin',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Policy Title *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a policy title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              Consumer<CategoryService>(
                builder: (context, categoryService, child) {
                  final categories = categoryService.categories.where((cat) => cat != 'All').toList();
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: [
                      ...categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      const DropdownMenuItem(
                        value: 'add_new',
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 16),
                            SizedBox(width: 8),
                            Text('Add New Category'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == 'add_new') {
                        _showAddCategoryDialog();
                      } else {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Link Field
              TextFormField(
                controller: _linkController,
                decoration: InputDecoration(
                  labelText: 'Related Link (Optional)',
                  hintText: 'https://example.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),

              // Content Field
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: 'Policy Content *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter policy content';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Documents Required Field
              TextFormField(
                controller: _documentsRequiredController,
                decoration: InputDecoration(
                  labelText: 'Documents Required (Optional)',
                  hintText: 'List the documents required for this policy (e.g., Aadhaar, Income Certificate, etc.)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 24),

              // Video Upload Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Video Upload',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Video Selection
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _selectVideo,
                              icon: const Icon(Icons.video_library),
                              label: Text(
                                _selectedVideoPath != null
                                    ? 'Video Selected'
                                    : 'Select Video',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isUploadingVideo ? null : _uploadVideo,
                            icon: _isUploadingVideo
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.cloud_upload),
                            label: Text(_isUploadingVideo ? 'Uploading...' : 'Upload'),
                          ),
                        ],
                      ),
                      
                      
                      if (_selectedVideoPath != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Selected: ${_selectedVideoPath!.split('/').last}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                      
                      if (_videoUrl != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Video uploaded successfully',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Upload Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadPolicy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isUploading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(width: 12),
                            Text('Uploading Policy...'),
                          ],
                        )
                      : const Text(
                          'Upload Policy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessSplash() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Policy Added Successfully!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'The policy has been uploaded and indexed for search.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close splash
                    Navigator.of(context).pop(true); // Return to home screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: _newCategoryController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'Enter new category name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _newCategoryController.clear();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final categoryName = _newCategoryController.text.trim();
              if (categoryName.isNotEmpty) {
                final categoryService = Provider.of<CategoryService>(context, listen: false);
                categoryService.addCategory(categoryName);
                setState(() {
                  _selectedCategory = categoryName;
                });
                _newCategoryController.clear();
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
