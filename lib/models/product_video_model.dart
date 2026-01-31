/// Product Video Model - DEBUG VERSION with detailed logging
class ProductVideoModel {
  final String id;
  final String productId;
  final String sellerId;
  final String videoUrl;
  final String thumbnailUrl;
  final int duration; // seconds
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Additional fields from joined tables
  final String? productName;
  final double? productPrice;
  final String? sellerName;
  final String? sellerImageUrl;
  
  // ✅ NEW: Product options
  final List<String>? colors;
  final List<String>? sizes;

  ProductVideoModel({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.productName,
    this.productPrice,
    this.sellerName,
    this.sellerImageUrl,
    this.colors,
    this.sizes,
  });

  /// ✅ CRASH-PROOF: From JSON (Supabase response) with DEBUG LOGGING
  factory ProductVideoModel.fromJson(Map<String, dynamic> json) {
    try {
      print('📦 Parsing video JSON: ${json['id']}');
      
      // Handle product data if joined
      final product = json['products'] as Map<String, dynamic>?;
      final seller = json['sellers'] as Map<String, dynamic>?;
      
      print('   Product data: $product');
      print('   Seller data: $seller');

      // ✅ Extract colors from product with better error handling
      List<String>? colors;
      if (product != null && product['colors'] != null) {
        try {
          print('   Raw colors: ${product['colors']} (type: ${product['colors'].runtimeType})');
          if (product['colors'] is List) {
            colors = List<String>.from(product['colors']);
            print('   ✅ Parsed colors: $colors');
          } else if (product['colors'] is String) {
            colors = [product['colors'] as String];
            print('   ✅ Converted string to list: $colors');
          }
        } catch (e) {
          print('   ⚠️ Error parsing colors: $e');
        }
      } else {
        print('   ℹ️ No colors data available');
      }

      // ✅ Extract sizes from product with better error handling
      List<String>? sizes;
      if (product != null && product['sizes'] != null) {
        try {
          print('   Raw sizes: ${product['sizes']} (type: ${product['sizes'].runtimeType})');
          if (product['sizes'] is List) {
            sizes = List<String>.from(product['sizes']);
            print('   ✅ Parsed sizes: $sizes');
          } else if (product['sizes'] is String) {
            sizes = [product['sizes'] as String];
            print('   ✅ Converted string to list: $sizes');
          }
        } catch (e) {
          print('   ⚠️ Error parsing sizes: $e');
        }
      } else {
        print('   ℹ️ No sizes data available');
      }

      final video = ProductVideoModel(
        id: json['id'] as String? ?? '',
        productId: json['product_id'] as String? ?? '',
        sellerId: json['seller_id'] as String? ?? '',
        videoUrl: json['video_url'] as String? ?? '',
        thumbnailUrl: json['thumbnail_url'] as String? ?? '',
        duration: json['duration'] as int? ?? 0,
        viewsCount: json['views_count'] as int? ?? 0,
        likesCount: json['likes_count'] as int? ?? 0,
        commentsCount: json['comments_count'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
        productName: product?['name'] as String?,
        productPrice: product?['price'] != null
            ? (product!['price'] as num).toDouble()
            : null,
        sellerName: seller?['business_name'] as String? ?? 
                    seller?['full_name'] as String?,
        sellerImageUrl: seller?['profile_image_url'] as String?,
        colors: colors,
        sizes: sizes,
      );
      
      print('   ✅ Video parsed successfully: ${video.productName}');
      return video;
    } catch (e, stackTrace) {
      print('❌ ERROR parsing video: $e');
      print('Stack trace: $stackTrace');
      print('Full JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'seller_id': sellerId,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'duration': duration,
      'views_count': viewsCount,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ProductVideoModel copyWith({
    String? id,
    String? productId,
    String? sellerId,
    String? videoUrl,
    String? thumbnailUrl,
    int? duration,
    int? viewsCount,
    int? likesCount,
    int? commentsCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? productName,
    double? productPrice,
    String? sellerName,
    String? sellerImageUrl,
    List<String>? colors,
    List<String>? sizes,
  }) {
    return ProductVideoModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sellerId: sellerId ?? this.sellerId,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      viewsCount: viewsCount ?? this.viewsCount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      productName: productName ?? this.productName,
      productPrice: productPrice ?? this.productPrice,
      sellerName: sellerName ?? this.sellerName,
      sellerImageUrl: sellerImageUrl ?? this.sellerImageUrl,
      colors: colors ?? this.colors,
      sizes: sizes ?? this.sizes,
    );
  }

  /// Format duration as MM:SS
  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format views count (e.g., 1.2K, 1.5M)
  String get formattedViews {
    if (viewsCount >= 1000000) {
      return '${(viewsCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewsCount >= 1000) {
      return '${(viewsCount / 1000).toStringAsFixed(1)}K';
    }
    return viewsCount.toString();
  }

  /// Format likes count
  String get formattedLikes {
    if (likesCount >= 1000000) {
      return '${(likesCount / 1000000).toStringAsFixed(1)}M';
    } else if (likesCount >= 1000) {
      return '${(likesCount / 1000).toStringAsFixed(1)}K';
    }
    return likesCount.toString();
  }

  /// Format comments count
  String get formattedComments {
    if (commentsCount >= 1000000) {
      return '${(commentsCount / 1000000).toStringAsFixed(1)}M';
    } else if (commentsCount >= 1000) {
      return '${(commentsCount / 1000).toStringAsFixed(1)}K';
    }
    return commentsCount.toString();
  }

  /// Format price
  String get formattedPrice {
    if (productPrice == null) return '₦0';
    return '₦${productPrice!.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  /// Time since posted (e.g., "2h ago", "3d ago")
  String get timeSincePosted {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
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