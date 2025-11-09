import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';

/// Order Service - Manages order operations
class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new order from cart items
  /// Returns the created order
  Future<OrderModel> createOrder({
    required String buyerId,
    required String sellerId,
    required String productId,
    required int quantity,
    required double unitPrice,
    required double totalAmount,
    required String paymentMethod, // 'full', 'half', 'pay_on_delivery'
    required String? deliveryAddressId,
    String? paymentReference, // Paystack reference for online payments
    int? transactionId, // Paystack transaction ID
    String? notes,
  }) async {
    try {

      // ADD THESE DEBUG PRINTS HERE
      print('DEBUG - Payment method value: "$paymentMethod"');
      print('DEBUG - Payment method type: ${paymentMethod.runtimeType}');
      print('DEBUG - Payment method length: ${paymentMethod.length}');
    
      // Insert order
      final response = await _supabase
        .from('orders')
        .insert({
          'buyer_id': buyerId,
          'seller_id': sellerId,
          'product_id': productId,
          'quantity': quantity,
          'unit_price': unitPrice,
          'total_amount': totalAmount,
          'payment_method': paymentMethod,
          'payment_status': paymentMethod == 'pay_on_delivery' ? 'pending' : 'completed',
          'payment_reference': paymentReference,
          'payment_verified_at': paymentMethod != 'pay_on_delivery' ? DateTime.now().toIso8601String() : null,
          'transaction_id': transactionId,
          'delivery_address_id': deliveryAddressId,
          'notes': notes,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('''
          *,
          products(name, image_urls),
          sellers!seller_id(id, business_name, user_id),
          buyer:profiles!buyer_id(full_name, phone_number),
          delivery_addresses(address_line, city, state, landmark)
     ''')
        .single();

      return OrderModel.fromJson(response);
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  /// Create multiple orders from selected cart items
  /// Used during checkout when user selects multiple items
  Future<List<OrderModel>> createMultipleOrders({
    required String buyerId,
    required List<Map<String, dynamic>> orderItems,
    required String? deliveryAddressId,
    Map<String, String>? paymentReferences,
    Map<String, int>? transactionIds,
  }) async {
    try {
      List<OrderModel> createdOrders = [];

      for (final item in orderItems) {
        final productId = item['productId'] as String;
        final order = await createOrder(
          buyerId: buyerId,
          sellerId: item['sellerId'] as String,
          productId: productId,
          quantity: item['quantity'] as int,
          unitPrice: item['unitPrice'] as double,
          totalAmount: item['totalAmount'] as double,
          paymentMethod: item['paymentMethod'] as String,
          deliveryAddressId: deliveryAddressId,
          paymentReference: paymentReferences?[productId],
          transactionId: transactionIds?[productId],
          notes: item['notes'] as String?,
        );
        createdOrders.add(order);
      }

      return createdOrders;
    } catch (e) {
      print('Error creating multiple orders: $e');
      rethrow;
    }
  }

  /// Get all orders for a buyer
  Future<List<OrderModel>> getBuyerOrders(String buyerId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            products(name, image_urls),
            sellers!seller_id(id, business_name, user_id),
            delivery_addresses(address_line, city, state, landmark)
          ''')
          .eq('buyer_id', buyerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching buyer orders: $e');
      rethrow;
    }
  }

  /// Get all orders for a seller
  Future<List<OrderModel>> getSellerOrders(String sellerId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            products(name, image_urls),
            buyer:profiles!buyer_id(full_name, phone_number),
            delivery_addresses(address_line, city, state, landmark)
          ''')
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching seller orders: $e');
      rethrow;
    }
  }

  /// Get a single order by ID
  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            products(name, image_urls, description, seller_id),
            sellers!seller_id(id, business_name, user_id),
            buyer:profiles!buyer_id(full_name, phone_number),
            delivery_addresses(address_line, city, state, landmark, phone_number)
          ''')
          .eq('id', orderId)
          .maybeSingle();

      return response != null ? OrderModel.fromJson(response) : null;
    } catch (e) {
      print('Error fetching order: $e');
      return null;
    }
  }

  /// Get order by order number
  Future<OrderModel?> getOrderByNumber(String orderNumber) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            products(name, image_urls),
            sellers!seller_id(id, business_name, user_id),
            buyer:profiles!buyer_id(full_name),
            delivery_addresses(address_line, city, state)
          ''')
          .eq('order_number', orderNumber)
          .maybeSingle();

      return response != null ? OrderModel.fromJson(response) : null;
    } catch (e) {
      print('Error fetching order by number: $e');
      return null;
    }
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({
            'order_status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      return true;
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }

  /// Update payment status
  Future<bool> updatePaymentStatus(
  String orderId,
  String paymentStatus, {
  String? paymentReference,
  int? transactionId,
}) async {
  try {
    final Map<String, dynamic> updateData = { // ✅ Add explicit type here
      'payment_status': paymentStatus,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (paymentReference != null) {
      updateData['payment_reference'] = paymentReference;
    }

    if (transactionId != null) {
      updateData['transaction_id'] = transactionId;
    }

    if (paymentStatus == 'completed') {
      updateData['payment_verified_at'] = DateTime.now().toIso8601String();
    }

    await _supabase.from('orders').update(updateData).eq('id', orderId);

    return true;
  } catch (e) {
    print('Error updating payment status: $e');
    return false;
  }
}

  /// Confirm delivery with 6-digit code
  Future<bool> confirmDelivery(String orderId, String deliveryCode) async {
    try {
      // Get order to verify delivery code
      final order = await getOrderById(orderId);

      if (order == null) {
        print('Order not found');
        return false;
      }

      if (order.deliveryCode != deliveryCode) {
        print('Invalid delivery code');
        return false;
      }

      // Update order status to delivered and release escrow
      await _supabase
          .from('orders')
          .update({
            'order_status': 'delivered',
            'delivery_confirmed_at': DateTime.now().toIso8601String(),
            'escrow_released': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      return true;
    } catch (e) {
      print('Error confirming delivery: $e');
      return false;
    }
  }

  /// Cancel order (buyer or seller)
  Future<bool> cancelOrder(String orderId, String? reason) async {
    try {
      await _supabase
          .from('orders')
          .update({
            'order_status': 'cancelled',
            'notes': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      return true;
    } catch (e) {
      print('Error cancelling order: $e');
      return false;
    }
  }

  /// Get active orders count (for buyer)
  Future<int> getActiveOrdersCount(String buyerId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('id')
          .eq('buyer_id', buyerId)
          .not('order_status', 'in', '(delivered,cancelled,refunded)')
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error getting active orders count: $e');
      return 0;
    }
  }

  /// Get orders by status
  Future<List<OrderModel>> getOrdersByStatus(
    String userId,
    List<String> statuses, {
    bool isSeller = false,
  }) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            products(name, image_urls),
            ${isSeller ? 'buyer:profiles!buyer_id(full_name)' : 'sellers!seller_id(id, business_name)'},
            delivery_addresses(address_line, city, state)
          ''')
          .eq(isSeller ? 'seller_id' : 'buyer_id', userId)
          .inFilter('order_status', statuses)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching orders by status: $e');
      rethrow;
    }
  }

  /// Get total spent by buyer
  Future<double> getTotalSpent(String buyerId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('total_amount')
          .eq('buyer_id', buyerId)
          .inFilter('payment_status', ['completed', 'paid']); // Support both old and new status

      double total = 0.0;
      for (final order in response) {
        total += (order['total_amount'] as num).toDouble();
      }

      return total;
    } catch (e) {
      print('Error calculating total spent: $e');
      return 0.0;
    }
  }

  /// Check if buyer has purchased a specific product
  Future<bool> hasPurchased(String buyerId, String productId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('id')
          .eq('buyer_id', buyerId)
          .eq('product_id', productId)
          .eq('order_status', 'delivered')
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking purchase: $e');
      return false;
    }
  }
}