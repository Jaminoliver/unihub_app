/// Dispute Model - Matches 'disputes' table in Supabase
class DisputeModel {
  final String id;
  final String orderId;
  final String raisedByUserId;
  final String raisedByType; // 'buyer' or 'seller'
  final String disputeReason;
  final String description;
  final List<String>? evidenceUrls;
  final String status; // 'open', 'under_review', 'resolved', 'closed'
  final String priority; // 'low', 'medium', 'high'
  final String? adminNotes;
  final String? resolution;
  final String? adminAction;
  final String? resolvedByAdminId;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined data
  final String? orderNumber;
  final String? productName;
  final String? productImageUrl;
  final double? orderAmount;

  DisputeModel({
    required this.id,
    required this.orderId,
    required this.raisedByUserId,
    required this.raisedByType,
    required this.disputeReason,
    required this.description,
    this.evidenceUrls,
    this.status = 'open',
    this.priority = 'medium',
    this.adminNotes,
    this.resolution,
    this.adminAction,
    this.resolvedByAdminId,
    this.resolvedAt,
    required this.createdAt,
    this.updatedAt,
    this.orderNumber,
    this.productName,
    this.productImageUrl,
    this.orderAmount,
  });

  factory DisputeModel.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;
    final product = order?['product'] as Map<String, dynamic>?;

    return DisputeModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      raisedByUserId: json['raised_by_user_id'] as String,
      raisedByType: json['raised_by_type'] as String,
      disputeReason: json['dispute_reason'] as String,
      description: json['description'] as String,
      evidenceUrls: json['evidence_urls'] != null
          ? List<String>.from(json['evidence_urls'] as List)
          : null,
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'medium',
      adminNotes: json['admin_notes'] as String?,
      resolution: json['resolution'] as String?,
      adminAction: json['admin_action'] as String?,
      resolvedByAdminId: json['resolved_by_admin_id'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      orderNumber: order?['order_number'] as String?,
      productName: product?['name'] as String?,
      productImageUrl: product?['image_urls'] != null &&
              (product!['image_urls'] as List).isNotEmpty
          ? (product['image_urls'] as List).first as String?
          : null,
      orderAmount: order?['total_amount'] != null
          ? (order!['total_amount'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'raised_by_user_id': raisedByUserId,
      'raised_by_type': raisedByType,
      'dispute_reason': disputeReason,
      'description': description,
      'evidence_urls': evidenceUrls,
      'status': status,
      'priority': priority,
      'admin_notes': adminNotes,
      'resolution': resolution,
      'admin_action': adminAction,
      'resolved_by_admin_id': resolvedByAdminId,
      'resolved_at': resolvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Status helpers
  bool get isOpen => status == 'open';
  bool get isUnderReview => status == 'under_review';
  bool get isResolved => status == 'resolved';
  bool get isClosed => status == 'closed';

  // Priority helpers
  bool get isLowPriority => priority == 'low';
  bool get isMediumPriority => priority == 'medium';
  bool get isHighPriority => priority == 'high';

  // Display text
  String get statusDisplayText {
    switch (status) {
      case 'open':
        return 'Open';
      case 'under_review':
        return 'Under Review';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return 'Unknown';
    }
  }

  String get reasonDisplayText {
    switch (disputeReason) {
      case 'product_not_received':
        return 'Product Not Received';
      case 'wrong_item_received':
        return 'Wrong Item Received';
      case 'damaged_item':
        return 'Damaged Item';
      case 'fake_counterfeit':
        return 'Fake/Counterfeit Product';
      case 'seller_not_shipping':
        return 'Seller Not Shipping';
      case 'buyer_not_confirming':
        return 'Buyer Not Confirming Delivery';
      case 'payment_issue':
        return 'Payment Issue';
      case 'refund_not_received':
        return 'Refund Not Received';
      case 'other':
        return 'Other Issue';
      default:
        return disputeReason;
    }
  }

  String get formattedAmount {
    if (orderAmount == null) return '₦0';
    return '₦${orderAmount!.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  String get timeAgo {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}