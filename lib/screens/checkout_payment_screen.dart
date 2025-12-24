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

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final PaymentService _paymentService = PaymentService();
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  bool _isProcessing = false;
  String _currentStep = '';
  bool _showSuccessAnimation = false;
  int _selectedPaymentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedPaymentTab = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  String _formatPrice(double price) {
    return '₦${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }

  Future<void> _processCheckout() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _currentStep = 'Processing payment...';
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('Please log in to continue');

      final requiresPayment = _requiresOnlinePayment();
      String? paymentReference;
      int? transactionId;

      if (requiresPayment) {
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
            'payment_method': _selectedPaymentTab == 0 ? 'card' : 'transfer',
          },
        );

        if (paymentResult == null) {
          if (mounted) {
            setState(() => _isProcessing = false);
            _showPaymentFailedDialog('Payment was not completed.');
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
          productId: product.id,
          quantity: item.quantity,
          unitPrice: product.price,
          totalAmount: item.totalPrice,
          paymentMethod: paymentMethod,
          deliveryAddressId: widget.deliveryAddress.id,
          paymentReference: paymentReference,
          transactionId: transactionId,
          selectedColor: item.selectedColor,
          selectedSize: item.selectedSize,
        );

        createdOrders.add(order);
      }

      for (final item in widget.selectedItems) {
        await _cartService.removeFromCart(item.id);
      }

      setState(() => _showSuccessAnimation = true);
      await Future.delayed(Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => OrderConfirmationScreen(orders: createdOrders),
          ),
          (route) => route.settings.name == '/home' || route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showPaymentFailedDialog('Checkout failed: ${e.toString()}');
      }
    }
  }

  void _showPaymentFailedDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.errorRed, size: 24),
            SizedBox(width: 8),
            Text('Payment Failed', style: TextStyle(fontSize: 18, color: AppColors.getTextPrimary(context))),
          ],
        ),
        content: Text(message, style: TextStyle(fontSize: 14, color: AppColors.getTextMuted(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Back', style: TextStyle(color: AppColors.getTextMuted(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccessAnimation) return _buildSuccessScreen();

    final totalAmount = _calculateTotalAmount();
    final escrowAmount = _calculateEscrowAmount();
    final requiresPayment = _requiresOnlinePayment();

    return WillPopScope(
      onWillPop: () async => !_isProcessing,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getCardBackground(context),
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(context)),
          leading: _isProcessing
              ? SizedBox.shrink()
              : IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
          title: Text('Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),
          ),
        ),
        body: Column(
          children: [
            Container(
              color: AppColors.getCardBackground(context),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  _buildStep('Cart', true),
                  _buildLine(true),
                  _buildStep('Address', true),
                  _buildLine(true),
                  _buildStep('Review', true),
                  _buildLine(true),
                  _buildStep('Payment', true),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),

            Expanded(
              child: _isProcessing
                  ? _buildProcessingState()
                  : requiresPayment
                      ? _buildPaymentOptions(escrowAmount)
                      : _buildPODState(totalAmount),
            ),
          ],
        ),
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
              color: active ? AppColors.primaryOrange : AppColors.getBorder(context).withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? AppColors.primaryOrange : AppColors.getTextMuted(context),
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
      color: active ? AppColors.primaryOrange : AppColors.getBorder(context).withOpacity(0.3),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primaryOrange),
          SizedBox(height: 24),
          Text(_currentStep, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
          SizedBox(height: 8),
          Text('Please wait...', style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context))),
        ],
      ),
    );
  }

  Widget _buildPaymentOptions(double escrowAmount) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3)),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
            ),
            labelColor: AppColors.primaryOrange,
            unselectedLabelColor: AppColors.getTextMuted(context),
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.credit_card, size: 18), SizedBox(width: 6), Text('Card')])),
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.account_balance, size: 18), SizedBox(width: 6), Text('Transfer')])),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPaymentTab(
                icon: Icons.credit_card,
                title: 'Card Payment',
                subtitle: 'Visa, Mastercard, Verve',
                features: [
                  {'icon': Icons.security, 'text': 'Secure & encrypted'},
                  {'icon': Icons.flash_on, 'text': 'Instant processing'},
                ],
              ),
              _buildPaymentTab(
                icon: Icons.account_balance,
                title: 'Bank Transfer',
                subtitle: 'USSD or Internet Banking',
                features: [
                  {'icon': Icons.phone_android, 'text': 'Dial from mobile'},
                  {'icon': Icons.check_circle, 'text': 'Auto confirmation'},
                ],
              ),
            ],
          ),
        ),

        _buildBottomBar(true, escrowAmount),
      ],
    );
  }

  Widget _buildPaymentTab({required IconData icon, required String title, required String subtitle, required List<Map<String, dynamic>> features}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 28, color: AppColors.primaryOrange),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                      SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFFCD34D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Color(0xFFFCD34D).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield, color: Color(0xFF92400E), size: 16),
                    SizedBox(width: 8),
                    Text('Escrow Protection', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Payment held securely until you confirm delivery with your 6-digit code. Auto-refund after 5 days if not delivered.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E).withOpacity(0.8), height: 1.3),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 10),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(Icons.lock, 'Funds held max 5 days'),
              _buildInfoChip(Icons.refresh, 'Auto-refund if undelivered'),
              _buildInfoChip(Icons.pin, '6-digit delivery code'),
              _buildInfoChip(Icons.security, 'Never share your code'),
            ],
          ),
          
          if (icon == Icons.credit_card) ...[
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF3B82F6).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user, color: Color(0xFF1E40AF), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Secured by Paystack',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          SizedBox(height: 14),
          
          ...features.map((f) => Container(
            margin: EdgeInsets.only(bottom: 1),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(context),
              border: Border(
                bottom: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(f['icon'] as IconData, color: AppColors.primaryOrange, size: 18),
                SizedBox(width: 12),
                Text(f['text'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context))),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.getTextMuted(context)),
          SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 10, color: AppColors.getTextMuted(context), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPODState(double amount) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(height: 40),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delivery_dining, size: 60, color: AppColors.successGreen),
                ),
                SizedBox(height: 24),
                Text('Pay on Delivery', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                SizedBox(height: 8),
                Text('You\'ll pay ${_formatPrice(amount)} when you receive', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.getTextMuted(context))),
                SizedBox(height: 32),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.getCardBackground(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      _buildPODStep(Icons.check_circle, 'Order Confirmed', 'We\'ll prepare your order'),
                      Divider(height: 32, color: AppColors.getBorder(context).withOpacity(0.3)),
                      _buildPODStep(Icons.local_shipping, 'Item Delivered', 'Receive your items'),
                      Divider(height: 32, color: AppColors.getBorder(context).withOpacity(0.3)),
                      _buildPODStep(Icons.payments, 'Pay Cash', 'Pay the delivery agent'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        _buildBottomBar(false, amount),
      ],
    );
  }

  Widget _buildPODStep(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(icon, color: AppColors.successGreen, size: 28),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
              Text(description, style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool requiresPayment, double amount) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        border: Border(
          top: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3)),
        ),
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
                    requiresPayment ? 'Pay Now' : 'Total Amount',
                    style: TextStyle(
                      fontSize: 12, 
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w500
                    ), 
                  ),
                  Text(
                    _formatPrice(amount),
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: AppColors.primaryOrange
                    ), 
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: _processCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getCardBackground(context),
                foregroundColor: AppColors.primaryOrange,
                elevation: 0,
                side: BorderSide(
                  color: AppColors.primaryOrange,
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
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.getCardBackground(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 100, color: AppColors.successGreen),
            SizedBox(height: 24),
            Text('Order Confirmed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            SizedBox(height: 8),
            Text('Redirecting...', style: TextStyle(fontSize: 14, color: AppColors.getTextMuted(context))),
          ],
        ),
      ),
    );
  }
}