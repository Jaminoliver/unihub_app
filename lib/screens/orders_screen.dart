// orders_screen.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import '../widgets/unihub_loading_widget.dart';
import 'order_details_screen.dart';

const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class OrdersScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback? onRefresh;
  
  const OrdersScreen({super.key, this.initialTab = 0, this.onRefresh});

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
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadOrders();
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
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final orders = await _orderService.getBuyerOrders(user.id);
      
      if (mounted) {
        setState(() {
          _activeOrders = orders.where((o) => !['delivered', 'cancelled', 'refunded'].contains(o.orderStatus)).toList();
          _completedOrders = orders.where((o) => ['delivered', 'cancelled', 'refunded'].contains(o.orderStatus)).toList()
            ..sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getCardBackground(context),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: const Text('My Orders', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5))),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryOrange,
              unselectedLabelColor: AppColors.getTextMuted(context),
              indicatorColor: AppColors.primaryOrange,
              indicatorWeight: 2,
              labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              tabs: [
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Active'), if (_activeOrders.isNotEmpty) ...[SizedBox(width: 6), _badge(_activeOrders.length, true)]])),
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('History'), if (_completedOrders.isNotEmpty) ...[SizedBox(width: 6), _badge(_completedOrders.length, false)]])),
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
                RefreshIndicator(onRefresh: _loadOrders, color: AppColors.primaryOrange, child: _buildList(_activeOrders, true)),
                RefreshIndicator(onRefresh: _loadOrders, color: AppColors.primaryOrange, child: _buildList(_completedOrders, false)),
              ],
            ),
    );
  }

  Widget _badge(int count, bool isActive) => Container(
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      gradient: isActive ? kOrangeGradient : null,
      color: isActive ? null : AppColors.getTextMuted(context),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text('$count', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
  );

  Widget _buildList(List<OrderModel> orders, bool isActive) {
    if (orders.isEmpty) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.primaryOrange.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(isActive ? Icons.shopping_bag_outlined : Icons.history, size: 48, color: AppColors.primaryOrange),
                ),
                SizedBox(height: 16),
                Text(isActive ? 'No Active Orders' : 'No Order History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                SizedBox(height: 6),
                Text(isActive ? 'Your active orders will appear here' : 'Your completed orders will appear here', style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context))),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => SizedBox(height: 8),
      itemBuilder: (_, i) => _buildOrderCard(orders[i]),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: order.id))).then((_) => _loadOrders()),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: order.productImageUrl != null
                  ? Image.network(order.productImageUrl!, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(order.productName ?? 'Product', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(width: 8),
                      _statusBadge(order.orderStatus),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(order.orderNumber, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.getTextMuted(context), fontFamily: 'monospace')),
                      SizedBox(width: 8),
                      Text('•', style: TextStyle(color: AppColors.getTextMuted(context))),
                      SizedBox(width: 8),
                      Text('${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Text(order.formattedTotal, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                      SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.getTextMuted(context).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('Qty ${order.quantity}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.getTextMuted(context))),
                      ),
                      Spacer(),
                      Icon(Icons.chevron_right, size: 18, color: AppColors.getTextMuted(context)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(color: AppColors.getBackground(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3))),
    child: Icon(Icons.image, color: AppColors.getTextMuted(context), size: 24),
  );

  Widget _statusBadge(String status) {
    final configs = {
      'pending': [Color(0xFFF59E0B), 'Pending'],
      'confirmed': [Color(0xFF3B82F6), 'Processing'],
      'shipped': [Color(0xFF8B5CF6), 'Shipped'],
      'delivered': [Color(0xFF10B981), 'Delivered'],
      'cancelled': [Color(0xFFEF4444), 'Cancelled'],
      'refunded': [Color(0xFFEF4444), 'Refunded'],
    };
    final config = configs[status] ?? configs['pending']!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: (config[0] as Color).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(config[1] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: config[0] as Color)),
    );
  }
}