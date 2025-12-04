import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/chat_message_model.dart';
import '../models/product_model.dart';
import '../services/chat_service.dart';
import '../services/product_service.dart';
import '../services/cart_service.dart';
import '../main.dart';
import 'product_details_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> with SingleTickerProviderStateMixin {
  final _chatService = ChatService();
  final _productService = ProductService();
  final _cartService = CartService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  String? _userUniversity;
  String? _userState;
  late AnimationController _typingAnimationController;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadUserContext();
    _initializeChat();
  }

  Future<void> _loadUserContext() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final userData = await supabase
          .from('users')
          .select('university_id, state')
          .eq('id', userId)
          .single();

      final universityData = await supabase
          .from('universities')
          .select('name')
          .eq('id', userData['university_id'])
          .single();

      setState(() {
        _userUniversity = universityData['name'];
        _userState = userData['state'];
      });
    } catch (e) {
      print('Error loading user context: $e');
    }
  }

  void _initializeChat() {
    final welcomeMsg = ChatMessageModel.text(
      id: 'welcome',
      content: 'Hey! 👋 I\'m your UniHub shopping assistant. What can I help you find today?',
      sender: MessageSender.ai,
    );
    setState(() {
      _messages = [welcomeMsg];
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _messageController.clear();
    
    // Add user message
    final userMsg = ChatMessageModel.text(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      sender: MessageSender.user,
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
      _messages.add(ChatMessageModel.loading());
    });

    _scrollToBottom();

    try {
      // Send to AI (Edge Function handles product search)
      final aiResponse = await _chatService.sendMessage(
        userMessage: text,
        userId: userId,
        userUniversity: _userUniversity ?? 'Unknown',
        userState: _userState ?? 'Lagos',
      );

      setState(() {
        _messages.removeLast(); // Remove loading
        _messages.add(aiResponse);
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessageModel.error('Oops! Something went wrong 😅\nPlease try again.'));
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: Color(0xFFFF6B35), size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UniHub AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                Text('Shopping Assistant', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message) {
    final isUser = message.sender == MessageSender.user;
    
    if (message.type == MessageType.loading) {
      return _buildLoadingIndicator();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAiAvatar(),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFFFF6B35) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                if (message.type == MessageType.productCarousel && message.productIds != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildProductCarousel(message.productIds!),
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildAiAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.smart_toy, color: Color(0xFFFF6B35), size: 18),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.grey, size: 18),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _buildAiAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _typingAnimationController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final delay = index * 0.2;
                    final value = (_typingAnimationController.value + delay) % 1.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            Colors.grey[300],
                            const Color(0xFFFF6B35),
                            value,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCarousel(List<String> productIds) {
    return FutureBuilder<List<ProductModel>>(
      future: _fetchProducts(productIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final products = snapshot.data!;
        if (products.isEmpty) return const SizedBox();

        return SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(products[index]);
            },
          ),
        );
      },
    );
  }

  Future<List<ProductModel>> _fetchProducts(List<String> productIds) async {
    try {
      final response = await supabase
          .from('products')
          .select('''
            *,
            universities!inner(name, abbr)
          ''')
          .inFilter('id', productIds)
          .limit(5);

      return (response as List).map((json) {
        json['university_name'] = json['universities']['name'];
        json['university_abbr'] = json['universities']['abbr'];
        return ProductModel.fromJson(json);
      }).toList();
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  Widget _buildProductCard(ProductModel product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(productId: product.id),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: product.mainImageUrl ?? '',
                height: 120,
                width: 140,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.formattedPrice,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 10, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          product.universityAbbr ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                      if (product.averageRating != null) ...[
                        const Icon(Icons.star, size: 10, color: Colors.amber),
                        Text(
                          product.averageRating!.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Ask me anything...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: _isLoading
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text('This will start a fresh conversation. Your cart items won\'t be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _chatService.clearConversation();
              _initializeChat();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }
}