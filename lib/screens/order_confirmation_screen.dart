import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'orders_screen.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final List<OrderModel> orders;

  const OrderConfirmationScreen({super.key, required this.orders});

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 800));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _totalAmount => widget.orders.fold(0.0, (sum, o) => sum + o.totalAmount);
  int get _totalItems => widget.orders.fold(0, (sum, o) => sum + o.quantity);

  String _formatPrice(double price) => '₦${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _navigateToOrders();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(height: 40),
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                          ),
                          child: Icon(Icons.check, size: 70, color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 32),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Text('Order Confirmed!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
                            SizedBox(height: 8),
                            Text('Your ${widget.orders.length} order${widget.orders.length > 1 ? 's have' : ' has'} been placed successfully', 
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                      SizedBox(height: 40),
                      _buildSummaryCard(),
                      SizedBox(height: 24),
                      _buildOrdersList(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Color(0xFFFF6B35).withOpacity(0.3), blurRadius: 15, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Orders', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: 4),
                  Text('${widget.orders.length}', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Items', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: 4),
                  Text('$_totalItems', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          Divider(height: 24, color: Colors.white24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Amount', style: TextStyle(color: Colors.white, fontSize: 14)),
              Text(_formatPrice(_totalAmount), style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
        SizedBox(height: 16),
        ...widget.orders.map((order) => _buildOrderCard(order)),
      ],
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, size: 16, color: Color(0xFFFF6B35)),
              SizedBox(width: 8),
              Expanded(
                child: Text(order.orderNumber, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Color(0xFFFF6B35))),
              ),
            ],
          ),
          if (order.deliveryCode != null && order.deliveryCode!.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.green[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delivery Code', style: TextStyle(fontSize: 10, color: Colors.green[800], fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(order.deliveryCode!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[900], fontFamily: 'monospace', letterSpacing: 4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          Divider(height: 20),
          Row(
            children: [
              if (order.productImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(order.productImageUrl!, width: 50, height: 50, fit: BoxFit.cover, 
                    errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey[200], child: Icon(Icons.image, size: 20, color: Colors.grey[400]))),
                )
              else
                Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), 
                  child: Icon(Icons.image, size: 20, color: Colors.grey[400])),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.productName ?? 'Product', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 4),
                    Text('Qty: ${order.quantity}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatPrice(order.totalAmount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPaymentColor(order.paymentMethod).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_getPaymentLabel(order.paymentMethod), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _getPaymentColor(order.paymentMethod))),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _navigateToOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF6B35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('View My Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }

 void _navigateToOrders() {
  Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
    '/orders',
    (route) => false,
  );
}

  Color _getPaymentColor(String method) {
    switch (method) {
      case 'full': return Colors.green;
      case 'half': return Colors.orange;
      case 'pay_on_delivery': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _getPaymentLabel(String method) {
    switch (method) {
      case 'full': return 'FULL';
      case 'half': return 'HALF';
      case 'pay_on_delivery': return 'POD';
      default: return method.toUpperCase();
    }
  }
}