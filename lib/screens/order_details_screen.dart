// order_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../constants/app_colors.dart';
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

const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final _orderService = OrderService();
  final _reviewService = ReviewService();
  final _authService = AuthService();

  OrderModel? _order;
  ReviewModel? _existingReview;
  bool _isLoading = true;
  bool _isLoadingReview = false;
  bool _isTimelineExpanded = false;
  bool _isCodeVisible = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final order = await _orderService.getOrderById(widget.orderId);
      setState(() {
        _order = order;
        _isLoading = false;
      });
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
        content: Text(message),
        backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied', isError: false);
  }

  bool get _shouldShowReview => ['delivered', 'cancelled', 'refunded'].contains(_order?.orderStatus);
  bool get _shouldShowDeliveryCode => _order?.deliveryCode != null && !_order!.isDelivered && _order!.orderStatus != 'cancelled' && _order!.orderStatus != 'refunded';
  bool get _shouldShowExpectedDelivery => !['delivered', 'cancelled', 'refunded'].contains(_order?.orderStatus);
  bool get _shouldShowTrackOrder => _order?.orderStatus == 'shipped';

  DateTime get _expectedDeliveryDate => _order!.createdAt.add(Duration(days: 5));

  String get _currentStatusText {
    if (_order!.orderStatus == 'cancelled') return 'Order Cancelled';
    if (_order!.orderStatus == 'refunded') return 'Order Refunded';
    if (_order!.isDelivered) return 'Order Delivered';
    if (_order!.isShipped) return 'Package in Transit';
    if (_order!.orderStatus == 'confirmed') return 'Preparing Your Order';
    return 'Order Placed';
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
      {'title': 'Confirmed', 'subtitle': 'Seller notified', 'isCompleted': true, 'icon': Icons.check_circle, 'color': AppColors.infoBlue},
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
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getCardBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
          onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => OrdersScreen()), (route) => route.isFirst),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: const Text('Order Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
          : _order == null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadOrder,
                  color: AppColors.primaryOrange,
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: [
                      _buildStatusBanner(),
                      if (_shouldShowExpectedDelivery) ...[SizedBox(height: 8), _buildExpectedDelivery()],
                      if (_shouldShowTrackOrder) ...[SizedBox(height: 8), _buildTrackButton()],
                      SizedBox(height: 12),
                      _buildTimeline(),
                      SizedBox(height: 12),
                      _buildProductSection(),
                      SizedBox(height: 12),
                      _buildInfoSection(),
                      if (_shouldShowDeliveryCode) ...[SizedBox(height: 12), _buildDeliveryCode()],
                      if (_shouldShowReview) ...[SizedBox(height: 12), _buildReviewSection()],
                      SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.errorRed.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.error_outline, size: 48, color: AppColors.errorRed),
            ),
            SizedBox(height: 16),
            Text('Order not found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
            SizedBox(height: 6),
            Text('This order could not be loaded', style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context))),
          ],
        ),
      );

  Widget _buildStatusBanner() {
    final configs = {
      'pending': [Color(0xFFF59E0B), 'Pending', Icons.schedule],
      'confirmed': [Color(0xFF3B82F6), 'Processing', Icons.check_circle],
      'shipped': [Color(0xFF8B5CF6), 'Shipped', Icons.local_shipping],
      'delivered': [Color(0xFF10B981), 'Delivered', Icons.done_all],
      'cancelled': [Color(0xFFEF4444), 'Cancelled', Icons.cancel],
      'refunded': [Color(0xFFEF4444), 'Refunded', Icons.money_off],
    };
    final config = configs[_order!.orderStatus] ?? configs['pending']!;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (config[0] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (config[0] as Color).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: config[0] as Color, shape: BoxShape.circle),
            child: Icon(config[2] as IconData, color: Colors.white, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config[1] as String, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                Text(_order!.orderNumber, style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context), fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpectedDelivery() => Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.infoBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.infoBlue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.local_shipping, color: AppColors.infoBlue, size: 18),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Expected Delivery', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
                Text(DateFormat('E, d MMM yyyy').format(_expectedDeliveryDate), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
              ],
            ),
          ],
        ),
      );

  Widget _buildTrackButton() => OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackOrdersScreen())),
        icon: Icon(Icons.map, size: 16),
        label: Text('Track Order'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryOrange,
          side: BorderSide(color: AppColors.primaryOrange),
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

  Widget _buildTimeline() => Container(
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _isTimelineExpanded = !_isTimelineExpanded),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timeline, color: AppColors.primaryOrange, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: Text(_currentStatusText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)))),
                        Icon(_isTimelineExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.getTextMuted(context), size: 20),
                      ],
                    ),
                    SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _progressPercentage / 100,
                        backgroundColor: AppColors.getBorder(context).withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation(AppColors.primaryOrange),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isTimelineExpanded) ...[
              Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),
              Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: _timelineSteps.asMap().entries.map((e) => _buildTimelineStep(e.value, e.key == _timelineSteps.length - 1)).toList(),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _buildTimelineStep(Map<String, dynamic> step, bool isLast) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: step['isCompleted'] ? step['color'] : AppColors.getBorder(context).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(step['icon'], size: 14, color: step['isCompleted'] ? Colors.white : AppColors.getTextMuted(context)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step['title'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: step['isCompleted'] ? AppColors.getTextPrimary(context) : AppColors.getTextMuted(context))),
                Text(step['subtitle'], style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSection() => _buildSection(
        'Product',
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _order!.productImageUrl != null
                  ? Image.network(_order!.productImageUrl!, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_order!.productName ?? 'Product', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)), maxLines: 2, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),
                  Text('Qty ${_order!.quantity}${_order!.selectedSize != null ? ' • Size: ${_order!.selectedSize}' : ''}${_order!.selectedColor != null ? ' • ${_order!.selectedColor}' : ''}', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
                  SizedBox(height: 4),
                  Text(_order!.formattedTotal, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildInfoSection() => _buildSection(
        'Order Info',
        Column(
          children: [
            _infoRow('Order Number', _order!.orderNumber, copyable: true),
            _divider(),
            _infoRow('Order Date', DateFormat('E, d MMM yyyy').format(_order!.createdAt)),
            _divider(),
            _infoRow('Payment', {'full': 'Full Payment', 'half': 'Half Payment', 'pod': 'Pay on Delivery'}[_order!.paymentMethod] ?? _order!.paymentMethod),
            if (!(_order!.isCancelled && _order!.isPayOnDelivery)) ...[
              _divider(),
              _infoRow('Status', _order!.paymentStatusDisplayText, color: _order!.isPaymentCompleted ? AppColors.successGreen : AppColors.warningYellow),
            ],
            _divider(),
            _infoRow('Delivery', _order!.deliveryAddress ?? 'Not provided'),
            _divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                Text(_order!.formattedTotal, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
              ],
            ),
            SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _generateReceipt,
              icon: Icon(Icons.download, size: 16),
              label: Text('Download Receipt'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.getTextPrimary(context),
                side: BorderSide(color: AppColors.getBorder(context)),
                padding: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );

  Widget _buildDeliveryCode() => Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock, color: AppColors.successGreen, size: 18),
                SizedBox(width: 8),
                Text('Delivery Code', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
              ],
            ),
            SizedBox(height: 8),
            Text('Share ONLY when you receive your item', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.getCardBackground(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.successGreen.withOpacity(0.5)),
                    ),
                    child: Center(
                      child: Text(_isCodeVisible ? _order!.deliveryCode! : '●●●●●●', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.successGreen, letterSpacing: _isCodeVisible ? 4 : 3)),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() => _isCodeVisible = !_isCodeVisible),
                  icon: Icon(_isCodeVisible ? Icons.visibility_off : Icons.visibility, color: AppColors.successGreen, size: 18),
                  style: IconButton.styleFrom(backgroundColor: AppColors.getCardBackground(context), padding: EdgeInsets.all(10)),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(_order!.deliveryCode!, 'Delivery code'),
                  icon: Icon(Icons.copy, color: AppColors.successGreen, size: 18),
                  style: IconButton.styleFrom(backgroundColor: AppColors.getCardBackground(context), padding: EdgeInsets.all(10)),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildReviewSection() {
    if (_isLoadingReview) return _buildSection('Review', Center(child: CircularProgressIndicator(color: AppColors.primaryOrange, strokeWidth: 2)));

    if (_existingReview != null) {
      return _buildSection(
        'Your Review',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(5, (i) => Icon(i < _existingReview!.ratingInt ? Icons.star : Icons.star_border, size: 16, color: AppColors.primaryOrange)),
                if (_existingReview!.isVerifiedPurchase) ...[
                  SizedBox(width: 6),
                  Icon(Icons.verified, color: AppColors.successGreen, size: 12),
                  SizedBox(width: 3),
                  Text('Verified', style: TextStyle(fontSize: 10, color: AppColors.successGreen, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
            SizedBox(height: 8),
            Text(_existingReview!.comment, style: TextStyle(fontSize: 13, color: AppColors.getTextPrimary(context), height: 1.4)),
            SizedBox(height: 6),
            Text('Reviewed ${_existingReview!.timeAgo}', style: TextStyle(fontSize: 10, color: AppColors.getTextMuted(context))),
            SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _showLeaveReviewDialog,
              icon: Icon(Icons.edit, size: 14),
              label: Text('Edit Review'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                side: BorderSide(color: AppColors.primaryOrange),
                padding: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    return _buildSection(
      'Rate Your Experience',
      Column(
        children: [
          Text('How satisfied are you with this product?', style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context))),
          SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _showLeaveReviewDialog,
            icon: Icon(Icons.rate_review, size: 16),
            label: Text('Leave Review', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) => Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _infoRow(String label, String value, {bool copyable = false, Color? color}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
                  SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color ?? AppColors.getTextPrimary(context))),
                ],
              ),
            ),
            if (copyable) IconButton(icon: Icon(Icons.copy, size: 16, color: AppColors.getTextMuted(context)), onPressed: () => _copyToClipboard(value, label), padding: EdgeInsets.zero, constraints: BoxConstraints()),
          ],
        ),
      );

  Widget _divider() => Divider(height: 16, color: AppColors.getBorder(context).withOpacity(0.3));

  Widget _placeholder() => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(color: AppColors.getBackground(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3))),
        child: Icon(Icons.image, color: AppColors.getTextMuted(context), size: 24),
      );
}