import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && session.user != null) {
        _subscribeToUserTopic(session.user.id);
      } else {
        _unsubscribeFromCurrentUserTopic();
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Foreground notification received');
      if (message.notification != null) {
        print('Title: ${message.notification!.title}');
        print('Body: ${message.notification!.body}');
        _showLocalNotification(message.notification!.title ?? 'UniHub', message.notification!.body ?? '');
      }
    });

    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) print('App opened from terminated state');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background state');
    });
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails('unihub_orders', 'Orders',
        channelDescription: 'Order notifications', importance: Importance.high, priority: Priority.high, showWhen: true);
    const iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    await _localNotifications.show(DateTime.now().millisecond, title, body, NotificationDetails(android: androidDetails, iOS: iosDetails));
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
  }
}