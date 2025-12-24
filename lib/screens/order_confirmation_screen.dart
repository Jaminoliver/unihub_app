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
        backgroundColor: AppColors.getBackground(context),
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
                            color: AppColors.successGreen,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.successGreen.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                          ),
                          child: Icon(Icons.check, size: 70, color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 32),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Text('Order Confirmed!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                            SizedBox(height: 8),
                            Text('Your ${widget.orders.length} order${widget.orders.length > 1 ? 's have' : ' has'} been placed successfully', 
                              style: TextStyle(fontSize: 14, color: AppColors.getTextMuted(context)), textAlign: TextAlign.center),
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
        gradient: LinearGradient(colors: [AppColors.primaryOrange, Color(0xFFFF8C42)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.primaryOrange.withOpacity(0.3), blurRadius: 15, offset: Offset(0, 8))],
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
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text('Order Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
        ),
        ...widget.orders.map((order) => _buildOrderCard(order)),
      ],
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.receipt_long, size: 16, color: AppColors.primaryOrange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: AppColors.primaryOrange),
                  ),
                ),
              ],
            ),
          ),

          if (order.deliveryCode != null && order.deliveryCode!.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: AppColors.successGreen),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delivery Code', style: TextStyle(fontSize: 10, color: AppColors.successGreen, fontWeight: FontWeight.w600)),
                          SizedBox(height: 2),
                          Text(
                            order.deliveryCode!,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.successGreen, fontFamily: 'monospace', letterSpacing: 4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
          ],

          Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),

          Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: order.productImageUrl != null
                      ? Image.network(
                          order.productImageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productName ?? 'Product',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildDetailChip('Qty: ${order.quantity}'),
                          if (order.selectedSize != null && order.selectedSize!.isNotEmpty)
                            _buildDetailChip('Size: ${order.selectedSize}'),
                          if (order.selectedColor != null && order.selectedColor!.isNotEmpty)
                            _buildDetailChip('Color: ${order.selectedColor}'),
                          _buildPaymentChip(order.paymentMethod),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        _formatPrice(order.totalAmount),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.getBackground(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3)),
      ),
      child: Icon(Icons.image, size: 24, color: AppColors.getTextMuted(context)),
    );
  }

  Widget _buildDetailChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.getTextMuted(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.getTextMuted(context).withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.getTextMuted(context)),
      ),
    );
  }

  Widget _buildPaymentChip(String method) {
    final color = _getPaymentColor(method);
    final label = _getPaymentLabel(method);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        border: Border(top: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _navigateToOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('View My Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      case 'full': return AppColors.successGreen;
      case 'half': return Color(0xFFF59E0B);
      case 'pay_on_delivery': return Color(0xFF3B82F6);
      default: return AppColors.getTextMuted(context);
    }
  }

  String _getPaymentLabel(String method) {
    switch (method) {
      case 'full': return 'Full Payment';
      case 'half': return 'Half Payment';
      case 'pay_on_delivery': return 'Pay on Delivery';
      default: return method.toUpperCase();
    }
  }
}