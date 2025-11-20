/// Order Model - Matches 'orders' table in Supabase
class OrderModel {
  final String id;
  final String orderNumber;
  final String buyerId;
  final String sellerId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String paymentMethod; // 'full', 'half', 'pod'
  final String paymentStatus; // 'pending', 'completed', 'failed', 'refunded'
  final String orderStatus; // 'pending', 'confirmed', 'shipped', 'delivered', 'cancelled', 'refunded'
  final String? deliveryAddressId;
  final String? deliveryCode;
  final DateTime? deliveryConfirmedAt;
  final double escrowAmount;
  final bool escrowReleased;
  final double commissionAmount;
  final double? sellerPayoutAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // New payment tracking fields
  final String? paymentReference; // Paystack payment reference
  final int? transactionId; // Paystack transaction ID
  final DateTime? paymentVerifiedAt; // When payment was verified
  final String? selectedColor;
  final String? selectedSize;

  // Joined data
  final String? productName;
  final String? productImageUrl;
  final String? sellerName;
  final String? buyerName;
  final String? deliveryAddress;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.paymentMethod,
    this.paymentStatus = 'pending',
    this.orderStatus = 'pending',
    this.deliveryAddressId,
    this.deliveryCode,
    this.deliveryConfirmedAt,
    this.escrowAmount = 0,
    this.escrowReleased = false,
    this.commissionAmount = 0,
    this.sellerPayoutAmount,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.paymentReference,
    this.transactionId,
    this.paymentVerifiedAt,
    this.selectedColor,
    this.selectedSize,
    this.productName,
    this.productImageUrl,
    this.sellerName,
    this.buyerName,
    this.deliveryAddress,
  });

 factory OrderModel.fromJson(Map<String, dynamic> json) {
  final product = json['products'] as Map<String, dynamic>?;
  final seller = json['seller'] as Map<String, dynamic>?;
  final buyer = json['buyer'] as Map<String, dynamic>?;
  final address = json['delivery_addresses'] as Map<String, dynamic>?;

  return OrderModel(
    id: json['id'] as String,
    orderNumber: json['order_number'] as String,
    buyerId: json['buyer_id'] as String,
    sellerId: json['seller_id'] as String,
    productId: json['product_id'] as String,
    quantity: json['quantity'] as int,
    unitPrice: (json['unit_price'] as num).toDouble(),
    totalAmount: (json['total_amount'] as num).toDouble(),
    paymentMethod: json['payment_method'] as String,
    paymentStatus: json['payment_status'] as String? ?? 'pending',
    orderStatus: json['order_status'] as String? ?? 'pending',
    deliveryAddressId: json['delivery_address_id'] as String?,
    deliveryCode: json['delivery_code'] as String?,
    deliveryConfirmedAt: json['delivery_confirmed_at'] != null
        ? DateTime.parse(json['delivery_confirmed_at'] as String)
        : null,
    escrowAmount: (json['escrow_amount'] as num?)?.toDouble() ?? 0,
    escrowReleased: json['escrow_released'] as bool? ?? false,
    commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
    sellerPayoutAmount: json['seller_payout_amount'] != null
        ? (json['seller_payout_amount'] as num).toDouble()
        : null,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : null,
    paymentReference: json['payment_reference'] as String?,
    transactionId: json['transaction_id'] as int?,
    paymentVerifiedAt: json['payment_verified_at'] != null
        ? DateTime.parse(json['payment_verified_at'] as String)
        : null,
    // ✅ ADD THESE TWO LINES:
    selectedColor: json['selected_color'] as String?,
    selectedSize: json['selected_size'] as String?,
    // END OF NEW LINES
    productName: product?['name'] as String?,
    productImageUrl:
        product?['image_urls'] != null &&
                (product!['image_urls'] as List).isNotEmpty
            ? (product['image_urls'] as List).first as String?
            : null,
    sellerName: seller?['full_name'] as String?,
    buyerName: buyer?['full_name'] as String?,
    deliveryAddress: address?['address_line'] as String?,
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'order_status': orderStatus,
      'delivery_address_id': deliveryAddressId,
      'delivery_code': deliveryCode,
      'delivery_confirmed_at': deliveryConfirmedAt?.toIso8601String(),
      'escrow_amount': escrowAmount,
      'escrow_released': escrowReleased,
      'commission_amount': commissionAmount,
      'seller_payout_amount': sellerPayoutAmount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'payment_reference': paymentReference,
      'transaction_id': transactionId,
      'payment_verified_at': paymentVerifiedAt?.toIso8601String(),
      'selected_color': selectedColor,
      'selected_size': selectedSize,
    };
  }

  // Formatted amounts
  String get formattedTotal =>
      '₦${totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';

  String get formattedEscrow =>
      '₦${escrowAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';

  // Status helpers
  bool get isPending => orderStatus == 'pending';
  bool get isConfirmed => orderStatus == 'confirmed';
  bool get isShipped => orderStatus == 'shipped';
  bool get isDelivered => orderStatus == 'delivered';
  bool get isCancelled => orderStatus == 'cancelled';
  bool get isRefunded => orderStatus == 'refunded';

  // Payment status helpers
  bool get isPaymentPending => paymentStatus == 'pending';
  bool get isPaymentCompleted => paymentStatus == 'completed';
  bool get isPaymentFailed => paymentStatus == 'failed';
  bool get isPaymentRefunded => paymentStatus == 'refunded';

  // Payment method helpers
  bool get isFullPayment => paymentMethod == 'full';
  bool get isHalfPayment => paymentMethod == 'half';
  // --- FIX: Changed 'pay_on_delivery' to 'pod' ---
  bool get isPayOnDelivery => paymentMethod == 'pod';

  // Status display text
  String get statusDisplayText {
    switch (orderStatus) {
      case 'pending':
        return 'Order Placed';
      case 'confirmed':
        return 'Confirmed by Seller';
      case 'shipped':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      default:
        return 'Unknown';
    }
  }

  // Payment status display text
  String get paymentStatusDisplayText {
    switch (paymentStatus) {
      case 'pending':
        return 'Payment Pending';
      case 'completed':
        return 'Payment Completed';
      case 'failed':
        return 'Payment Failed';
      case 'refunded':
        return 'Payment Refunded';
      default:
        return 'Unknown';
    }
  }

  // Status color
  String get statusColor {
    switch (orderStatus) {
      case 'pending':
        return 'orange';
      case 'confirmed':
        return 'blue';
      case 'shipped':
        return 'purple';
      case 'delivered':
        return 'green';
      case 'cancelled':
        return 'red';
      case 'refunded':
        return 'grey';
      default:
        return 'grey';
    }
  }
}