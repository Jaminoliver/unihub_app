class DisputeMessageModel {
  final String id;
  final String disputeId;
  final String senderId;
  final String senderType; // 'buyer', 'seller', 'admin'
  final String message;
  final List<String>? attachments;
  final DateTime createdAt;

  DisputeMessageModel({
    required this.id,
    required this.disputeId,
    required this.senderId,
    required this.senderType,
    required this.message,
    this.attachments,
    required this.createdAt,
  });

  factory DisputeMessageModel.fromJson(Map<String, dynamic> json) {
    return DisputeMessageModel(
      id: json['id'] as String,
      disputeId: json['dispute_id'] as String,
      senderId: json['sender_id'] as String,
      senderType: json['sender_type'] as String,
      message: json['message'] as String,
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'] as List)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dispute_id': disputeId,
      'sender_id': senderId,
      'sender_type': senderType,
      'message': message,
      'attachments': attachments,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isBuyer => senderType == 'buyer';
  bool get isAdmin => senderType == 'admin';
  bool get isSeller => senderType == 'seller';

  String get timeAgo {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}