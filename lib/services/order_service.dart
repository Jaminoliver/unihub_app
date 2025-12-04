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
    String? selectedColor,
    String? selectedSize,
  }) async {
    try {
      final double escrowAmount = _paymentService.calculateEscrowAmount(totalAmount, paymentMethod);
      
      // Calculate commission (5% for online payments only)
      final double commissionRate = 0.05; // 5%
      final double commissionAmount = paymentMethod != 'pod' ? totalAmount * commissionRate : 0.0;
      final double sellerPayoutAmount = paymentMethod != 'pod' ? totalAmount - commissionAmount : 0.0;

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
          'commission_amount': commissionAmount,
          'seller_payout_amount': sellerPayoutAmount,
          'selected_color': selectedColor,
          'selected_size': selectedSize,
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

      // CREATE TRANSACTION RECORD FOR ONLINE PAYMENTS (full or half payment)
      if (paymentMethod != 'pod' && paymentReference != null) {
        try {
          await _supabase.from('transactions').insert({
            'user_id': buyerId,
            'order_id': newOrder.id,
            'transaction_type': 'payment',
            'amount': totalAmount,
            'status': 'success',
            'payment_provider': 'paystack',
            'payment_reference': paymentReference,
            'metadata': {
              'product_id': productId,
              'product_name': productName,
              'quantity': quantity,
              'seller_id': sellerId,
              'order_number': newOrder.orderNumber,
              'payment_method': paymentMethod,
              'escrow_amount': escrowAmount,
              'commission_amount': commissionAmount,
            },
            'created_at': DateTime.now().toIso8601String(),
          });

          print('✅ Payment transaction created for order ${newOrder.orderNumber}');
        } catch (txnError) {
          print('⚠️ Warning: Failed to create transaction record: $txnError');
          // Don't throw - order was created successfully
        }
      }

      // Send notifications
      await _notificationService.createNotification(
        userId: buyerId,
        type: NotificationType.orderPlaced,
        title: 'Order Placed Successfully',
        message: '$productName - Order #${newOrder.orderNumber}',
        orderNumber: newOrder.orderNumber,
        orderId: newOrder.id,
        amount: newOrder.totalAmount,
      );

      if (escrowAmount > 0) {
        await _notificationService.createNotification(
          userId: buyerId,
          type: NotificationType.paymentEscrow,
          title: 'Payment Secured',
          message: 'Your payment of ₦${escrowAmount.toStringAsFixed(0)} for $productName is in escrow.',
          orderNumber: newOrder.orderNumber,
          orderId: newOrder.id,
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
          selectedColor: item['selectedColor'] as String?,
          selectedSize: item['selectedSize'] as String?,
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

      return (response as List).map((json) => OrderModel.fromJson(json)).toList();
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

      return (response as List).map((json) => OrderModel.fromJson(json)).toList();
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

  Future<bool> confirmDelivery(String orderId, String deliveryCode) async {
    try {
      final response = await _supabase.functions.invoke(
        'release-escrow',
        body: {'orderId': orderId, 'deliveryCode': deliveryCode},
      );

      if (response.status != null && response.status! >= 300) {
        throw Exception(response.data?['error'] ?? 'Failed to confirm delivery');
      }
      return true;
    } catch (e) {
      print('Error confirming delivery: $e');
      rethrow;
    }
  }

  Future<bool> cancelOrder(String orderId, String? reason) async {
    try {
      final response = await _supabase.functions.invoke(
        'refund-escrow',
        body: {
          'orderId': orderId,
          'reason': reason ?? 'Order cancelled by buyer',
          'isAutoRefund': false,
        },
      );

      if (response.status != null && response.status! >= 300) {
        throw Exception(response.data?['error'] ?? 'Failed to cancel order');
      }
      return true;
    } catch (e) {
      print('Error cancelling order: $e');
      rethrow;
    }
  }

  bool canCancelOrder(OrderModel order) {
    return !['shipped', 'delivered', 'cancelled', 'refunded'].contains(order.orderStatus);
  }

  Duration? getTimeUntilAutoCancel(OrderModel order) {
    if (['delivered', 'cancelled', 'refunded'].contains(order.orderStatus)) return null;
    final deadline = order.createdAt.add(Duration(days: 6));
    final now = DateTime.now();
    return now.isAfter(deadline) ? null : deadline.difference(now);
  }
}