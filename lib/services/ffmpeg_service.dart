import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';

class FFmpegService {
  static const String _convertedVideoPrefix = 'converted_';
  
  /// Check if video is already converted
  static bool isVideoConverted(String videoUrl) {
    return videoUrl.contains(_convertedVideoPrefix);
  }
  
  /// Convert video to streaming format using FFmpeg
  static Future<String?> convertVideoToStreamingFormat(String originalVideoUrl) async {
    try {
      debugPrint('Starting video conversion for: $originalVideoUrl');
      
      // Download the original video
      final response = await http.get(Uri.parse(originalVideoUrl));
      if (response.statusCode != 200) {
        debugPrint('Failed to download video: ${response.statusCode}');
        return null;
      }
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final inputPath = '${tempDir.path}/input_video.mp4';
      final outputPath = '${tempDir.path}/converted_video.mp4';
      
      // Save downloaded video
      final inputFile = File(inputPath);
      await inputFile.writeAsBytes(response.bodyBytes);
      
      debugPrint('Video downloaded to: $inputPath');
      
      // Convert video using FFmpeg
      final result = await _convertVideoWithFFmpeg(inputPath, outputPath);
      
      if (result != 0) {
        debugPrint('FFmpeg conversion failed with exit code: $result');
        return null;
      }
      
      // Upload converted video to Firebase Storage
      final convertedVideoUrl = await _uploadConvertedVideo(outputPath);
      
      // Clean up temporary files
      await inputFile.delete();
      await File(outputPath).delete();
      
      debugPrint('Video conversion completed: $convertedVideoUrl');
      return convertedVideoUrl;
      
    } catch (e) {
      debugPrint('Error converting video: $e');
      return null;
    }
  }
  
  /// Convert video using FFmpeg command (simplified for now)
  static Future<int> _convertVideoWithFFmpeg(String inputPath, String outputPath) async {
    try {
      // For now, just copy the file without conversion
      // In a real implementation, you would use a native FFmpeg binary
      final inputFile = File(inputPath);
      final outputFile = File(outputPath);
      
      if (await inputFile.exists()) {
        await inputFile.copy(outputPath);
        debugPrint('Video copied (no conversion applied)');
        return 0;
      } else {
        debugPrint('Input file does not exist');
        return -1;
      }
      
    } catch (e) {
      debugPrint('Error processing video: $e');
      return -1;
    }
  }
  
  /// Upload converted video to Firebase Storage
  static Future<String?> _uploadConvertedVideo(String localPath) async {
    try {
      final file = File(localPath);
      final fileName = '${_convertedVideoPrefix}${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ref = FirebaseStorage.instance.ref().child('converted_videos/$fileName');
      
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('Converted video uploaded: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      debugPrint('Error uploading converted video: $e');
      return null;
    }
  }
  
  /// Get streaming-optimized video URL (convert if needed)
  static Future<String?> getStreamingVideoUrl(String originalVideoUrl) async {
    try {
      // Check if already converted
      if (isVideoConverted(originalVideoUrl)) {
        debugPrint('Video already converted, using existing URL');
        return originalVideoUrl;
      }
      
      // Convert video
      final convertedUrl = await convertVideoToStreamingFormat(originalVideoUrl);
      return convertedUrl;
      
    } catch (e) {
      debugPrint('Error getting streaming video URL: $e');
      return originalVideoUrl; // Fallback to original
    }
  }
}
