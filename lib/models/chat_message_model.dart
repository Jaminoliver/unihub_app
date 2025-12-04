enum MessageType {
  text,
  productCard,
  productCarousel,
  quickActions,
  error,
  loading,
}

enum MessageSender {
  user,
  ai,
}

class ChatMessageModel {
  final String id;
  final String content;
  final MessageSender sender;
  final MessageType type;
  final DateTime timestamp;
  final List<String>? productIds; // For product cards/carousel
  final List<String>? quickActionOptions; // For quick action buttons
  final Map<String, dynamic>? metadata; // Extra data

  ChatMessageModel({
    required this.id,
    required this.content,
    required this.sender,
    required this.type,
    required this.timestamp,
    this.productIds,
    this.quickActionOptions,
    this.metadata,
  });

  factory ChatMessageModel.text({
    required String id,
    required String content,
    required MessageSender sender,
  }) {
    return ChatMessageModel(
      id: id,
      content: content,
      sender: sender,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessageModel.productCarousel({
    required String id,
    required String content,
    required List<String> productIds,
  }) {
    return ChatMessageModel(
      id: id,
      content: content,
      sender: MessageSender.ai,
      type: MessageType.productCarousel,
      timestamp: DateTime.now(),
      productIds: productIds,
    );
  }

  factory ChatMessageModel.quickActions({
    required String id,
    required String content,
    required List<String> options,
  }) {
    return ChatMessageModel(
      id: id,
      content: content,
      sender: MessageSender.ai,
      type: MessageType.quickActions,
      timestamp: DateTime.now(),
      quickActionOptions: options,
    );
  }

  factory ChatMessageModel.loading() {
    return ChatMessageModel(
      id: 'loading',
      content: '',
      sender: MessageSender.ai,
      type: MessageType.loading,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessageModel.error(String errorMessage) {
    return ChatMessageModel(
      id: 'error_${DateTime.now().millisecondsSinceEpoch}',
      content: errorMessage,
      sender: MessageSender.ai,
      type: MessageType.error,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'sender': sender.name,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'product_ids': productIds,
      'quick_action_options': quickActionOptions,
      'metadata': metadata,
    };
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      content: json['content'] as String,
      sender: MessageSender.values.firstWhere(
        (e) => e.name == json['sender'],
        orElse: () => MessageSender.ai,
      ),
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      productIds: json['product_ids'] != null
          ? List<String>.from(json['product_ids'])
          : null,
      quickActionOptions: json['quick_action_options'] != null
          ? List<String>.from(json['quick_action_options'])
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  ChatMessageModel copyWith({
    String? id,
    String? content,
    MessageSender? sender,
    MessageType? type,
    DateTime? timestamp,
    List<String>? productIds,
    List<String>? quickActionOptions,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      productIds: productIds ?? this.productIds,
      quickActionOptions: quickActionOptions ?? this.quickActionOptions,
      metadata: metadata ?? this.metadata,
    );
  }
}