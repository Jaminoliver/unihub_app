import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import '../widgets/unihub_loading_widget.dart';
import 'order_details_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  final _orderService = OrderService();
  final _authService = AuthService();
  late TabController _tabController;
  
  List<OrderModel> _activeOrders = [];
  List<OrderModel> _completedOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    // This first setState is safe, no await before it
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user == null) {
        // --- FIX: Added mounted check ---
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final orders = await _orderService.getBuyerOrders(user.id);
      
      // --- FIX: Added mounted check after await ---
      if (mounted) {
        setState(() {
          _activeOrders = orders.where((o) => !['delivered', 'cancelled', 'refunded'].contains(o.orderStatus)).toList();
          _completedOrders = orders.where((o) => ['delivered', 'cancelled', 'refunded'].contains(o.orderStatus)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      // --- FIX: Added mounted check around all setState/Scaffold calls ---
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Orders', style: AppTextStyles.heading.copyWith(fontSize: 16)),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color(0xFFFF6B35),
          unselectedLabelColor: Colors.grey,
          indicatorColor: Color(0xFFFF6B35),
          indicatorWeight: 3,
          tabs: [
            _buildTab('Active', _activeOrders.length),
            _buildTab('History', _completedOrders.length),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: UniHubLoader(size: 80))
          : RefreshIndicator(
              onRefresh: _loadOrders,
              color: Color(0xFFFF6B35),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrdersList(_activeOrders, true),
                  _buildOrdersList(_completedOrders, false),
                ],
              ),
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
            SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: label == 'Active' ? Color(0xFFFF6B35) : Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<OrderModel> orders, bool isActive) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? Icons.shopping_bag_outlined : Icons.history, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(isActive ? 'No Active Orders' : 'No Order History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            SizedBox(height: 8),
            Text(isActive ? 'Your active orders will appear here' : 'Your completed orders will appear here', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: order.id))).then((_) => _loadOrders()),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.orderNumber, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                      SizedBox(height: 4),
                      Text('${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                _buildStatusBadge(order.orderStatus, order.statusDisplayText),
              ],
            ),
            Divider(height: 20),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: order.productImageUrl != null
                      ? Image.network(order.productImageUrl!, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderImage())
                      : _placeholderImage(),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.productName ?? 'Product', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Text('Qty: ${order.quantity}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          SizedBox(width: 12),
                          _buildPaymentBadge(order.paymentMethod),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Amount', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    SizedBox(height: 2),
                    Text(order.formattedTotal, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                  ],
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Icon(Icons.image, color: Colors.grey[400]));
  }

  Widget _buildStatusBadge(String status, String displayText) {
    final colors = {
      'pending': [Colors.orange[50]!, Colors.orange[700]!],
      'confirmed': [Colors.blue[50]!, Colors.blue[700]!],
      'shipped': [Colors.purple[50]!, Colors.purple[700]!],
      'delivered': [Colors.green[50]!, Colors.green[700]!],
      'cancelled': [Colors.red[50]!, Colors.red[700]!],
      'refunded': [Colors.red[50]!, Colors.red[700]!],
    };
    final color = colors[status] ?? [Colors.grey[200]!, Colors.grey[700]!];
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color[0], borderRadius: BorderRadius.circular(8)),
      child: Text(displayText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color[1])),
    );
  }

  Widget _buildPaymentBadge(String method) {
    // --- FIX: Changed 'pay_on_delivery' to 'pod' ---
    final colors = {'full': Colors.green, 'half': Colors.orange, 'pod': Colors.blue};
    final labels = {'full': 'Full', 'half': 'Half', 'pod': 'POD'};
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: (colors[method] ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(labels[method] ?? method, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors[method] ?? Colors.grey)),
    );
  }
}