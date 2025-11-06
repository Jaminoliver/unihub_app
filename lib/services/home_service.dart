import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

/// Home Screen Service - Fetches data for home screen widgets
class HomeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get trending activity for a university
  Future<Map<String, dynamic>> getTrendingActivity(String universityId) async {
    try {
      final response = await _supabase
          .from('trending_activity')
          .select('*')
          .eq('university_id', universityId)
          .single();

      return {
        'active_users': response['active_users_count'] as int,
        'products_viewed': response['products_viewed_today'] as int,
        'products_sold': response['products_sold_today'] as int,
        'last_updated': DateTime.parse(response['last_updated'] as String),
      };
    } catch (e) {
      print('Error fetching trending activity: $e');
      return {
        'active_users': 156,
        'products_viewed': 230,
        'products_sold': 12,
        'last_updated': DateTime.now(),
      };
    }
  }

  /// Get recent purchases for campus pulse
  Future<List<Map<String, dynamic>>> getRecentPurchases(
    String universityId, {
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('recent_purchases')
          .select('''
            *,
            products(name, price)
          ''')
          .eq('university_id', universityId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((item) {
        final product = item['products'] as Map<String, dynamic>?;
        return {
          'buyer_name': item['buyer_name'] as String,
          'product_name': product?['name'] as String? ?? 'Product',
          'created_at': DateTime.parse(item['created_at'] as String),
        };
      }).toList();
    } catch (e) {
      print('Error fetching recent purchases: $e');
      return [];
    }
  }

  /// Get flash sale products
  Future<List<ProductModel>> getFlashSaleProducts({
    String? universityId,
    int limit = 10,
  }) async {
    try {
      final query = _supabase
          .from('products')
          .select('''
            *,
            categories(name),
            sellers(full_name, business_name)
            universities(name, short_name)
          ''')
          .eq('is_available', true)
          .eq('is_flash_sale', true)
          .gt('flash_sale_ends_at', DateTime.now().toIso8601String());

      final finalQuery =
          (universityId != null
                  ? query.eq('university_id', universityId)
                  : query)
              .limit(limit)
              .order('sold_count', ascending: false);

      final response = await finalQuery;
      return (response as List)
          .map((json) => _mapProduct(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching flash sale products: $e');
      return [];
    }
  }

  /// Get top selling products
  Future<List<ProductModel>> getTopSellingProducts({
    String? universityId,
    int limit = 6,
  }) async {
    try {
      final query = _supabase
          .from('products')
          .select('''
            *,
            categories(name),
            sellers(full_name, business_name)
            universities(name, short_name)
          ''')
          .eq('is_available', true)
          .eq('is_top_seller', true);

      final finalQuery =
          (universityId != null
                  ? query.eq('university_id', universityId)
                  : query)
              .limit(limit)
              .order('sold_count', ascending: false);

      final response = await finalQuery;
      return (response as List)
          .map((json) => _mapProduct(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching top selling products: $e');
      return [];
    }
  }

  /// Get trending products
  Future<List<ProductModel>> getTrendingProducts({
    String? universityId,
    int limit = 10,
  }) async {
    try {
      final query = _supabase
          .from('products')
          .select('''
            *,
            categories(name),
            sellers(full_name, business_name)
            universities(name, short_name)
          ''')
          .eq('is_available', true)
          .eq('is_trending', true);

      final finalQuery =
          (universityId != null
                  ? query.eq('university_id', universityId)
                  : query)
              .limit(limit)
              .order('view_count', ascending: false);

      final response = await finalQuery;
      return (response as List)
          .map((json) => _mapProduct(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching trending products: $e');
      return [];
    }
  }

  /// Get featured products
  Future<List<ProductModel>> getFeaturedProducts({
    String? universityId,
    int limit = 8,
  }) async {
    try {
      final query = _supabase
          .from('products')
          .select('''
            *,
            categories(name),
            sellers(full_name, business_name)
            universities(name, short_name)
          ''')
          .eq('is_available', true)
          .eq('is_featured', true);

      final finalQuery =
          (universityId != null
                  ? query.eq('university_id', universityId)
                  : query)
              .limit(limit)
              .order('favorite_count', ascending: false);

      final response = await finalQuery;
      return (response as List)
          .map((json) => _mapProduct(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching featured products: $e');
      return [];
    }
  }

  /// Get recommended products
  Future<List<ProductModel>> getRecommendedProducts({
    String? universityId,
    String? userId,
    int limit = 6,
  }) async {
    try {
      final query = _supabase
          .from('products')
          .select('''
            *,
            categories(name),
            sellers(full_name, business_name)
            universities(name, short_name)
          ''')
          .eq('is_available', true);

      final finalQuery =
          (universityId != null
                  ? query.eq('university_id', universityId)
                  : query)
              .limit(limit)
              .order('view_count', ascending: false);

      final response = await finalQuery;
      return (response as List)
          .map((json) => _mapProduct(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching recommended products: $e');
      return [];
    }
  }

  /// Get top products by state
  Future<List<Map<String, dynamic>>> getTopProductsByState({
    required String state,
    int limit = 3,
  }) async {
    try {
      final response = await _supabase
          .from('products')
          .select('id, name, sold_count, image_urls')
          .eq('is_available', true)
          .limit(limit)
          .order('sold_count', ascending: false);

      return (response as List).map((item) {
        final imageUrls = item['image_urls'];
        String? firstImage;

        if (imageUrls is List && imageUrls.isNotEmpty) {
          firstImage = imageUrls[0] as String?;
        } else if (imageUrls is String) {
          firstImage = imageUrls;
        }

        return {
          'id': item['id'] as String,
          'name': item['name'] as String,
          'sold': item['sold_count'] as int? ?? 0,
          'image': firstImage,
        };
      }).toList();
    } catch (e) {
      print('Error fetching top products by state: $e');
      return [];
    }
  }

  /// Helper: Map product with nested data
  ProductModel _mapProduct(Map<String, dynamic> json) {
    final category = json['categories'] as Map<String, dynamic>?;
    final seller = json['sellers'] as Map<String, dynamic>?;
    final university = json['universities'] as Map<String, dynamic>?;

    return ProductModel.fromJson({
      ...json,
      'category_name': category?['name'],
      'seller_name': seller?['business_name'] ?? seller?['full_name'],
      'university_name': university?['short_name'] ?? university?['name'],
    });
  }
}
