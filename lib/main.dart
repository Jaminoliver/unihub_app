import 'package:flutter/material.dart'; // <-- THIS IS THE MISSING LINE
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_paystack/flutter_paystack.dart';

// New Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart'; // This will show an error until we create it

// Your existing screen imports
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/categories_screen.dart';
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

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Your existing initializations
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await paystackPlugin.initialize(publicKey: 'pk_test_611362c58ad79b5446897d88ef3d2f9c8b5b88d6');

  // Initialize our new service
  await PushNotificationService().init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
  );

  runApp(const UniHubApp());
}

final supabase = Supabase.instance.client;

//
// --- THE REST OF YOUR CODE IS UNCHANGED ---
//
class UniHubApp extends StatelessWidget {
  const UniHubApp({super.key});

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

  int _cartRefreshKey = 0;
  int _ordersRefreshKey = 0;

  final _pageTitles = ['Home', 'Categories', 'My Cart', 'My Orders', 'Profile'];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final session = supabase.auth.currentSession;
    if (session == null && mounted) {
      Navigator.of(context).pushReplacementNamed('/account_type');
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      setState(() {
        _selectedIndex = 2;
        _cartRefreshKey++;
      });
      return;
    }

    if (index == 3) {
      setState(() {
        _selectedIndex = 3;
        _ordersRefreshKey++;
      });
      return;
    }

    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      return;
    }

    if (index == 0) {
      final canPop = _navigatorKeys[0].currentState?.canPop() ?? false;
      if (canPop) {
        _navigatorKeys[0].currentState?.popUntil((route) => route.isFirst);
      } else if (_homeScrollController.hasClients &&
          _homeScrollController.offset > 0.0) {
        _homeScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        setState(() {
          _navigatorKeys[0] = GlobalKey<NavigatorState>();
        });
      }
      return;
    }

    _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final canPop =
            await _navigatorKeys[_selectedIndex].currentState?.maybePop() ??
                false;
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
                  return MaterialPageRoute(
                    builder: (context) => _getPage(index),
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
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: 'Categories'),
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
        return const CategoriesScreen();
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
        return const SizedBox.shrink();
    }
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _clearCartNotifier.dispose();
    super.dispose();
  }
}