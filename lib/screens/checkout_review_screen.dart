import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'checkout_address_screen.dart';

/// Checkout Step 1: Review Order
/// Shows selected cart items, payment methods, and totals
class CheckoutReviewScreen extends StatefulWidget {
  final List<CartModel> selectedItems;
  final Map<String, String> paymentMethods; // {cartItemId: 'full'|'half'|'pod'}

  const CheckoutReviewScreen({
    super.key,
    required this.selectedItems,
    required this.paymentMethods,
  });

  @override
  State<CheckoutReviewScreen> createState() => _CheckoutReviewScreenState();
}

class _CheckoutReviewScreenState extends State<CheckoutReviewScreen> {
  double _calculateSubtotal() {
    return widget.selectedItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double _calculateEscrowTotal() {
    double total = 0.0;
    for (final item in widget.selectedItems) {
      final paymentMethod = widget.paymentMethods[item.id] ?? 'full';
      final itemTotal = item.totalPrice;

      if (paymentMethod == 'full') {
        total += itemTotal;
      } else if (paymentMethod == 'half') {
        total += itemTotal / 2;
      }
      // POD adds 0 to escrow
    }
    return total;
  }

  String _formatPrice(double price) {
    return '₦${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'full':
        return 'Full Payment';
      case 'half':
        return 'Half Payment';
      case 'pod':
        return 'Pay on Delivery';
      default:
        return 'Unknown';
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method) {
      case 'full':
        return Colors.green;
      case 'half':
        return Colors.orange;
      case 'pod':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _calculateSubtotal();
    final escrowTotal = _calculateEscrowTotal();
    final deliveryFee = 0.0; // Can be calculated based on location
    final total = subtotal + deliveryFee;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Review Order',
          style: AppTextStyles.heading.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress Indicator
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepIndicator('1', 'Review', true, true),
                _buildStepLine(false),
                _buildStepIndicator('2', 'Address', false, false),
                _buildStepLine(false),
                _buildStepIndicator('3', 'Payment', false, false),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                // Order Items Section
                _buildSectionTitle('Order Items (${widget.selectedItems.length})'),
                SizedBox(height: 12),
                ...widget.selectedItems.map((item) => _buildOrderItemCard(item)),

                SizedBox(height: 24),

                // Payment Summary Section
                _buildSectionTitle('Payment Summary'),
                SizedBox(height: 12),
                _buildSummaryCard(subtotal, escrowTotal, deliveryFee, total),

                SizedBox(height: 24),

                // Important Notes
                _buildNotesCard(),

                SizedBox(height: 100), // Space for bottom button
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildStepIndicator(String number, String label, bool active, bool completed) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active || completed ? Color(0xFFFF6B35) : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: completed
                ? Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    number,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? Color(0xFFFF6B35) : Colors.grey[600],
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool active) {
    return Container(
      width: 40,
      height: 2,
      margin: EdgeInsets.only(bottom: 24),
      color: active ? Color(0xFFFF6B35) : Colors.grey[300],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildOrderItemCard(CartModel item) {
    final paymentMethod = widget.paymentMethods[item.id] ?? 'full';
    final product = item.product!;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              product.imageUrls.first,
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
          ),
          SizedBox(width: 12),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPaymentMethodColor(paymentMethod).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getPaymentMethodName(paymentMethod),
                        style: TextStyle(
                          fontSize: 10,
                          color: _getPaymentMethodColor(paymentMethod),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPrice(item.totalPrice),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double subtotal, double escrowTotal, double deliveryFee, double total) {
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
        children: [
          _buildSummaryRow('Subtotal', _formatPrice(subtotal), false),
          SizedBox(height: 12),
          _buildSummaryRow('Delivery Fee', _formatPrice(deliveryFee), false),
          Divider(height: 24),
          _buildSummaryRow('Total', _formatPrice(total), true),
          SizedBox(height: 8),
          _buildSummaryRow('To Pay Now (Escrow)', _formatPrice(escrowTotal), true, color: Color(0xFFFF6B35)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool bold, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color ?? (bold ? Colors.black : Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color ?? (bold ? Colors.black : Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Notes:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '• Escrow amount will be held securely\n'
                  '• Funds released to seller after delivery\n'
                  '• You\'ll receive a 6-digit delivery code\n'
                  '• Share code only when you receive item',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[800],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () {
            // Navigate to address selection
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CheckoutAddressScreen(
                  selectedItems: widget.selectedItems,
                  paymentMethods: widget.paymentMethods,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFFF6B35),
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Continue to Address',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}