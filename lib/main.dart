import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import 'dart:async';
import 'services/chat_service.dart';
import 'screens/ai_chat_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';
import 'services/notification_service.dart';

// Screen imports
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth/account_type_selection_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';

const supabaseUrl = 'https://owuogoooqdfbdnbkdyeo.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93dW9nb29vcWRmYmRuYmtkeWVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5Mzg2MDYsImV4cCI6MjA3NzUxNDYwNn0.g6I65rY5hhb8CnH38-7_fEsB6jPQpWy_QcqVVpIyDH8';

final paystackPlugin = PaystackPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 ========== APP INITIALIZATION START ==========');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ Firebase initialized');

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  print('✅ Supabase initialized');

  await paystackPlugin.initialize(publicKey: 'pk_test_611362c58ad79b5446897d88ef3d2f9c8b5b88d6');
  print('✅ Paystack initialized');

  await PushNotificationService().init();
  print('✅ Push notification service initialized');

  ChatService().initialize();
  print('✅ Chat service initialized');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
  );

  print('🚀 ========== APP INITIALIZATION COMPLETE ==========');
  
  runApp(const UniHubApp());
}

final supabase = Supabase.instance.client;

class UniHubApp extends StatefulWidget {
  const UniHubApp({super.key});

  @override
  State<UniHubApp> createState() => _UniHubAppState();
}

class _UniHubAppState extends State<UniHubApp> {
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await Future.delayed(Duration(milliseconds: 500));
    
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      print('🔔 Initializing NotificationService on app startup...');
      await NotificationService().fetchNotifications();
      print('✅ NotificationService initialized - realtime listener active');
    } else {
      print('⚠️ No user logged in, skipping notification initialization');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniHub',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0057D9), brightness: Brightness.light),
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/account_type': (context) => const AccountTypeSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const BottomNavBar(initialIndex: 0),
        '/profile': (context) => const BottomNavBar(initialIndex: 4),
        '/cart': (context) => const BottomNavBar(initialIndex: 2),
        '/categories': (context) => const BottomNavBar(initialIndex: 1),
        '/orders': (context) => const BottomNavBar(initialIndex: 3),
      },
      onUnknownRoute: (settings) {
        print('❌ ========== UNKNOWN ROUTE ==========');
        print('❌ Attempted route: ${settings.name}');
        print('❌ Arguments: ${settings.arguments}');
        print('❌ This route does not exist in the routes map!');
        print('❌ Falling back to home screen');
        print('❌ ========== UNKNOWN ROUTE END ==========');
        
        return MaterialPageRoute(
          builder: (context) => const BottomNavBar(initialIndex: 0),
        );
      },
    );
  }
}

class BottomNavBar extends StatefulWidget {
  final int initialIndex;
  const BottomNavBar({super.key, this.initialIndex = 0});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  late int _selectedIndex;
  final _homeScrollController = ScrollController();
  late List<GlobalKey<NavigatorState>> _navigatorKeys;
  final _clearCartNotifier = ValueNotifier<bool>(false);
  
  StreamSubscription<AuthState>? _authSubscription;

  int _cartRefreshKey = 0;
  int _ordersRefreshKey = 0;

  final _pageTitles = ['Home', 'Vibe', 'My Cart', 'My Orders', 'Profile'];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
    
    print('🏠 ========== BOTTOM NAV BAR INITIALIZED ==========');
    print('🏠 Initial index: $_selectedIndex');
    print('🏠 Initial page: ${_pageTitles[_selectedIndex]}');
    print('🏠 ========== BOTTOM NAV BAR INIT END ==========');
    
    _checkAuth();
    _setupAuthListener();
    _initializeNotificationsIfNeeded();
  }

  Future<void> _initializeNotificationsIfNeeded() async {
    await Future.delayed(Duration(milliseconds: 800));
    
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      if (NotificationService().allNotifications.isEmpty) {
        print('🔔 Initializing NotificationService from BottomNavBar...');
        await NotificationService().fetchNotifications();
        print('✅ NotificationService initialized from BottomNavBar');
      }
    }
  }

  Future<void> _checkAuth() async {
    final session = supabase.auth.currentSession;
    if (session == null && mounted) {
      print('⚠️ No active session, redirecting to account type selection');
      Navigator.of(context).pushReplacementNamed('/account_type');
    }
  }

  void _setupAuthListener() {
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session == null && mounted) {
        print('🚪 Auth session ended, logging out');
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/account_type',
          (route) => false,
        );
      }
    });
  }

  void _onItemTapped(int index) {
    print('🔄 ========== TAB CHANGED ==========');
    print('🔄 Previous tab: ${_pageTitles[_selectedIndex]}');
    print('🔄 New tab: ${_pageTitles[index]}');
    
    if (index == 2) {
      print('🔄 Cart tab selected - refreshing cart');
      setState(() {
        _selectedIndex = 2;
        _cartRefreshKey++;
      });
      print('🔄 ========== TAB CHANGE END ==========');
      return;
    }

    if (index == 3) {
      print('🔄 Orders tab selected - refreshing orders');
      setState(() {
        _selectedIndex = 3;
        _ordersRefreshKey++;
      });
      print('🔄 ========== TAB CHANGE END ==========');
      return;
    }

    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      print('🔄 ========== TAB CHANGE END ==========');
      return;
    }

    // Double tap handling
    print('🔄 Same tab tapped - handling double tap');
    
    if (index == 0) {
      final canPop = _navigatorKeys[0].currentState?.canPop() ?? false;
      if (canPop) {
        print('🔄 Popping home navigation stack');
        _navigatorKeys[0].currentState?.popUntil((route) => route.isFirst);
      } else if (_homeScrollController.hasClients &&
          _homeScrollController.offset > 0.0) {
        print('🔄 Scrolling to top of home screen');
        _homeScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        print('🔄 Refreshing home screen');
        setState(() {
          _navigatorKeys[0] = GlobalKey<NavigatorState>();
        });
      }
      print('🔄 ========== TAB CHANGE END ==========');
      return;
    }

    print('🔄 Popping to first route in tab $index');
    _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    print('🔄 ========== TAB CHANGE END ==========');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        print('⬅️ Back button pressed on tab: ${_pageTitles[_selectedIndex]}');
        final canPop =
            await _navigatorKeys[_selectedIndex].currentState?.maybePop() ??
                false;
        print('⬅️ Can pop: $canPop');
        return !canPop;
      },
      child: Scaffold(
        appBar: null,
        body: Stack(
          children: List.generate(5, (index) {
            return Offstage(
              offstage: _selectedIndex != index,
              child: Navigator(
                key: _navigatorKeys[index],
                onGenerateRoute: (settings) {
                  print('🧭 Generating route for tab $index (${_pageTitles[index]})');
                  print('🧭 Route settings: ${settings.name}');
                  print('🧭 Route arguments: ${settings.arguments}');
                  
                  return MaterialPageRoute(
                    builder: (context) {
                      print('🏗️ Building page for tab $index');
                      final page = _getPage(index);
                      print('✅ Page built: ${page.runtimeType}');
                      return page;
                    },
                    settings: settings,
                  );
                },
              ),
            );
          }),
        ),
        bottomNavigationBar: NavigationBar(
          height: 70,
          backgroundColor: Colors.white,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'Vibe'),
            NavigationDestination(
                icon: Icon(Icons.shopping_cart_outlined),
                selectedIcon: Icon(Icons.shopping_cart),
                label: 'Cart'),
            NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: 'Orders'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return HomeScreen(scrollController: _homeScrollController);
      case 1:
        return const AiChatScreen();
      case 2:
        return CartScreen(
          key: ValueKey('cart_$_cartRefreshKey'),
          clearCartNotifier: _clearCartNotifier,
        );
      case 3:
        return OrdersScreen(
          key: ValueKey('orders_$_ordersRefreshKey'),
        );
      case 4:
        return const ProfileScreen();
      default:
        print('⚠️ Unknown tab index: $index, falling back to home');
        return HomeScreen(scrollController: _homeScrollController);
    }
  }

  @override
  void dispose() {
    print('🧹 Disposing BottomNavBar');
    _authSubscription?.cancel();
    _homeScrollController.dispose();
    _clearCartNotifier.dispose();
    super.dispose();
  }
}
