import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/dispute_model.dart';
import '../models/dispute_message_model.dart';
import '../services/dispute_service.dart';
import '../constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DisputeChatScreen extends StatefulWidget {
  final DisputeModel dispute;

  const DisputeChatScreen({
    super.key,
    required this.dispute,
  });

  @override
  State<DisputeChatScreen> createState() => _DisputeChatScreenState();
}

class _DisputeChatScreenState extends State<DisputeChatScreen> {
  final DisputeService _disputeService = DisputeService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  List<DisputeMessageModel> _messages = [];
  List<File> _selectedFiles = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingFiles = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _disputeService.getDisputeMessages(widget.dispute.id);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load messages: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _pickFiles() async {
    if (_selectedFiles.length >= 5) {
      _showError('Maximum 5 files allowed');
      return;
    }

    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return;

      final filesToAdd = pickedFiles.take(5 - _selectedFiles.length).toList();
      
      setState(() {
        _selectedFiles.addAll(filesToAdd.map((xFile) => File(xFile.path)));
      });
    } catch (e) {
      _showError('Failed to pick files: $e');
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<List<String>> _uploadFiles() async {
    final List<String> uploadedUrls = [];

    for (final file in _selectedFiles) {
      try {
        final url = await _disputeService.uploadDisputeAttachment(
          widget.dispute.id,
          file,
        );
        
        if (url != null) {
          uploadedUrls.add(url);
        }
      } catch (e) {
        print('Error uploading file: $e');
      }
    }

    return uploadedUrls;
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    
    if (message.isEmpty && _selectedFiles.isEmpty) return;
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _isUploadingFiles = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      List<String> attachmentUrls = [];
      
      if (_selectedFiles.isNotEmpty) {
        attachmentUrls = await _uploadFiles();
      }

      await _disputeService.sendDisputeMessage(
        disputeId: widget.dispute.id,
        senderId: user.id,
        message: message.isNotEmpty ? message : '📎 Attachment',
        attachments: attachmentUrls.isNotEmpty ? attachmentUrls : null,
      );

      _messageController.clear();
      setState(() {
        _selectedFiles.clear();
      });
      
      await _loadMessages();
    } catch (e) {
      _showError('Failed to send message: $e');
    } finally {
      setState(() {
        _isSending = false;
        _isUploadingFiles = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inHours < 24) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day} ${_getMonthName(dateTime.month)}, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getFileName(String url) {
    return url.split('/').last;
  }

  Widget _buildMessageBubble(DisputeMessageModel message) {
    final isYou = message.isBuyer;
    final isAdmin = message.isAdmin;

    return Align(
      alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isYou) ...[
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary.withOpacity(0.8),
                child: const Text('A', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isYou ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isYou ? const Color(0xFF2196F3) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: isYou ? null : Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isYou)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        Text(
                          message.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: isYou ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (message.attachments != null && message.attachments!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...message.attachments!.map((url) {
                            final isPDF = url.toLowerCase().endsWith('.pdf');
                            if (isPDF) {
                              return GestureDetector(
                                onTap: () {
                                  // Open PDF
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isYou ? const Color(0xFF1976D2) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf,
                                        size: 16,
                                        color: isYou ? Colors.white : Colors.grey[700],
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _getFileName(url),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isYou ? Colors.white : Colors.grey[700],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              return GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.network(url),
                                          const SizedBox(height: 16),
                                          IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    height: 150,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 150,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              );
                            }
                          }),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                    child: Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
            if (isYou) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF2196F3),
                child: const Text('Y', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canReply = widget.dispute.status != 'resolved' && widget.dispute.status != 'closed';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Dispute',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              '#${widget.dispute.orderNumber}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Context Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border(bottom: BorderSide(color: Colors.red[200]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.dispute.reasonDisplayText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[900],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.dispute.status.toUpperCase(),
                    style: TextStyle(fontSize: 10, color: Colors.red[900], fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2196F3)))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start chatting with admin',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
          ),

          // Resolution Banner
          if (widget.dispute.isResolved && widget.dispute.resolution != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border(top: BorderSide(color: Colors.green[200]!)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✓ Resolved',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[900]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.dispute.resolution!,
                          style: TextStyle(fontSize: 11, color: Colors.green[800]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Input Area
          if (canReply)
            Container(
              padding: const EdgeInsets.all(12),
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
              child: Column(
                children: [
                  if (_selectedFiles.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedFiles.asMap().entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              border: Border.all(color: Colors.blue[200]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image, size: 14, color: Color(0xFF2196F3)),
                                const SizedBox(width: 6),
                                Text(
                                  entry.value.path.split('/').last,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF2196F3)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _removeFile(entry.key),
                                  child: const Icon(Icons.close, size: 14, color: Color(0xFF2196F3)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: Color(0xFF2196F3)),
                        onPressed: _isSending ? null : _pickFiles,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type message...',
                            hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          maxLines: null,
                          enabled: !_isSending,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF2196F3),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: _isSending ? null : _sendMessage,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedFiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '💡 Max 5 files',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Center(
                child: Text(
                  'Dispute ${widget.dispute.status}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}