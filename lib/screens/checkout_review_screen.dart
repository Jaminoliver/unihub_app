import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../models/address_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'checkout_payment_screen.dart';
import 'checkout_address_screen.dart';

class CheckoutReviewScreen extends StatefulWidget {
  final List<CartModel> selectedItems;
  final Map<String, String> paymentMethods;
  final DeliveryAddressModel deliveryAddress;

  const CheckoutReviewScreen({
    super.key,
    required this.selectedItems,
    required this.paymentMethods,
    required this.deliveryAddress,
  });

  @override
  State<CheckoutReviewScreen> createState() => _CheckoutReviewScreenState();
}

class _CheckoutReviewScreenState extends State<CheckoutReviewScreen> {
  String _formatPrice(double price) {
    return '₦${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }

  double _calculateTotal() {
    return widget.selectedItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double _calculateEscrow() {
    double escrow = 0.0;
    for (final item in widget.selectedItems) {
      final method = widget.paymentMethods[item.id] ?? 'full';
      if (method == 'full') escrow += item.totalPrice;
      if (method == 'half') escrow += item.totalPrice / 2;
    }
    return escrow;
  }

  bool _requiresPayment() {
    return widget.paymentMethods.values.any((m) => m == 'full' || m == 'half');
  }

  String _getPaymentMethodLabel(String method) {
    switch (method) {
      case 'full': return 'Full Payment';
      case 'half': return 'Half Payment';
      case 'pod': return 'Pay on Delivery';
      default: return method;
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method) {
      case 'full': return Color(0xFF10B981);
      case 'half': return Color(0xFFF59E0B);
      case 'pod': return Color(0xFF3B82F6);
      default: return Colors.grey;
    }
  }

  void _proceedToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPaymentScreen(
          selectedItems: widget.selectedItems,
          paymentMethods: widget.paymentMethods,
          deliveryAddress: widget.deliveryAddress,
        ),
      ),
    );
  }

  void _changeAddress() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutAddressScreen(
          selectedItems: widget.selectedItems,
          paymentMethods: widget.paymentMethods,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _calculateTotal();
    final escrow = _calculateEscrow();
    final requiresPayment = _requiresPayment();

    return WillPopScope(
      onWillPop: () async {
        Navigator.popUntil(context, (route) => route.settings.name == '/cart' || route.isFirst);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.popUntil(context, (route) => route.settings.name == '/cart' || route.isFirst);
            },
          ),
          title: Text('Review Order', style: AppTextStyles.heading.copyWith(fontSize: 18)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Simple Progress Line
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  _buildStep('Cart', true),
                  _buildLine(true),
                  _buildStep('Address', true),
                  _buildLine(true),
                  _buildStep('Review', true),
                  _buildLine(false),
                  _buildStep('Payment', false),
                ],
              ),
            ),
            Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                physics: ClampingScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address
                    _buildAddressCard(),
                    SizedBox(height: 12),

                    // Items
                    _buildOrderItemsCard(),
                    SizedBox(height: 12),

                    // Summary
                    _buildSummaryCard(total, escrow, requiresPayment),
                    
                    if (requiresPayment) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(0xFF3B82F6).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF1E40AF), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your payment is protected by escrow until delivery confirmation',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E40AF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(requiresPayment, escrow, total),
      ),
    );
  }

  Widget _buildStep(String label, bool active) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: active ? Color(0xFFFF6B35).withOpacity(0.05) : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? Color(0xFFFF6B35) : Colors.grey[500],
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLine(bool active) {
    return Container(
      width: 8,
      height: 3,
      margin: EdgeInsets.only(bottom: 18),
      color: active ? Color(0xFFFF6B35) : Colors.grey[300],
    );
  }

  Widget _buildAddressCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Color(0xFFFF6B35), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Delivery Address',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _changeAddress,
                  child: Text(
                    'Change',
                    style: TextStyle(color: Color(0xFFFF6B35), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.deliveryAddress.addressLine,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 6),
                Text(
                  '${widget.deliveryAddress.city}, ${widget.deliveryAddress.state}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (widget.deliveryAddress.landmark?.isNotEmpty ?? false) ...[
                  SizedBox(height: 4),
                  Text(
                    'Near ${widget.deliveryAddress.landmark}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
                if (widget.deliveryAddress.phoneNumber?.isNotEmpty ?? false) ...[
                  SizedBox(height: 4),
                  Text(
                    widget.deliveryAddress.phoneNumber!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.shopping_bag, color: Color(0xFFFF6B35), size: 18),
                SizedBox(width: 8),
                Text(
                  'Order Items',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B35).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.selectedItems.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(12),
            itemCount: widget.selectedItems.length,
            separatorBuilder: (_, __) => SizedBox(height: 16),
            itemBuilder: (context, index) => _buildOrderItem(widget.selectedItems[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(CartModel item) {
    final product = item.product;
    if (product == null) return SizedBox.shrink();
    final paymentMethod = widget.paymentMethods[item.id] ?? 'full';

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 70,
            height: 70,
            color: Colors.grey.shade100,
            child: product.mainImageUrl != null
                ? Image.network(
                    product.mainImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.grey),
                  )
                : Icon(Icons.image, color: Colors.grey),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (item.selectedColor != null && item.selectedColor!.isNotEmpty)
                    _buildTag(item.selectedColor!, Colors.grey[700]!),
                  if (item.selectedSize != null && item.selectedSize!.isNotEmpty)
                    _buildTag(item.selectedSize!, Colors.grey[700]!),
                  _buildTag('Qty: ${item.quantity}', Colors.grey[700]!),
                  _buildTag(
                    _getPaymentMethodLabel(paymentMethod),
                    _getPaymentMethodColor(paymentMethod),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                _formatPrice(item.totalPrice),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildSummaryCard(double total, double escrow, bool requiresPayment) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Color(0xFFFF6B35), size: 18),
              SizedBox(width: 8),
              Text(
                'Order Summary',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              Text(_formatPrice(total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(
                _formatPrice(total),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          if (requiresPayment) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFFFCD34D).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFFCD34D).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, size: 16, color: Color(0xFF92400E)),
                  SizedBox(width: 8),
                  Text(
                    'Pay Now: ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatPrice(escrow),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool requiresPayment, double escrow, double total) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // <--- 1. BACKGROUND IS NOW WHITE
        border: Border(
          top: BorderSide(color: Colors.grey.shade200), // Subtle separation line
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requiresPayment ? 'Pay Now' : 'Total',
                    style: TextStyle(
                      fontSize: 12, 
                      color: Color(0xFFFF6B35), // <--- 2. LABEL IS ORANGE
                      fontWeight: FontWeight.w500
                    ), 
                  ),
                  Text(
                    _formatPrice(requiresPayment ? escrow : total),
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: Color(0xFFFF6B35) // <--- 2. PRICE IS ORANGE
                    ), 
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: _proceedToPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // <--- 3. BUTTON BACKGROUND IS WHITE
                foregroundColor: Color(0xFFFF6B35), // <--- BUTTON TEXT IS ORANGE
                elevation: 0,
                side: BorderSide(
                  color: Color(0xFFFF6B35), // <--- 3. BUTTON BORDER IS ORANGE
                  width: 1.5
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: Text(
                requiresPayment ? 'Proceed' : 'Confirm',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }}