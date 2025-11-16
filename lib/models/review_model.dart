class ReviewModel {
  final String id;
  final String productId;
  final String userId;
  final String? orderId; // <-- Kept nullable for your test data
  final double rating;
  final String comment;
  final bool isVerifiedPurchase;
  final int helpfulCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // User info (from join)
  final String? userName;
  final String? userImageUrl;

  ReviewModel({
    required this.id,
    required this.productId,
    required this.userId,
    this.orderId, // <-- Kept optional
    required this.rating,
    required this.comment,
    this.isVerifiedPurchase = false,
    this.helpfulCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.userName,
    this.userImageUrl,
  });

  // From JSON (Supabase response)
  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    // Handle nested user data from join
    String? userName;
    String? userImageUrl;
    
    // --- THIS IS THE FIX ---
    // Check for 'profiles' and the correct column 'profile_image_url'
    if (json['profiles'] is Map<String, dynamic>) {
      userName = json['profiles']['full_name'] as String?;
      userImageUrl = json['profiles']['profile_image_url'] as String?; // <-- FIXED
    } 
    // Fallback in case 'users' is used elsewhere
    else if (json['users'] is Map<String, dynamic>) {
      userName = json['users']['full_name'] as String?;
      userImageUrl = json['users']['profile_image_url'] as String?; // <-- FIXED
    } else {
      userName = json['user_name'] as String?;
      userImageUrl = json['user_image_url'] as String?;
    }

    // Parse rating - handle both string and numeric types
    double ratingValue = 0.0;
    if (json['rating'] is String) {
      ratingValue = double.tryParse(json['rating']) ?? 0.0;
    } else if (json['rating'] is num) {
      ratingValue = (json['rating'] as num).toDouble();
    }

    return ReviewModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      userId: json['user_id'] as String,
      
      orderId: json['order_id'] as String?, // <-- Kept nullable
      
      rating: ratingValue,
      comment: json['comment'] as String? ?? '',
      isVerifiedPurchase: json['is_verified_purchase'] as bool? ?? false,
      helpfulCount: json['helpful_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      userName: userName,
      userImageUrl: userImageUrl,
    );
  }

  // To JSON (for Supabase insert/update)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'user_id': userId,
      'order_id': orderId, 
      'rating': rating.toString(), 
      'comment': comment,
      'is_verified_purchase': isVerifiedPurchase,
      'helpful_count': helpfulCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // Get rating as integer for star display
  int get ratingInt => rating.round();
}