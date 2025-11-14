import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/category_service.dart';

class AddSchemeDialog extends StatefulWidget {
  final String schemeName;

  const AddSchemeDialog({super.key, required this.schemeName});

  @override
  State<AddSchemeDialog> createState() => _AddSchemeDialogState();
}

class _AddSchemeDialogState extends State<AddSchemeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _linkController = TextEditingController();
  final _documentsController = TextEditingController();
  String _selectedCategory = 'Social Welfare';

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.schemeName;
    _descriptionController.text = 'Scheme recommended for you based on your profile';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _linkController.dispose();
    _documentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Scheme to App'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Scheme Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter scheme title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Consumer<CategoryService>(
                builder: (context, categoryService, child) {
                  return DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(),
                    ),
                    items: categoryService.categories
                        .where((c) => c != 'All')
                        .map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Policy Details *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter scheme details, benefits, eligibility...',
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter policy details';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'Official Link (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'https://example.com',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _documentsController,
                decoration: const InputDecoration(
                  labelText: 'Documents Required (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Aadhar, PAN, etc.',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'title': _titleController.text.trim(),
                'description': _descriptionController.text.trim(),
                'category': _selectedCategory,
                'content': _contentController.text.trim(),
                'link': _linkController.text.trim().isNotEmpty
                    ? _linkController.text.trim()
                    : null,
                'documentsRequired': _documentsController.text.trim().isNotEmpty
                    ? _documentsController.text.trim()
                    : null,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Add Scheme'),
        ),
      ],
    );
  }
}

