import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../widgets/unihub_loading_widget.dart';
import 'order_details_screen.dart';
import 'orders_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  final _notificationService = NotificationService();
  late TabController _tabController;
  
  late Future<void> _notificationsFuture;
  
  // Add a key to force rebuild when notifications change
  int _notificationCount = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notificationsFuture = _notificationService.fetchNotifications();
    
    // Periodically check for new notifications
    _startNotificationPolling();
  }
  
  void _startNotificationPolling() {
    // Check for new notifications every 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        final currentCount = _notificationService.allNotifications.length;
        if (currentCount != _notificationCount) {
          setState(() {
            _notificationCount = currentCount;
          });
        }
        _startNotificationPolling();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(timestamp);
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.orderPlaced:
        return Icons.shopping_bag;
      case NotificationType.paymentEscrow:
        return Icons.security; // Lock icon for escrow
      case NotificationType.escrowReleased:
        return Icons.lock_open; // Unlocked icon for release
      case NotificationType.orderConfirmed:
        return Icons.check_circle;
      case NotificationType.orderShipped:
        return Icons.local_shipping;
      case NotificationType.orderOutForDelivery:
        return Icons.delivery_dining;
      case NotificationType.orderDelivered:
        return Icons.done_all;
      case NotificationType.orderCancelled:
        return Icons.cancel;
      case NotificationType.refundInitiated:
      case NotificationType.refundCompleted:
        return Icons.monetization_on;
      case NotificationType.itemAddedToCart:
        return Icons.add_shopping_cart;
      case NotificationType.priceDropAlert:
        return Icons.trending_down;
      case NotificationType.backInStock:
        return Icons.inventory_2;
      case NotificationType.sellerResponse:
        return Icons.message;
      case NotificationType.reviewReminder:
        return Icons.star;
      case NotificationType.wishlistSale:
        return Icons.favorite;
      case NotificationType.paymentFailed:
        return Icons.error;
      case NotificationType.deliveryDelayed:
        return Icons.schedule;
      case NotificationType.orderReturned:
        return Icons.replay;
      case NotificationType.walletCredited:
        return Icons.account_balance_wallet;
      case NotificationType.newPromo:
        return Icons.local_offer;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.orderPlaced:
      case NotificationType.orderConfirmed:
      case NotificationType.orderDelivered:
        return const Color(0xFF10B981); // Green
      case NotificationType.paymentEscrow:
        return const Color(0xFFFFA500); // Orange for secured payment
      case NotificationType.escrowReleased:
        return const Color(0xFF10B981); // Green for released escrow
      case NotificationType.walletCredited:
      case NotificationType.refundCompleted:
        return const Color(0xFF3B82F6); // Blue
      case NotificationType.orderShipped:
      case NotificationType.orderOutForDelivery:
        return const Color(0xFFFFA500); // Orange
      case NotificationType.priceDropAlert:
      case NotificationType.newPromo:
      case NotificationType.wishlistSale:
        return const Color(0xFFFF6B35); // Brand orange
      case NotificationType.orderCancelled:
      case NotificationType.paymentFailed:
        return const Color(0xFFEF4444); // Red
      case NotificationType.deliveryDelayed:
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  List<NotificationModel> _getFilteredNotifications() {
    final allNotifs = _notificationService.allNotifications;
    if (_tabController.index == 0) return allNotifs;
    return allNotifs.where((n) => !n.isRead).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: AppTextStyles.heading.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Trash icon to clear all notifications
          if (_notificationService.allNotifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.black),
              onPressed: () => _showClearConfirmDialog(),
              tooltip: 'Clear all notifications',
            ),
          // Mark all read button
          if (_notificationService.unreadCount > 0)
            TextButton(
              onPressed: () async {
                await _notificationService.markAllAsRead();
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text(
                'Mark all read',
                style: TextStyle(color: Color(0xFFFF6B35), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF6B35),
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: const Color(0xFFFF6B35),
          onTap: (_) => setState(() {}),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('All'),
                  if (_notificationService.allNotifications.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _tabController.index == 0 ? Color(0xFFFF6B35) : AppColors.textLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_notificationService.allNotifications.length}',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Unread'),
                  if (_notificationService.unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _tabController.index == 1 ? Color(0xFFFF6B35) : AppColors.textLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_notificationService.unreadCount}',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<void>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: UniHubLoader(size: 80));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading notifications'));
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationsList(),
              _buildNotificationsList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationsList() {
    final notifications = _getFilteredNotifications();

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 64,
                color: AppColors.textLight.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tabController.index == 0 ? 'No notifications yet' : 'No unread notifications',
              style: AppTextStyles.subheading.copyWith(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final icon = _getNotificationIcon(notification.type);
    final color = _getNotificationColor(notification.type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Color(0xFFFF6B35).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead 
              ? Colors.grey.withOpacity(0.2) 
              : Color(0xFFFF6B35).withOpacity(0.3), 
          width: 1
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) async {
          await _notificationService.deleteNotification(notification.id);
          setState(() {});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification deleted'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        child: InkWell(
          onTap: () async {
            if (!notification.isRead) {
              await _notificationService.markAsRead(notification.id);
              setState(() {});
            }
            // Navigate based on notification type
            _handleNotificationTap(notification);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTextStyles.body.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(0xFFFF6B35),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          color: AppColors.textLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: AppColors.textLight),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(notification.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

 void _handleNotificationTap(NotificationModel notification) {
  // Navigate based on notification type
  switch (notification.type) {
    case NotificationType.orderPlaced:
    case NotificationType.paymentEscrow:
    case NotificationType.orderConfirmed:
    case NotificationType.orderShipped:
    case NotificationType.orderOutForDelivery:
    case NotificationType.orderCancelled:
    case NotificationType.refundInitiated:
    case NotificationType.refundCompleted:
    case NotificationType.escrowReleased:
      // Navigate to order details if orderId exists
      if (notification.orderId != null) {  // CHANGED: Use orderId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailsScreen(orderId: notification.orderId!),  // CHANGED
          ),
        );
      }
      break;
    
    case NotificationType.orderDelivered:
      // Navigate to delivered orders tab
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrdersScreen(initialTab: 1), // Index 1 = History tab (completed orders)
        ),
      );
      break;
    
    default:
      // For other notifications, don't navigate
      break;
  }
}
  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Notifications?'),
        content: const Text('This will permanently delete all your notifications. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _notificationService.clearAll();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications cleared')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}