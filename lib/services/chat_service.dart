import 'package:uuid/uuid.dart';
import '../models/chat_message_model.dart';
import '../models/chat_interaction_model.dart';
import '../models/product_model.dart';
import '../main.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final List<ChatMessageModel> _conversationHistory = [];
  String? _currentSessionId;

  final _uuid = const Uuid();

  // Initialize (no longer needed for edge function, but keep for compatibility)
  void initialize() {
    _conversationHistory.clear();
    _currentSessionId = null;
  }

  // Get conversation history
  List<ChatMessageModel> get conversationHistory => List.unmodifiable(_conversationHistory);

  // Send message via Supabase Edge Function
  Future<ChatMessageModel> sendMessage({
    required String userMessage,
    required String userId,
    required String userUniversity,
    required String userState,
    List<ProductModel>? contextProducts, // Not needed anymore
  }) async {
    try {
      // Add user message to history
      final userMsg = ChatMessageModel.text(
        id: _uuid.v4(),
        content: userMessage,
        sender: MessageSender.user,
      );
      _conversationHistory.add(userMsg);

      // Call Supabase Edge Function
      final response = await supabase.functions.invoke(
        'ai-chat',
        body: {
          'query': userMessage,
          'userId': userId,
          'userUniversity': userUniversity,
          'userState': userState,
        },
      );

      if (response.data == null) {
        throw Exception('No response from AI service');
      }

      final data = response.data as Map<String, dynamic>;
      final aiMessage = data['message'] as String;
      final productIds = data['productIds'] as List<dynamic>?;

      // Debug logging
      print('🤖 AI Response: $aiMessage');
      print('📦 Product IDs: $productIds');

      // Create AI message
      ChatMessageModel aiMsg;
      if (productIds != null && productIds.isNotEmpty) {
        aiMsg = ChatMessageModel.productCarousel(
          id: _uuid.v4(),
          content: aiMessage,
          productIds: productIds.map((id) => id.toString()).toList(),
        );
      } else {
        aiMsg = ChatMessageModel.text(
          id: _uuid.v4(),
          content: aiMessage,
          sender: MessageSender.ai,
        );
      }

      _conversationHistory.add(aiMsg);

      // Save session if needed
      if (_currentSessionId == null) {
        await _createSession(userId);
      } else {
        await _updateSession();
      }

      return aiMsg;
    } catch (e) {
      print('Chat error: $e');
      final errorMsg = ChatMessageModel.error(
        'Oops! Something went wrong 😅\nPlease try again.',
      );
      _conversationHistory.add(errorMsg);
      return errorMsg;
    }
  }

  Future<void> _createSession(String userId) async {
    try {
      _currentSessionId = _uuid.v4();
      await supabase.from('chat_sessions').insert({
        'id': _currentSessionId,
        'user_id': userId,
        'messages': _conversationHistory.map((m) => m.toJson()).toList(),
      });
    } catch (e) {
      print('Error creating session: $e');
    }
  }

  Future<void> _updateSession() async {
    if (_currentSessionId == null) return;
    try {
      await supabase.from('chat_sessions').update({
        'messages': _conversationHistory.map((m) => m.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentSessionId!);
    } catch (e) {
      print('Error updating session: $e');
    }
  }

  // Track product click
  Future<void> trackProductClick(String interactionId, String productId) async {
    try {
      final interaction = await supabase
          .from('chat_interactions')
          .select()
          .eq('id', interactionId)
          .single();

      final clickedIds = List<String>.from(interaction['product_ids_clicked'] ?? []);
      if (!clickedIds.contains(productId)) {
        clickedIds.add(productId);
        await supabase
            .from('chat_interactions')
            .update({'product_ids_clicked': clickedIds})
            .eq('id', interactionId);
      }
    } catch (e) {
      print('Error tracking click: $e');
    }
  }

  // Track add to cart
  Future<void> trackAddToCart(String interactionId, String productId) async {
    try {
      final interaction = await supabase
          .from('chat_interactions')
          .select()
          .eq('id', interactionId)
          .single();

      final cartIds = List<String>.from(interaction['product_ids_added_to_cart'] ?? []);
      if (!cartIds.contains(productId)) {
        cartIds.add(productId);
        await supabase
            .from('chat_interactions')
            .update({'product_ids_added_to_cart': cartIds})
            .eq('id', interactionId);
      }
    } catch (e) {
      print('Error tracking cart add: $e');
    }
  }

  // Submit feedback
  Future<void> submitFeedback(String interactionId, bool wasHelpful, String? feedbackText) async {
    try {
      await supabase.from('chat_interactions').update({
        'was_helpful': wasHelpful,
        'feedback_text': feedbackText,
      }).eq('id', interactionId);
    } catch (e) {
      print('Error submitting feedback: $e');
    }
  }

  // Clear conversation
  void clearConversation() {
    _conversationHistory.clear();
    _currentSessionId = null;
  }
}