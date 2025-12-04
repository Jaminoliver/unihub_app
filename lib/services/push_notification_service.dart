import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  String? _currentUserTopic;

  Future<void> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    final token = await _fcm.getToken();
    print('📱📱📱 NEW FCM TOKEN 📱📱📱');
    print(token);
    print('📱📱📱 END TOKEN 📱📱📱');

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(InitializationSettings(android: android, iOS: ios));

    // Save token immediately if user is logged in
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null && token != null) {
      await _saveTokenToDatabase(currentUser.id, token);
    }

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null && session.user != null) {
        _subscribeToUserTopic(session.user.id);
        
        // Save token to database
        final newToken = await _fcm.getToken();
        if (newToken != null) {
          await _saveTokenToDatabase(session.user.id, newToken);
        }
      } else {
        _unsubscribeFromCurrentUserTopic();
        await _removeTokenFromDatabase();
      }
    });

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      print('🔄 FCM Token refreshed: $newToken');
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await _saveTokenToDatabase(userId, newToken);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 ========== FOREGROUND NOTIFICATION RECEIVED ==========');
      print('🔔 Message ID: ${message.messageId}');
      print('🔔 Notification: ${message.notification?.toMap()}');
      print('🔔 Data: ${message.data}');
      
      if (message.notification != null) {
        print('📬 Title: ${message.notification!.title}');
        print('📬 Body: ${message.notification!.body}');
        
        _showLocalNotification(
          message.notification!.title ?? 'UniHub',
          message.notification!.body ?? '',
          message.data,
        );
      }
      print('🔔 ========== FOREGROUND NOTIFICATION END ==========');
    });

    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🚀 ========== APP OPENED FROM TERMINATED STATE ==========');
        print('🚀 Message ID: ${message.messageId}');
        print('🚀 Data: ${message.data}');
        _handleNotificationTap(message.data);
        print('🚀 ========== TERMINATED STATE HANDLER END ==========');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔄 ========== APP OPENED FROM BACKGROUND STATE ==========');
      print('🔄 Message ID: ${message.messageId}');
      print('🔄 Data: ${message.data}');
      _handleNotificationTap(message.data);
      print('🔄 ========== BACKGROUND STATE HANDLER END ==========');
    });
  }

  Future<void> _saveTokenToDatabase(String userId, String token) async {
    try {
      final deviceType = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'web';

      await Supabase.instance.client.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_type': deviceType,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');

      print('✅ FCM token saved to database');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  Future<void> _removeTokenFromDatabase() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await Supabase.instance.client
            .from('fcm_tokens')
            .delete()
            .eq('token', token);
        print('✅ FCM token removed from database');
      }
    } catch (e) {
      print('❌ Error removing FCM token: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    print('📱 ========== PUSH NOTIFICATION TAP HANDLER START ==========');
    print('📱 Raw data received: $data');
    print('📱 Data keys: ${data.keys.toList()}');
    
    // Log each data field
    if (data.containsKey('campaign_id')) {
      print('📊 Campaign ID: ${data['campaign_id']}');
    }
    if (data.containsKey('deep_link')) {
      print('🔗 Deep Link: ${data['deep_link']}');
      print('🔗 Deep Link Type: ${data['deep_link'].runtimeType}');
      print('🔗 Deep Link isEmpty: ${data['deep_link'].toString().isEmpty}');
    }
    if (data.containsKey('title')) {
      print('📝 Title: ${data['title']}');
    }
    if (data.containsKey('body')) {
      print('📝 Body: ${data['body']}');
    }
    
    // Track both opened and clicked
    if (data.containsKey('campaign_id')) {
      print('📊 Tracking notification analytics...');
      _trackNotificationOpened(data['campaign_id']);
      
      // If has deep link, also track click
      if (data.containsKey('deep_link') && data['deep_link'].toString().isNotEmpty) {
        print('📊 Deep link exists, tracking click...');
        _trackNotificationClicked(data['campaign_id']);
      } else {
        print('📊 No deep link to track click');
      }
    } else {
      print('⚠️ No campaign_id found in data');
    }
    
    print('ℹ️ Push notification handling complete');
    print('ℹ️ User should navigate to notifications screen to see notification');
    print('📱 ========== PUSH NOTIFICATION TAP HANDLER END ==========');
  }

  Future<void> _trackNotificationOpened(String campaignId) async {
    try {
      print('📊 Tracking notification opened for campaign: $campaignId');
      
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ No user ID, cannot track');
        return;
      }

      print('📊 User ID: $userId');
      print('📊 Updating notification_analytics table...');

      await Supabase.instance.client
          .from('notification_analytics')
          .update({
            'opened_at': DateTime.now().toIso8601String(),
          })
          .eq('campaign_id', campaignId)
          .eq('user_id', userId)
          .isFilter('opened_at', null);

      print('📊 Calling increment_campaign_opened RPC...');

      // Also update campaign stats
      await Supabase.instance.client.rpc(
        'increment_campaign_opened',
        params: {'campaign_uuid': campaignId}
      );

      print('✅ Notification open tracked successfully');
    } catch (e) {
      print('❌ Error tracking notification open: $e');
    }
  }

  Future<void> _trackNotificationClicked(String campaignId) async {
    try {
      print('📊 Tracking notification clicked for campaign: $campaignId');
      
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ No user ID, cannot track');
        return;
      }

      print('📊 User ID: $userId');
      print('📊 Updating notification_analytics table...');

      await Supabase.instance.client
          .from('notification_analytics')
          .update({
            'clicked_at': DateTime.now().toIso8601String(),
          })
          .eq('campaign_id', campaignId)
          .eq('user_id', userId)
          .isFilter('clicked_at', null);

      print('📊 Calling increment_campaign_clicked RPC...');

      // Also update campaign stats
      await Supabase.instance.client.rpc(
        'increment_campaign_clicked',
        params: {'campaign_uuid': campaignId}
      );

      print('✅ Notification click tracked successfully');
    } catch (e) {
      print('❌ Error tracking notification click: $e');
    }
  }

  Future<void> _showLocalNotification(String title, String body, Map<String, dynamic> data) async {
    print('📲 Showing local notification');
    print('📲 Title: $title');
    print('📲 Body: $body');
    print('📲 Payload data: $data');
    
    const androidDetails = AndroidNotificationDetails(
      'unihub_orders',
      'Orders',
      channelDescription: 'Order notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: data['deep_link'],
    );
    
    print('✅ Local notification shown');
  }

  Future<void> _subscribeToUserTopic(String userId) async {
    await _unsubscribeFromCurrentUserTopic();
    final topic = 'user_$userId';
    try {
      await _fcm.subscribeToTopic(topic);
      _currentUserTopic = topic;
      print('✅ Subscribed to: $topic');
      final token = await _fcm.getToken();
      print('📱 My FCM Token: $token');
    } catch (e) {
      print('❌ Subscribe error: $e');
    }
  }

  Future<void> _unsubscribeFromCurrentUserTopic() async {
    if (_currentUserTopic != null) {
      try {
        await _fcm.unsubscribeFromTopic(_currentUserTopic!);
        print('🚫 Unsubscribed from: $_currentUserTopic');
      } catch (e) {
        print('❌ Unsubscribe error: $e');
      }
      _currentUserTopic = null;
    }
  }

  Future<void> handleLogout() async {
    await _unsubscribeFromCurrentUserTopic();
    await _removeTokenFromDatabase();
  }
}