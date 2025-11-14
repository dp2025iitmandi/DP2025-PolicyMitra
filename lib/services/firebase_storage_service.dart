import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload video file to Firebase Storage
  // If policyId is provided, uses policy-specific path: videos/{policyId}.mp4
  // Otherwise uses timestamp-based path
  Future<String?> uploadVideo(File videoFile, {String? policyId}) async {
    try {
      final String fileName;
      if (policyId != null && policyId.isNotEmpty) {
        // Use policy-specific path for admin uploads
        fileName = 'videos/$policyId.mp4';
      } else {
        // Use timestamp-based path for general uploads
        fileName = 'videos/${DateTime.now().millisecondsSinceEpoch}_${videoFile.path.split('/').last}';
      }
      
      final ref = _storage.ref().child(fileName);
      
      // Set metadata for video
      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        cacheControl: 'public,max-age=31536000',
      );
      
      final uploadTask = ref.putFile(videoFile, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('Video uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading video to Firebase Storage: $e');
      return null;
    }
  }

  // Upload file from file picker result
  Future<String?> uploadVideoFromPicker(PlatformFile file) async {
    try {
      final fileName = 'videos/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref().child(fileName);
      
      final uploadTask = ref.putData(file.bytes!);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('Video uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading video to Firebase Storage: $e');
      return null;
    }
  }

  // Delete video from Firebase Storage
  Future<bool> deleteVideo(String videoUrl) async {
    try {
      // Extract the file path from the URL
      final ref = _storage.refFromURL(videoUrl);
      await ref.delete();
      
      debugPrint('Video deleted successfully: $videoUrl');
      return true;
    } catch (e) {
      debugPrint('Error deleting video from Firebase Storage: $e');
      return false;
    }
  }

  // Check if video exists in Firebase Storage
  Future<bool> videoExists(String videoUrl) async {
    try {
      final ref = _storage.refFromURL(videoUrl);
      await ref.getMetadata();
      return true;
    } catch (e) {
      debugPrint('Video does not exist or error checking: $e');
      return false;
    }
  }

  // Get video metadata
  Future<FullMetadata?> getVideoMetadata(String videoUrl) async {
    try {
      final ref = _storage.refFromURL(videoUrl);
      return await ref.getMetadata();
    } catch (e) {
      debugPrint('Error getting video metadata: $e');
      return null;
    }
  }

  // List all videos in the videos folder
  Future<List<Reference>> listVideos() async {
    try {
      final listResult = await _storage.ref().child('videos').listAll();
      return listResult.items;
    } catch (e) {
      debugPrint('Error listing videos: $e');
      return [];
    }
  }
}
