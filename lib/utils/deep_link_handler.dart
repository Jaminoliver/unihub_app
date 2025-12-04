import 'package:flutter/material.dart';
import '../screens/special_deal_products_screen.dart';
import '../screens/category_products_screen.dart';
import '../screens/product_details_screen.dart';
import '../screens/search_screen.dart';
import '../screens/wishlist_screen.dart';
import '../screens/notifications_screen.dart';
import '../services/auth_service.dart';

class DeepLinkHandler {
  static void navigate(BuildContext context, String deepLink) {
    if (deepLink.isEmpty) {
      print('⚠️ Empty deep link provided');
      return;
    }

    print('🔗 ========== DEEP LINK NAVIGATION START ==========');
    print('🔗 Deep link: $deepLink');

    final uri = Uri.parse(deepLink);
    final path = uri.path;
    final params = uri.queryParameters;

    print('📍 Parsed URI - Path: $path');
    print('📍 Query params: $params');

    try {
      // Route based on path
      if (path == '/home') {
        print('✅ Navigating to HOME');
        print('🎯 Using root navigator to switch to home');
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/home', (route) => false);
        print('✅ HOME navigation completed');
      } 
      else if (path == '/orders') {
        print('✅ Navigating to ORDERS');
        print('🎯 Using root navigator to switch to orders tab');
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/orders', (route) => false);
        print('✅ ORDERS navigation completed');
      } 
      else if (path == '/cart') {
        print('✅ Navigating to CART');
        print('🎯 Using root navigator to switch to cart tab');
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/cart', (route) => false);
        print('✅ CART navigation completed');
      } 
      else if (path == '/profile') {
        print('✅ Navigating to PROFILE');
        print('🎯 Using root navigator to switch to profile tab');
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/profile', (route) => false);
        print('✅ PROFILE navigation completed');
      }
      else if (path == '/wishlist') {
        print('✅ Navigating to WISHLIST');
        print('🎯 Using Navigator.push with MaterialPageRoute');
        _navigateToWishlist(context);
        print('✅ WISHLIST navigation completed');
      }
      else if (path == '/wallet') {
        print('⚠️ WALLET route not implemented yet (seller feature)');
        _showNotImplementedMessage(context, 'Wallet');
      } 
      else if (path == '/notifications') {
        print('✅ Navigating to NOTIFICATIONS');
        print('🎯 Using Navigator.push with MaterialPageRoute');
        _navigateToNotifications(context);
        print('✅ NOTIFICATIONS navigation completed');
      }
      // Category page
      else if (path.startsWith('/category/')) {
        final categoryId = path.replaceFirst('/category/', '');
        print('🎯 ========== CATEGORY NAVIGATION ==========');
        print('🎯 Category ID extracted: $categoryId');
        print('🎯 Calling _navigateToCategory...');
        _navigateToCategory(context, categoryId);
        print('🎯 _navigateToCategory completed');
        print('🎯 ========== CATEGORY NAVIGATION END ==========');
      }
      // Special deals
      else if (path.startsWith('/special-deals/')) {
        final dealType = path.replaceFirst('/special-deals/', '');
        print('🎯 ========== SPECIAL DEAL NAVIGATION ==========');
        print('🎯 Deal type extracted: $dealType');
        print('🎯 Calling _navigateToSpecialDeal...');
        _navigateToSpecialDeal(context, dealType);
        print('🎯 _navigateToSpecialDeal completed');
        print('🎯 ========== SPECIAL DEAL NAVIGATION END ==========');
      }
      // Product details
      else if (path.startsWith('/product/')) {
        final productId = path.replaceFirst('/product/', '');
        print('🎯 ========== PRODUCT DETAILS NAVIGATION ==========');
        print('🎯 Product ID extracted: $productId');
        print('🎯 Calling _navigateToProductDetails...');
        _navigateToProductDetails(context, productId);
        print('🎯 _navigateToProductDetails completed');
        print('🎯 ========== PRODUCT DETAILS NAVIGATION END ==========');
      }
      // Search with query parameter
      else if (path == '/search') {
        final query = params['query'] ?? '';
        print('🎯 ========== SEARCH NAVIGATION ==========');
        print('🎯 Search query: $query');
        print('🎯 Calling _navigateToSearch...');
        _navigateToSearch(context, query);
        print('🎯 _navigateToSearch completed');
        print('🎯 ========== SEARCH NAVIGATION END ==========');
      }
      // Products with filters
      else if (path == '/products') {
        if (params.containsKey('search')) {
          final query = params['search'] ?? '';
          print('🎯 ========== PRODUCT SEARCH NAVIGATION ==========');
          print('🎯 Search query from products: $query');
          print('🎯 Calling _navigateToSearch...');
          _navigateToSearch(context, query);
          print('🎯 _navigateToSearch completed');
          print('🎯 ========== PRODUCT SEARCH NAVIGATION END ==========');
        } else if (params.containsKey('category')) {
          print('✅ Navigating to CATEGORY PRODUCTS: ${params['category']}');
          _showNotImplementedMessage(context, 'Category by name');
        } else if (params.containsKey('state')) {
          print('✅ Navigating to PRODUCTS BY STATE: ${params['state']}');
          _showNotImplementedMessage(context, 'Products by state');
        } else {
          print('✅ Navigating to ALL PRODUCTS');
          _showNotImplementedMessage(context, 'All products');
        }
      }
      else {
        print('❌ ========== UNKNOWN DEEP LINK ==========');
        print('❌ Unknown path: $path');
        print('❌ Full deep link: $deepLink');
        print('❌ This deep link has no handler!');
        _showNotImplementedMessage(context, 'Unknown route: $path');
      }
      
      print('✅ ========== DEEP LINK NAVIGATION COMPLETED ==========');
    } catch (e, stackTrace) {
      print('❌ ========== DEEP LINK NAVIGATION ERROR ==========');
      print('❌ Error: $e');
      print('❌ Stack trace: $stackTrace');
      print('❌ ========== ERROR END ==========');
    }
  }

  static void _navigateToCategory(BuildContext context, String categoryId) async {
    print('🎯 _navigateToCategory START');
    print('🎯 Category ID: $categoryId');
    
    try {
      // Get user's state and university from auth service
      final authService = AuthService();
      final userProfile = await authService.getCurrentUserProfile();
      
      final state = userProfile?.state ?? 'Lagos';
      final universityId = userProfile?.universityId;
      
      print('🎯 User state: $state');
      print('🎯 User university ID: $universityId');
      print('🎯 About to push CategoryProductsScreen...');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            print('🎯 Building CategoryProductsScreen widget...');
            return CategoryProductsScreen(
              categoryId: categoryId,
              categoryName: 'Category', // Will be fetched in the screen
              state: state,
              universityId: universityId,
            );
          },
        ),
      ).then((_) {
        print('🎯 CategoryProductsScreen route completed');
      });
      
      print('🎯 Navigator.push completed successfully');
    } catch (e, stackTrace) {
      print('❌ Error in _navigateToCategory: $e');
      print('❌ Stack trace: $stackTrace');
    }

    print('🎯 _navigateToCategory END');
  }

  static void _navigateToSpecialDeal(BuildContext context, String dealType) async {
    print('🎯 _navigateToSpecialDeal START');
    print('🎯 Deal type: $dealType');
    
    try {
      final dealTitles = {
        'flash_sale': 'Flash Sale',
        'discounted': 'Discounted Products',
        'last_chance': 'Last Chance Deals',
        'under_10k': 'Under ₦10,000',
        'top_deals': 'Top Deals',
        'new_this_week': 'New This Week',
      };

      final title = dealTitles[dealType] ?? 'Special Deals';
      print('🎯 Deal title: $title');

      // Get user's state and university from auth service
      final authService = AuthService();
      final userProfile = await authService.getCurrentUserProfile();
      
      final state = userProfile?.state ?? 'Lagos';
      final universityId = userProfile?.universityId;

      print('🎯 State: $state');
      print('🎯 University ID: $universityId');
      print('🎯 About to push SpecialDealProductsScreen...');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            print('🎯 Building SpecialDealProductsScreen widget...');
            return SpecialDealProductsScreen(
              dealType: dealType,
              dealTitle: title,
              state: state,
              universityId: universityId,
            );
          },
        ),
      ).then((_) {
        print('🎯 SpecialDealProductsScreen route completed');
      });
      
      print('🎯 Navigator.push completed successfully');
    } catch (e, stackTrace) {
      print('❌ Error in _navigateToSpecialDeal: $e');
      print('❌ Stack trace: $stackTrace');
    }

    print('🎯 _navigateToSpecialDeal END');
  }

  static void _navigateToProductDetails(BuildContext context, String productId) {
    print('🎯 _navigateToProductDetails START');
    print('🎯 Product ID: $productId');
    
    try {
      print('🎯 About to push ProductDetailsScreen...');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            print('🎯 Building ProductDetailsScreen widget...');
            return ProductDetailsScreen(productId: productId);
          },
        ),
      ).then((_) {
        print('🎯 ProductDetailsScreen route completed');
      });
      
      print('🎯 Navigator.push completed successfully');
    } catch (e, stackTrace) {
      print('❌ Error in _navigateToProductDetails: $e');
      print('❌ Stack trace: $stackTrace');
    }

    print('🎯 _navigateToProductDetails END');
  }

  static void _navigateToSearch(BuildContext context, String query) async {
    print('🎯 _navigateToSearch START');
    print('🎯 Search query: $query');
    
    try {
      // Get user's state and university from auth service
      final authService = AuthService();
      final userProfile = await authService.getCurrentUserProfile();
      
      final state = userProfile?.state ?? 'Lagos';
      final universityId = userProfile?.universityId;
      final universityName = userProfile?.universityName ?? 'University';
      
      print('🎯 User state: $state');
      print('🎯 User university: $universityName');
      print('🎯 About to push SearchScreen...');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            print('🎯 Building SearchScreen widget...');
            return SearchScreen(
              universityId: universityId,
              universityName: universityName,
              state: state,
            );
          },
        ),
      ).then((_) {
        print('🎯 SearchScreen route completed');
      });
      
      print('🎯 Navigator.push completed successfully');
    } catch (e, stackTrace) {
      print('❌ Error in _navigateToSearch: $e');
      print('❌ Stack trace: $stackTrace');
    }

    print('🎯 _navigateToSearch END');
  }

  static void _navigateToWishlist(BuildContext context) {
    print('🎯 _navigateToWishlist START');
    
    try {
      print('🎯 About to push WishlistScreen...');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            print('🎯 Building WishlistScreen widget...');
            return const WishlistScreen();
          },
        ),
      ).then((_) {
        print('🎯 WishlistScreen route completed');
      });
      
      print('🎯 Navigator.push completed successfully');
    } catch (e, stackTrace) {
      print('❌ Error in _navigateToWishlist: $e');
      print('❌ Stack trace: $stackTrace');
    }

    print('🎯 _navigateToWishlist END');
  }

  static void _navigateToNotifications(BuildContext context) {
    print('🎯 _navigateToNotifications START');
    
    try {
      print('🎯 About to push NotificationsScreen...');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            print('🎯 Building NotificationsScreen widget...');
            return const NotificationsScreen();
          },
        ),
      ).then((_) {
        print('🎯 NotificationsScreen route completed');
      });
      
      print('🎯 Navigator.push completed successfully');
    } catch (e, stackTrace) {
      print('❌ Error in _navigateToNotifications: $e');
      print('❌ Stack trace: $stackTrace');
    }

    print('🎯 _navigateToNotifications END');
  }

  static void _showNotImplementedMessage(BuildContext context, String feature) {
    print('⚠️ Feature not implemented: $feature');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature: Coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static String getDisplayText(String deepLink) {
    if (deepLink.isEmpty) return 'No link';

    final uri = Uri.parse(deepLink);
    final path = uri.path;
    final params = uri.queryParameters;

    if (path == '/home') return 'Home Screen';
    if (path == '/orders') return 'My Orders';
    if (path == '/cart') return 'Shopping Cart';
    if (path == '/profile') return 'Profile';
    if (path == '/wallet') return 'Wallet';
    if (path == '/wishlist') return 'Wishlist';
    if (path.startsWith('/category/')) return 'Category Page';
    if (path.startsWith('/special-deals/')) return 'Special Deal';
    if (path.startsWith('/product/')) return 'Product Details';
    if (path == '/search') return 'Search';
    if (path == '/products') {
      if (params.containsKey('search')) return 'Search: ${params['search']}';
      if (params.containsKey('category')) return 'Category: ${params['category']}';
      if (params.containsKey('state')) return 'State: ${params['state']}';
      return 'All Products';
    }

    return deepLink;
  }
}