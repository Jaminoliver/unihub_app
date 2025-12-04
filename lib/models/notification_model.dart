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
  paymentReleased, 
  disputeResolved,
  escrowReleased,
  
  // ✅ Dispute notification types
  disputeRaised,
  disputeCreated,
  disputeRaisedAgainst,
  newDispute,
  disputeStatusChanged,
  
  // ✅ Admin notification types
  adminNotification,
  adminDeal,
  adminAnnouncement,
  adminAlert;

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
  final String? orderNumber;
  final String? orderId;
  final double? amount;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  
  // ✅ NEW: Admin notification fields
  final String? imageUrl;
  final String? deepLink;
  final List<Map<String, dynamic>>? actionButtons;
  final String? campaignId;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.orderNumber,
    this.orderId,
    this.amount,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
    this.imageUrl,
    this.deepLink,
    this.actionButtons,
    this.campaignId,
  });

  NotificationModel copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    String? orderNumber,
    String? orderId,
    double? amount,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? metadata,
    String? imageUrl,
    String? deepLink,
    List<Map<String, dynamic>>? actionButtons,
    String? campaignId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      orderNumber: orderNumber ?? this.orderNumber,
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
      imageUrl: imageUrl ?? this.imageUrl,
      deepLink: deepLink ?? this.deepLink,
      actionButtons: actionButtons ?? this.actionButtons,
      campaignId: campaignId ?? this.campaignId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toSnakeCase(),
      'title': title,
      'message': message,
      'order_number': orderNumber,
      'order_id': orderId,
      'amount': amount,
      'created_at': timestamp.toIso8601String(),
      'is_read': isRead,
      'metadata': metadata,
      'image_url': imageUrl,
      'deep_link': deepLink,
      'action_buttons': actionButtons,
      'campaign_id': campaignId,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      type: NotificationType.fromSnakeCase(json['type']),
      title: json['title'],
      message: json['message'],
      orderNumber: json['order_number'],
      orderId: json['order_id'],
      amount: json['amount']?.toDouble(),
      timestamp: DateTime.parse(json['created_at']).toLocal(),
      isRead: json['is_read'] ?? false,
      metadata: json['metadata'],
      imageUrl: json['image_url'],
      deepLink: json['deep_link'],
      actionButtons: json['action_buttons'] != null 
          ? List<Map<String, dynamic>>.from(json['action_buttons'])
          : null,
      campaignId: json['campaign_id'],
    );
  }
  
  // ✅ Helper: Check if this is an admin notification
  bool get isAdminNotification {
    return type == NotificationType.adminNotification ||
           type == NotificationType.adminDeal ||
           type == NotificationType.adminAnnouncement ||
           type == NotificationType.adminAlert;
  }
}