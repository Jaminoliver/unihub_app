import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'orders_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderService _orderService = OrderService();
  final TextEditingController _deliveryCodeController = TextEditingController();

  OrderModel? _order;
  bool _isLoading = true;
  bool _isConfirming = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _deliveryCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);

    try {
      final order = await _orderService.getOrderById(widget.orderId);
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading order: $e')),
      );
    }
  }

  Future<void> _confirmDelivery() async {
    final code = _deliveryCodeController.text.trim();

    if (code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid 6-digit code')),
      );
      return;
    }

    setState(() => _isConfirming = true);

    try {
      final success = await _orderService.confirmDelivery(widget.orderId, code);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery confirmed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOrder();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid delivery code. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isConfirming = false);
    }
  }

  Future<void> _cancelOrder() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel this order?'),
            SizedBox(height: 12),
            if (_order!.paymentMethod != 'pod') ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your payment of ₦${_order!.escrowAmount?.toStringAsFixed(0)} will be refunded within 5-7 business days.',
                        style: TextStyle(fontSize: 12, color: Colors.green[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No, Keep Order', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final success = await _orderService.cancelOrder(
        widget.orderId,
        'Cancelled by buyer',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_order!.paymentMethod == 'pod'
                ? 'Order cancelled successfully!'
                : 'Order cancelled! Refund will be processed within 5-7 business days.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        
        // Navigate back to orders screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => OrdersScreen(initialTab: 1)),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => OrdersScreen()),
              (route) => route.isFirst,
            );
          },
        ),
        title: Text('Order Details', style: AppTextStyles.heading.copyWith(fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : _order == null
              ? _buildErrorState()
              : ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    _buildStatusCard(),
                    SizedBox(height: 16),
                    _buildOrderInfoCard(),
                    SizedBox(height: 16),
                    _buildProductCard(),
                    SizedBox(height: 16),
                    _buildDeliveryCard(),
                    SizedBox(height: 16),
                    _buildPaymentCard(),
                    
                    // Show auto-cancel warning if applicable
                    if (_orderService.canCancelOrder(_order!)) ...[
                      SizedBox(height: 16),
                      _buildAutoCancelWarning(),
                    ],
                    
                    if (!_order!.isDelivered && !_order!.isCancelled) ...[
                      SizedBox(height: 16),
                      _buildDeliveryConfirmationCard(),
                      
                      // Cancel button - only for cancellable orders
                      if (_orderService.canCancelOrder(_order!)) ...[
                        SizedBox(height: 12),
                        _buildCancelButton(),
                      ],
                    ],
                    SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _buildAutoCancelWarning() {
    final timeRemaining = _orderService.getTimeUntilAutoCancel(_order!);
    
    if (timeRemaining == null) return SizedBox.shrink();

    final daysLeft = timeRemaining.inDays;
    final hoursLeft = timeRemaining.inHours % 24;

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: Colors.orange[700], size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-Cancel Warning',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'This order will be automatically cancelled and refunded in $daysLeft day${daysLeft != 1 ? 's' : ''} ${hoursLeft}h if not delivered.',
                  style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isCancelling ? null : _cancelOrder,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isCancelling
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Cancel Order',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ... Rest of the widget methods remain the same ...

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Order not found',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getStatusGradient(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _getStatusIcon(),
            color: Colors.white,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            _order!.statusDisplayText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            _order!.orderNumber,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_order!.orderStatus) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'refunded':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<Color> _getStatusGradient() {
    final color = _getStatusColor();
    return [color, color.withOpacity(0.7)];
  }

  IconData _getStatusIcon() {
    switch (_order!.orderStatus) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      case 'refunded':
        return Icons.money_off;
      default:
        return Icons.info;
    }
  }

 Widget _buildOrderInfoCard() {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Order Number', _order!.orderNumber, Icons.receipt_long, copyable: true),
        Divider(height: 20),
        _buildInfoRow('Order Date', _formatDate(_order!.createdAt), Icons.calendar_today),
        Divider(height: 20),
        _buildInfoRow('Payment Method', _getPaymentMethodText(), Icons.payment),
        
        // Only show payment status if NOT a cancelled POD order
        if (!(_order!.isCancelled && _order!.isPayOnDelivery)) ...[
          Divider(height: 20),
          _buildInfoRow('Payment Status', _order!.paymentStatusDisplayText, Icons.account_balance_wallet,
              color: _order!.isPaymentCompleted ? Colors.green : Colors.orange),
        ],
      ],
    ),
  );
}

String _getPaymentMethodText() {
  switch (_order!.paymentMethod) {
    case 'full':
      return 'Full Payment';
    case 'half':
      return 'Half Payment';
    case 'pod':
      return 'Pay on Delivery';
    default:
      return _order!.paymentMethod;
  }
}

  Widget _buildProductCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              if (_order!.productImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _order!.productImageUrl!,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey[200],
                      child: Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                )
              else
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.image, color: Colors.grey),
                ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _order!.productName ?? 'Product',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Qty: ${_order!.quantity}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _order!.formattedTotal,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Color(0xFFFF6B35), size: 20),
              SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            _order!.deliveryAddress ?? 'Address not available',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          _buildPaymentRow('Subtotal', _order!.formattedTotal),
          _buildPaymentRow('Commission (5%)', _formatPrice(_order!.commissionAmount)),
          _buildPaymentRow('Seller Receives', _formatPrice(_order!.sellerPayoutAmount ?? 0),
              bold: true, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildDeliveryConfirmationCard() {
    if (_order!.deliveryCode == null || _order!.deliveryCode!.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock, color: Colors.green[700], size: 20),
              SizedBox(width: 8),
              Text(
                'Your Delivery Code',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Share this code ONLY when you receive your item',
            style: TextStyle(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[300]!, width: 2),
                ),
                child: Text(
                  _order!.deliveryCode!,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                    fontFamily: 'monospace',
                    letterSpacing: 8,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy, color: Colors.green[700], size: 28),
                onPressed: () => _copyToClipboard(_order!.deliveryCode!, 'Delivery code'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon,
      {bool copyable = false, Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (copyable)
          IconButton(
            icon: Icon(Icons.copy, size: 18, color: Colors.grey[600]),
            onPressed: () => _copyToClipboard(value, label),
          ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatPrice(double price) {
    return '₦${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}