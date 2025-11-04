import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_model.dart'; // Assuming you have this model

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
            products(
              *,
              categories(name),
              profiles!seller_id(full_name, profile_image_url),
              universities(name, short_name)
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => CartModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching cart items: $e');
      rethrow; // Throw error to be caught by UI
    }
  }

  /// Get cart item count
  Future<int> getCartCount(String userId) async {
    try {
      // FIX 1: Use the .count() modifier for efficiency
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
              profiles!seller_id(full_name, profile_image_url),
              universities(name, short_name)
            )
          ''')
          .single();

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
              profiles!seller_id(full_name, profile_image_url),
              universities(name, short_name)
            )
          ''')
          .single();

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

      // FIX 2: Use a for-loop to handle the 'Future<double>' from item.totalPrice
      double total = 0.0;
      for (final item in cartItems) {
        // Assuming item.totalPrice is a getter that might be async
        // If it's not async, you can just use: total += item.totalPrice;
        // But your error suggested it was a FutureOr<double>.
        // If `totalPrice` is just `price * quantity` in your model,
        // make sure it's not an `async` getter.
        // For this example, I'll assume it's a simple double getter:
        total += item
            .totalPrice; // If totalPrice is `double get totalPrice => price * quantity;`
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
              profiles!seller_id(full_name, profile_image_url),
              universities(name, short_name)
            )
          ''')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      return response != null ? CartModel.fromJson(response) : null;
    } catch (e) {
      print('Error fetching cart item: $e');
      return null;
    }
  }
}
