import 'package:cloud_firestore/cloud_firestore.dart';

class PolicyModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String? link;
  final String content;
  final String? documentsRequired;
  final String? videoUrl;
  final String? scriptText; // Generated script from Gemini
  final String? videoHeygenId;
  final String? videoStatus;
  final String? videoError;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PolicyModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.link,
    required this.content,
    this.documentsRequired,
    this.videoUrl,
    this.scriptText,
    this.videoHeygenId,
    this.videoStatus,
    this.videoError,
    this.createdAt,
    this.updatedAt,
  });

  // For Supabase compatibility
  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    return PolicyModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      link: json['link'],
      content: json['content'] ?? '',
      documentsRequired: _coerceDocuments(json['documents_required']),
      videoUrl: json['video_url'],
      scriptText: json['script_text'],
      videoHeygenId: json['video_heygen_id'],
      videoStatus: json['video_status'],
      videoError: json['video_error'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  // For Firestore
  factory PolicyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PolicyModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      link: data['link'],
      content: data['content'] ?? '',
      documentsRequired: _coerceDocuments(data['documentsRequired']),
      videoUrl: data['videoUrl'],
      scriptText: data['scriptText'],
      videoHeygenId: data['videoHeygenId'],
      videoStatus: data['videoStatus'],
      videoError: data['videoError'],
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
    );
  }

  // For Supabase compatibility
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'link': link,
      'content': content,
      'documents_required': documentsRequired,
      'video_url': videoUrl,
      'script_text': scriptText,
      'video_heygen_id': videoHeygenId,
      'video_status': videoStatus,
      'video_error': videoError,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // For Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'link': link,
      'content': content,
      'documentsRequired': documentsRequired,
      'videoUrl': videoUrl,
      'scriptText': scriptText,
      'videoHeygenId': videoHeygenId,
      'videoStatus': videoStatus,
      'videoError': videoError,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PolicyModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? link,
    String? content,
    String? documentsRequired,
    String? videoUrl,
    String? scriptText,
    String? videoHeygenId,
    String? videoStatus,
    String? videoError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PolicyModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      link: link ?? this.link,
      content: content ?? this.content,
      documentsRequired: documentsRequired ?? this.documentsRequired,
      videoUrl: videoUrl ?? this.videoUrl,
      scriptText: scriptText ?? this.scriptText,
      videoHeygenId: videoHeygenId ?? this.videoHeygenId,
      videoStatus: videoStatus ?? this.videoStatus,
      videoError: videoError ?? this.videoError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String? _coerceDocuments(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is Iterable) {
    return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).join(', ');
  }
  return value.toString();
}
