import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dispute_model.dart';
import 'dispute_chatbot_screen.dart';

class ViewDisputesScreen extends StatefulWidget {
  const ViewDisputesScreen({Key? key}) : super(key: key);

  @override
  State<ViewDisputesScreen> createState() => _ViewDisputesScreenState();
}

class _ViewDisputesScreenState extends State<ViewDisputesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DisputeModel> allDisputes = [];
  bool isLoading = true;
  String? errorMessage;
  RealtimeChannel? _disputeChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDisputes();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disputeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeUpdates() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _disputeChannel = Supabase.instance.client
        .channel('user_disputes_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'disputes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'raised_by_user_id',
            value: user.id,
          ),
          callback: (payload) => _loadDisputes(),
        )
        .subscribe();
  }

  Future<void> _loadDisputes() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final response = await Supabase.instance.client
          .from('disputes')
          .select('''
            *,
            order:orders!disputes_order_id_fkey(
              order_number,
              total_amount,
              order_status,
              payment_method,
              escrow_amount,
              buyer:profiles!orders_buyer_id_fkey(full_name, email),
              seller:sellers!orders_seller_id_fkey(business_name, full_name, email),
              delivery_address:delivery_addresses!orders_delivery_address_id_fkey(address_line, city, state),
              product:products(name, image_urls)
            )
          ''')
          .eq('raised_by_user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          allDisputes = (response as List).map((json) => DisputeModel.fromJson(json)).toList();
          isLoading = false;
          errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load disputes: $e';
          isLoading = false;
        });
      }
    }
  }

  List<DisputeModel> get openDisputes => allDisputes.where((d) => d.isOpen || d.isUnderReview).toList();
  List<DisputeModel> get resolvedDisputes => allDisputes.where((d) => d.isResolved || d.isClosed).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Disputes', 
          style: TextStyle(color: Color(0xFF1F2937), fontSize: 20, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF3B82F6),
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'All (${allDisputes.length})'),
            Tab(text: 'Open (${openDisputes.length})'),
            Tab(text: 'Resolved (${resolvedDisputes.length})'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDisputeList(allDisputes),
                    _buildDisputeList(openDisputes),
                    _buildDisputeList(resolvedDisputes),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DisputeChatbotScreen()),
        ).then((_) => _loadDisputes()),
        icon: const Icon(Icons.add),
        label: const Text('New Dispute'),
        backgroundColor: const Color(0xFF3B82F6),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Oops! Something went wrong', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 8),
            Text(errorMessage ?? 'Unknown error occurred', 
              style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                _loadDisputes();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisputeList(List<DisputeModel> disputes) {
    if (disputes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.gavel, size: 64, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            Text('No disputes found', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text('Your disputes will appear here', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DisputeChatbotScreen()),
              ).then((_) => _loadDisputes()),
              icon: const Icon(Icons.add),
              label: const Text('Raise a Dispute'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDisputes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: disputes.length,
        itemBuilder: (context, index) => _DisputeCard(
          dispute: disputes[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DisputeChatbotScreen(existingDisputeId: disputes[index].id)),
          ).then((_) => _loadDisputes()),
        ),
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final DisputeModel dispute;
  final VoidCallback onTap;

  const _DisputeCard({required this.dispute, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isManualOrder = dispute.orderId.startsWith('manual_');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCEFFF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(dispute.disputeNumber ?? 'N/A', 
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                    ),
                    const SizedBox(width: 8),
                    if (isManualOrder)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 10, color: Colors.orange[700]),
                            const SizedBox(width: 4),
                            Text('Manual', style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange[700])),
                          ],
                        ),
                      ),
                    const Spacer(),
                    _buildStatusChip(),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildProductImage(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isManualOrder ? 'Order (Manual Entry)' : dispute.orderNumber ?? 'Unknown Order',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                          ),
                          const SizedBox(height: 3),
                          Text(dispute.productName ?? 'Product Issue', 
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(_getReasonIcon(), size: 18, color: const Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(dispute.reasonDisplayText, 
                          style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                      ),
                    ],
                  ),
                ),
                if (dispute.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(dispute.description, 
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (dispute.resolution != null && dispute.resolution!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Color(0xFF065F46)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(dispute.resolution!, 
                            style: const TextStyle(
                              fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w500),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(dispute.timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    if (dispute.orderAmount != null) ...[
                      const Spacer(),
                      Text(dispute.formattedAmount, 
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    if (dispute.productImageUrl != null && dispute.productImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          dispute.productImageUrl!,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 50,
              height: 50,
              color: Colors.grey[200],
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.image_not_supported, size: 20, color: Colors.grey[400]),
          ),
        ),
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[100]!, Colors.blue[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.shopping_bag, size: 24, color: Colors.blue[700]),
    );
  }

  Widget _buildStatusChip() {
    final Color bgColor;
    final Color textColor;
    final String label;
    final IconData icon;

    if (dispute.isResolved || dispute.isClosed) {
      bgColor = const Color(0xFFD1FAE5);
      textColor = const Color(0xFF065F46);
      label = dispute.statusDisplayText;
      icon = Icons.check_circle;
    } else if (dispute.isUnderReview) {
      bgColor = const Color(0xFFDCEFFF);
      textColor = const Color(0xFF1E40AF);
      label = dispute.statusDisplayText;
      icon = Icons.hourglass_empty;
    } else {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFF92400E);
      label = dispute.statusDisplayText;
      icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }

  IconData _getReasonIcon() {
    switch (dispute.disputeReason) {
      case 'product_not_received': return Icons.local_shipping;
      case 'wrong_item_received': return Icons.swap_horiz;
      case 'damaged_item': return Icons.broken_image;
      case 'fake_counterfeit': return Icons.warning;
      case 'seller_not_shipping': return Icons.timer_off;
      case 'buyer_not_confirming': return Icons.timer_off;
      case 'refund_not_received': return Icons.money_off;
      case 'payment_issue': return Icons.payment;
      case 'other': return Icons.help_outline;
      default: return Icons.report_problem;
    }
  }
}