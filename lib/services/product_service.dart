import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import 'dart:math';

class ProductService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Helper: Get user's category interests with weights
  Future<Map<String, double>> _getUserCategoryInterests(String userId) async {
    try {
      final categoryScores = <String, double>{};
      
      // 1. Get categories from orders (weight: 3x)
      final orders = await _supabase
          .from('orders')
          .select('products(category_id)')
          .eq('buyer_id', userId);
      
      for (var order in orders as List) {
        final product = order['products'];
        if (product != null && product['category_id'] != null) {
          final categoryId = product['category_id'] as String;
          categoryScores[categoryId] = (categoryScores[categoryId] ?? 0) + 3.0;
        }
      }
      
      // 2. Get categories from wishlist (weight: 2x)
      final wishlist = await _supabase
          .from('wishlist')
          .select('products(category_id)')
          .eq('user_id', userId);
      
      for (var item in wishlist as List) {
        final product = item['products'];
        if (product != null && product['category_id'] != null) {
          final categoryId = product['category_id'] as String;
          categoryScores[categoryId] = (categoryScores[categoryId] ?? 0) + 2.0;
        }
      }
      
      // 3. Get categories from product views (weight: 1x)
      final views = await _supabase
          .from('product_views')
          .select('products(category_id)')
          .eq('user_id', userId);
      
      for (var view in views as List) {
        final product = view['products'];
        if (product != null && product['category_id'] != null) {
          final categoryId = product['category_id'] as String;
          categoryScores[categoryId] = (categoryScores[categoryId] ?? 0) + 1.0;
        }
      }
      
      return categoryScores;
    } catch (e) {
      return {};
    }
  }

  // Helper: Get top N categories by score
  List<String> _getTopCategories(Map<String, double> categoryScores, int limit) {
    final entries = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList();
  }

  // Get shuffle seed that changes every 3 days
  int _getShuffleSeed() {
    final now = DateTime.now();
    final daysSinceEpoch = now.difference(DateTime(2025, 1, 1)).inDays;
    return daysSinceEpoch ~/ 3;
  }

  // Helper: Count views from product_views table
  Future<int> _getViewCount(String productId) async {
    try {
      final response = await _supabase
          .from('product_views')
          .select()
          .eq('product_id', productId);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // Helper: Count sales from orders table
  Future<int> _getSalesCount(String productId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('quantity')
          .eq('product_id', productId)
          .eq('order_status', 'delivered');
      
      int total = 0;
      for (var order in response as List) {
        total += (order['quantity'] as int? ?? 0);
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  // Helper: Get delivery count from orders
  Future<int> _getDeliveryCount(String productId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('product_id', productId)
          .eq('order_status', 'delivered');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // Helper: Get average rating and review count
  Future<Map<String, dynamic>> _getReviewStats(String productId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('rating')
          .eq('product_id', productId);
      
      final reviews = response as List;
      if (reviews.isEmpty) {
        return {'rating': 0.0, 'count': 0};
      }
      
      double sum = 0;
      for (var review in reviews) {
        sum += (review['rating'] as num? ?? 0).toDouble();
      }
      
      return {
        'rating': sum / reviews.length,
        'count': reviews.length,
      };
    } catch (e) {
      return {'rating': 0.0, 'count': 0};
    }
  }

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
      print('📦 ALL PRODUCTS: state=$state, priorityUni=$priorityUniversityId, categoryId=$categoryId, limit=$limit');
      
      final response = await _supabase.rpc('get_products_by_state_details', params: {'p_state': state, 'p_limit': limit, 'p_offset': offset, 'p_category_id': categoryId});
      final products = (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
      
      print('📦 ALL PRODUCTS: Fetched ${products.length} products from database');
      
      // NEW SORTING: All Products with balanced scoring
      final random = Random(_getShuffleSeed());
      final productsWithScores = await Future.wait(
        products.map((product) async {
          final viewCount = await _getViewCount(product.id);
          final salesCount = await _getSalesCount(product.id);
          final deliveryCount = await _getDeliveryCount(product.id);
          final reviewStats = await _getReviewStats(product.id);
          
          // Calculate recency boost
          final daysSinceCreated = DateTime.now().difference(product.createdAt).inDays;
          double recencyBoost = 0;
          if (daysSinceCreated < 7) {
            recencyBoost = 10;
          } else if (daysSinceCreated < 30) {
            recencyBoost = 5;
          }
          
          // Calculate score
          final campusBonus = (priorityUniversityId != null && product.universityId == priorityUniversityId) ? 20.0 : 0.0;
          final randomFactor = random.nextInt(10).toDouble();
          
          final score = campusBonus +
              (deliveryCount * 2.0) +
              (viewCount * 0.5) +
              (reviewStats['rating'] * 5.0) +
              (reviewStats['count'] * 0.3) +
              recencyBoost +
              randomFactor;
          
          return {
            'product': product,
            'score': score,
          };
        })
      );
      
      // Sort by score
      productsWithScores.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      
      final result = productsWithScores.map((item) => item['product'] as ProductModel).toList();
      print('📦 ALL PRODUCTS: Sorted and returning ${result.length} products');
      return result;
    } catch (e) {
      print('❌ ALL PRODUCTS ERROR: $e');
      throw Exception('Failed to fetch products: $e');
    }
  }

  Future<List<ProductModel>> getAllProducts({String? universityId, String? categoryId, String? state, int limit = 50, int offset = 0}) async {
    if (state != null) {
      return getProductsByState(state: state, priorityUniversityId: universityId, categoryId: categoryId, limit: limit, offset: offset);
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

  // ✅ UPDATED: Automatic trending based on engagement score
  Future<List<ProductModel>> getTrendingProducts({String? universityId, int limit = 50}) async {
    try {
      print('🔥 TRENDING: universityId=$universityId, limit=$limit');
      
      var query = _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)').eq('is_available', true);
      if (universityId != null) {
        query = query.eq('university_id', universityId);
        print('🔥 TRENDING: Filtering by university');
      }
      
      // Fetch more products to calculate scores
      final response = await query.limit(150).order('view_count', ascending: false);
      final products = (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
      
      print('🔥 TRENDING: Fetched ${products.length} products');
      
      // Calculate trending score: (views × 2) + (sales × 5) + (deliveries × 3)
      products.sort((a, b) {
        final scoreA = (a.viewCount * 2.0) + (a.soldCount * 5.0) + (a.deliveryCount * 3.0);
        final scoreB = (b.viewCount * 2.0) + (b.soldCount * 5.0) + (b.deliveryCount * 3.0);
        return scoreB.compareTo(scoreA);
      });
      
      final result = products.take(limit).toList();
      print('🔥 TRENDING: Returning ${result.length} products');
      return result;
    } catch (e) {
      print('❌ TRENDING ERROR: $e');
      return [];
    }
  }

  Future<List<ProductModel>> getRecommendedProducts({String? universityId, String? userId, int limit = 30}) async {
    try {
      // If no userId, return trending
      if (userId == null) {
        print('⚠️ No userId, falling back to trending');
        return getTrendingProducts(universityId: universityId, limit: limit);
      }
      
      // Get user's category interests
      final categoryScores = await _getUserCategoryInterests(userId);
      print('📊 Category scores: $categoryScores');
      
      // Check if user has enough interactions (at least 10 total score)
      final totalScore = categoryScores.values.fold(0.0, (sum, score) => sum + score);
      print('📈 Total score: $totalScore');
      
      if (totalScore < 10) {
        // New user or not enough data → fallback to trending
        print('⚠️ Not enough data (score: $totalScore), falling back to trending');
        return getTrendingProducts(universityId: universityId, limit: limit);
      }
      
      // Get top 3 categories
      final topCategories = _getTopCategories(categoryScores, 3);
      print('🏆 Top 3 categories: $topCategories');
      
      if (topCategories.isEmpty) {
        print('⚠️ No categories found, falling back to trending');
        return getTrendingProducts(universityId: universityId, limit: limit);
      }
      
      // Fetch products from each category (STATE-WIDE, not university-specific)
      final allProducts = <ProductModel>[];
      
      // Category 1: 15 products
      if (topCategories.isNotEmpty) {
        final response = await _supabase
            .from('products')
            .select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)')
            .eq('is_available', true)
            .eq('category_id', topCategories[0])
            .limit(15);
        
        final cat1Products = (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
        print('📦 Category 1: ${cat1Products.length} products');
        allProducts.addAll(cat1Products);
      }
      
      // Category 2: 10 products
      if (topCategories.length > 1) {
        final response = await _supabase
            .from('products')
            .select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)')
            .eq('is_available', true)
            .eq('category_id', topCategories[1])
            .limit(10);
        
        final cat2Products = (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
        print('📦 Category 2: ${cat2Products.length} products');
        allProducts.addAll(cat2Products);
      }
      
      // Category 3: 5 products
      if (topCategories.length > 2) {
        final response = await _supabase
            .from('products')
            .select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)')
            .eq('is_available', true)
            .eq('category_id', topCategories[2])
            .limit(5);
        
        final cat3Products = (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
        print('📦 Category 3: ${cat3Products.length} products');
        allProducts.addAll(cat3Products);
      }
      
      print('📦 Total before fill: ${allProducts.length} products');
      
      // If we have too few products, fill with trending
      if (allProducts.length < 10) {
        print('⚠️ Not enough products (${allProducts.length}), filling with trending');
        final trending = await getTrendingProducts(universityId: universityId, limit: limit - allProducts.length);
        allProducts.addAll(trending);
      }
      
      // Remove duplicates
      final uniqueProducts = <String, ProductModel>{};
      for (var product in allProducts) {
        uniqueProducts[product.id] = product;
      }
      
      // Get wishlist to exclude already wishlisted items
      final wishlistIds = <String>{};
      try {
        final wishlist = await _supabase
            .from('wishlist')
            .select('product_id')
            .eq('user_id', userId);
        for (var item in wishlist as List) {
          wishlistIds.add(item['product_id'] as String);
        }
        print('💝 Wishlist items: ${wishlistIds.length}');
      } catch (e) {
        print('⚠️ Error fetching wishlist: $e');
        // Continue without wishlist filter
      }
      
      // Filter out wishlisted products and sort by engagement
      final filteredProducts = uniqueProducts.values
          .where((p) => !wishlistIds.contains(p.id))
          .toList();
      
      print('📦 After wishlist filter: ${filteredProducts.length} products');
      
      // Sort by engagement score
      final random = Random(_getShuffleSeed());
      filteredProducts.sort((a, b) {
        final scoreA = (a.viewCount * 0.5) + 
                      (a.soldCount * 2.0) + 
                      (a.deliveryCount * 1.5) + 
                      ((a.averageRating ?? 0) * 3.0) +
                      random.nextInt(10);
        
        final scoreB = (b.viewCount * 0.5) + 
                      (b.soldCount * 2.0) + 
                      (b.deliveryCount * 1.5) + 
                      ((b.averageRating ?? 0) * 3.0) +
                      random.nextInt(10);
        
        return scoreB.compareTo(scoreA);
      });
      
      final result = filteredProducts.take(limit).toList();
      print('✅ Final result: ${result.length} products');
      return result;
    } catch (e) {
      print('❌ ERROR in getRecommendedProducts: $e');
      // On any error, fallback to trending
      return getTrendingProducts(universityId: universityId, limit: limit);
    }
  }

  Future<List<ProductModel>> getProductsByLowestPrice({String? universityId, String? state, int limit = 50}) async {
    if (state != null) {
      print('💰 LOWEST PRICE: state=$state, universityId=$universityId, limit=$limit');
      
      final products = await getProductsByState(state: state, priorityUniversityId: universityId, limit: limit, offset: 0);
      
      print('💰 LOWEST PRICE: Fetched ${products.length} products, calculating spam penalties...');
      
      // NEW SORTING: Price + spam penalty
      final productsWithSortValue = await Future.wait(
        products.map((product) async {
          final salesCount = await _getSalesCount(product.id);
          final reviewCount = (await _getReviewStats(product.id))['count'] as int;
          
          // Spam penalty
          double spamPenalty = 0;
          if (salesCount == 0 && reviewCount == 0) {
            final daysSinceCreated = DateTime.now().difference(product.createdAt).inDays;
            if (daysSinceCreated < 7) {
              spamPenalty = 2000; // New product with no engagement
            } else {
              spamPenalty = 1000; // Old product with no engagement
            }
          }
          
          final sortValue = product.price + spamPenalty;
          
          return {
            'product': product,
            'sortValue': sortValue,
          };
        })
      );
      
      // Sort by sort value (price + penalty)
      productsWithSortValue.sort((a, b) => (a['sortValue'] as double).compareTo(b['sortValue'] as double));
      
      final result = productsWithSortValue.map((item) => item['product'] as ProductModel).toList();
      print('💰 LOWEST PRICE: Sorted and returning ${result.length} products');
      return result;
    }
    try {
      var query = _supabase.from('products').select('*, categories(name), sellers(full_name, business_name), universities(name, short_name)').eq('is_available', true);
      if (universityId != null) query = query.eq('university_id', universityId);
      final response = await query.limit(limit).order('price', ascending: true);
      return (response as List).map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ LOWEST PRICE ERROR: $e');
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

  Future<List<ProductModel>> searchProductsWithAI(String query, {String? universityId}) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-search',
        body: {
          'query': query,
          'userId': _supabase.auth.currentUser?.id,
          'campusId': universityId,
        },
      );

      final productList = response.data['products'] as List;
      return productList.map((json) => _mapProduct(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('AI search failed: $e');
      throw Exception('AI search failed: $e');
    }
  }

  Future<Map<String, dynamic>> searchProductsWithAIFull(String query, {String? universityId}) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-search',
        body: {
          'query': query,
          'userId': _supabase.auth.currentUser?.id,
          'campusId': universityId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final productList = data['products'] as List;
      final aiResponse = data['aiResponse'] as Map<String, dynamic>?;
      
      return {
        'products': productList.map((json) => _mapProduct(json as Map<String, dynamic>)).toList(),
        'aiMessage': aiResponse?['message'] as String?,
        'aiUnderstanding': aiResponse?['understanding'] as String?,
        'confidence': aiResponse?['confidence'] as double? ?? 0.0,
      };
    } catch (e) {
      print('AI search failed: $e');
      throw Exception('AI search failed: $e');
    }
  }
}