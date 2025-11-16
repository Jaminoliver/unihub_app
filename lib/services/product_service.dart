import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

class ProductService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getTrendingActivity(String universityId) async {
    try {
      final response = await _supabase.from('trending_activity').select('*').eq('university_id', universityId).single();
      return {
        'active_users': response['active_users_count'] as int,
        'products_viewed': response['products_viewed_today'] as int,
        'products_sold': response['products_sold_today'] as int,
        'last_updated': DateTime.parse(response['last_updated'] as String),
      };
    } catch (e) {
      return {'active_users': 156, 'products_viewed': 230, 'products_sold': 12, 'last_updated': DateTime.now()};
    }
  }

  Future<List<Map<String, dynamic>>> getRecentPurchases(String universityId, {int limit = 5}) async {
    try {
      final response = await _supabase.from('recent_purchases').select('*, products(name, price)').eq('university_id', universityId).order('created_at', ascending: false).limit(limit);
      return (response as List).map((item) {
        final product = item['products'] as Map<String, dynamic>?;
        return {
          'buyer_name': item['buyer_name'] as String,
          'product_name': product?['name'] as String? ?? 'Product',
          'created_at': DateTime.parse(item['created_at'] as String),
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ProductModel>> getProductsByState({required String state, String? priorityUniversityId, String? categoryId, int limit = 100, int offset = 0}) async {
    try {
      final response = await _supabase.rpc('get_products_by_state_details', params: {'p_state': state, 'p_limit': limit, 'p_offset': offset, 'p_category_id': categoryId});
      final products = (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
      if (priorityUniversityId != null) {
        products.sort((a, b) {
          if (a.universityId == priorityUniversityId && b.universityId != priorityUniversityId) return -1;
          if (b.universityId == priorityUniversityId && a.universityId != priorityUniversityId) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
      }
      return products;
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  Future<List<ProductModel>> getAllProducts({String? universityId, String? categoryId, String? state, int limit = 50, int offset = 0}) async {
    if (state != null) {
      final products = await getProductsByState(state: state, priorityUniversityId: universityId, categoryId: categoryId, limit: limit, offset: offset);
      products.sort((a, b) {
        if (a.universityId == universityId && b.universityId != universityId) return -1;
        if (b.universityId == universityId && a.universityId != universityId) return 1;
        final deliveryCompare = b.deliveryCount.compareTo(a.deliveryCount);
        if (deliveryCompare != 0) return deliveryCompare;
        return b.createdAt.compareTo(a.createdAt);
      });
      return products;
    }
    try {
      var query = _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)').eq('is_available', true);
      if (universityId != null) query = query.eq('university_id', universityId);
      if (categoryId != null) query = query.eq('category_id', categoryId);
      final response = await query.range(offset, offset + limit - 1).order('created_at', ascending: false);
      return (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  Future<List<ProductModel>> getFeaturedProducts({String? universityId, String? state, int limit = 10}) async {
    try {
      var query = _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name, state)').eq('is_available', true).eq('is_featured', true);
      if (universityId != null) query = query.eq('university_id', universityId);
      final response = await query.limit(limit).order('favorite_count', ascending: false);
      return (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch featured products: $e');
    }
  }

  Future<List<ProductModel>> getTopSellingProducts({String? universityId, int limit = 6}) async {
    try {
      var query = _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)').eq('is_available', true).eq('is_top_seller', true);
      if (universityId != null) query = query.eq('university_id', universityId);
      final response = await query.limit(limit).order('sold_count', ascending: false);
      return (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ProductModel>> getTrendingProducts({String? universityId, int limit = 10}) async {
    try {
      var query = _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)').eq('is_available', true).eq('is_trending', true);
      if (universityId != null) query = query.eq('university_id', universityId);
      final response = await query.limit(limit).order('view_count', ascending: false);
      return (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ProductModel>> getRecommendedProducts({String? universityId, String? userId, int limit = 6}) async {
    try {
      var query = _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)').eq('is_available', true);
      if (universityId != null) query = query.eq('university_id', universityId);
      final response = await query.limit(limit).order('view_count', ascending: false);
      return (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ProductModel>> getProductsByLowestPrice({String? universityId, String? state, int limit = 50}) async {
    if (state != null) {
      final products = await getProductsByState(state: state, priorityUniversityId: universityId, limit: limit, offset: 0);
      products.sort((a, b) {
        if (a.universityId == universityId && b.universityId != universityId) return -1;
        if (b.universityId == universityId && a.universityId != universityId) return 1;
        final deliveryCompare = b.deliveryCount.compareTo(a.deliveryCount);
        if (deliveryCompare != 0) return deliveryCompare;
        return a.price.compareTo(b.price);
      });
      return products;
    }
    try {
      var query = _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)').eq('is_available', true);
      if (universityId != null) query = query.eq('university_id', universityId);
      final response = await query.limit(limit).order('price', ascending: true);
      return (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch products by price: $e');
    }
  }

  Future<List<ProductModel>> searchProducts(String query, {String? universityId, String? categoryId, String? state, int limit = 50}) async {
    if (state != null) {
      final products = await getProductsByState(state: state, priorityUniversityId: universityId, categoryId: categoryId, limit: limit);
      final normalizedQuery = query.toLowerCase().trim();
      return products.where((p) {
        final name = p.name.toLowerCase();
        final description = p.description.toLowerCase();
        if (name.contains(normalizedQuery) || description.contains(normalizedQuery)) return true;
        if (normalizedQuery.endsWith('s') && normalizedQuery.length > 2) {
          final singular = normalizedQuery.substring(0, normalizedQuery.length - 1);
          if (name.contains(singular) || description.contains(singular)) return true;
        }
        final plural = normalizedQuery + 's';
        if (name.contains(plural) || description.contains(plural)) return true;
        return false;
      }).toList();
    }
    try {
      var baseQuery = _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)').eq('is_available', true).ilike('name', '%$query%');
      if (universityId != null) baseQuery = baseQuery.eq('university_id', universityId);
      if (categoryId != null) baseQuery = baseQuery.eq('category_id', categoryId);
      final response = await baseQuery.limit(limit);
      return (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  Future<List<String>> getSearchSuggestions({required String partialQuery, String? state, String? universityId, int limit = 10}) async {
    if (partialQuery.isEmpty || partialQuery.length < 2) return [];
    try {
      final normalizedQuery = partialQuery.toLowerCase().trim();
      if (state != null) {
        final products = await getProductsByState(state: state, priorityUniversityId: universityId, limit: 100);
        final matchingNames = <String>{};
        for (var product in products) {
          final name = product.name.toLowerCase();
          if (name.startsWith(normalizedQuery)) matchingNames.add(product.name);
          if (normalizedQuery.endsWith('s') && normalizedQuery.length > 2) {
            final singular = normalizedQuery.substring(0, normalizedQuery.length - 1);
            if (name.contains(singular)) {
              matchingNames.add(product.name);
            } else {
              final words = name.split(' ');
              for (var word in words) {
                if (word.startsWith(singular)) {
                  matchingNames.add(product.name);
                  break;
                }
              }
            }
          } else {
            final plural = normalizedQuery + 's';
            if (name.startsWith(plural)) {
              matchingNames.add(product.name);
            } else {
              final words = name.split(' ');
              for (var word in words) {
                if (word.startsWith(plural)) {
                  matchingNames.add(product.name);
                  break;
                }
              }
            }
          }
          if (matchingNames.length >= limit) break;
        }
        return matchingNames.take(limit).toList();
      }
      var query = _supabase.from('products').select('name').eq('is_available', true).ilike('name', '%$partialQuery%');
      if (universityId != null) query = query.eq('university_id', universityId);
      final response = await query.limit(limit * 2).order('view_count', ascending: false);
      final suggestions = <String>{};
      for (var item in response as List) {
        suggestions.add(item['name'] as String);
        if (suggestions.length >= limit) break;
      }
      return suggestions.toList();
    } catch (e) {
      return [];
    }
  }

  Future<ProductModel?> getProductById(String productId) async {
    try {
      final response = await _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)').eq('id', productId).single();
      return _mapProduct(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<ProductModel>> getRelatedProducts({required String currentProductId, required String categoryId, required String universityId, int limit = 10}) async {
    try {
      var query = _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)').eq('is_available', true).eq('category_id', categoryId).eq('university_id', universityId).neq('id', currentProductId);
      var response = await query.limit(limit).order('view_count', ascending: false);
      var products = (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
      if (products.length < 5) {
        var fallbackQuery = _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)').eq('is_available', true).eq('category_id', categoryId).neq('id', currentProductId).neq('university_id', universityId);
        var fallbackResponse = await fallbackQuery.limit(limit - products.length).order('view_count', ascending: false);
        final fallbackProducts = (fallbackResponse as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
        products.addAll(fallbackProducts);
      }
      return products;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopProductsByState({required String state, int limit = 3}) async {
    try {
      final response = await _supabase.from('products').select('id, name, sold_count, image_urls').eq('is_available', true).limit(limit).order('sold_count', ascending: false);
      return (response as List).map((item) {
        final imageUrls = item['image_urls'];
        String? firstImage;
        if (imageUrls is List && imageUrls.isNotEmpty) {
          firstImage = imageUrls[0] as String?;
        } else if (imageUrls is String) {
          firstImage = imageUrls;
        }
        return {'id': item['id'] as String, 'name': item['name'] as String, 'sold': item['sold_count'] as int? ?? 0, 'image': firstImage};
      }).toList();
    } catch (e) {
      return [];
    }
  }

  ProductModel _mapProduct(Map<String, dynamic> json) {
    final category = json['categories'] as Map<String, dynamic>?;
    final seller = json['sellers'] as Map<String, dynamic>?;
    final university = json['universities'] as Map<String, dynamic>?;
    return ProductModel.fromJson({...json, 'category_name': category?['name'], 'seller_name': seller?['business_name'] ?? seller?['full_name'], 'university_name': university?['short_name'] ?? university?['name']});
  }

  Future<void> incrementViewCount(String productId) async {
    try {
      await _supabase.rpc('increment_product_views', params: {'product_id': productId});
    } catch (e) {}
  }

  Future<List<ProductModel>> getFlashSaleProducts({required String state, String? priorityUniversityId, int limit = 50}) async {
    final products = await getProductsByState(state: state, priorityUniversityId: priorityUniversityId, limit: 150, offset: 0);
    final flashSaleProducts = products.where((p) {
      final hasDiscount = p.discountPercentage != null && p.discountPercentage! >= 20;
      final lowStock = p.stockQuantity <= 10;
      final isRecent = DateTime.now().difference(p.createdAt).inDays <= 7;
      final highSales = p.soldCount >= 5;
      final isPopular = p.deliveryCount >= 5;
      return (hasDiscount && (lowStock || isRecent || highSales)) || isPopular;
    }).toList();
    flashSaleProducts.sort((a, b) => b.deliveryCount.compareTo(a.deliveryCount));
    return flashSaleProducts.take(limit).toList();
  }

  Future<List<ProductModel>> getDiscountedProducts({required String state, String? priorityUniversityId, int limit = 50}) async {
    final products = await getProductsByState(state: state, priorityUniversityId: priorityUniversityId, limit: 150);
    final discounted = products.where((p) => p.hasDiscount).toList();
    discounted.sort((a, b) => (b.discountPercentage ?? 0).compareTo(a.discountPercentage ?? 0));
    return discounted.take(limit).toList();
  }

  Future<List<ProductModel>> getLastChanceProducts({required String state, String? priorityUniversityId, int limit = 50}) async {
    final products = await getProductsByState(state: state, priorityUniversityId: priorityUniversityId, limit: 150);
    final lastChance = products.where((p) => p.stockQuantity <= 5 && p.stockQuantity > 0).toList();
    lastChance.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
    return lastChance.take(limit).toList();
  }

  Future<List<ProductModel>> getUnder10kProducts({required String state, String? priorityUniversityId, int limit = 50}) async {
    final products = await getProductsByState(state: state, priorityUniversityId: priorityUniversityId, limit: 150);
    final under10k = products.where((p) => p.price < 10000).toList();
    under10k.sort((a, b) => a.price.compareTo(b.price));
    return under10k.take(limit).toList();
  }

  Future<List<ProductModel>> getTopDealsProducts({required String state, String? priorityUniversityId, int limit = 50}) async {
    final products = await getProductsByState(state: state, priorityUniversityId: priorityUniversityId, limit: 150, offset: 0);
    final topDeals = products.where((p) {
      final hasGoodRating = (p.averageRating ?? 0) >= 4.0;
      final hasDiscount = p.hasDiscount;
      final hasSales = p.soldCount >= 3;
      final isPopular = p.deliveryCount >= 5;
      return (hasGoodRating || (hasDiscount && hasSales)) || isPopular;
    }).toList();
    topDeals.sort((a, b) {
      final scoreA = (a.averageRating ?? 0) * 2 + (a.soldCount * 0.5) + (a.discountPercentage ?? 0) * 0.3 + (a.deliveryCount * 1.0);
      final scoreB = (b.averageRating ?? 0) * 2 + (b.soldCount * 0.5) + (b.discountPercentage ?? 0) * 0.3 + (b.deliveryCount * 1.0);
      return scoreB.compareTo(scoreA);
    });
    return topDeals.take(limit).toList();
  }

  Future<List<ProductModel>> getNewThisWeekProducts({required String state, String? priorityUniversityId, int limit = 50}) async {
    final products = await getProductsByState(state: state, priorityUniversityId: priorityUniversityId, limit: 150);
    final newProducts = products.where((p) => DateTime.now().difference(p.createdAt).inDays <= 7).toList();
    newProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return newProducts.take(limit).toList();
  }
}