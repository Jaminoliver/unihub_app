/// Model for tracking chat interactions for AI learning
class ChatInteractionModel {
  final String id;
  final String userId;
  final String userMessage;
  final String aiResponse;
  final List<String>? productIdsShown;
  final List<String>? productIdsClicked;
  final List<String>? productIdsAddedToCart;
  final bool? wasHelpful; // thumbs up/down
  final String? feedbackText;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  ChatInteractionModel({
    required this.id,
    required this.userId,
    required this.userMessage,
    required this.aiResponse,
    this.productIdsShown,
    this.productIdsClicked,
    this.productIdsAddedToCart,
    this.wasHelpful,
    this.feedbackText,
    required this.createdAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_message': userMessage,
      'ai_response': aiResponse,
      'product_ids_shown': productIdsShown,
      'product_ids_clicked': productIdsClicked,
      'product_ids_added_to_cart': productIdsAddedToCart,
      'was_helpful': wasHelpful,
      'feedback_text': feedbackText,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ChatInteractionModel.fromJson(Map<String, dynamic> json) {
    return ChatInteractionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userMessage: json['user_message'] as String,
      aiResponse: json['ai_response'] as String,
      productIdsShown: json['product_ids_shown'] != null
          ? List<String>.from(json['product_ids_shown'])
          : null,
      productIdsClicked: json['product_ids_clicked'] != null
          ? List<String>.from(json['product_ids_clicked'])
          : null,
      productIdsAddedToCart: json['product_ids_added_to_cart'] != null
          ? List<String>.from(json['product_ids_added_to_cart'])
          : null,
      wasHelpful: json['was_helpful'] as bool?,
      feedbackText: json['feedback_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  ChatInteractionModel copyWith({
    String? id,
    String? userId,
    String? userMessage,
    String? aiResponse,
    List<String>? productIdsShown,
    List<String>? productIdsClicked,
    List<String>? productIdsAddedToCart,
    bool? wasHelpful,
    String? feedbackText,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return ChatInteractionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userMessage: userMessage ?? this.userMessage,
      aiResponse: aiResponse ?? this.aiResponse,
      productIdsShown: productIdsShown ?? this.productIdsShown,
      productIdsClicked: productIdsClicked ?? this.productIdsClicked,
      productIdsAddedToCart: productIdsAddedToCart ?? this.productIdsAddedToCart,
      wasHelpful: wasHelpful ?? this.wasHelpful,
      feedbackText: feedbackText ?? this.feedbackText,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}