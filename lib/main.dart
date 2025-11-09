import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_paystack/flutter_paystack.dart';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth/account_type_selection_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';

// Supabase configuration
const supabaseUrl = 'https://owuogoooqdfbdnbkdyeo.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93dW9nb29vcWRmYmRuYmtkeWVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5Mzg2MDYsImV4cCI6MjA3NzUxNDYwNn0.g6I65rY5hhb8CnH38-7_fEsB6jPQpWy_QcqVVpIyDH8';

// Global Paystack plugin instance
final paystackPlugin = PaystackPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // Initialize Paystack using the global instance
  await paystackPlugin.initialize(
    publicKey: 'pk_test_611362c58ad79b5446897d88ef3d2f9c8b5b88d6',
  );

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const UniHubApp());
}

// Global Supabase client (moved AFTER main function)
final supabase = Supabase.instance.client;

class UniHubApp extends StatelessWidget {
  const UniHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniHub',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0057D9),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
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

  // Create a scroll controller for the Home screen
  final ScrollController _homeScrollController = ScrollController();
  
  // Removed 'const' and made it late-initialized in initState
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _checkAuth();

    // Initialize the pages list here, passing the controller to HomeScreen
    _pages = [
      HomeScreen(
        key: const PageStorageKey('homeScreen'), // Remembers scroll position
        scrollController: _homeScrollController,
      ),
      const CategoriesScreen(
        key: PageStorageKey('categoriesScreen'),
      ),
      const CartScreen(
        key: PageStorageKey('cartScreen'),
      ),
      const OrdersScreen(
        key: PageStorageKey('ordersScreen'),
      ),
      const ProfileScreen(
        key: PageStorageKey('profileScreen'),
      ),
    ];
  }

  Future<void> _checkAuth() async {
    final session = supabase.auth.currentSession;
    if (session == null && mounted) {
      Navigator.of(context).pushReplacementNamed('/account_type');
    }
  }

  // This method now handles the "scroll to top" logic
  void _onItemTapped(int index) {
    // Check if the user is *re-tapping* the Home icon (index 0)
    if (index == 0 && _selectedIndex == 0) {
      // If we are already on the Home tab, scroll to top
      if (_homeScrollController.hasClients) {
        _homeScrollController.animateTo(
          0.0, // Scroll to the top
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Otherwise, just switch tabs
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: Colors.white,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}