import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../widgets/unihub_loading_widget.dart';
import 'order_details_screen.dart';
import '../utils/deep_link_handler.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
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

  Future<void> _handleRefresh() async {
    await _notificationService.fetchNotifications();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(timestamp);
  }

  Map<String, List<NotificationModel>> _groupNotifications(
    List<NotificationModel> notifications,
  ) {
    final Map<String, List<NotificationModel>> grouped = {};
    final now = DateTime.now();

    for (final notif in notifications) {
      final diff = now.difference(notif.timestamp).inDays;
      String key;

      if (diff == 0) {
        key = 'Today';
      } else if (diff == 1) {
        key = 'Yesterday';
      } else if (diff < 7) {
        key = 'This Week';
      } else {
        key = 'Earlier';
      }

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(notif);
    }

    return grouped;
  }

  Map<String, dynamic> _getColorTheme(NotificationType type) {
    final themes = {
      NotificationType.orderPlaced: {
        'accent': Color(0xFFF59E0B),
        'bg': Color(0xFFFFF7ED),
        'icon': Icons.shopping_bag,
      },
      NotificationType.orderConfirmed: {
        'accent': Color(0xFF3B82F6),
        'bg': Color(0xFFEFF6FF),
        'icon': Icons.check_circle,
      },
      NotificationType.orderShipped: {
        'accent': Color(0xFF8B5CF6),
        'bg': Color(0xFFF3E8FF),
        'icon': Icons.local_shipping,
      },
      NotificationType.orderDelivered: {
        'accent': Color(0xFF10B981),
        'bg': Color(0xFFECFDF5),
        'icon': Icons.done_all,
      },
      NotificationType.orderCancelled: {
        'accent': Color(0xFFEF4444),
        'bg': Color(0xFFFEF2F2),
        'icon': Icons.cancel,
      },
      NotificationType.paymentEscrow: {
        'accent': Color(0xFF3B82F6),
        'bg': Color(0xFFEFF6FF),
        'icon': Icons.shield,
        'badge': 'Escrow',
      },
      NotificationType.escrowReleased: {
        'accent': Color(0xFF3B82F6),
        'bg': Color(0xFFEFF6FF),
        'icon': Icons.shield_outlined,
      },
      NotificationType.paymentReleased: {
        'accent': Color(0xFF10B981),
        'bg': Color(0xFFECFDF5),
        'icon': Icons.account_balance_wallet,
      },
      'admin': {
        'accent': Color(0xFF6B7280),
        'bg': Color(0xFFF9FAFB),
        'icon': Icons.campaign,
      },
    };

    if (type.toString().contains('admin') || type.toString().contains('announcement')) {
      return themes['admin']!;
    }

    return themes[type] ?? {
      'accent': Color(0xFF9CA3AF),
      'bg': Color(0xFFF9FAFB),
      'icon': Icons.notifications,
    };
  }

  List<NotificationModel> _getFiltered(List<NotificationModel> all) {
    return _tabController.index == 0 ? all : all.where((n) => !n.isRead).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.notificationsStream,
        initialData: _notificationService.allNotifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _notificationService.allNotifications.isEmpty) {
            return Center(child: UniHubLoader(size: 80));
          }

          final all = snapshot.data ?? [];
          final filtered = _getFiltered(all);

          if (filtered.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.primaryOrange,
            child: _buildNotificationsList(filtered),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.getCardBackground(context),
      elevation: 0,
      automaticallyImplyLeading: false,
      iconTheme: IconThemeData(color: AppColors.getTextPrimary(context)),
      title: Text(
        'Notifications',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryOrange,
        ),
      ),
      centerTitle: false,
      actions: [
        StreamBuilder<int>(
          stream: _notificationService.unreadCountStream,
          initialData: _notificationService.unreadCount,
          builder: (context, snapshot) {
            final unread = snapshot.data ?? 0;

            if (unread == 0) return SizedBox(width: 8);

            return TextButton(
              onPressed: () async {
                await _notificationService.markAllAsRead();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text('All marked as read'),
                        ],
                      ),
                      backgroundColor: AppColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: EdgeInsets.all(16),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 1),
            ),
          ),
          child: StreamBuilder<List<NotificationModel>>(
            stream: _notificationService.notificationsStream,
            initialData: _notificationService.allNotifications,
            builder: (context, snapshot) {
              final all = snapshot.data ?? [];
              final unread = all.where((n) => !n.isRead).length;

              return TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryOrange,
                unselectedLabelColor: AppColors.getTextMuted(context),
                indicatorColor: AppColors.primaryOrange,
                indicatorWeight: 3,
                labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                unselectedLabelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                onTap: (_) => setState(() {}),
                tabs: [
                  _buildTab('All', all.length),
                  _buildTab('Unread', unread),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    final isActive = (_tabController.index == 0 && label == 'All') ||
        (_tabController.index == 1 && label == 'Unread');

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
                gradient: isActive
                    ? LinearGradient(
                        colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
                      )
                    : null,
                color: !isActive ? AppColors.getTextMuted(context) : null,
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

  Widget _buildNotificationsList(List<NotificationModel> notifications) {
    final grouped = _groupNotifications(notifications);

    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, groupIndex) {
        final key = grouped.keys.elementAt(groupIndex);
        final notifs = grouped[key]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (groupIndex > 0) SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextMuted(context),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...notifs.asMap().entries.map((entry) {
              final index = entry.key;
              final notif = entry.value;

              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 300 + (index * 50)),
                tween: Tween<double>(begin: 0, end: 1),
                curve: Curves.easeOut,
                builder: (context, double value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: _buildNotificationCard(notif),
                    ),
                  );
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notif) {
    final theme = _getColorTheme(notif.type);
    final accentColor = theme['accent'] as Color;
    final bgColor = theme['bg'] as Color;
    final icon = theme['icon'] as IconData;
    final badge = theme['badge'] as String?;

    final isUnread = !notif.isRead;

    return GestureDetector(
      onTap: () => _handleTap(notif),
      child: Container(
        margin: EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(16),
          border: isUnread
              ? Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.4),
                  width: 2,
                )
              : Border.all(
                  color: AppColors.getBorder(context).withOpacity(0.3),
                  width: 0.5,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isUnread ? 0.08 : 0.06),
              blurRadius: isUnread ? 16 : 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: isUnread ? 6 : 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      bgColor.withOpacity(0.3),
                      bgColor.withOpacity(0.0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.only(left: isUnread ? 6 : 4),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, size: 20, color: accentColor),
                        ),

                        SizedBox(width: 12),

                        Expanded(
                          child: Row(
                            children: [
                              if (isUnread)
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: EdgeInsets.only(right: 10, top: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primaryOrange,
                                        Color(0xFFFF8C42),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryOrange.withOpacity(0.5),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (badge != null) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor,
                                  accentColor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  badge,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: 12),

                    Text(
                      notif.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextPrimary(context),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (notif.imageUrl != null && notif.imageUrl!.isNotEmpty) ...[
                      SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: notif.imageUrl!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 150,
                            color: AppColors.getBorder(context).withOpacity(0.3),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(accentColor),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => SizedBox.shrink(),
                        ),
                      ),
                    ],

                    SizedBox(height: 12),

                    Container(
                      height: 1,
                      color: accentColor.withOpacity(0.15),
                    ),

                    SizedBox(height: 10),

                    Row(
                      children: [
                        if (notif.orderNumber != null) ...[
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: accentColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tag, size: 11, color: accentColor),
                                SizedBox(width: 4),
                                Text(
                                  '#${notif.orderNumber}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Spacer(),
                        ],
                        Icon(Icons.access_time, size: 12, color: AppColors.getTextMuted(context)),
                        SizedBox(width: 4),
                        Text(
                          _formatTimestamp(notif.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextMuted(context),
                          ),
                        ),
                      ],
                    ),

                    if (notif.amount != null && notif.amount! > 0) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withOpacity(0.1),
                              accentColor.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accentColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Amount',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.getTextMuted(context),
                              ),
                            ),
                            Text(
                              '₦${NumberFormat("#,##0", "en_US").format(notif.amount)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
                  color: AppColors.getBorder(context).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _tabController.index == 0
                      ? Icons.notifications_off_outlined
                      : Icons.mark_email_read_outlined,
                  size: 64,
                  color: AppColors.getTextMuted(context),
                ),
              ),
              SizedBox(height: 20),
              Text(
                _tabController.index == 0
                    ? 'No Notifications'
                    : 'All Caught Up!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
              ),
              SizedBox(height: 8),
              Text(
                _tabController.index == 0
                    ? 'Your notifications will appear here'
                    : 'You\'ve read all notifications',
                style: TextStyle(fontSize: 14, color: AppColors.getTextMuted(context)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleTap(NotificationModel notif) async {
    if (!notif.isRead) {
      await _notificationService.markAsRead(notif.id);
    }

    if (notif.isAdminNotification && notif.campaignId != null) {
      await _trackAnalytics(notif);
    }

    if (notif.isAdminNotification &&
        notif.deepLink != null &&
        notif.deepLink!.isNotEmpty) {
      DeepLinkHandler.navigate(context, notif.deepLink!);
      return;
    }

    final orderTypes = [
      NotificationType.orderPlaced,
      NotificationType.orderConfirmed,
      NotificationType.orderShipped,
      NotificationType.orderOutForDelivery,
      NotificationType.orderDelivered,
      NotificationType.orderCancelled,
      NotificationType.orderReturned,
      NotificationType.deliveryDelayed,
    ];
    
    if (orderTypes.contains(notif.type)) {
      String? orderIdToUse = notif.orderId;
      
      if (orderIdToUse == null || orderIdToUse.isEmpty) {
        if (notif.orderNumber != null) {
          try {
            final supabase = Supabase.instance.client;
            final result = await supabase
                .from('orders')
                .select('id')
                .eq('order_number', notif.orderNumber!)
                .single();
            
            orderIdToUse = result['id'] as String?;
          } catch (e) {
            print('Error fetching order ID: $e');
          }
        }
      }
      
      if (orderIdToUse != null && orderIdToUse.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailsScreen(orderId: orderIdToUse!),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open order details'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return;
    }

    switch (notif.type) {
      case NotificationType.paymentEscrow:
      case NotificationType.paymentReleased:
      case NotificationType.escrowReleased:
      case NotificationType.walletCredited:
        break;
      default:
        break;
    }
  }

  Future<void> _trackAnalytics(NotificationModel notif) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null || notif.campaignId == null) return;

      await supabase.rpc('update_notification_opened', params: {
        'p_campaign_id': notif.campaignId,
        'p_user_id': userId,
      });

      await supabase.rpc('increment_campaign_opened', params: {
        'campaign_uuid': notif.campaignId,
      });
    } catch (e) {
      print('Error tracking: $e');
    }
  }
}