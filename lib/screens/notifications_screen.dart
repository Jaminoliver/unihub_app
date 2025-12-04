import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../widgets/unihub_loading_widget.dart';
import 'order_details_screen.dart';
import 'orders_screen.dart';
import '../utils/deep_link_handler.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  final _notificationService = NotificationService();
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notificationService.fetchNotifications();
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
      case NotificationType.orderReturned:
        return Icons.keyboard_return;
      case NotificationType.paymentEscrow:
      case NotificationType.escrowReleased:
        return Icons.lock;
      case NotificationType.paymentReleased:
      case NotificationType.walletCredited:
        return Icons.account_balance_wallet;
      case NotificationType.paymentFailed:
        return Icons.error_outline;
      case NotificationType.refundInitiated:
      case NotificationType.refundCompleted:
        return Icons.currency_exchange;
      case NotificationType.disputeRaised:
      case NotificationType.disputeCreated:
      case NotificationType.disputeRaisedAgainst:
      case NotificationType.newDispute:
        return Icons.report_problem;
      case NotificationType.disputeResolved:
      case NotificationType.disputeStatusChanged:
        return Icons.check_circle_outline;
      case NotificationType.itemAddedToCart:
        return Icons.add_shopping_cart;
      case NotificationType.priceDropAlert:
      case NotificationType.wishlistSale:
        return Icons.trending_down;
      case NotificationType.backInStock:
        return Icons.inventory;
      case NotificationType.sellerResponse:
        return Icons.reply;
      case NotificationType.reviewReminder:
        return Icons.rate_review;
      case NotificationType.deliveryDelayed:
        return Icons.schedule;
      case NotificationType.newPromo:
        return Icons.celebration;
      case NotificationType.adminNotification:
        return Icons.admin_panel_settings;
      case NotificationType.adminDeal:
        return Icons.local_fire_department;
      case NotificationType.adminAnnouncement:
        return Icons.campaign;
      case NotificationType.adminAlert:
        return Icons.warning;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.orderPlaced:
      case NotificationType.itemAddedToCart:
        return Color(0xFFFF6B35);
      case NotificationType.orderConfirmed:
      case NotificationType.orderDelivered:
      case NotificationType.paymentReleased:
      case NotificationType.refundCompleted:
      case NotificationType.disputeResolved:
      case NotificationType.walletCredited:
        return Color(0xFF4CAF50);
      case NotificationType.orderShipped:
      case NotificationType.adminAnnouncement:
        return Color(0xFF2196F3);
      case NotificationType.orderOutForDelivery:
      case NotificationType.backInStock:
        return Color(0xFF00BCD4);
      case NotificationType.orderCancelled:
      case NotificationType.paymentFailed:
      case NotificationType.adminAlert:
        return Color(0xFFF44336);
      case NotificationType.orderReturned:
      case NotificationType.refundInitiated:
        return Color(0xFFFF5722);
      case NotificationType.paymentEscrow:
      case NotificationType.escrowReleased:
        return Color(0xFF9C27B0);
      case NotificationType.disputeRaised:
      case NotificationType.disputeCreated:
      case NotificationType.disputeRaisedAgainst:
      case NotificationType.newDispute:
      case NotificationType.disputeStatusChanged:
      case NotificationType.deliveryDelayed:
        return Color(0xFFFF9800);
      case NotificationType.priceDropAlert:
      case NotificationType.wishlistSale:
      case NotificationType.newPromo:
      case NotificationType.adminDeal:
        return Color(0xFFFF6B35);
      case NotificationType.sellerResponse:
      case NotificationType.reviewReminder:
        return Color(0xFF607D8B);
      case NotificationType.adminNotification:
        return Color(0xFF6366F1);
    }
  }

  List<NotificationModel> _getFilteredNotifications(List<NotificationModel> allNotifs) {
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
          StreamBuilder<int>(
            stream: _notificationService.unreadCountStream,
            initialData: _notificationService.unreadCount,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              
              return Row(
                children: [
                  if (_notificationService.allNotifications.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.black),
                      onPressed: () => _showClearConfirmDialog(),
                      tooltip: 'Clear all notifications',
                    ),
                  if (unreadCount > 0)
                    TextButton(
                      onPressed: () async {
                        await _notificationService.markAllAsRead();
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
                        style: TextStyle(
                          color: Color(0xFFFF6B35),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: StreamBuilder<List<NotificationModel>>(
            stream: _notificationService.notificationsStream,
            initialData: _notificationService.allNotifications,
            builder: (context, snapshot) {
              final allNotifs = snapshot.data ?? [];
              final unreadCount = allNotifs.where((n) => !n.isRead).length;
              
              return TabBar(
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
                        if (allNotifs.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _tabController.index == 0 ? Color(0xFFFF6B35) : AppColors.textLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${allNotifs.length}',
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
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _tabController.index == 1 ? Color(0xFFFF6B35) : AppColors.textLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.notificationsStream,
        initialData: _notificationService.allNotifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && 
              _notificationService.allNotifications.isEmpty) {
            return Center(child: UniHubLoader(size: 80));
          }

          final allNotifs = snapshot.data ?? [];
          
          return TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationsList(allNotifs),
              _buildNotificationsList(allNotifs),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationsList(List<NotificationModel> allNotifs) {
    final notifications = _getFilteredNotifications(allNotifs);

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
            await _handleNotificationTap(notification);
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              if (notification.imageUrl != null && notification.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image.network(
                    notification.imageUrl!,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => SizedBox.shrink(),
                  ),
                ),
              
              Padding(
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _trackNotificationAnalytics(NotificationModel notification) async {
  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    
    if (userId == null || notification.campaignId == null) {
      print('⚠️ Cannot track analytics: userId=$userId, campaignId=${notification.campaignId}');
      return;
    }

    print('📊 ========== TRACKING NOTIFICATION ANALYTICS ==========');
    print('📊 Campaign ID: ${notification.campaignId}');
    print('📊 Notification ID: ${notification.id}');
    print('📊 User ID: $userId');

    // Update opened_at using RPC
    print('📊 Calling update_notification_opened RPC...');
    await supabase.rpc('update_notification_opened', params: {
      'p_campaign_id': notification.campaignId,
      'p_user_id': userId,
    });
    print('✅ Opened timestamp updated');

    // Increment campaign opened count - FIXED PARAMETER NAME
    print('📊 Calling increment_campaign_opened RPC...');
    await supabase.rpc('increment_campaign_opened', params: {
      'campaign_uuid': notification.campaignId,  // ✅ CHANGED FROM 'campaign_id' to 'campaign_uuid'
    });
    print('✅ Campaign opened count incremented');

    // If there's a deep link, track the click
    if (notification.deepLink != null && notification.deepLink!.isNotEmpty) {
      print('📊 Deep link exists, tracking click...');
      
      // Update clicked_at using RPC
      print('📊 Calling update_notification_clicked RPC...');
      await supabase.rpc('update_notification_clicked', params: {
        'p_campaign_id': notification.campaignId,
        'p_user_id': userId,
      });
      print('✅ Clicked timestamp updated');

      // Increment campaign clicked count - FIXED PARAMETER NAME
      print('📊 Calling increment_campaign_clicked RPC...');
      await supabase.rpc('increment_campaign_clicked', params: {
        'campaign_uuid': notification.campaignId,  // ✅ CHANGED FROM 'campaign_id' to 'campaign_uuid'
      });
      print('✅ Campaign clicked count incremented');
    }

    print('✅ ========== ANALYTICS TRACKED SUCCESSFULLY ==========');
  } catch (e, stackTrace) {
    print('❌ ========== ERROR TRACKING ANALYTICS ==========');
    print('❌ Error: $e');
    print('❌ Stack trace: $stackTrace');
  }
}

  // ✅ UPDATED WITH ANALYTICS TRACKING
  Future<void> _handleNotificationTap(NotificationModel notification) async {
    print('🔔 ========== NOTIFICATION TAP HANDLER START ==========');
    print('🔔 Notification ID: ${notification.id}');
    print('🔔 Notification Title: ${notification.title}');
    print('🔔 Notification Type: ${notification.type}');
    print('🔔 Is Admin Notification: ${notification.isAdminNotification}');
    print('🔔 Campaign ID: ${notification.campaignId}');
    print('🔔 Deep Link: ${notification.deepLink}');
    print('🔔 Order ID: ${notification.orderId}');
    
    // Mark as read
    if (!notification.isRead) {
      print('📝 Marking notification as read...');
      await _notificationService.markAsRead(notification.id);
      print('✅ Notification marked as read');
    }
    
    // ✅ Track analytics for admin notifications
    if (notification.isAdminNotification && notification.campaignId != null) {
      await _trackNotificationAnalytics(notification);
    }
    
    // Handle admin notifications with deep links FIRST
    if (notification.isAdminNotification && 
        notification.deepLink != null && 
        notification.deepLink!.isNotEmpty) {
      print('🎯 ADMIN NOTIFICATION WITH DEEP LINK DETECTED');
      print('🎯 Deep Link Value: ${notification.deepLink}');
      print('🎯 Calling DeepLinkHandler.navigate()...');
      
      DeepLinkHandler.navigate(context, notification.deepLink!);
      
      print('🎯 DeepLinkHandler.navigate() returned');
      print('🔔 ========== NOTIFICATION TAP HANDLER END (Admin) ==========');
      return;
    }
    
    print('ℹ️ Not an admin notification with deep link, checking notification type...');
    
    // Handle regular notification types
    switch (notification.type) {
      case NotificationType.orderPlaced:
      case NotificationType.orderConfirmed:
      case NotificationType.orderShipped:
      case NotificationType.orderOutForDelivery:
      case NotificationType.orderDelivered:
      case NotificationType.orderCancelled:
      case NotificationType.orderReturned:
      case NotificationType.deliveryDelayed:
        print('📦 ORDER NOTIFICATION - Order ID: ${notification.orderId}');
        if (notification.orderId != null) {
          print('✅ Navigating to order details...');
          Navigator.pushNamed(
            context,
            '/order-details',
            arguments: {'orderId': notification.orderId}
          );
        } else {
          print('⚠️ No order ID found');
        }
        break;
      
      case NotificationType.paymentEscrow:
      case NotificationType.paymentReleased:
      case NotificationType.escrowReleased:
      case NotificationType.walletCredited:
      case NotificationType.refundInitiated:
      case NotificationType.refundCompleted:
        print('💰 PAYMENT NOTIFICATION - Navigating to wallet');
        Navigator.pushNamed(context, '/wallet');
        break;
      
      case NotificationType.disputeRaised:
      case NotificationType.disputeCreated:
      case NotificationType.disputeRaisedAgainst:
      case NotificationType.newDispute:
      case NotificationType.disputeResolved:
      case NotificationType.disputeStatusChanged:
        print('⚖️ DISPUTE NOTIFICATION - Order ID: ${notification.orderId}');
        if (notification.orderId != null) {
          print('✅ Navigating to dispute details...');
          Navigator.pushNamed(
            context,
            '/dispute-details',
            arguments: {'orderId': notification.orderId}
          );
        } else {
          print('⚠️ No order ID found');
        }
        break;
      
      case NotificationType.itemAddedToCart:
        print('🛒 CART NOTIFICATION - Navigating to cart');
        Navigator.pushNamed(context, '/cart');
        break;
      
      case NotificationType.priceDropAlert:
      case NotificationType.backInStock:
      case NotificationType.wishlistSale:
        print('❤️ WISHLIST NOTIFICATION - Navigating to wishlist');
        Navigator.pushNamed(context, '/wishlist');
        break;
      
      case NotificationType.reviewReminder:
        print('⭐ REVIEW NOTIFICATION - Order ID: ${notification.orderId}');
        if (notification.orderId != null) {
          print('✅ Navigating to write review...');
          Navigator.pushNamed(
            context,
            '/write-review',
            arguments: {'orderId': notification.orderId}
          );
        } else {
          print('⚠️ No order ID found');
        }
        break;
      
      case NotificationType.sellerResponse:
      case NotificationType.newPromo:
      case NotificationType.paymentFailed:
      case NotificationType.adminNotification:
      case NotificationType.adminDeal:
      case NotificationType.adminAnnouncement:
      case NotificationType.adminAlert:
        print('ℹ️ No specific action for notification type: ${notification.type}');
        break;
    }
    
    print('🔔 ========== NOTIFICATION TAP HANDLER END ==========');
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