import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message_model.dart';
import '../models/order_model.dart';
import '../services/dispute_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/chat_bubble_widget.dart';
import '../widgets/dispute_chatbot_widgets.dart';

class DisputeChatbotScreen extends StatefulWidget {
  final String? existingDisputeId;
  const DisputeChatbotScreen({Key? key, this.existingDisputeId}) : super(key: key);

  @override
  State<DisputeChatbotScreen> createState() => _DisputeChatbotScreenState();
}

class _DisputeChatbotScreenState extends State<DisputeChatbotScreen> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _disputeService = DisputeService();
  final _imagePicker = ImagePicker();
  
  List<ChatMessageModel> messages = [];
  bool isTyping = false, isSubmitted = false, isClosed = false, isSendingMessage = false, isUploadingImage = false;
  
  int currentStep = 0;
  String? selectedOrderId, selectedOrderNumber, selectedProductName, selectedProductImage, selectedReason, description, disputeId, disputeNumber, currentUserId;
  List<File> selectedImages = [], pendingChatImages = [];
  List<String> evidenceUrls = [];
  RealtimeChannel? _chatChannel;
  
  bool showAllOrders = false;
  List<OrderModel> allUserOrders = [];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _chatChannel?.unsubscribe();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================
  
  Future<void> _initializeUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    
    setState(() => currentUserId = user.id);
    widget.existingDisputeId != null ? _loadExistingDispute() : await _loadState();
  }

  // ==================== STATE PERSISTENCE ====================
  
  String _getStateKey() => 'dispute_chatbot_state_$currentUserId';
  
  Future<void> _saveState() async {
    if (currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getStateKey(), jsonEncode({
      'userId': currentUserId,
      'messages': messages.map((m) => m.toJson()).toList(),
      'currentStep': currentStep,
      'selectedOrderId': selectedOrderId,
      'selectedOrderNumber': selectedOrderNumber,
      'selectedProductName': selectedProductName,
      'selectedProductImage': selectedProductImage,
      'selectedReason': selectedReason,
      'description': description,
      'evidenceUrls': evidenceUrls,
      'isSubmitted': isSubmitted,
      'disputeId': disputeId,
      'disputeNumber': disputeNumber,
      'isClosed': isClosed,
    }));
  }

  Future<void> _loadState() async {
    if (currentUserId == null) {
      _startConversation();
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final stateJson = prefs.getString(_getStateKey());
    
    if (stateJson != null) {
      try {
        final data = jsonDecode(stateJson);
        
        if (data['userId'] != currentUserId) {
          await _clearState();
          _startConversation();
          return;
        }
        
        setState(() {
          messages = (data['messages'] as List).map((m) => ChatMessageModel.fromJson(m)).toList();
          currentStep = data['currentStep'] ?? 0;
          selectedOrderId = data['selectedOrderId'];
          selectedOrderNumber = data['selectedOrderNumber'];
          selectedProductName = data['selectedProductName'];
          selectedProductImage = data['selectedProductImage'];
          selectedReason = data['selectedReason'];
          description = data['description'];
          evidenceUrls = List<String>.from(data['evidenceUrls'] ?? []);
          isSubmitted = data['isSubmitted'] ?? false;
          disputeId = data['disputeId'];
          disputeNumber = data['disputeNumber'];
          isClosed = data['isClosed'] ?? false;
        });
        
        if (isSubmitted && disputeId != null) {
          _checkDisputeStatus();
          _setupRealtimeChat();
          _loadExistingMessages();
        }
        
        if (!isSubmitted && currentStep > 0) _showResumeBanner();
      } catch (e) {
        await _clearState();
        _startConversation();
      }
    } else {
      _startConversation();
    }
    
    _scrollToBottom();
  }

  Future<void> _clearState() async {
    if (currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getStateKey());
  }

  void _showResumeBanner() {
    Future.delayed(Duration(milliseconds: 300), () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.replay_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Continuing your previous dispute...')),
            ],
          ),
          backgroundColor: Color(0xFF3B82F6),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Start New',
            textColor: Colors.white,
            onPressed: () => showStartNewDisputeDialog(context, _startNewDispute),
          ),
        ),
      );
    });
  }

  Future<void> _loadExistingDispute() async {
  try {
    final dispute = await _disputeService.getDisputeById(widget.existingDisputeId!);
    if (dispute != null) {
      setState(() {
        disputeId = dispute.id;
        disputeNumber = dispute.disputeNumber;
        selectedOrderId = dispute.orderId;
        selectedOrderNumber = dispute.orderNumber;
        selectedProductName = dispute.productName;
        selectedProductImage = dispute.productImageUrl;
        selectedReason = dispute.disputeReason;
        description = dispute.description;
        isSubmitted = true;
        currentStep = 6;
        isClosed = dispute.isResolved;
      });
      
      _addBotMessage('Welcome back! You\'re viewing dispute #${dispute.disputeNumber}', delay: 0);
      
      // Build the dispute details message
      String disputeDetails = '📋 **Dispute Details:**\n\n';
      
      if (dispute.orderNumber != null && dispute.productName != null) {
        disputeDetails += '🛍️ **Order:** #${dispute.orderNumber} - ${dispute.productName}\n\n';
      }
      
      if (dispute.disputeReason != null) {
        final reasons = _disputeService.getDisputeReasons();
        final reasonKey = int.tryParse(dispute.disputeReason.toString());
        final reasonLabel = reasonKey != null ? reasons[reasonKey]?.toString() : null;
        disputeDetails += '⚠️ **Reason:** ${reasonLabel ?? 'Issue reported'}\n\n';
      }
      
      if (dispute.description != null && dispute.description!.isNotEmpty) {
        disputeDetails += '📝 **Description:** ${dispute.description}\n\n';
      }
      
      if (dispute.evidenceUrls != null && dispute.evidenceUrls!.isNotEmpty) {
        disputeDetails += '📎 **Evidence:** ${dispute.evidenceUrls!.length} image(s) attached\n\n';
      }
      
      disputeDetails += '━━━━━━━━━━━━━━━━━━━━';
      
      _addBotMessage(disputeDetails, delay: 0);
      
      _saveState();
      _scrollToBottom();
      
      // Now load the conversation (admin replies)
      Future.delayed(Duration(milliseconds: 300), () {
        if (!mounted) return;
        
        if (dispute.isResolved) {
          _addBotMessage('✅ This dispute has been resolved.\n\n${dispute.resolution ?? "Case closed."}', delay: 0);
        } else {
          // Load any existing admin messages
          _loadExistingMessages().then((_) {
            // If no admin messages yet, show a pending message
            if (!messages.any((m) => m.sender == MessageSender.admin)) {
              _addBotMessage(
                '⏳ Your dispute is under review. An admin will respond shortly.',
                delay: 0,
              );
            }
          });
          _setupRealtimeChat();
        }
      });
    }
  } catch (e) {
    _startConversation();
  }
}

  Future<void> _loadExistingMessages() async {
    if (disputeId == null) return;
    
    try {
      final chatMessages = await _disputeService.getDisputeMessages(disputeId!);
      
      for (final msg in chatMessages) {
        if (msg.senderType == 'buyer') {
          _addUserMessage(msg.message, saveState: false);
          if (msg.attachments != null && msg.attachments!.isNotEmpty) {
            for (final url in msg.attachments!) {
              _addUserMessage('📎 Image attached', saveState: false);
            }
          }
        } else if (msg.senderType == 'admin') {
          _addAdminMessage(msg.message, attachments: msg.attachments, saveState: false);
        }
      }
      
      _saveState();
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  // ==================== CONVERSATION FLOW ====================

  void _startConversation() {
    _addBotMessage(
      'Hi there! 👋\n\nI\'m your dispute assistant. Let\'s resolve any issues with your order.\n\nLet\'s get started!',
      delay: 500,
    );
    
    Future.delayed(Duration(milliseconds: 1800), _showOrderSelection);
  }

  void _showOrderSelection() async {
    setState(() {
      isTyping = true;
      currentStep = 1;
    });
    
    await Future.delayed(Duration(milliseconds: 1000));
    
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      
      final response = await Supabase.instance.client
          .from('orders')
          .select('''
            *,
            products!orders_product_id_fkey(name, image_urls)
          ''')
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false)
          .limit(6);
      
      final orders = (response as List).map((json) => OrderModel.fromJson(json)).toList();
      
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      final allOrdersResponse = await Supabase.instance.client
          .from('orders')
          .select('''
            *,
            products!orders_product_id_fkey(name, image_urls)
          ''')
          .eq('buyer_id', user.id)
          .gte('created_at', thirtyDaysAgo.toIso8601String())
          .order('created_at', ascending: false);
      
      setState(() {
        allUserOrders = (allOrdersResponse as List).map((json) => OrderModel.fromJson(json)).toList();
        isTyping = false;
      });
      
      final msg = ChatMessageModel.orderSelection(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        content: orders.isEmpty 
          ? 'No recent orders found. Please enter your order number:'
          : 'Select the order you want to raise a dispute for:',
        orders: orders,
      );
      
      setState(() => messages.add(msg));
      _saveState();
      _scrollToBottom();
    } catch (e) {
      setState(() => isTyping = false);
      _addBotMessage('Sorry, couldn\'t load your orders. Please try again or enter your order number.');
    }
  }

  void _expandOrders() {
    if (allUserOrders.length > 6) {
      final msg = ChatMessageModel.orderSelection(
        id: 'msg_expanded_${DateTime.now().millisecondsSinceEpoch}',
        content: 'Showing all orders from the last 30 days:',
        orders: allUserOrders,
      );
      
      setState(() {
        messages.add(msg);
        showAllOrders = true;
      });
      _saveState();
      _scrollToBottom();
    }
  }

  void _onOrderSelected(OrderModel order) {
    setState(() {
      selectedOrderId = order.id;
      selectedOrderNumber = order.orderNumber;
      selectedProductName = order.productName;
      selectedProductImage = order.productImageUrl;
    });
    
    _addUserMessage('Order #${order.orderNumber} - ${order.productName ?? "Product"}');
    _saveState();
    
    Future.delayed(Duration(milliseconds: 600), _showReasonSelection);
  }

  void _onManualOrderEntry() {
    showManualOrderEntryDialog(context, _verifyAndProcessOrder);
  }

  Future<void> _verifyAndProcessOrder(String orderNum) async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      
      final response = await Supabase.instance.client
          .from('orders')
          .select('''
            *,
            products!orders_product_id_fkey(name, image_urls)
          ''')
          .eq('buyer_id', user.id)
          .eq('order_number', orderNum)
          .maybeSingle();
      
      if (response != null) {
        final order = OrderModel.fromJson(response);
        setState(() {
          selectedOrderId = order.id;
          selectedOrderNumber = order.orderNumber;
          selectedProductName = order.productName;
          selectedProductImage = order.productImageUrl;
        });
        _addUserMessage('Order #${order.orderNumber} - ${order.productName ?? "Product"}');
        _saveState();
        Future.delayed(Duration(milliseconds: 600), _showReasonSelection);
      } else {
        final anyOrderCheck = await Supabase.instance.client
            .from('orders')
            .select('id')
            .eq('order_number', orderNum)
            .maybeSingle();
        
        if (anyOrderCheck != null) {
          showOrderNotFoundDialog(
            context,
            orderNum,
            'This order belongs to a different account.\n\nPlease verify you\'re logged in with the correct account.',
            isWrongAccount: true,
            onTryAgain: _onManualOrderEntry,
            onSuggestionTap: _verifyAndProcessOrder,
          );
        } else {
          final similarOrders = await _findSimilarOrders(orderNum, user.id);
          showOrderNotFoundDialog(
            context,
            orderNum,
            'We couldn\'t find this order in your history.\n\nPlease check the order number and try again.',
            suggestions: similarOrders,
            onTryAgain: _onManualOrderEntry,
            onSuggestionTap: _verifyAndProcessOrder,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying order: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<List<String>> _findSimilarOrders(String orderNum, String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('orders')
          .select('order_number')
          .eq('buyer_id', userId)
          .order('created_at', ascending: false)
          .limit(20);
      
      final orders = (response as List).map((o) => o['order_number'] as String).toList();
      
      final suggestions = orders.where((o) {
        int differences = 0;
        if (o.length != orderNum.length) return false;
        
        for (int i = 0; i < o.length; i++) {
          if (o[i] != orderNum[i]) differences++;
          if (differences > 2) return false;
        }
        return differences > 0 && differences <= 2;
      }).take(3).toList();
      
      return suggestions;
    } catch (e) {
      return [];
    }
  }

  void _showReasonSelection() {
    setState(() {
      isTyping = true;
      currentStep = 2;
    });
    
    Future.delayed(Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() => isTyping = false);
      
      final msg = ChatMessageModel.reasonChips(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        content: 'What issue are you experiencing with this order?',
        reasons: _disputeService.getDisputeReasons(),
      );
      
      setState(() => messages.add(msg));
      _saveState();
      _scrollToBottom();
    });
  }

  void _onReasonSelected(String reason, String label) {
    setState(() => selectedReason = reason);
    _addUserMessage(label);
    _saveState();
    Future.delayed(Duration(milliseconds: 600), _askForDescription);
  }

  void _askForDescription() {
    _addBotMessage(
      'Please describe the issue in detail. The more information you provide, the faster we can help resolve it.',
      delay: 1000,
    );
    setState(() => currentStep = 3);
    _saveState();
  }

  void _onDescriptionSubmitted(String text) {
    setState(() => description = text);
    _addUserMessage(text);
    _saveState();
    Future.delayed(Duration(milliseconds: 600), _askForEvidence);
  }

  void _askForEvidence() {
    _addBotMessage(
      'Would you like to upload any evidence?\n\n📷 Photos or screenshots can help speed up the resolution process.',
      delay: 1000,
    );
    setState(() => currentStep = 4);
    _saveState();
  }

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return;

      setState(() => selectedImages.addAll(pickedFiles.map((xFile) => File(xFile.path))));
      _addUserMessage('📎 ${pickedFiles.length} image(s) attached');
      _saveState();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _continueAfterEvidence() {
    _addUserMessage(selectedImages.isEmpty ? 'Continue without evidence' : 'Continue with ${selectedImages.length} image(s)');
    _saveState();
    Future.delayed(Duration(milliseconds: 600), _showSummary);
  }

  void _showSummary() {
    setState(() {
      isTyping = true;
      currentStep = 5;
    });
    
    Future.delayed(Duration(milliseconds: 1000), () {
      setState(() => isTyping = false);
      _addBotMessage('Great! Let me summarize your dispute:', delay: 0);
      
      Future.delayed(Duration(milliseconds: 500), () {
        final msg = ChatMessageModel.summaryCard(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          disputeData: {
            'orderNumber': selectedOrderNumber,
            'productName': selectedProductName,
            'productImage': selectedProductImage,
            'reason': selectedReason,
            'description': description,
            'evidenceCount': selectedImages.length,
          },
        );
        
        setState(() => messages.add(msg));
        _saveState();
        _scrollToBottom();
      });
    });
  }

  Future<void> _submitDispute() async {
    setState(() => isTyping = true);

    try {
      final user = Supabase.instance.client.auth.currentUser!;

      final dispute = await _disputeService.createDispute(
        orderId: selectedOrderId ?? 'manual_${DateTime.now().millisecondsSinceEpoch}',
        raisedByUserId: user.id,
        raisedByType: 'buyer',
        disputeReason: selectedReason!,
        description: description!,
        evidenceUrls: null,
      );

      if (selectedImages.isNotEmpty) {
        final urls = <String>[];
        for (final file in selectedImages) {
          final url = await _disputeService.uploadDisputeAttachment(dispute.id, file);
          if (url != null) urls.add(url);
        }
        evidenceUrls = urls;
      }

      setState(() {
        isSubmitted = true;
        disputeId = dispute.id;
        disputeNumber = dispute.disputeNumber;
        currentStep = 6;
        isTyping = false;
      });

      _addBotMessage(
        '✅ Success! Your dispute has been submitted.\n\nDispute Number: #${dispute.disputeNumber}\n\nAn admin will review your case shortly and respond here.',
        delay: 500,
      );

      await _saveState();
      await _clearState();
      _setupRealtimeChat();
      
    } catch (e) {
      setState(() => isTyping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit dispute: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ==================== REAL-TIME CHAT ====================

  void _setupRealtimeChat() {
    if (disputeId == null) return;

    _chatChannel = Supabase.instance.client
        .channel('dispute_messages_$disputeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'dispute_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'dispute_id',
            value: disputeId,
          ),
          callback: (payload) {
            final newMessage = payload.newRecord;
            final senderType = newMessage['sender_type'] as String?;
            final message = newMessage['message'] as String?;
            
            if (senderType == 'admin' && message != null) {
              List<String>? attachments;
              if (newMessage['attachments'] is List) {
                attachments = List<String>.from(newMessage['attachments'] as List);
              }
              _addAdminMessage(message, attachments: attachments);
            }
          },
        )
        .subscribe();
  }

  Future<void> _checkDisputeStatus() async {
    if (disputeId == null) return;
    
    try {
      final dispute = await _disputeService.getDisputeById(disputeId!);
      if (dispute != null && dispute.isResolved) {
        setState(() => isClosed = true);
        _addBotMessage('✅ This dispute has been resolved.\n\n${dispute.resolution ?? "Case closed."}', delay: 0);
        _saveState();
      }
    } catch (e) {
      print('Error checking dispute status: $e');
    }
  }

  Future<void> _sendChatMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || isSendingMessage || !isSubmitted) return;

    _addUserMessage(message);
    _messageController.clear();
    
    setState(() => isSendingMessage = true);

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      await _disputeService.sendDisputeMessage(
        disputeId: disputeId!,
        senderId: user.id,
        message: message,
      );
    } catch (e) {
      setState(() => messages.removeWhere((m) => m.content == message && m.isUser));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isSendingMessage = false);
    }
  }

  Future<void> _pickChatImages() async {
    if (isUploadingImage || !isSubmitted || isClosed) return;
    
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return;
      setState(() => pendingChatImages.addAll(pickedFiles.map((xFile) => File(xFile.path))));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendPendingChatImages() async {
    if (pendingChatImages.isEmpty) return;
    
    setState(() => isUploadingImage = true);
    
    try {
      final urls = <String>[];
      for (final file in pendingChatImages) {
        final url = await _disputeService.uploadDisputeAttachment(disputeId!, file);
        if (url != null) urls.add(url);
      }
      
      if (urls.isNotEmpty) {
        final user = Supabase.instance.client.auth.currentUser!;
        await _disputeService.sendDisputeMessage(
          disputeId: disputeId!,
          senderId: user.id,
          message: '📎 ${urls.length} image(s)',
          attachments: urls,
        );
        _addUserMessage('📎 ${urls.length} image(s) sent');
      }
      
      setState(() => pendingChatImages.clear());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isUploadingImage = false);
    }
  }

  void _removePendingImage(int index) {
    setState(() => pendingChatImages.removeAt(index));
  }

  // ==================== MESSAGE HELPERS ====================

  void _addBotMessage(String text, {int delay = 0}) {
    if (delay > 0) setState(() => isTyping = true);
    
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() {
        isTyping = false;
        messages.add(ChatMessageModel.text(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          content: text,
          sender: MessageSender.ai,
        ));
      });
      _saveState();
      _scrollToBottom();
    });
  }

  void _addUserMessage(String text, {bool saveState = true}) {
    setState(() {
      messages.add(ChatMessageModel.text(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        content: text,
        sender: MessageSender.user,
      ));
    });
    if (saveState) _saveState();
    _scrollToBottom();
  }

  void _addAdminMessage(String text, {List<String>? attachments, bool saveState = true}) {
    setState(() {
      messages.add(ChatMessageModel.adminMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        content: text,
        attachments: attachments,
      ));
    });
    if (saveState) _saveState();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startNewDispute() async {
    await _saveState();
    setState(() {
      messages.clear();
      currentStep = 0;
      selectedOrderId = null;
      selectedOrderNumber = null;
      selectedProductName = null;
      selectedProductImage = null;
      selectedReason = null;
      description = null;
      selectedImages.clear();
      evidenceUrls.clear();
      isSubmitted = false;
      disputeId = null;
      disputeNumber = null;
      isClosed = false;
    });
    _startConversation();
  }

  void _handleExitDispute() async {
    try {
      await _saveState();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!isSubmitted && currentStep > 0) {
          showExitDisputeDialog(context, _handleExitDispute);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Color(0xFFF9FAFB),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (disputeNumber != null && selectedOrderNumber != null) 
              DisputeInfoBanner(disputeNumber: disputeNumber!, orderNumber: selectedOrderNumber!),
            if (!isSubmitted && currentStep > 0) 
              DisputeProgressIndicator(currentStep: currentStep),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                itemCount: messages.length + (isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (isTyping && index == messages.length) return TypingIndicator();
                  return ChatBubbleWidget(
                    message: messages[index],
                    onOrderSelected: _onOrderSelected,
                    onManualOrderEntry: _onManualOrderEntry,
                    onReasonSelected: _onReasonSelected,
                    onShowOlderOrders: (!showAllOrders && allUserOrders.length > 6) ? _expandOrders : null,
                    canShowMore: !showAllOrders && allUserOrders.length > 6,
                  );
                },
              ),
            ),
            _buildInputSection(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
        onPressed: () {
          if (!isSubmitted && currentStep > 0) {
            showExitDisputeDialog(context, _handleExitDispute);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
              shape: BoxShape.circle,
            ),
            child: Icon(isSubmitted ? Icons.chat : Icons.support_agent, size: 20, color: Colors.white),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isSubmitted ? 'Dispute Chat' : 'New Dispute', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              if (disputeNumber != null)
                Text('#$disputeNumber', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
      actions: [
        if (isSubmitted)
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Color(0xFF3B82F6)),
            tooltip: 'Start New Dispute',
            onPressed: () => showStartNewDisputeDialog(context, _startNewDispute),
          ),
      ],
    );
  }

  Widget _buildInputSection() {
    if (!isSubmitted) {
      if (currentStep == 3) {
        return DisputeDescriptionInput(
          controller: _messageController,
          onSubmit: () {
            if (_messageController.text.trim().isNotEmpty) {
              _onDescriptionSubmitted(_messageController.text.trim());
              _messageController.clear();
            }
          },
        );
      } else if (currentStep == 4) {
        return DisputeEvidenceInput(
          selectedImages: selectedImages,
          onPickImages: _pickImages,
          onContinue: _continueAfterEvidence,
          onRemoveImage: (index) => setState(() => selectedImages.removeAt(index)),
        );
      } else if (currentStep == 5) {
        return DisputeSubmitButton(onSubmit: _submitDispute);
      }
    } else if (isSubmitted && !isClosed) {
      return DisputeAdminChatInput(
        controller: _messageController,
        pendingImages: pendingChatImages,
        isSendingMessage: isSendingMessage,
        isUploadingImage: isUploadingImage,
        onPickImages: _pickChatImages,
        onSendMessage: _sendChatMessage,
        onSendPendingImages: _sendPendingChatImages,
        onRemovePendingImage: _removePendingImage,
      );
    } else if (isClosed) {
      return DisputeClosedBanner();
    }
    return SizedBox.shrink();
  }
}