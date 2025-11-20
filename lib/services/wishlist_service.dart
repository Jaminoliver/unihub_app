import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

class WishlistService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<ProductModel>> getUserWishlist(String userId) async {
    try {
      final response = await _supabase
          .from('wishlist')
          .select('product_id, products(*, categories(name), sellers(full_name, business_name), universities(name, short_name))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        final productData = item['products'] as Map<String, dynamic>;
        return _mapProduct(productData);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch wishlist: $e');
    }
  }

  Future<Set<String>> getUserWishlistIds(String userId) async {
    try {
      final response = await _supabase
          .from('wishlist')
          .select('product_id')
          .eq('user_id', userId);
      
      return (response as List)
          .map((item) => item['product_id'] as String)
          .toSet();
    } catch (e) {
      return {};
    }
  }

  Future<bool> addToWishlist({required String userId, required String productId}) async {
    try {
      await _supabase.from('wishlist').insert({
        'user_id': userId,
        'product_id': productId,
      });
      return true;
    } catch (e) {
      print('Failed to add to wishlist: $e');
      return false;
    }
  }

  Future<void> removeFromWishlist({required String userId, required String productId}) async {
    try {
      await _supabase
          .from('wishlist')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    } catch (e) {
      throw Exception('Failed to remove from wishlist: $e');
    }
  }

  Future<bool> isInWishlist({required String userId, required String productId}) async {
    try {
      final response = await _supabase
          .from('wishlist')
          .select('id')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<int> getWishlistCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase
          .from('wishlist')
          .select('id')
          .eq('user_id', userId);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

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