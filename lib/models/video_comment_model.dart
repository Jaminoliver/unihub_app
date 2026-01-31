/// Video Comment Model - Matches 'video_comments' table in Supabase
class VideoCommentModel {
  final String id;
  final String videoId;
  final String userId;
  final String commentText;
  final DateTime createdAt;

  // Additional fields from joined tables
  final String? userName;
  final String? userImageUrl;

  VideoCommentModel({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.commentText,
    required this.createdAt,
    this.userName,
    this.userImageUrl,
  });

  /// ✅ CRASH-PROOF: From JSON (Supabase response)
  factory VideoCommentModel.fromJson(Map<String, dynamic> json) {
    // Handle user data if joined (from profiles table)
    final user = json['profiles'] as Map<String, dynamic>?;

    return VideoCommentModel(
      id: json['id'] as String? ?? '',
      videoId: json['video_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      commentText: json['comment_text'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      userName: user?['full_name'] as String?,
      userImageUrl: user?['profile_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'video_id': videoId,
      'user_id': userId,
      'comment_text': commentText,
      'created_at': createdAt.toIso8601String(),
    };
  }

  VideoCommentModel copyWith({
    String? id,
    String? videoId,
    String? userId,
    String? commentText,
    DateTime? createdAt,
    String? userName,
    String? userImageUrl,
  }) {
    return VideoCommentModel(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      commentText: commentText ?? this.commentText,
      createdAt: createdAt ?? this.createdAt,
      userName: userName ?? this.userName,
      userImageUrl: userImageUrl ?? this.userImageUrl,
    );
  }

  /// Get display name (first name only if available)
  String get displayName {
    if (userName == null || userName!.trim().isEmpty) {
      return 'User';
    }

    final parts = userName!.trim().split(' ');
    if (parts.isEmpty) {
      return 'User';
    }

    return parts.first.trim();
  }

  /// Time since comment (e.g., "2h ago", "3d ago")
  String get timeSinceComment {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}