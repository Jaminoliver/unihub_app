import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../models/address_model.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/payment_service.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'order_confirmation_screen.dart';
import '../main.dart';

class CheckoutPaymentScreen extends StatefulWidget {
  final List<CartModel> selectedItems;
  final Map<String, String> paymentMethods;
  final DeliveryAddressModel deliveryAddress;

  const CheckoutPaymentScreen({
    super.key,
    required this.selectedItems,
    required this.paymentMethods,
    required this.deliveryAddress,
  });

  @override
  State<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen> {
  final OrderService _orderService = OrderService();
  final PaymentService _paymentService = PaymentService();
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();

  bool _isProcessing = false;
  String _currentStep = 'Initializing...';
  bool _showSuccessAnimation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processCheckout());
  }

  double _calculateTotalAmount() {
    return widget.selectedItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double _calculateEscrowAmount() {
    double total = 0.0;
    for (final item in widget.selectedItems) {
      final paymentMethod = widget.paymentMethods[item.id] ?? 'full';
      total += _paymentService.calculateEscrowAmount(item.totalPrice, paymentMethod);
    }
    return total;
  }

  bool _requiresOnlinePayment() {
    for (final item in widget.selectedItems) {
      final paymentMethod = widget.paymentMethods[item.id] ?? 'full';
      if (_paymentService.requiresOnlinePayment(paymentMethod)) return true;
    }
    return false;
  }

  Future<void> _processCheckout() async {
    setState(() {
      _isProcessing = true;
      _currentStep = 'Processing checkout...';
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('Please log in to continue');

      final requiresPayment = _requiresOnlinePayment();
      String? paymentReference;
      int? transactionId;

      if (requiresPayment) {
        setState(() => _currentStep = 'Processing payment...');
        final escrowAmount = _calculateEscrowAmount();
        final userEmail = user.email ?? 'buyer@unihub.com';

        final paymentResult = await _paymentService.processPayment(
          context: context,
          email: userEmail,
          amount: escrowAmount,
          currency: 'NGN',
          metadata: {
            'buyer_id': user.id,
            'item_count': widget.selectedItems.length.toString(),
            'delivery_address': widget.deliveryAddress.shortAddress,
          },
        );

        if (paymentResult == null) {
          if (mounted) {
            _paymentService.showPaymentFailedDialog(
              context,
              'Payment was not completed. Please try again.',
            );
            Navigator.pop(context);
          }
          return;
        }

        paymentReference = paymentResult['reference'] as String?;
        transactionId = paymentResult['transaction_id'] as int?;
      }

      setState(() => _currentStep = 'Creating orders...');
      final createdOrders = <OrderModel>[];

      for (final item in widget.selectedItems) {
        final product = item.product!;
        final paymentMethod = widget.paymentMethods[item.id] ?? 'full';

        final order = await _orderService.createOrder(
          buyerId: user.id,
          sellerId: product.sellerId,
          quantity: item.quantity,
          unitPrice: product.price,
          totalAmount: item.totalPrice,
          paymentMethod: paymentMethod,
          deliveryAddressId: widget.deliveryAddress.id,
          paymentReference: paymentReference,
          transactionId: transactionId, productId: product.id,
        );
        createdOrders.add(order);
      }

      setState(() => _currentStep = 'Finalizing...');
      for (final item in widget.selectedItems) {
        await _cartService.removeFromCart(item.id);
      }

      setState(() => _showSuccessAnimation = true);
      await Future.delayed(Duration(seconds: 2));

      if (mounted) {
        // Navigate to Order Confirmation screen
        // But clear the cart/checkout screens from the stack first
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => OrderConfirmationScreen(orders: createdOrders),
          ),
          (route) => route.settings.name == '/home' || route.isFirst,
        );
      }
    } catch (e) {
      print('Error during checkout: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccessAnimation) return _buildSuccessAnimation();

    final totalAmount = _calculateTotalAmount();
    final escrowAmount = _calculateEscrowAmount();
    final requiresPayment = _requiresOnlinePayment();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _isProcessing ? SizedBox.shrink() : IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Payment', style: AppTextStyles.heading.copyWith(fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStep('1', 'Review', true, true),
                _buildLine(true),
                _buildStep('2', 'Address', true, true),
                _buildLine(true),
                _buildStep('3', 'Payment', true, !_isProcessing),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: _isProcessing ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Color(0xFFFF6B35).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6B35),
                          strokeWidth: 4,
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    Text(_currentStep, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                    SizedBox(height: 12),
                    Text('Please wait...', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                ) : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment, size: 80, color: Color(0xFFFF6B35)),
                    SizedBox(height: 24),
                    Text(
                      requiresPayment ? 'Secure Payment' : 'Pay on Delivery',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 32),
                    _buildAmountCard(totalAmount, escrowAmount, requiresPayment),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
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
                );
              },
            ),
            SizedBox(height: 32),
            Text('Payment Successful!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Redirecting to orders...', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String label, bool active, bool completed) {
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
                : Text(number, style: TextStyle(color: active ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: active ? Color(0xFFFF6B35) : Colors.grey[600])),
      ],
    );
  }

  Widget _buildLine(bool active) {
    return Container(
      width: 40,
      height: 2,
      margin: EdgeInsets.only(bottom: 24),
      color: active ? Color(0xFFFF6B35) : Colors.grey[300],
    );
  }

  Widget _buildAmountCard(double totalAmount, double escrowAmount, bool requiresPayment) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Amount', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              Text(_paymentService.formatAmount(totalAmount), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          if (requiresPayment) ...[
            Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pay Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                Text(_paymentService.formatAmount(escrowAmount), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}