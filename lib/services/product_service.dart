import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

/// FIXED: Now implements smart university prioritization as per PRD
class ProductService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get products by STATE with university prioritization
  /// PRIMARY: User's university appears first
  /// SECONDARY: Other universities in same state appear after scrolling
  Future<List<ProductModel>> getProductsByState({
    required String state,
    String? priorityUniversityId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      // Step 1: Get all university IDs in this state
      final universitiesResponse = await _supabase
          .from('universities')
          .select('id')
          .ilike('state', state)
          .eq('is_active', true);

      final universityIds = (universitiesResponse as List)
          .map((u) => u['id'] as String)
          .toList();

      if (universityIds.isEmpty) return [];

      // Step 2: Fetch ALL products from state
      var query = _supabase
          .from('products')
          .select('''
            *,
            categories(name),
            profiles!seller_id(full_name, profile_image_url),
            universities(id, name, short_name, state)
          ''')
          .eq('is_available', true)
          .inFilter('university_id', universityIds);

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final response = await query
          .range(offset, offset + limit - 1)
          .order('created_at', ascending: false);

      final products = (response as List)
          .map((json) => _mapProductFromResponse(json as Map<String, dynamic>))
          .toList();

      // Step 3: Sort by priority university (client-side)
      if (priorityUniversityId != null) {
        products.sort((a, b) {
          // Products from priority university come first
          if (a.universityId == priorityUniversityId &&
              b.universityId != priorityUniversityId)
            return -1;
          if (b.universityId == priorityUniversityId &&
              a.universityId != priorityUniversityId)
            return 1;
          // Otherwise maintain creation date order
          return b.createdAt.compareTo(a.createdAt);
        });
      }

      return products;
    } catch (e) {
      print('Error fetching products by state: $e');
      throw Exception('Failed to fetch products: $e');
    }
  }

  /// Legacy method - now uses getProductsByState under the hood
  Future<List<ProductModel>> getAllProducts({
    String? universityId,
    String? categoryId,
    String? state,
    int limit = 50,
    int offset = 0,
  }) async {
    // If state is provided, use smart filtering
    if (state != null) {
      return getProductsByState(
        state: state,
        priorityUniversityId: universityId,
        categoryId: categoryId,
        limit: limit,
        offset: offset,
      );
    }

    // Fallback: fetch by university only (for backward compatibility)
    try {
      var query = _supabase
          .from('products')
          .select('''
            *,
            categories(name),
            profiles!seller_id(full_name, profile_image_url),
            universities(name, short_name)
          ''')
          .eq('is_available', true);

      if (universityId != null) {
        query = query.eq('university_id', universityId);
      }

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final response = await query
          .range(offset, offset + limit - 1)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => _mapProductFromResponse(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching products: $e');
      throw Exception('Failed to fetch products: $e');
    }
  }

  Future<List<ProductModel>> getFeaturedProducts({
    String? universityId,
    String? state,
    int limit = 10,
  }) async {
    try {
      var query = _supabase
          .from('products')
          .select('''
            *,
            categories(name),
            profiles!seller_id(full_name, profile_image_url),
            universities(name, short_name, state)
          ''')
          .eq('is_available', true)
          .eq('is_featured', true);

      if (universityId != null) {
        query = query.eq('university_id', universityId);
      }

      final response = await query
          .limit(limit)
          .order('favorite_count', ascending: false);

      return (response as List)
          .map((json) => _mapProductFromResponse(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching featured products: $e');
      throw Exception('Failed to fetch featured products: $e');
    }
  }

  Future<List<ProductModel>> getProductsByLowestPrice({
    String? universityId,
    String? state,
    int limit = 50,
  }) async {
    if (state != null) {
      final products = await getProductsByState(
        state: state,
        priorityUniversityId: universityId,
        limit: limit,
      );
      products.sort((a, b) => a.price.compareTo(b.price));
      return products;
    }

    try {
      var query = _supabase
          .from('products')
          .select('''
            *,
            categories(name),
            profiles!seller_id(full_name, profile_image_url),
            universities(name, short_name)
          ''')
          .eq('is_available', true);

      if (universityId != null) {
        query = query.eq('university_id', universityId);
      }

      final response = await query.limit(limit).order('price', ascending: true);

      return (response as List)
          .map((json) => _mapProductFromResponse(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching products by price: $e');
      throw Exception('Failed to fetch products by price: $e');
    }
  }

  Future<List<ProductModel>> searchProducts(
    String query, {
    String? universityId,
    String? categoryId,
    String? state,
    int limit = 50,
  }) async {
    if (state != null) {
      final products = await getProductsByState(
        state: state,
        priorityUniversityId: universityId,
        categoryId: categoryId,
        limit: limit,
      );

      // Filter by search query
      return products
          .where(
            (p) =>
                p.name.toLowerCase().contains(query.toLowerCase()) ||
                p.description.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }

    try {
      var baseQuery = _supabase
          .from('products')
          .select('''
            *,
            categories(name),
            profiles!seller_id(full_name, profile_image_url),
            universities(name, short_name)
          ''')
          .eq('is_available', true)
          .ilike('name', '%$query%');

      if (universityId != null) {
        baseQuery = baseQuery.eq('university_id', universityId);
      }

      if (categoryId != null) {
        baseQuery = baseQuery.eq('category_id', categoryId);
      }

      final response = await baseQuery.limit(limit);

      return (response as List)
          .map((json) => _mapProductFromResponse(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error searching products: $e');
      throw Exception('Failed to search products: $e');
    }
  }

  Future<ProductModel?> getProductById(String productId) async {
    try {
      final response = await _supabase
          .from('products')
          .select('''
            *,
            categories(name),
            profiles!seller_id(full_name, profile_image_url),
            universities(name, short_name)
          ''')
          .eq('id', productId)
          .single();

      return _mapProductFromResponse(response);
    } catch (e) {
      print('Error fetching product: $e');
      return null;
    }
  }

  ProductModel _mapProductFromResponse(Map<String, dynamic> json) {
    final category = json['categories'] as Map<String, dynamic>?;
    final seller = json['profiles'] as Map<String, dynamic>?;
    final university = json['universities'] as Map<String, dynamic>?;

    return ProductModel.fromJson({
      ...json,
      'category_name': category?['name'],
      'seller_name': seller?['full_name'],
      'seller_image_url': seller?['profile_image_url'],
      'university_name': university?['short_name'] ?? university?['name'],
    });
  }

  Future<void> incrementViewCount(String productId) async {
    try {
      await _supabase.rpc(
        'increment_product_views',
        params: {'product_id': productId},
      );
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }
}
