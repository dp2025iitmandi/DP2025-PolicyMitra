import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/policy_model.dart';
import '../services/firebase_firestore_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/admin_service.dart';
import '../services/language_service.dart';
import '../widgets/translated_text.dart';
import 'video_page.dart';

class PolicyDetailScreen extends StatefulWidget {
  final PolicyModel policy;

  const PolicyDetailScreen({
    super.key,
    required this.policy,
  });

  @override
  State<PolicyDetailScreen> createState() => _PolicyDetailScreenState();
}

class _PolicyDetailScreenState extends State<PolicyDetailScreen> {
  final FirebaseStorageService _storageService = FirebaseStorageService();

  PolicyModel? _currentPolicy;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _policySubscription;

  bool _isGenerating = false;
  bool _isPolling = false;
  bool _userInitiatedPlayback = false;
  bool _startedPolling = false;
  bool _isUploadingVideo = false;
  String _statusMessage = '';
  
  // Translated policy content
  Map<String, String>? _translatedContent;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _currentPolicy = widget.policy;
    _initPolicyListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPolicyData();
      _translatePolicyContent();
    });
  }
  
  void _onLanguageChanged() {
    _translatePolicyContent();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Setup language listener
    try {
      final languageService = Provider.of<LanguageService>(context, listen: false);
      languageService.addListener(_onLanguageChanged);
    } catch (e) {
      // Context might not be available
    }
  }
  
  // Translate policy content when language changes
  Future<void> _translatePolicyContent() async {
    if (_currentPolicy == null) return;
    
    final languageService = Provider.of<LanguageService>(context, listen: false);
    
    // Only translate if Hindi is selected
    if (!languageService.isHindi) {
      setState(() {
        _translatedContent = null;
        _isTranslating = false;
      });
      return;
    }
    
    setState(() {
      _isTranslating = true;
    });
    
    try {
      final translated = await languageService.translatePolicyContent(
        title: _currentPolicy!.title,
        description: _currentPolicy!.description,
        content: _currentPolicy!.content,
        documentsRequired: _currentPolicy!.documentsRequired ?? '',
      );
      
      if (mounted) {
        setState(() {
          _translatedContent = translated;
          _isTranslating = false;
        });
      }
    } catch (e) {
      debugPrint('Error translating policy content: $e');
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _policySubscription?.cancel();
    try {
      final languageService = Provider.of<LanguageService>(context, listen: false);
      languageService.removeListener(_onLanguageChanged);
    } catch (e) {
      // Context might not be available during dispose
    }
    super.dispose();
  }

  void _initPolicyListener() {
    _policySubscription = FirebaseFirestore.instance
        .collection('policies')
        .doc(widget.policy.id)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final updatedPolicy = PolicyModel.fromFirestore(snapshot);
      final previousStatus = _currentPolicy?.videoStatus;
      setState(() {
        _currentPolicy = updatedPolicy;
      });

      final videoId = null; // HeyGen removed
      final newStatus = updatedPolicy.videoStatus;
      if (videoId != null &&
          videoId.isNotEmpty &&
          (newStatus == 'processing' || newStatus == 'pending') &&
          !_startedPolling) {
        _resumePolling(videoId, updatedPolicy.id, autoResume: true);
      }

      if (previousStatus != newStatus && newStatus == 'completed' && _userInitiatedPlayback) {
        _userInitiatedPlayback = false;
        final url = updatedPolicy.videoUrl;
        if (url != null && url.isNotEmpty) {
          _playVideoWithUrl(url, updatedPolicy.title);
        }
      }
    });
  }

  Future<void> _refreshPolicyData() async {
    try {
      final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
      final updatedPolicy = await firestoreService.getPolicyById(widget.policy.id);
      if (updatedPolicy != null && mounted) {
        setState(() {
          _currentPolicy = updatedPolicy;
        });
      }
    } catch (error) {
      debugPrint('[PolicyDetailScreen] Error refreshing policy data: $error');
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening link: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleGenerateVideo({bool isRetry = false}) async {
    final policy = _currentPolicy ?? widget.policy;
    if (_isGenerating || _isPolling) return;

    setState(() {
      _isGenerating = true;
      _statusMessage = isRetry ? 'Retrying video generation...' : 'Preparing video script...';
    });

    if (isRetry) {
      await _resetPolicyForRetry(policy.id);
    }

    _userInitiatedPlayback = true;

    // HeyGen video generation removed - video not available
    setState(() {
      _isGenerating = false;
      _statusMessage = '';
      _userInitiatedPlayback = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video generation is not available.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _resumePolling(
    String videoId,
    String policyId, {
    bool autoResume = false,
  }) async {
    // HeyGen polling removed - video generation not available
    if (!mounted) return;
    setState(() {
      _isPolling = false;
      _isGenerating = false;
      _statusMessage = '';
      _userInitiatedPlayback = false;
      _startedPolling = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video generation is not available.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _resetPolicyForRetry(String policyId) async {
    await FirebaseFirestore.instance.collection('policies').doc(policyId).update({
      'videoStatus': 'pending',
      'videoError': FieldValue.delete(),
      'videoUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _playVideo() async {
    final policy = _currentPolicy ?? widget.policy;
    final url = policy.videoUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No video available for this policy'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    _playVideoWithUrl(url, policy.title);
  }

  void _playVideoWithUrl(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPage(
          videoUrl: url,
          policyTitle: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final policy = _currentPolicy ?? widget.policy;
    final languageService = Provider.of<LanguageService>(context);
    
    // Use translated content if available and Hindi is selected
    final displayTitle = (languageService.isHindi && _translatedContent != null)
        ? _translatedContent!['title'] ?? policy.title
        : policy.title;
    final displayDescription = (languageService.isHindi && _translatedContent != null)
        ? _translatedContent!['description'] ?? policy.description
        : policy.description;
    final displayContent = (languageService.isHindi && _translatedContent != null)
        ? _translatedContent!['content'] ?? policy.content
        : policy.content;
    final displayDocuments = (languageService.isHindi && _translatedContent != null)
        ? (_translatedContent!['documentsRequired'] ?? policy.documentsRequired ?? '')
        : (policy.documentsRequired ?? '');
    
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const TranslatedText('policy_details'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        leading: Consumer<AdminService>(
          builder: (context, adminService, _) {
            if (!adminService.isAdmin) return const SizedBox.shrink();
            
            return IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select All Policy Text',
              onPressed: () => _selectAllPolicyText(policy, displayTitle, displayDescription, displayContent, displayDocuments),
            );
          },
        ),
        actions: [
          // Admin video upload button
          Consumer<AdminService>(
            builder: (context, adminService, _) {
              if (!adminService.isAdmin) return const SizedBox.shrink();
              
              return IconButton(
                icon: _isUploadingVideo
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.video_library),
                tooltip: 'Upload Video for this Policy',
                onPressed: _isUploadingVideo ? null : () => _handleAdminVideoUpload(policy),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _isTranslating
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        TranslatedText(
                          'loading',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : SelectableText(
                    displayTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.black87,
                    ),
                  ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getCategoryColor(policy.category),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                policy.category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildDescriptionCard(context, policy, displayDescription),
            const SizedBox(height: 24),
            _buildVideoAction(context, policy),
            const SizedBox(height: 24),
            _buildPolicyDetailsCard(context, policy, displayContent),
            const SizedBox(height: 24),
            if (displayDocuments != null && displayDocuments.isNotEmpty)
              _buildDocumentsCard(context, policy, displayDocuments),
            if (displayDocuments != null && displayDocuments.isNotEmpty)
              const SizedBox(height: 24),
            _buildLinkCard(context, policy),
            const SizedBox(height: 20),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildVideoAction(BuildContext context, PolicyModel policy) {
    final hasVideo = policy.videoUrl != null && policy.videoUrl!.isNotEmpty;
    final status = policy.videoStatus ?? (hasVideo ? 'completed' : 'idle');
    final isProcessing = status == 'processing' ||
        (status == 'pending' && (policy.videoHeygenId?.isNotEmpty ?? false)) ||
        _isGenerating ||
        _isPolling;
    final isFailed = status == 'failed';

    // If no video and not processing/failed, show error box
    if (!hasVideo && !isProcessing && !isFailed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          border: Border.all(color: Colors.orange[300]!, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.orange[800], size: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Video not available, coming soon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[900],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Only show Play Video button if video exists
    if (hasVideo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _isGenerating || _isPolling ? null : _playVideo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey[400],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_filled, size: 22),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Play Video',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      );
    }

    // Show processing state
    if (isProcessing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          border: Border.all(color: Colors.amber[300]!, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber[800]!),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Generating...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber[900],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Failed state - show error box
    if (isFailed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border.all(color: Colors.red[300]!, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[800], size: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Video generation failed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[900],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Default: no video available (shouldn't reach here, but fallback)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[300]!, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Colors.orange[800], size: 24),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Video not available, coming soon',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange[900],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context, PolicyModel policy, String displayDescription) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            'description',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            displayDescription,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyDetailsCard(BuildContext context, PolicyModel policy, String displayContent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            displayContent,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard(BuildContext context, PolicyModel policy, String displayDocuments) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            'documents_required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            displayDocuments,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(BuildContext context, PolicyModel policy) {
    final link = policy.link;
    final hasLink = link != null && link.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasLink ? Icons.link : Icons.link_off,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Related Link',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            hasLink ? link! : 'No link available',
            style: TextStyle(
              fontSize: 14,
              color: hasLink ? Theme.of(context).colorScheme.primary : Colors.grey[600],
              decoration: hasLink ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
          if (hasLink) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _launchUrl(link),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Link'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Handle admin video upload
  Future<void> _handleAdminVideoUpload(PolicyModel policy) async {
    try {
      // Open file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      if (file.path == null && file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Could not access video file'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _isUploadingVideo = true;
      });

      String? videoUrl;

      if (file.path != null) {
        // Upload from file path (mobile) - use policy-specific path
        final videoFile = File(file.path!);
        videoUrl = await _storageService.uploadVideo(videoFile, policyId: policy.id);
      } else if (file.bytes != null) {
        // Upload from bytes (web) - for web, we'll need to handle differently
        // For now, use the general upload method
        videoUrl = await _storageService.uploadVideoFromPicker(file);
      }

      if (videoUrl == null || videoUrl.isEmpty) {
        throw Exception('Failed to upload video to Firebase Storage');
      }

      // Update policy in Firestore with video URL
      final firestoreService = Provider.of<FirebaseFirestoreService>(context, listen: false);
      await FirebaseFirestore.instance
          .collection('policies')
          .doc(policy.id)
          .update({
        'videoUrl': videoUrl,
        'videoStatus': 'completed',
        'videoCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'videoError': FieldValue.delete(),
      });

      // Refresh policy data
      await _refreshPolicyData();

      if (mounted) {
        setState(() {
          _isUploadingVideo = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      debugPrint('[PolicyDetailScreen] Error uploading video: $error');
      if (mounted) {
        setState(() {
          _isUploadingVideo = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'agriculture':
        return Colors.green;
      case 'education':
        return Colors.blue;
      case 'healthcare':
        return Colors.red;
      case 'housing':
        return Colors.orange;
      case 'social welfare':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _mapCreateStatus(String status) {
    switch (status) {
      case 'formatting':
        return 'Formatting policy...';
      case 'requesting':
        return 'Requesting video...';
      case 'processing':
        return 'Video is being processed...';
      default:
        return status;
    }
  }

  // Select all policy text (title, description, content, documents) - no links or buttons
  void _selectAllPolicyText(PolicyModel policy, String displayTitle, String displayDescription, String displayContent, String? displayDocuments) {
    final StringBuffer buffer = StringBuffer();
    
    // Add title
    buffer.writeln(displayTitle);
    buffer.writeln();
    
    // Add description
    buffer.writeln('Description:');
    buffer.writeln(displayDescription);
    buffer.writeln();
    
    // Add policy content/details
    buffer.writeln('Policy Details:');
    buffer.writeln(displayContent);
    buffer.writeln();
    
    // Add documents required (if available)
    if (displayDocuments != null && displayDocuments.isNotEmpty) {
      buffer.writeln('Documents Required:');
      buffer.writeln(displayDocuments);
      buffer.writeln();
    }
    
    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All policy text copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
