import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_model.dart';

/// Cart Service - Manages shopping cart operations
class CartService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all cart items for current user
  Future<List<CartModel>> getCartItems(String userId) async {
    try {
      final response = await _supabase
          .from('cart')
          .select('''
            *,
            products!inner(
              *,
              categories(name),
              universities(name, short_name)
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Fetch seller info separately for each product
      final cartItems = (response as List).map((json) {
        return json as Map<String, dynamic>;
      }).toList();

      // Enrich with seller data from sellers table
      for (var item in cartItems) {
        if (item['products'] != null && item['products']['seller_id'] != null) {
          try {
            final sellerResponse = await _supabase
                .from('sellers')
                .select('id, business_name, user_id')
                .eq('id', item['products']['seller_id'])
                .maybeSingle();
            
            if (sellerResponse != null) {
              item['products']['seller'] = sellerResponse;
            }
          } catch (e) {
            print('Error fetching seller for product: $e');
          }
        }
      }

      return cartItems
          .map((json) => CartModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching cart items: $e');
      rethrow;
    }
  }

  /// Get cart item count
  Future<int> getCartCount(String userId) async {
    try {
      final response = await _supabase
          .from('cart')
          .select('id')
          .eq('user_id', userId)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error fetching cart count: $e');
      return 0;
    }
  }

  /// Add item to cart
  Future<CartModel?> addToCart({
    required String userId,
    required String productId,
    int quantity = 1,
  }) async {
    try {
      // Check if item already exists in cart
      final existing = await _supabase
          .from('cart')
          .select('id, quantity')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing != null) {
        // Update existing cart item quantity
        final newQuantity = (existing['quantity'] as int) + quantity;
        return await updateCartItemQuantity(
          existing['id'] as String,
          newQuantity,
        );
      }

      // Add new cart item
      final response = await _supabase
          .from('cart')
          .insert({
            'user_id': userId,
            'product_id': productId,
            'quantity': quantity,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('''
            *,
            products(
              *,
              categories(name),
              universities(name, short_name)
            )
          ''')
          .single();

      // Fetch seller info separately
      if (response['products'] != null && response['products']['seller_id'] != null) {
        try {
          final sellerResponse = await _supabase
              .from('sellers')
              .select('id, business_name, user_id')
              .eq('id', response['products']['seller_id'])
              .maybeSingle();
          
          if (sellerResponse != null) {
            response['products']['seller'] = sellerResponse;
          }
        } catch (e) {
          print('Error fetching seller: $e');
        }
      }

      return CartModel.fromJson(response);
    } catch (e) {
      print('Error adding to cart: $e');
      rethrow;
    }
  }

  /// Update cart item quantity
  Future<CartModel?> updateCartItemQuantity(
    String cartItemId,
    int newQuantity,
  ) async {
    try {
      if (newQuantity <= 0) {
        await removeFromCart(cartItemId);
        return null;
      }

      final response = await _supabase
          .from('cart')
          .update({
            'quantity': newQuantity,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cartItemId)
          .select('''
            *,
            products(
              *,
              categories(name),
              universities(name, short_name)
            )
          ''')
          .single();

      // Fetch seller info separately
      if (response['products'] != null && response['products']['seller_id'] != null) {
        try {
          final sellerResponse = await _supabase
              .from('sellers')
              .select('id, business_name, user_id')
              .eq('id', response['products']['seller_id'])
              .maybeSingle();
          
          if (sellerResponse != null) {
            response['products']['seller'] = sellerResponse;
          }
        } catch (e) {
          print('Error fetching seller: $e');
        }
      }

      return CartModel.fromJson(response);
    } catch (e) {
      print('Error updating cart item: $e');
      rethrow;
    }
  }

  /// Remove item from cart
  Future<bool> removeFromCart(String cartItemId) async {
    try {
      await _supabase.from('cart').delete().eq('id', cartItemId);
      return true;
    } catch (e) {
      print('Error removing from cart: $e');
      return false;
    }
  }

  /// Clear entire cart for user
  Future<bool> clearCart(String userId) async {
    try {
      await _supabase.from('cart').delete().eq('user_id', userId);
      return true;
    } catch (e) {
      print('Error clearing cart: $e');
      return false;
    }
  }

  /// Get cart total amount
  Future<double> getCartTotal(String userId) async {
    try {
      final cartItems = await getCartItems(userId);

      double total = 0.0;
      for (final item in cartItems) {
        total += item.totalPrice;
      }
      return total;
    } catch (e) {
      print('Error calculating cart total: $e');
      return 0.0;
    }
  }

  /// Check if product is in cart
  Future<bool> isInCart({
    required String userId,
    required String productId,
  }) async {
    try {
      final response = await _supabase
          .from('cart')
          .select('id')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking cart: $e');
      return false;
    }
  }

  /// Get cart item by product ID
  Future<CartModel?> getCartItemByProduct({
    required String userId,
    required String productId,
  }) async {
    try {
      final response = await _supabase
          .from('cart')
          .select('''
            *,
            products(
              *,
              categories(name),
              universities(name, short_name)
            )
          ''')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      if (response == null) return null;

      // Fetch seller info separately
      if (response['products'] != null && response['products']['seller_id'] != null) {
        try {
          final sellerResponse = await _supabase
              .from('sellers')
              .select('id, business_name, user_id')
              .eq('id', response['products']['seller_id'])
              .maybeSingle();
          
          if (sellerResponse != null) {
            response['products']['seller'] = sellerResponse;
          }
        } catch (e) {
          print('Error fetching seller: $e');
        }
      }

      return CartModel.fromJson(response);
    } catch (e) {
      print('Error fetching cart item: $e');
      return null;
    }
  }
}