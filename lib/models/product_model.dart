// Product Model - Matches 'products' table in Supabase
class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String condition;
  final String categoryId;
  final String? categoryName;
  final String sellerId;
  final String? sellerName;
  final String? sellerImageUrl;
  final String universityId;
  final String? universityName;
  final String? universityAbbr;
  final List<String> imageUrls;
  final String? mainImageUrl;
  final int stockQuantity;
  final bool isAvailable;
  final bool isFeatured;
  final int viewCount;
  final int favoriteCount;
  final double? averageRating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int deliveryCount;

  // Additional fields
  final double? originalPrice;
  final int? discountPercentage;
  final String? brand;
  final String? color;
  final List<String>? colors; // ✅ NEW: Multiple color options
  final List<String>? sizes;
  final int soldCount;
  final bool isFlashSale;
  final DateTime? flashSaleEndsAt;
  final bool isTopSeller;
  final bool isTrending;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.condition,
    required this.categoryId,
    this.categoryName,
    required this.sellerId,
    this.sellerName,
    this.sellerImageUrl,
    required this.universityId,
    this.universityName,
    this.universityAbbr,
    required this.imageUrls,
    this.stockQuantity = 1,
    this.isAvailable = true,
    this.isFeatured = false,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.averageRating,
    this.reviewCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.originalPrice,
    this.discountPercentage,
    this.brand,
    this.color,
    this.colors,  // ✅ NEW
    this.sizes,
    this.soldCount = 0,
    this.isFlashSale = false,
    this.flashSaleEndsAt,
    this.isTopSeller = false,
    this.isTrending = false,
    this.deliveryCount = 0,
  }) : mainImageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Handle image URLs
    List<String> images = [];
    if (json['image_urls'] != null) {
      if (json['image_urls'] is List) {
        images = List<String>.from(json['image_urls']);
      } else if (json['image_urls'] is String) {
        final imageStr = json['image_urls'] as String;
        if (imageStr.startsWith('[') && imageStr.endsWith(']')) {
          try {
            images = List<String>.from(
              imageStr
                  .substring(1, imageStr.length - 1)
                  .split(',')
                  .map((s) => s.trim().replaceAll('"', ''))
                  .where((s) => s.isNotEmpty),
            );
          } catch (e) {
            print('Error parsing image URLs: $e');
          }
        } else if (imageStr.isNotEmpty) {
          images = [imageStr];
        }
      }
    }

    // ✅ Handle colors array (FIXED: was using 'color' instead of 'colors')
    List<String>? colors;
    if (json['colors'] != null) {
      if (json['colors'] is List) {
        colors = List<String>.from(json['colors']);
      }
    }

    // ✅ Handle sizes array
    List<String>? sizes;
    if (json['sizes'] != null) {
      if (json['sizes'] is List) {
        sizes = List<String>.from(json['sizes']);
      }
    }

    // Handle university abbreviation
    String? abbr;
    if (json['university_abbr'] != null) {
      abbr = json['university_abbr'] as String;
    } else if (json['universities'] is Map<String, dynamic> &&
        json['universities']['abbr'] != null) {
      abbr = json['universities']['abbr'] as String;
    }

    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: _parsePrice(json['price']),
      condition: json['condition'] as String? ?? 'used',
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String?,
      sellerId: json['seller_id'] as String,
      sellerName: json['seller_name'] as String?,
      sellerImageUrl: json['seller_image_url'] as String?,
      universityId: json['university_id'] as String,
      universityName: json['university_name'] as String?,
      universityAbbr: abbr,
      imageUrls: images,
      stockQuantity: json['stock_quantity'] as int? ?? 1,
      isAvailable: json['is_available'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      viewCount: json['view_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      averageRating: json['average_rating'] != null
          ? (json['average_rating'] as num).toDouble()
          : null,
      reviewCount: json['review_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      originalPrice: json['original_price'] != null
          ? _parsePrice(json['original_price'])
          : null,
      discountPercentage: json['discount_percentage'] != null
          ? int.tryParse(json['discount_percentage'].toString())
          : null,
      brand: json['brand'] as String?,
      color: json['color'] is String 
    ? json['color'] as String 
    : (json['color'] is List && (json['color'] as List).isNotEmpty 
        ? (json['color'] as List).first.toString() 
        : null),
      colors: json['colors'] is List ? List<String>.from(json['colors']) : null,  // ← ADD THIS LINE
      sizes: json['sizes'] is List ? List<String>.from(json['sizes']) : null,      // ← ADD THIS LINE
      soldCount: json['sold_count'] as int? ?? 0,
      isFlashSale: json['is_flash_sale'] as bool? ?? false,
      flashSaleEndsAt: json['flash_sale_ends_at'] != null
          ? DateTime.parse(json['flash_sale_ends_at'] as String)
          : null,
      isTopSeller: json['is_top_seller'] as bool? ?? false,
      isTrending: json['is_trending'] as bool? ?? false,
      deliveryCount: json['delivery_count'] as int? ?? 0,
    );
  }

  static double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is num) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'condition': condition,
      'category_id': categoryId,
      'seller_id': sellerId,
      'university_id': universityId,
      'image_urls': imageUrls,
      'stock_quantity': stockQuantity,
      'is_available': isAvailable,
      'is_featured': isFeatured,
      'view_count': viewCount,
      'favorite_count': favoriteCount,
      'average_rating': averageRating,
      'review_count': reviewCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'original_price': originalPrice,
      'discount_percentage': discountPercentage,
      'brand': brand,
      'color': color,
      'colors': colors, // ✅ ADDED
      'sizes': sizes,
      'sold_count': soldCount,
      'is_flash_sale': isFlashSale,
      'flash_sale_ends_at': flashSaleEndsAt?.toIso8601String(),
      'is_top_seller': isTopSeller,
      'is_trending': isTrending,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? condition,
    String? categoryId,
    String? categoryName,
    String? sellerId,
    String? sellerName,
    String? sellerImageUrl,
    String? universityId,
    String? universityName,
    String? universityAbbr,
    List<String>? imageUrls,
    int? stockQuantity,
    bool? isAvailable,
    bool? isFeatured,
    int? viewCount,
    int? favoriteCount,
    double? averageRating,
    int? reviewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? originalPrice,
    int? discountPercentage,
    String? brand,
    String? color,
    List<String>? colors, // ✅ ADDED
    List<String>? sizes,
    int? soldCount,
    bool? isFlashSale,
    DateTime? flashSaleEndsAt,
    bool? isTopSeller,
    bool? isTrending,
    int? deliveryCount,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      condition: condition ?? this.condition,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerImageUrl: sellerImageUrl ?? this.sellerImageUrl,
      universityId: universityId ?? this.universityId,
      universityName: universityName ?? this.universityName,
      universityAbbr: universityAbbr ?? this.universityAbbr,
      imageUrls: imageUrls ?? this.imageUrls,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      brand: brand ?? this.brand,
      color: color ?? this.color,
      colors: colors ?? this.colors, // ✅ ADDED
      sizes: sizes ?? this.sizes,
      soldCount: soldCount ?? this.soldCount,
      isFlashSale: isFlashSale ?? this.isFlashSale,
      flashSaleEndsAt: flashSaleEndsAt ?? this.flashSaleEndsAt,
      isTopSeller: isTopSeller ?? this.isTopSeller,
      isTrending: isTrending ?? this.isTrending,
      deliveryCount: deliveryCount ?? this.deliveryCount,
    );
  }

  String get formattedPrice =>
      '₦${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';

  String? get formattedOriginalPrice {
    if (originalPrice == null) return null;
    return '₦${originalPrice!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  double? get discountAmount {
    if (originalPrice == null || originalPrice! <= price) return null;
    return originalPrice! - price;
  }

  bool get hasDiscount {
    return originalPrice != null && originalPrice! > price;
  }

  bool get isFlashSaleActive {
    if (!isFlashSale || flashSaleEndsAt == null) return false;
    return DateTime.now().isBefore(flashSaleEndsAt!);
  }

  Duration? get flashSaleTimeRemaining {
    if (!isFlashSaleActive) return null;
    return flashSaleEndsAt!.difference(DateTime.now());
  }
}