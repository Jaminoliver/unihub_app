import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import '../widgets/unihub_loading_widget.dart';
import 'order_details_screen.dart';

class OrdersScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback? onRefresh;
  
  const OrdersScreen({
    super.key,
    this.initialTab = 0,
    this.onRefresh,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _orderService = OrderService();
  final _authService = AuthService();
  late TabController _tabController;
  
  List<OrderModel> _activeOrders = [];
  List<OrderModel> _completedOrders = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadOrders();
  }

  @override
  void didUpdateWidget(OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onRefresh != oldWidget.onRefresh) {
      _loadOrders();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final orders = await _orderService.getBuyerOrders(user.id);
      
      if (mounted) {
        setState(() {
          _activeOrders = orders
              .where((o) => !['delivered', 'cancelled', 'refunded'].contains(o.orderStatus))
              .toList();
          
          _completedOrders = orders
              .where((o) => ['delivered', 'cancelled', 'refunded'].contains(o.orderStatus))
              .toList()
            ..sort((a, b) {
              final aDate = a.updatedAt ?? a.createdAt;
              final bDate = b.updatedAt ?? b.createdAt;
              return bDate.compareTo(aDate);
            });
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Orders',
          style: AppTextStyles.heading.copyWith(fontSize: 20),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.lightGrey, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryOrange,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.primaryOrange,
              indicatorWeight: 3,
              labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              tabs: [
                _buildTab('Active', _activeOrders.length),
                _buildTab('History', _completedOrders.length),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: UniHubLoader(size: 80))
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _loadOrders,
                  color: AppColors.primaryOrange,
                  child: _buildOrdersList(_activeOrders, true),
                ),
                RefreshIndicator(
                  onRefresh: _loadOrders,
                  color: AppColors.primaryOrange,
                  child: _buildOrdersList(_completedOrders, false),
                ),
              ],
            ),
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: label == 'Active'
                    ? LinearGradient(
                        colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
                      )
                    : null,
                color: label != 'Active' ? AppColors.textLight : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<OrderModel> orders, bool isActive) {
    if (orders.isEmpty) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isActive ? Icons.shopping_bag_outlined : Icons.history,
                    size: 64,
                    color: AppColors.textLight,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  isActive ? 'No Active Orders' : 'No Order History',
                  style: AppTextStyles.heading.copyWith(fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  isActive
                      ? 'Your active orders will appear here'
                      : 'Your completed orders will appear here',
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0, end: 1),
          curve: Curves.easeOut,
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: _buildOrderCard(orders[index]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailsScreen(orderId: order.id),
        ),
      ).then((_) => _loadOrders()),
      child: Container(
        margin: EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.3),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                          style: TextStyle(fontSize: 11, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(order),
                ],
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: order.productImageUrl != null
                            ? Image.network(
                                order.productImageUrl!,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _placeholderImage(),
                              )
                            : _placeholderImage(),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.productName ?? 'Product',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightGrey.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Qty: ${order.quantity}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                _buildPaymentBadge(order.paymentMethod),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (order.isShipped && !order.isDelivered) ...[
                    SizedBox(height: 12),
                    _buildShippingIndicator(),
                  ],
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryOrange.withOpacity(0.1),
                          Color(0xFFFF8C42).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          order.formattedTotal,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                          ),
                        ),
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

  Widget _buildShippingIndicator() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B5CF6).withOpacity(0.1), Color(0xFF9333EA).withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder(
            duration: Duration(seconds: 2),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(value * 10, 0),
                child: Icon(
                  Icons.local_shipping,
                  size: 20,
                  color: Color(0xFF8B5CF6),
                ),
              );
            },
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In Transit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your order is on the way',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.image, color: AppColors.textLight, size: 32),
    );
  }

  Widget _buildStatusBadge(OrderModel order) {
    final statusConfig = {
      'pending': {
        'colors': [Color(0xFFFFF7ED), Color(0xFFF59E0B)],
        'icon': Icons.schedule,
        'text': 'Pending',
      },
      'confirmed': {
        'colors': [Color(0xFFEFF6FF), Color(0xFF3B82F6)],
        'icon': Icons.check_circle,
        'text': 'Processing',
      },
      'shipped': {
        'colors': [Color(0xFFF3E8FF), Color(0xFF8B5CF6)],
        'icon': Icons.local_shipping,
        'text': 'Shipped',
      },
      'delivered': {
        'colors': [Color(0xFFECFDF5), Color(0xFF10B981)],
        'icon': Icons.done_all,
        'text': 'Delivered',
      },
      'cancelled': {
        'colors': [Color(0xFFFEF2F2), Color(0xFFEF4444)],
        'icon': Icons.cancel,
        'text': 'Cancelled',
      },
      'refunded': {
        'colors': [Color(0xFFFEF2F2), Color(0xFFEF4444)],
        'icon': Icons.money_off,
        'text': 'Refunded',
      },
    };

    final config = statusConfig[order.orderStatus] ?? statusConfig['pending']!;
    final colors = config['colors'] as List<Color>;
    final icon = config['icon'] as IconData;
    final text = config['text'] as String;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors[0],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors[1].withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors[1]),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colors[1],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(String method) {
    final config = {
      'full': {'color': AppColors.successGreen, 'label': 'Full'},
      'half': {'color': AppColors.warningYellow, 'label': 'Half'},
      'pod': {'color': AppColors.infoBlue, 'label': 'POD'},
    };

    final data = config[method] ?? config['full']!;
    final color = data['color'] as Color;
    final label = data['label'] as String;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}