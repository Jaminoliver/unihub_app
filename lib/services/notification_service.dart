import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final _random = Random();
  
  final List<NotificationModel> _notifications = [];
  
  RealtimeChannel? _notificationChannel;

  List<NotificationModel> get allNotifications => List.unmodifiable(_notifications);
  
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      _notifications.clear();
      _notifications.addAll((data as List)
          .map((map) => NotificationModel.fromJson(map))
          .toList());
      
      listenForNewNotifications(userId);
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  void listenForNewNotifications(String userId) {
    _notificationChannel?.unsubscribe();
    _notificationChannel = _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newNotification = NotificationModel.fromJson(payload.newRecord);
            _notifications.insert(0, newNotification);
          },
        )
        .subscribe();
  }

  Future<void> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? orderNumber,
    String? orderId,        // ADD THIS parameter
    double? amount,
  }) async {
    try {
      final response = await _supabase.from('notifications').insert({
        'user_id': userId,
        'type': type.toSnakeCase(),
        'title': title,
        'message': message,
        'order_number': orderNumber,
        'order_id': orderId,    // ADD THIS to insert
        'amount': amount,
        'is_read': false,
      }).select().single();
      
      final newNotification = NotificationModel.fromJson(response);
      _notifications.insert(0, newNotification);
      
      print('Notification created: $title');
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      try {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('id', id);
      } catch (e) {
        print('Error marking as read in DB: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      print('Error marking all as read in DB: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    try {
      await _supabase.from('notifications').delete().eq('id', id);
    } catch (e) {
      print('Error deleting notification in DB: $e');
    }
  }

  Future<void> clearAll() async {
    _notifications.clear();
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('notifications').delete().eq('user_id', userId);
    } catch (e) {
      print('Error clearing all notifications in DB: $e');
    }
  }

  void generateDummyNotifications() {
    final dummyNotifications = [
      NotificationModel(
        id: '1',
        type: NotificationType.orderPlaced,
        title: 'Order Placed Successfully',
        message: 'Nike Air Max 270 - Order #ORD-2024-1234',
        orderNumber: 'ORD-2024-1234',
        orderId: 'actual-order-uuid-here',  // ADD THIS with actual order ID
        timestamp: DateTime.now().subtract(Duration(minutes: 5)),
        metadata: {'itemName': 'Nike Air Max 270'},
      ),
      NotificationModel(
        id: '2',
        type: NotificationType.paymentEscrow,
        title: 'Payment Secured',
        message: '₦15,500 has been added to escrow',
        orderNumber: 'ORD-2024-1234',       // ADD THIS
        orderId: 'actual-order-uuid-here',  // ADD THIS with actual order ID
        amount: 15500,
        timestamp: DateTime.now().subtract(Duration(minutes: 6)),
      ),
      NotificationModel(
        id: '3',
        type: NotificationType.orderConfirmed,
        title: 'Order Confirmed',
        message: 'Seller confirmed your order #ORD-2024-1234',
        orderNumber: 'ORD-2024-1234',
        orderId: 'actual-order-uuid-here',  // ADD THIS with actual order ID
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
        isRead: true,
      ),
    ];

    _notifications.addAll(dummyNotifications);
  }
}