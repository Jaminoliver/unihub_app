import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../models/order_model.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class ChatBubbleWidget extends StatelessWidget {
  final ChatMessageModel message;
  final Function(OrderModel)? onOrderSelected;
  final Function()? onManualOrderEntry;
  final Function(String, String)? onReasonSelected;
  final Function()? onShowOlderOrders;
  final bool canShowMore;

  const ChatBubbleWidget({
    Key? key,
    required this.message,
    this.onOrderSelected,
    this.onManualOrderEntry,
    this.onReasonSelected,
    this.onShowOlderOrders,
    this.canShowMore = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.orderSelection:
        return _buildOrderSelection(context);
      case MessageType.reasonChips:
        return _buildReasonChips(context);
      case MessageType.imagePreview:
        return _buildImagePreview(context);
      case MessageType.summaryCard:
        return _buildSummaryCard(context);
      case MessageType.adminMessage:
        return _buildAdminMessage(context);
      default:
        return _buildTextMessage(context);
    }
  }

  Widget _buildTextMessage(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF2196F3),
                child: Icon(Icons.support_agent, size: 16, color: Colors.white),
              ),
              SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? Color(0xFF2196F3) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: isUser ? null : Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isUser ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (isUser) ...[
              SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF2196F3),
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSelection(BuildContext context) {
    final ordersList = message.metadata?['orders'] as List? ?? [];
    
    final orders = ordersList.map((item) {
      if (item is OrderModel) return item;
      else if (item is Map<String, dynamic>) return OrderModel.fromJson(item);
      else if (item is Map) return OrderModel.fromJson(Map<String, dynamic>.from(item));
      else throw Exception('Unexpected order type: ${item.runtimeType}');
    }).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBotHeader(),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (orders.isNotEmpty) ...[
                SizedBox(height: 12),
                Text(
                  'Recent orders (last 6):',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                ...orders.map((order) => _buildOrderCard(order)),
                if (canShowMore && onShowOlderOrders != null) ...[
                  SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onShowOlderOrders,
                    icon: Icon(Icons.expand_more, size: 18),
                    label: Text('Show Older Orders'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 44),
                      side: BorderSide(color: Color(0xFF3B82F6)),
                      foregroundColor: Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ],
              SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onManualOrderEntry,
                icon: Icon(Icons.help_outline, size: 16),
                label: Text('Can\'t find your order?'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 44),
                  side: BorderSide(color: Colors.grey[400]!),
                  foregroundColor: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final formattedDate = dateFormat.format(order.createdAt);
    
    return InkWell(
      onTap: () => onOrderSelected?.call(order),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            if (order.productImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  order.productImageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholderImage(),
                ),
              )
            else
              _placeholderImage(),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.productName ?? 'Product',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '#${order.orderNumber}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.orderStatus),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order.statusDisplayText,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3),
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                  SizedBox(height: 3),
                  Text(
                    order.formattedTotal,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'shipped': return Colors.purple;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildReasonChips(BuildContext context) {
    final reasons = (message.metadata?['reasons'] as List?)
        ?.map((e) => Map<String, String>.from(e as Map))
        .toList() ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBotHeader(),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reasons.map((reason) {
                  return InkWell(
                    onTap: () => onReasonSelected?.call(
                      reason['value'] ?? '',
                      reason['label'] ?? '',
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        reason['label'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    final images = (message.metadata?['images'] as List?)?.cast<String>() ?? [];
    
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: 250),
              child: GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: images.length > 1 ? 2 : 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(images[index]),
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final data = message.metadata ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBotHeader(),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.summarize, color: Color(0xFF2196F3), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Dispute Summary',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Divider(height: 20),
              _summaryRow('Order', data['orderNumber'] ?? 'N/A', Icons.receipt),
              _summaryRow('Issue', _getReasonLabel(data['reason']), Icons.error_outline),
              _summaryRow('Description', data['description'] ?? 'N/A', Icons.description),
              _summaryRow('Evidence', '${data['evidenceCount'] ?? 0} images', Icons.image),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Review carefully before submitting',
                        style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAdminMessage(BuildContext context) {
    final attachments = (message.metadata?['attachments'] as List?)?.cast<String>();
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF2196F3),
              child: Text('A', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          message.content,
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        if (attachments != null && attachments.isNotEmpty) ...[
                          SizedBox(height: 8),
                          ...attachments.map((url) => _buildAttachment(url)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachment(String url) {
    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          height: 150,
          errorBuilder: (_, __, ___) => Container(
            height: 150,
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildBotHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFF2196F3),
          child: Icon(Icons.support_agent, size: 16, color: Colors.white),
        ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _summaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.image, color: Colors.grey[400], size: 24),
    );
  }

  String _getReasonLabel(String? reason) {
    switch (reason) {
      case 'product_not_received': return 'Product Not Received';
      case 'wrong_item_received': return 'Wrong Item Received';
      case 'damaged_item': return 'Damaged Item';
      case 'fake_counterfeit': return 'Fake/Counterfeit';
      case 'seller_not_shipping': return 'Seller Not Shipping';
      case 'payment_issue': return 'Payment Issue';
      case 'refund_not_received': return 'Refund Not Received';
      case 'other': return 'Other Issue';
      default: return reason ?? 'N/A';
    }
  }
}