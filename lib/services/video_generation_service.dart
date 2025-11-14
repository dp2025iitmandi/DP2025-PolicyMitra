import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../models/policy_model.dart';
import '../config/app_config.dart';
import 'groq_service.dart';
import 'firebase_storage_service.dart';

class VideoGenerationService {
  final GroqService _groqService = GroqService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorageService _storageService = FirebaseStorageService();

  /// Generate video for a policy
  /// Returns the Firebase Storage video URL if successful, null otherwise
  /// [onProgress] callback receives progress (0.0 to 1.0) and status message
  /// [isCancelled] callback to check if generation was cancelled
  Future<String?> generateVideoForPolicy(
    PolicyModel policy, {
    Function(double progress, String status)? onProgress,
    bool Function()? isCancelled,
  }) async {
    try {
      debugPrint('Starting video generation for policy: ${policy.id}');

      // Step 1: Generate script using Groq (0% - 25%)
      onProgress?.call(0.0, 'Step 1: Generating script with Groq...');
      debugPrint('Step 1: Generating script with Groq...');
      
      if (isCancelled?.call() == true) {
        debugPrint('Video generation cancelled at Step 1');
        return null;
      }
      
      final script = await _generateScriptWithGroq(policy);
      
      if (isCancelled?.call() == true) {
        debugPrint('Video generation cancelled after script generation');
        return null;
      }
      
      if (script == null || script.isEmpty) {
        debugPrint('Failed to generate script');
        onProgress?.call(0.0, 'Failed to generate script');
        return null;
      }

      onProgress?.call(0.25, 'Script generated successfully');
      debugPrint('Script generated successfully');
      
      // Step 2: Generate video using HeyGen API via backend (25% - 70%)
      onProgress?.call(0.25, 'Step 2: Creating video with HeyGen...');
      debugPrint('Step 2: Generating video with HeyGen API...');
      
      if (isCancelled?.call() == true) {
        debugPrint('Video generation cancelled before video API call');
        return null;
      }
      
      // Use script directly - Groq now generates plain narration text
      // Clean up any extra whitespace or formatting
      final narrationText = script.trim().replaceAll(RegExp(r'\s+'), ' ');
      
      final heygenVideoUrl = await _generateVideoWithHeyGen(
        policy,
        narrationText,
        onProgress: (progress) {
          // Polling progress: 25% to 70%
          final totalProgress = 0.25 + (progress * 0.45);
          onProgress?.call(totalProgress, 'Step 2: Rendering video... (${(progress * 100).toInt()}%)');
        },
        isCancelled: isCancelled,
      );
      
      if (isCancelled?.call() == true) {
        debugPrint('Video generation cancelled during video generation');
        return null;
      }
      
      if (heygenVideoUrl == null || heygenVideoUrl.isEmpty) {
        debugPrint('Failed to generate video');
        onProgress?.call(0.0, 'Failed to generate video');
        return null;
      }

      onProgress?.call(0.7, 'Video generated successfully');
      debugPrint('HeyGen video generated successfully: $heygenVideoUrl');
      
      // Step 3: Download video from HeyGen URL (70% - 85%)
      onProgress?.call(0.7, 'Step 3: Downloading video...');
      debugPrint('Step 3: Downloading video from HeyGen...');
      
      if (isCancelled?.call() == true) {
        debugPrint('Video generation cancelled before download');
        return null;
      }
      
      final downloadedVideoFile = await _downloadVideoFromUrl(heygenVideoUrl);
      
      if (isCancelled?.call() == true) {
        debugPrint('Video generation cancelled during download');
        return null;
      }
      
      if (downloadedVideoFile == null) {
        debugPrint('Failed to download video');
        onProgress?.call(0.0, 'Failed to download video');
        return null;
      }

      onProgress?.call(0.85, 'Video downloaded successfully');
      debugPrint('Video downloaded successfully');
      
      // Step 4: Upload video to Firebase Storage (85% - 95%)
      onProgress?.call(0.85, 'Step 4: Uploading video to Firebase Storage...');
      debugPrint('Step 4: Uploading video to Firebase Storage...');
      
      if (isCancelled?.call() == true) {
        debugPrint('Video generation cancelled before upload');
        // Clean up downloaded file
        try {
          await downloadedVideoFile.delete();
        } catch (e) {
          debugPrint('Error deleting downloaded file: $e');
        }
        return null;
      }
      
      final firebaseStorageUrl = await _storageService.uploadVideo(downloadedVideoFile);
      
      // Clean up downloaded file after upload
      try {
        await downloadedVideoFile.delete();
        debugPrint('Temporary video file deleted');
      } catch (e) {
        debugPrint('Error deleting temporary file: $e');
      }
      
      if (isCancelled?.call() == true) {
        debugPrint('Video generation cancelled during upload');
        return null;
      }
      
      if (firebaseStorageUrl == null || firebaseStorageUrl.isEmpty) {
        debugPrint('Failed to upload video to Firebase Storage');
        onProgress?.call(0.0, 'Failed to upload video');
        return null;
      }

      onProgress?.call(0.95, 'Video uploaded successfully');
      debugPrint('Video uploaded to Firebase Storage: $firebaseStorageUrl');
      
      // Step 5: Update policy in database with Firebase Storage URL (95% - 100%)
      onProgress?.call(0.95, 'Step 5: Saving video URL to database...');
      debugPrint('Step 5: Updating policy in database...');
      
      if (isCancelled?.call() == true) {
        debugPrint('Video generation cancelled before database update');
        return null;
      }
      
      // Store both script_text and video_url (Firebase Storage URL) in database
      await _updatePolicyVideoData(policy.id, script, firebaseStorageUrl);
      
      onProgress?.call(1.0, 'Complete!');
      debugPrint('Policy updated successfully with script and Firebase Storage video URL');
      return firebaseStorageUrl;
    } catch (e) {
      debugPrint('Error generating video: $e');
      onProgress?.call(0.0, 'Error: $e');
      return null;
    }
  }

  /// Generate video script using Groq
  /// Uses the exact prompt format as specified in requirements
  Future<String?> _generateScriptWithGroq(PolicyModel policy) async {
    try {
      // Format the scheme data exactly as required
      final schemeData = '''
SCHEME NAME: ${policy.title}

DESCRIPTION: ${policy.description}

POLICY DETAILS: ${policy.content}

DOCUMENTS REQUIRED: ${policy.documentsRequired ?? 'Not specified'}
''';

      // Updated prompt for HeyGen API - generates plain narration text in HINDI
      // HeyGen API requires plain text narration without scene descriptions
      final prompt = '''You are an expert government-scheme video scriptwriter for AI avatar awareness videos in India.

Input will be: SCHEME NAME, DESCRIPTION, POLICY DETAILS, DOCUMENTS REQUIRED.

Based on this, generate a CLEAN NARRATION SCRIPT in HINDI for an AI avatar video with the following CRITICAL rules:

**LANGUAGE REQUIREMENTS:**
- Script MUST be in HINDI (Devanagari script)
- Use simple, clear Hindi that is easy to understand for all Indian citizens
- Use Indian currency (₹ Rupees) when mentioning amounts
- Reference Indian places, cities, or states when giving examples
- Use Indian names and contexts

**IMPORTANT FORMAT REQUIREMENTS:**
- Output ONLY plain narration text in Hindi - NO scene descriptions, NO brackets, NO "Narration:" labels
- Length: 200-250 words (approximately 90 seconds / 1 minute 30 seconds of speech)
- Write as a continuous, natural narration that flows smoothly
- Tone: professional, optimistic, and inspiring

**CONTENT REQUIREMENTS:**
- Must include: purpose, eligibility, benefits, application process, and required documents
- No questions asked — fill any missing detail with realistic assumptions
- The narration should sound natural for an AI avatar speaking directly to the viewer
- End with an inspiring closing line like: "[SCHEME NAME] के माध्यम से हर नागरिक को सशक्त बनाना।"

**OUTPUT FORMAT:**
Output ONLY the Hindi narration text, nothing else. No scene descriptions, no formatting, just the plain Hindi text that the avatar will speak.

$schemeData''';

      debugPrint('Sending request to Groq API for script generation...');
      final script = await _groqService.generateVideoScript(prompt);
      
      if (script != null && script.isNotEmpty) {
        debugPrint('Script generated successfully (${script.length} characters)');
      } else {
        debugPrint('Failed to generate script from Groq');
      }
      
      return script;
    } catch (e) {
      debugPrint('Error generating script with Groq: $e');
      return null;
    }
  }

  /// Generate video using HeyGen API via backend
  /// [onProgress] callback for polling progress (0.0 to 1.0)
  /// [isCancelled] callback to check if generation was cancelled
  Future<String?> _generateVideoWithHeyGen(
    PolicyModel policy,
    String narrationText, {
    Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    try {
      debugPrint('Creating video with HeyGen API via backend...');
      debugPrint('Narration text length: ${narrationText.length} characters');
      
      // Prepare request body for backend
      // Note: caption is optional - removed to avoid API errors
      final requestBody = {
        'title': policy.title,
        // 'caption' removed - HeyGen API has issues with caption parameter
        'avatar_id': AppConfig.defaultAvatarId,
        'voice_id': AppConfig.defaultVoiceId,
        'input_text': narrationText,
      };
      
      // Call backend API to generate video
      final response = await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/generateVideo'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Backend API request timed out after 60 seconds');
        },
      );

      debugPrint('Backend API POST response: ${response.statusCode}');
      debugPrint('Backend API POST response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final responseData = data['data'];
          
          // According to HeyGen API v2 spec: Response contains "video_id"
          final videoId = responseData['video_id'] as String?;
          
          if (videoId != null && videoId.isNotEmpty) {
            debugPrint('Video generation started successfully: $videoId');
            debugPrint('Starting to poll for video completion...');
            
            // Poll for video URL since rendering is async
            return await _pollForVideoUrl(
              videoId,
              onProgress: onProgress,
              isCancelled: isCancelled,
            );
          } else {
            debugPrint('ERROR: No video_id in response: $responseData');
            return null;
          }
        } else {
          debugPrint('ERROR: Backend returned error: $data');
          return null;
        }
      } else {
        debugPrint('Backend API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error generating video with HeyGen API: $e');
      return null;
    }
  }

  /// Poll for video URL when job is processing asynchronously
  /// Uses backend API to check status via HeyGen API
  Future<String?> _pollForVideoUrl(
    String videoId, {
    int maxAttempts = 240, // Increased for HeyGen (can take 5-15 minutes)
    Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    // Wait 30 seconds before first check (videos take time to process)
    debugPrint('Waiting 30 seconds before first status check...');
    await Future.delayed(const Duration(seconds: 30));
    
    for (int i = 0; i < maxAttempts; i++) {
      // Check if cancelled before each poll
      if (isCancelled?.call() == true) {
        debugPrint('Video generation cancelled during polling');
        return null;
      }
      
      try {
        // Wait 5 seconds between polls
        if (i > 0) {
          await Future.delayed(const Duration(seconds: 5));
        }
        
        // Update progress (0.0 to 1.0 based on attempts)
        final progress = (i + 1) / maxAttempts;
        onProgress?.call(progress);
        
        // Call backend API to check video status
        final response = await http.get(
          Uri.parse('${AppConfig.backendBaseUrl}/api/videoStatus/$videoId'),
          headers: {
            'Content-Type': 'application/json',
          },
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Status check timed out');
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data['success'] == true && data['data'] != null) {
            final videoData = data['data'];
            
            // Log full response for debugging
            debugPrint('Polling attempt ${i + 1}/$maxAttempts: Full response = $videoData');
            
            // According to HeyGen API v2 spec: Check status and download_url
            final status = videoData['status'] as String?;
            final downloadUrl = videoData['download_url'] as String?;
            
            debugPrint('Polling attempt ${i + 1}/$maxAttempts: status = $status');
            
            if (status == 'completed' || status == 'done' || status == 'success') {
              // Video is ready, return the download URL
              if (downloadUrl != null && downloadUrl.isNotEmpty) {
                debugPrint('Video ready: $downloadUrl');
                onProgress?.call(1.0);
                return downloadUrl;
              } else {
                debugPrint('Status is completed but no download_url found in response: $videoData');
              }
            } else if (status == 'failed' || status == 'error') {
              // Log detailed error information
              final errorMessage = videoData['error'] ?? 
                                  videoData['message'] ?? 
                                  'Unknown error';
              debugPrint('Video generation failed: $errorMessage');
              debugPrint('Full error response: $videoData');
              return null;
            } else {
              // Status might be 'processing', 'pending', 'rendering', etc.
              // Continue polling
              debugPrint('Video still processing, status: $status');
            }
          } else {
            debugPrint('Backend returned error in status check: $data');
          }
        } else {
          debugPrint('Error checking video status: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('Error polling for video URL: $e');
        // Continue polling on error
      }
    }
    
    debugPrint('Timeout waiting for video generation (checked $maxAttempts times)');
    return null;
  }

  /// Download video from URL to temporary file
  Future<File?> _downloadVideoFromUrl(String videoUrl) async {
    try {
      debugPrint('Downloading video from URL: $videoUrl');
      
      // Create a temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      
      // Download the video
      final response = await http.get(
        Uri.parse(videoUrl),
      ).timeout(
        const Duration(minutes: 5), // 5 minute timeout for video download
        onTimeout: () {
          throw TimeoutException('Video download timed out after 5 minutes');
        },
      );
      
      if (response.statusCode == 200) {
        // Write the video bytes to file
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('Video downloaded successfully to: $filePath');
        debugPrint('Video file size: ${await file.length()} bytes');
        return file;
      } else {
        debugPrint('Error downloading video: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading video from URL: $e');
      return null;
    }
  }

  /// Update policy video URL and script text in Firestore
  Future<void> _updatePolicyVideoData(String policyId, String scriptText, String videoUrl) async {
    try {
      await _firestore
          .collection('policies')
          .doc(policyId)
          .update({
            'scriptText': scriptText,
            'videoUrl': videoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      debugPrint('Policy updated with script_text and video_url: $policyId');
      debugPrint('Video URL (Firebase Storage): $videoUrl');
      debugPrint('Script text length: ${scriptText.length} characters');
    } catch (e) {
      debugPrint('Error updating policy video data: $e');
      rethrow;
    }
  }

  /// Extract narration text from Groq script
  /// Removes scene descriptions and keeps only narration text
  /// Handles the format: [Scene X: ...] Narration: ...
  String _extractNarrationFromScript(String script) {
    // The script format from Groq is:
    // [Scene 1: visual description]
    // Narration: ...
    // [Scene 2: visual description]
    // Narration: ...
    // [Final Scene: display scheme name on screen]
    // Narration: (closing line)
    
    final lines = script.split('\n');
    final narrationLines = <String>[];
    bool inNarration = false;
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      // Skip empty lines
      if (trimmed.isEmpty) continue;
      
      // Check if this is a scene description (starts with [)
      if (trimmed.startsWith('[') && (trimmed.contains('Scene') || trimmed.contains('Final Scene'))) {
        inNarration = false;
        continue;
      }
      
      // Check if this is a narration line
      if (trimmed.toLowerCase().startsWith('narration:')) {
        inNarration = true;
        // Extract text after "Narration:"
        final narration = trimmed.replaceFirst(RegExp(r'^Narration:\s*', caseSensitive: false), '').trim();
        if (narration.isNotEmpty) {
          narrationLines.add(narration);
        }
        continue;
      }
      
      // If we're in narration mode and it's not a scene description, add the line
      if (inNarration && trimmed.isNotEmpty && !trimmed.startsWith('[')) {
        narrationLines.add(trimmed);
      }
    }
    
    // If no narration was extracted, use the whole script as fallback
    if (narrationLines.isEmpty) {
      debugPrint('Warning: No narration extracted from script, using full script');
      return script;
    }
    
    // Join narration lines with spaces to create continuous narration text
    final narrationText = narrationLines.join(' ');
    debugPrint('Extracted narration: ${narrationText.length} characters from ${narrationLines.length} lines');
    return narrationText;
  }

  /// Fetch policy from database by ID
  Future<PolicyModel?> fetchPolicyFromDatabase(String policyId) async {
    try {
      final doc = await _firestore.collection('policies').doc(policyId).get();
      
      if (doc.exists) {
        return PolicyModel.fromFirestore(doc);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error fetching policy from database: $e');
      return null;
    }
  }
}
