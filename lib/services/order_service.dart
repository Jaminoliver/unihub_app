import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../models/notification_model.dart';
import '../services/payment_service.dart';
import '../services/notification_service.dart';

class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PaymentService _paymentService = PaymentService();
  final NotificationService _notificationService = NotificationService();

  Future<OrderModel> createOrder({
    required String buyerId,
    required String sellerId,
    required String productId,
    required int quantity,
    required double unitPrice,
    required double totalAmount,
    required String paymentMethod,
    required String? deliveryAddressId,
    String? paymentReference,
    int? transactionId,
    String? notes,
  }) async {
    try {
      final double escrowAmount = _paymentService.calculateEscrowAmount(totalAmount, paymentMethod);

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
          'payment_status': paymentMethod == 'pod' ? 'pending' : 'completed',
          'payment_reference': paymentReference,
          'payment_verified_at': paymentMethod != 'pod' ? DateTime.now().toIso8601String() : null,
          'transaction_id': transactionId,
          'delivery_address_id': deliveryAddressId,
          'notes': notes,
          'created_at': DateTime.now().toIso8601String(),
          'escrow_amount': escrowAmount,
        })
        .select('''
          *,
          products(name, image_urls),
          sellers!seller_id(id, business_name, user_id),
          buyer:profiles!buyer_id(full_name, phone_number),
          delivery_addresses(address_line, city, state, landmark)
        ''')
        .single();
      
      final newOrder = OrderModel.fromJson(response);
      final productName = newOrder.productName ?? 'your item';

      await _notificationService.createNotification(
        userId: buyerId,
        type: NotificationType.orderPlaced,
        title: 'Order Placed Successfully',
        message: '$productName - Order #${newOrder.orderNumber}',
        orderNumber: newOrder.orderNumber,
        amount: newOrder.totalAmount,
      );

      if (escrowAmount > 0) {
        await _notificationService.createNotification(
          userId: buyerId,
          type: NotificationType.paymentEscrow,
          title: 'Payment Secured',
          message: 'Your payment of ₦${escrowAmount.toStringAsFixed(0)} for $productName is in escrow.',
          orderNumber: newOrder.orderNumber,
          amount: escrowAmount,
        );
      }

      return newOrder;
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

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

  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('''
            *,
            products(name, image_urls, description, seller_id),
            sellers!seller_id(id, business_name, user_id, bank_account_number, bank_code, account_name),
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

  Future<bool> updatePaymentStatus(
    String orderId,
    String paymentStatus, {
    String? paymentReference,
    int? transactionId,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
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

  Future<bool> confirmDelivery(String orderId, String deliveryCode) async {
    try {
      // Call the secure Edge Function to handle confirmation and payout
      final response = await _supabase.functions.invoke(
        'release-escrow',
        body: {
          'orderId': orderId,
          'deliveryCode': deliveryCode,
        },
      );

      // Check for a non-successful HTTP status (e.g., 400, 500)
      if (response.status != null && response.status! >= 300) {
        String errorMessage = 'Failed to confirm delivery.';
        // Check if the function sent back a specific error message
        if (response.data != null && response.data['error'] != null) {
          errorMessage = response.data['error'] as String;
        }
        print('Error from release-escrow function: $errorMessage');
        throw Exception(errorMessage);
      }

      // If status is 2xx, it was successful
      print('Edge function success: ${response.data['message']}');
      
      // The Edge Function now handles all notifications and DB updates
      return true;

    } catch (e) {
      // This will catch both network errors and the exception we threw above
      print('Error calling confirmDelivery: $e');
      rethrow;
    }
  }

  Future<bool> cancelOrder(String orderId, String? reason) async {
    try {
      // TODO: Add logic to call a 'refund-escrow' Edge Function if order was paid

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

  Future<double> getTotalSpent(String buyerId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('total_amount')
          .eq('buyer_id', buyerId)
          .inFilter('payment_status', ['completed', 'paid']);

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