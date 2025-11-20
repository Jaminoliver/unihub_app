import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

class VibeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // SWIPE TRACKING
  // ============================================

  /// Track user swipe (like or skip)
  Future<void> trackSwipe({
    required String productId,
    required String action, // 'like' or 'skip'
    required ProductModel product,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('swipe_history').insert({
        'user_id': userId,
        'product_id': productId,
        'action': action,
        'category_id': product.categoryId,
        'price': product.price,
        'university_id': product.universityId,
      });
    } catch (e) {
      print('Track swipe error: $e');
    }
  }

  // ============================================
  // AI RECOMMENDATIONS ("For You" Tab)
  // ============================================

  /// Get AI-powered recommendations based on user behavior
  Future<List<ProductModel>> getRecommendations({
    required String state,
    String? universityId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      // Call the edge function
      final response = await _supabase.functions.invoke(
        'ai-recommendations',
        body: {
          'userId': userId,
          'state': state,
          'universityId': universityId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final productList = data['products'] as List;

      return productList
          .map((json) => _mapProduct(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Get recommendations error: $e');
      // Return empty list on error - screen will show retry
      return [];
    }
  }

  // ============================================
  // AI SEARCH (Natural Language)
  // ============================================

  /// Search products using natural language
  Future<Map<String, dynamic>> searchWithAI({
    required String query,
    required String state,
    String? universityId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      final response = await _supabase.functions.invoke(
        'ai-search',
        body: {
          'query': query,
          'userId': userId,
          'state': state,
          'universityId': universityId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final productList = data['products'] as List;

      return {
        'products': productList
            .map((json) => _mapProduct(json as Map<String, dynamic>))
            .toList(),
        'aiMessage': data['aiMessage'] as String?,
        'understanding': data['understanding'] as String?,
      };
    } catch (e) {
      print('AI search error: $e');
      throw Exception('Search failed: $e');
    }
  }

  // ============================================
  // USER STATS
  // ============================================

  /// Get user's swipe statistics
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return _emptyStats();

      final response = await _supabase.rpc(
        'get_user_swipe_stats',
        params: {'p_user_id': userId},
      );

      if (response == null || response is! List || response.isEmpty) {
        return _emptyStats();
      }

      final stats = response[0] as Map<String, dynamic>;
      return {
        'totalSwipes': stats['total_swipes'] ?? 0,
        'likes': stats['likes'] ?? 0,
        'skips': stats['skips'] ?? 0,
        'topCategory': stats['top_category'],
        'avgPrice': stats['avg_price'],
      };
    } catch (e) {
      print('Get user stats error: $e');
      return _emptyStats();
    }
  }

  Map<String, dynamic> _emptyStats() {
    return {
      'totalSwipes': 0,
      'likes': 0,
      'skips': 0,
      'topCategory': null,
      'avgPrice': null,
    };
  }

  // ============================================
  // HELPER: Map Product
  // ============================================

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