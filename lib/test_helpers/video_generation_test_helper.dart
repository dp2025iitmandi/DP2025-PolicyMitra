import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper methods for testing video generation functionality
class VideoGenerationTestHelper {
  /// Reset video-related fields for a policy to allow testing generation again
  /// 
  /// This removes:
  /// - videoUrl
  /// - videoStatus
  /// - videoHeygenId
  /// - videoError
  /// 
  /// Use this to reset a policy and test generation again
  static Future<void> resetVideoForPolicy(String policyId) async {
    await FirebaseFirestore.instance.collection('policies').doc(policyId).update({
      'videoUrl': FieldValue.delete(),
      'videoStatus': FieldValue.delete(),
      'videoHeygenId': FieldValue.delete(),
      'videoError': FieldValue.delete(),
      'scriptText': FieldValue.delete(),
      'videoRequestedAt': FieldValue.delete(),
      'videoCompletedAt': FieldValue.delete(),
      'videoLastPolledAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark a policy's video as failed for testing retry functionality
  static Future<void> markVideoAsFailed(String policyId, String errorMessage) async {
    await FirebaseFirestore.instance.collection('policies').doc(policyId).update({
      'videoStatus': 'failed',
      'videoError': errorMessage,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get current video status for a policy
  static Future<Map<String, dynamic>?> getVideoStatus(String policyId) async {
    final doc = await FirebaseFirestore.instance
        .collection('policies')
        .doc(policyId)
        .get();
    
    if (!doc.exists) return null;
    
    final data = doc.data()!;
    return {
      'videoUrl': data['videoUrl'],
      'videoStatus': data['videoStatus'],
      'videoHeygenId': data['videoHeygenId'],
      'videoError': data['videoError'],
      'scriptText': data['scriptText'],
    };
  }
}

