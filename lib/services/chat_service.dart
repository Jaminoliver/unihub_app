import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  final String id;
  final String content;
  final String sender; // 'user' or 'ai'
  final DateTime timestamp;
  final List<ProductRecommendation>? products;
  final bool showProductCard;

  ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.products,
    this.showProductCard = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final productList = json['products'] as List?;
    return ChatMessage(
      id: json['id']?.toString() ?? DateTime.now().toString(), // Safety check
      content: json['message']?.toString() ?? '', // Safety check
      sender: json['sender']?.toString() ?? 'unknown',
      timestamp: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString()) 
          : DateTime.now(),
      products: productList?.map((p) => ProductRecommendation.fromJson(p)).toList(),
      showProductCard: json['should_show_card'] as bool? ?? false,
    );
  }
}

class ProductRecommendation {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String reason;

  ProductRecommendation({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.reason,
  });

  factory ProductRecommendation.fromJson(Map<String, dynamic> json) {
    return ProductRecommendation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Product',
      // Handle cases where price might be int, double, or string
      price: (json['price'] is num) 
          ? (json['price'] as num).toDouble() 
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      // 🛡️ FIX: Handle null image_url gracefully
      imageUrl: json['image_url']?.toString() ?? '', 
      // 🛡️ FIX: Handle null reason gracefully
      reason: json['reason']?.toString() ?? 'Recommended for you', 
    );
  }
}

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Send a message and get AI response with product recommendations
  Future<ChatMessage> sendMessage({
    required String message,
    required String conversationId,
    String? state,
    Map<String, dynamic>? userContext,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      print('🔵 Sending message to AI...');
      print('📝 Message: $message');

      // Get recent conversation history
      final history = await getConversationHistory(conversationId, limit: 6);

      // Call Edge Function
      print('🚀 Calling vibes-chat function...');
      final response = await _supabase.functions.invoke(
        'vibes-chat',
        body: {
          'messages': [
            ...history.map((msg) => {
                  'role': msg.sender,
                  'content': msg.content,
                }),
            {'role': 'user', 'content': message}
          ],
          'user_id': userId,
          'conversation_id': conversationId,
          'state': state,
          'context': {
            'recent_activity': userContext?['recent_activity'],
            'location': userContext?['location'],
            'preferences': userContext?['preferences'],
          },
        },
      );

      final data = response.data as Map<String, dynamic>;

      // Save user message to DB
      await _saveMessage(
        conversationId: conversationId,
        userId: userId,
        content: message,
        sender: 'user',
      );

      // 🛡️ FIX: Handle missing 'response' key safely
      // Sometimes AI returns 'message' instead of 'response', or nothing at all
      final responseContent = data['response']?.toString() ?? 
                            data['message']?.toString() ?? 
                            "I'm having a bit of trouble connecting. Try again?";

      final aiMessageId = await _saveMessage(
        conversationId: conversationId,
        userId: userId,
        content: responseContent,
        sender: 'ai',
        products: data['products'] as List?,
        showCard: data['should_show_card'] as bool? ?? false,
      );

      print('✅ Message saved successfully');

      return ChatMessage(
        id: aiMessageId,
        content: responseContent,
        sender: 'ai',
        timestamp: DateTime.now(),
        products: (data['products'] as List?)
            ?.map((p) => ProductRecommendation.fromJson(p))
            .toList(),
        showProductCard: data['should_show_card'] as bool? ?? false,
      );
    } catch (e, stackTrace) {
      print('❌ Chat error: $e');
      print('📍 Stack trace: $stackTrace');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Get conversation history
  Future<List<ChatMessage>> getConversationHistory(
    String conversationId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(limit);

      return (response as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching history: $e');
      return [];
    }
  }

  /// Get or create conversation for current user
  Future<String> getOrCreateConversation() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check for existing active conversation
      final existing = await _supabase
          .from('conversations')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      }

      return await startNewConversation();
    } catch (e) {
      print('❌ Failed to get conversation: $e');
      // Fallback: Just return a new local ID if DB fails to avoid blocking user
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// 🆕 Force create a NEW conversation ID (Wipes memory)
  Future<String> startNewConversation() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    print('🔄 Starting fresh conversation...');

    // Optional: Mark all old conversations as inactive
    try {
      await _supabase
          .from('conversations')
          .update({'is_active': false}).eq('user_id', userId);

      // Create new active conversation
      final newConv = await _supabase
          .from('conversations')
          .insert({
            'user_id': userId,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();
      
      return newConv['id'] as String;
    } catch (e) {
      print('⚠️ Error creating convo in DB, using local ID: $e');
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Save message to database
  Future<String> _saveMessage({
    required String conversationId,
    required String userId,
    required String content,
    required String sender,
    List<dynamic>? products,
    bool showCard = false,
  }) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'user_id': userId,
            'message': content,
            'sender': sender,
            'products': products,
            'should_show_card': showCard,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      print('⚠️ Failed to save message to history: $e');
      return 'temp-${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  /// 🆕 Send Feedback (Thumbs Up/Down)
  Future<void> sendFeedback({
    required String conversationId,
    required String messageContent,
    required bool isPositive,
  }) async {
    try {
      await _supabase
          .from('ai_logs')
          .update({
            'user_feedback': isPositive ? 'thumbs_up' : 'thumbs_down'
          })
          .eq('conversation_id', conversationId)
          .eq('ai_response_text', messageContent); 

      print('✅ Feedback recorded');
    } catch (e) {
      print('❌ Failed to record feedback: $e');
    }
  }
}