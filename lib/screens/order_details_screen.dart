import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'orders_screen.dart';
import '../models/review_model.dart';
import '../services/reviews_service.dart';
import '../services/auth_service.dart';
import '../widgets/leave_review_dialog.dart';
import 'package:intl/intl.dart';
import 'track_orders_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _orderService = OrderService();
  final _reviewService = ReviewService();
  final _authService = AuthService();

  OrderModel? _order;
  ReviewModel? _existingReview;
  bool _isLoading = true;
  bool _isLoadingReview = false;
  bool _isTimelineExpanded = false;
  bool _isCodeVisible = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _loadOrder();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      _animationController.forward();
      if (_shouldShowReview) await _loadExistingReview();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading order: $e');
    }
  }

  Future<void> _loadExistingReview() async {
    setState(() => _isLoadingReview = true);
    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        final review = await _reviewService.getUserReviewForOrder(userId, widget.orderId);
        if (mounted) setState(() => _existingReview = review);
      }
    } catch (e) {
      print('Error loading review: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReview = false);
    }
  }

  Future<void> _showLeaveReviewDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => LeaveReviewDialog(
        productName: _order!.productName ?? 'Product',
        productImageUrl: _order!.productImageUrl,
        onSubmit: (rating, comment) async {
          final userId = _authService.currentUserId;
          if (userId == null) throw Exception('User not logged in');
          final success = await _reviewService.submitReview(
            productId: _order!.productId,
            userId: userId,
            orderId: widget.orderId,
            rating: rating,
            comment: comment,
          );
          if (!success) throw Exception('Failed to submit review');
        },
      ),
    );
    if (result == true) {
      _showSnackBar('Thank you for your review!', isError: false);
      _loadExistingReview();
    }
  }

  Future<void> _generateReceipt() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('UNIHUB RECEIPT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Order #${_order!.orderNumber}', style: pw.TextStyle(fontSize: 16)),
            pw.Divider(),
            pw.Text('Product: ${_order!.productName}'),
            pw.Text('Quantity: ${_order!.quantity}'),
            pw.Text('Total Amount: ${_order!.formattedTotal}'),
            pw.SizedBox(height: 10),
            pw.Text('Order Date: ${DateFormat('E, d MMM yyyy').format(_order!.createdAt)}'),
            pw.Text('Status: ${_order!.statusDisplayText}'),
            pw.SizedBox(height: 10),
            pw.Text('Delivery Address:'),
            pw.Text(_order!.deliveryAddress ?? 'Not provided'),
            pw.Divider(),
            pw.Text('Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied', isError: false);
  }

  // Computed properties
  bool get _shouldShowReview => ['delivered', 'cancelled', 'refunded'].contains(_order?.orderStatus);
  bool get _shouldShowDeliveryCode => _order?.deliveryCode != null && 
      !_order!.isDelivered && 
      _order!.orderStatus != 'cancelled' && 
      _order!.orderStatus != 'refunded';
  bool get _shouldShowExpectedDelivery => !['delivered', 'cancelled', 'refunded'].contains(_order?.orderStatus);
  bool get _shouldShowTrackOrder => _order?.orderStatus == 'shipped';

  DateTime get _expectedDeliveryDate => _order!.createdAt.add(Duration(days: 5));

  String get _currentStatusText {
  if (_order!.orderStatus == 'cancelled') return '⊗ Order Cancelled';
  if (_order!.orderStatus == 'refunded') return '💰 Order Refunded';
  if (_order!.isDelivered) return '✓ Order Delivered';
  if (_order!.isShipped) return '🚚 Package in Transit';
  if (_order!.orderStatus == 'confirmed') return '📦 Preparing Your Order';
  return '📋 Order Placed';
}

  int get _progressPercentage {
    if (['cancelled', 'refunded', 'delivered'].contains(_order!.orderStatus)) return 100;
    if (_order!.isShipped) return 75;
    if (_order!.orderStatus == 'confirmed') return 50;
    return 25;
  }

  List<Map<String, dynamic>> get _timelineSteps {
    bool wasShipped = _order!.isShipped || _order!.isDelivered;
    List<Map<String, dynamic>> steps = [
      {'title': 'Order Placed', 'subtitle': DateFormat('E, d MMM').format(_order!.createdAt), 'isCompleted': true, 'icon': Icons.shopping_bag, 'color': AppColors.successGreen},
      {'title': 'Seller Notified', 'subtitle': 'Seller informed', 'isCompleted': true, 'icon': Icons.notifications_active, 'color': AppColors.infoBlue},
    ];

    if (_order!.orderStatus == 'cancelled') {
      if (wasShipped) steps.add({'title': 'Shipped', 'subtitle': 'Was shipped', 'isCompleted': true, 'icon': Icons.local_shipping, 'color': Color(0xFF8B5CF6)});
      steps.add({'title': 'Cancelled', 'subtitle': 'Order cancelled', 'isCompleted': true, 'icon': Icons.cancel, 'color': AppColors.errorRed});
      return steps;
    }

    if (_order!.orderStatus == 'refunded') {
      if (wasShipped) steps.add({'title': 'Shipped', 'subtitle': 'Was shipped', 'isCompleted': true, 'icon': Icons.local_shipping, 'color': Color(0xFF8B5CF6)});
      if (_order!.isDelivered) steps.add({'title': 'Delivered', 'subtitle': 'Was delivered', 'isCompleted': true, 'icon': Icons.done_all, 'color': AppColors.successGreen});
      steps.add({'title': 'Refunded', 'subtitle': 'Amount refunded', 'isCompleted': true, 'icon': Icons.money_off, 'color': AppColors.errorRed});
      return steps;
    }

    steps.add({'title': 'Shipped', 'subtitle': wasShipped ? 'On the way' : 'Awaiting shipment', 'isCompleted': wasShipped, 'icon': Icons.local_shipping, 'color': Color(0xFF8B5CF6)});
    steps.add({'title': 'Delivered', 'subtitle': _order!.isDelivered ? DateFormat('E, d MMM').format(_order!.deliveryConfirmedAt ?? _order!.createdAt) : 'Awaiting delivery', 'isCompleted': _order!.isDelivered, 'icon': Icons.done_all, 'color': AppColors.successGreen});
    return steps;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => OrdersScreen()),
            (route) => route.isFirst,
          ),
        ),
        title: Text('Order Details', style: AppTextStyles.heading.copyWith(fontSize: 18)),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primaryOrange),
                SizedBox(height: 16),
                Text('Loading order details...', style: AppTextStyles.body),
              ],
            ))
          : _order == null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadOrder,
                  color: AppColors.primaryOrange,
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: [
                      _buildStatusBanner(),
                      if (_shouldShowExpectedDelivery) ...[
                        SizedBox(height: 12),
                        _buildExpectedDeliveryCard(),
                      ],
                      if (_shouldShowTrackOrder) ...[
                        SizedBox(height: 12),
                        _buildTrackOrderButton(),
                      ],
                      SizedBox(height: 16),
                      _buildTimeline(),
                      SizedBox(height: 16),
                      _buildProductCard(),
                      SizedBox(height: 16),
                      _buildOrderInfoCard(),
                      SizedBox(height: 16),
                      _buildDeliveryAddressCard(),
                      SizedBox(height: 16),
                      _buildPaymentCard(),
                      SizedBox(height: 16),
                      _buildReceiptButton(),
                      if (_shouldShowDeliveryCode) ...[
                        SizedBox(height: 16),
                        _buildDeliveryCodeCard(),
                      ],
                      if (_shouldShowReview) ...[
                        SizedBox(height: 16),
                        _buildReviewSection(),
                      ],
                      SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() => Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppColors.errorRed.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
              ),
              SizedBox(height: 24),
              Text('Order not found', style: AppTextStyles.heading.copyWith(fontSize: 18)),
              SizedBox(height: 8),
              Text('This order could not be loaded', style: AppTextStyles.body, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _buildStatusBanner() {
    final configs = {
      'pending': [Color(0xFFFFF7ED), Color(0xFFF59E0B), Icons.schedule, 'Pending'],
      'confirmed': [Color(0xFFEFF6FF), Color(0xFF3B82F6), Icons.check_circle, 'Processing'],
      'shipped': [Color(0xFFF3E8FF), Color(0xFF8B5CF6), Icons.local_shipping, 'Shipped'],
      'delivered': [Color(0xFFECFDF5), Color(0xFF10B981), Icons.done_all, 'Delivered'],
      'cancelled': [Color(0xFFFEF2F2), Color(0xFFEF4444), Icons.cancel, 'Cancelled'],
      'refunded': [Color(0xFFFEF2F2), Color(0xFFEF4444), Icons.money_off, 'Refunded'],
    };
    final config = configs[_order!.orderStatus] ?? configs['pending']!;
    
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: config[0] as Color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (config[1] as Color).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: config[1] as Color, shape: BoxShape.circle),
              child: Icon(config[2] as IconData, color: Colors.white, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(config[3] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  SizedBox(height: 4),
                  Text(_order!.orderNumber, style: TextStyle(fontSize: 11, color: AppColors.textLight, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpectedDeliveryCard() => Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.infoBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.infoBlue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.local_shipping, color: AppColors.infoBlue, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expected Delivery', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                  Text(DateFormat('E, d MMM yyyy').format(_expectedDeliveryDate), 
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildTrackOrderButton() => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackOrdersScreen())),
          icon: Icon(Icons.map, size: 18),
          label: Text('Track Order'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryOrange,
            side: BorderSide(color: AppColors.primaryOrange, width: 1.5),
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _buildTimeline() => SlideTransition(
        position: Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut)),
        child: FadeTransition(
          opacity: _animationController,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _isTimelineExpanded = !_isTimelineExpanded),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timeline, color: AppColors.primaryOrange, size: 20),
                            SizedBox(width: 10),
                            Expanded(child: Text(_currentStatusText, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark))),
                            Icon(_isTimelineExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textLight),
                          ],
                        ),
                        SizedBox(height: 12),
                        Stack(
                          children: [
                            Container(height: 6, decoration: BoxDecoration(color: AppColors.lightGrey.withOpacity(0.3), borderRadius: BorderRadius.circular(3))),
                            FractionallySizedBox(
                              widthFactor: _progressPercentage / 100,
                              child: Container(height: 6, decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [AppColors.primaryOrange, Color(0xFFFF8C42)]),
                                borderRadius: BorderRadius.circular(3),
                              )),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('Tap to view details', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                ),
                if (_isTimelineExpanded) ...[
                  Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: _timelineSteps.asMap().entries.map((entry) {
                        final index = entry.key;
                        final step = entry.value;
                        return _buildTimelineStep(step, index == 0, index == _timelineSteps.length - 1);
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _buildTimelineStep(Map<String, dynamic> step, bool isFirst, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            if (!isFirst) Container(width: 2, height: 20, color: step['isCompleted'] ? step['color'] : AppColors.lightGrey),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: step['isCompleted'] ? step['color'] : AppColors.lightGrey.withOpacity(0.3),
                shape: BoxShape.circle,
                boxShadow: step['isCompleted'] ? [BoxShadow(color: (step['color'] as Color).withOpacity(0.3), blurRadius: 8, offset: Offset(0, 2))] : [],
              ),
              child: Icon(step['icon'], size: 18, color: step['isCompleted'] ? Colors.white : AppColors.textLight),
            ),
            if (!isLast) Container(width: 2, height: 24, color: step['isCompleted'] ? step['color'] : AppColors.lightGrey),
          ],
        ),
        SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step['title'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: step['isCompleted'] ? AppColors.textDark : AppColors.textLight)),
                SizedBox(height: 3),
                Text(step['subtitle'], style: TextStyle(fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard() => _buildCard(
        'Product Details',
        Icons.shopping_bag,
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _order!.productImageUrl != null
                  ? Image.network(_order!.productImageUrl!, width: 70, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_order!.productName ?? 'Product', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 6),
                  _chip(Icons.inventory_2, 'Qty: ${_order!.quantity}'),
                  if (_order!.selectedSize != null) ...[SizedBox(height: 4), _chip(Icons.straighten, 'Size: ${_order!.selectedSize}')],
                  if (_order!.selectedColor != null) ...[SizedBox(height: 4), _chip(Icons.palette, 'Color: ${_order!.selectedColor}')],
                  SizedBox(height: 6),
                  Text(_order!.formattedTotal, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildOrderInfoCard() => _buildCard(
        'Order Information',
        Icons.receipt_long,
        Column(
          children: [
            _infoRow('Order Number', _order!.orderNumber, Icons.confirmation_number, copyable: true),
            Divider(height: 20),
            _infoRow('Order Date', DateFormat('E, d MMM yyyy').format(_order!.createdAt), Icons.calendar_today),
            Divider(height: 20),
            _infoRow('Payment Method', {'full': 'Full Payment', 'half': 'Half Payment', 'pod': 'Pay on Delivery'}[_order!.paymentMethod] ?? _order!.paymentMethod, Icons.payment),
            if (!(_order!.isCancelled && _order!.isPayOnDelivery)) ...[
              Divider(height: 20),
              _infoRow('Payment Status', _order!.paymentStatusDisplayText, Icons.account_balance_wallet, 
                color: _order!.isPaymentCompleted ? AppColors.successGreen : AppColors.warningYellow),
            ],
          ],
        ),
      );

  Widget _buildDeliveryAddressCard() => _buildCard(
        'Delivery Address',
        Icons.location_on,
        Text(_order!.deliveryAddress ?? 'Not provided', style: TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.5)),
      );

  Widget _buildPaymentCard() => _buildCard(
        'Payment Summary',
        Icons.receipt,
        Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Order Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              Text(_order!.formattedTotal, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
            ]),
          ],
        ),
      );

  Widget _buildReceiptButton() => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _generateReceipt,
          icon: Icon(Icons.download, size: 18),
          label: Text('Download Receipt'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDark,
            side: BorderSide(color: AppColors.lightGrey),
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _buildDeliveryCodeCard() => Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.successGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock, color: AppColors.successGreen, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Your Delivery Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark))),
              ],
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(10)),
              child: Text('Share ONLY when you receive your item', style: TextStyle(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w500)),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.successGreen.withOpacity(0.5))),
                    child: Center(
                      child: Text(
                        _isCodeVisible ? _order!.deliveryCode! : '●●●●●●',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.successGreen, letterSpacing: _isCodeVisible ? 6 : 4),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  onPressed: () => setState(() => _isCodeVisible = !_isCodeVisible),
                  icon: Icon(_isCodeVisible ? Icons.visibility_off : Icons.visibility, color: AppColors.successGreen),
                  style: IconButton.styleFrom(backgroundColor: Colors.white, padding: EdgeInsets.all(12)),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(_order!.deliveryCode!, 'Delivery code'),
                  icon: Icon(Icons.copy, color: AppColors.successGreen),
                  style: IconButton.styleFrom(backgroundColor: Colors.white, padding: EdgeInsets.all(12)),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildReviewSection() {
    if (_isLoadingReview) return _buildCard('Review', Icons.star, Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)));

    if (_existingReview != null) {
      return _buildCard(
        'Your Review',
        Icons.check_circle,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(5, (i) => Icon(i < _existingReview!.ratingInt ? Icons.star : Icons.star_border, size: 20, color: AppColors.primaryOrange)),
                if (_existingReview!.isVerifiedPurchase) ...[
                  SizedBox(width: 8),
                  Icon(Icons.verified, color: AppColors.successGreen, size: 14),
                  SizedBox(width: 4),
                  Text('Verified', style: TextStyle(fontSize: 11, color: AppColors.successGreen, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
            SizedBox(height: 10),
            Text(_existingReview!.comment, style: TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4)),
            SizedBox(height: 8),
            Text('Reviewed ${_existingReview!.timeAgo}', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showLeaveReviewDialog,
                icon: Icon(Icons.edit, size: 16),
                label: Text('Edit Review'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryOrange,
                  side: BorderSide(color: AppColors.primaryOrange),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildCard(
      'Rate Your Experience',
      Icons.star_outline,
      Column(
        children: [
          Text('How satisfied are you with this product?', style: TextStyle(fontSize: 13, color: AppColors.textLight), textAlign: TextAlign.center),
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showLeaveReviewDialog,
              icon: Icon(Icons.rate_review, size: 18),
              label: Text('Leave Review', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, Widget child) => Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: AppColors.primaryOrange, size: 20), SizedBox(width: 10), Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark))]),
            SizedBox(height: 14),
            child,
          ],
        ),
      );

  Widget _infoRow(String label, String value, IconData icon, {bool copyable = false, Color? color}) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textLight),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? AppColors.textDark)),
              ],
            ),
          ),
          if (copyable) IconButton(icon: Icon(Icons.copy, size: 16, color: AppColors.textLight), onPressed: () => _copyToClipboard(value, label), padding: EdgeInsets.zero, constraints: BoxConstraints()),
        ],
      );

  Widget _chip(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textLight),
          SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: AppColors.textLight)),
        ],
      );

  Widget _placeholder() => Container(width: 70, height: 70, decoration: BoxDecoration(color: AppColors.lightGrey.withOpacity(0.3), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.image, color: AppColors.textLight, size: 32));
}