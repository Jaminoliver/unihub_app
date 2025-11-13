enum NotificationType {
  orderPlaced,
  paymentEscrow,
  orderConfirmed,
  orderShipped,
  orderOutForDelivery,
  orderDelivered,
  orderCancelled,
  refundInitiated,
  refundCompleted,
  itemAddedToCart,
  priceDropAlert,
  backInStock,
  sellerResponse,
  reviewReminder,
  wishlistSale,
  paymentFailed,
  deliveryDelayed,
  orderReturned,
  walletCredited,
  newPromo,
  escrowReleased;

  String toSnakeCase() {
    return name
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }

  static NotificationType fromSnakeCase(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.toSnakeCase() == value,
      orElse: () => NotificationType.orderPlaced,
    );
  }
}

class NotificationModel {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String? orderNumber;      // Display number like "ORD-12345"
  final String? orderId;          // ADD THIS: Actual database order ID
  final double? amount;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.orderNumber,
    this.orderId,                 // ADD THIS
    this.amount,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  NotificationModel copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    String? orderNumber,
    String? orderId,              // ADD THIS
    double? amount,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      orderNumber: orderNumber ?? this.orderNumber,
      orderId: orderId ?? this.orderId,  // ADD THIS
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toSnakeCase(),
      'title': title,
      'message': message,
      'order_number': orderNumber,
      'order_id': orderId,          // ADD THIS
      'amount': amount,
      'created_at': timestamp.toIso8601String(),
      'is_read': isRead,
      'metadata': metadata,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      type: NotificationType.fromSnakeCase(json['type']),
      title: json['title'],
      message: json['message'],
      orderNumber: json['order_number'],
      orderId: json['order_id'],    // ADD THIS
      amount: json['amount']?.toDouble(),
      timestamp: DateTime.parse(json['created_at']).toLocal(),
      isRead: json['is_read'] ?? false,
      metadata: json['metadata'],
    );
  }
}