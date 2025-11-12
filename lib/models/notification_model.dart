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
  newPromo;

  String toSnakeCase() {
    return name.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
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
  final String? orderNumber;
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
      amount: json['amount']?.toDouble(),
      timestamp: DateTime.parse(json['created_at'] ?? json['timestamp']),
      isRead: json['is_read'] ?? false,
      metadata: json['metadata'],
    );
  }
}