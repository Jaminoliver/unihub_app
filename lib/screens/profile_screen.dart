import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/wishlist_service.dart';
import '../services/order_service.dart';
import '../models/user_model.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'help_and_support_screen.dart';
import 'wishlist_screen.dart';
import 'orders_screen.dart';
import 'my_addresses_screen.dart';
import 'reviews_screen.dart';
import 'notifications_screen.dart';
import 'dispute_chatbot_screen.dart';
import '../widgets/unihub_loading_widget.dart';
import '../constants/app_colors.dart';

const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final WishlistService _wishlistService = WishlistService();
  final OrderService _orderService = OrderService();

  UserModel? _currentUser;
  int _wishlistCount = 0, _ordersCount = 0, _reviewsCount = 0;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _loadUserProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _profileService.getCurrentUserProfile();
      if (user != null) {
        final results = await Future.wait([
          _wishlistService.getUserWishlist(user.id),
          _orderService.getBuyerOrders(user.id),
          Supabase.instance.client.from('reviews').select('id').eq('user_id', user.id),
        ]);

        if (mounted) {
          setState(() {
            _currentUser = user;
            _wishlistCount = (results[0] as List).length;
            _ordersCount = (results[1] as List).length;
            _reviewsCount = (results[2] as List).length;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _showLogoutAnimation();
      await _authService.signOut();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/account_type', (route) => false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _showLogoutAnimation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(color: AppColors.getCardBackground(context), borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(color: AppColors.primaryOrange.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(Icons.waving_hand, color: AppColors.primaryOrange, size: 40),
                ),
              ),
              SizedBox(height: 20),
              FadeTransition(
                opacity: _animationController,
                child: Column(
                  children: [
                    Text('Logging Out...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                    SizedBox(height: 6),
                    Text('See you soon!', style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _animationController.forward();
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  Future<void> _navigateToEditProfile() async {
    if (_currentUser == null) return;
    
    Map<String, dynamic>? deliveryAddress;
    try {
      deliveryAddress = await _profileService.getDefaultDeliveryAddress(_currentUser!.id);
    } catch (e) {
      print('Error fetching delivery address: $e');
    }
    
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          user: _currentUser!, 
          deliveryAddress: deliveryAddress,
        )
      )
    );
    if (result == true) _loadUserProfile();
  }

  void _showEnlargedPhoto() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width,
                      maxHeight: MediaQuery.of(context).size.height,
                    ),
                    child: _currentUser!.profileImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _currentUser!.profileImageUrl!,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => Center(
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    _getInitials(_currentUser!.fullName),
                                    style: TextStyle(
                                      color: AppColors.primaryOrange,
                                      fontSize: 80,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: AppColors.primaryOrange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  _getInitials(_currentUser!.fullName),
                                  style: TextStyle(
                                    color: AppColors.primaryOrange,
                                    fontSize: 80,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: Colors.black, size: 24),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: GestureDetector(
                  onTap: _navigateToEditProfile,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Edit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: AppColors.getBackground(context), body: Center(child: UniHubLoader(size: 80)));
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: AppColors.errorRed),
              SizedBox(height: 20),
              Text('Error Loading Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
              SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.getTextMuted(context))),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _loadUserProfile, child: Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 60, color: AppColors.primaryOrange),
              SizedBox(height: 20),
              Text('Not Logged In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
              SizedBox(height: 20),
              ElevatedButton(onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/account_type', (route) => false), child: Text('Log In'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getCardBackground(context),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: AppColors.primaryOrange,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.all(20),
                color: AppColors.getCardBackground(context),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showEnlargedPhoto(),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.primaryOrange, Color(0xFFFF8C42)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _currentUser!.profileImageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: _currentUser!.profileImageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  errorWidget: (_, __, ___) => Center(child: Text(_getInitials(_currentUser!.fullName), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                                )
                              : Center(child: Text(_getInitials(_currentUser!.fullName), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(_currentUser!.fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)), overflow: TextOverflow.ellipsis)),
                              if (_currentUser!.isVerified) ...[SizedBox(width: 6), Icon(Icons.verified, color: AppColors.primaryOrange, size: 18)],
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(_currentUser!.email, style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context)), overflow: TextOverflow.ellipsis),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, color: AppColors.primaryOrange, size: 14),
                              SizedBox(width: 4),
                              Text('${_currentUser!.state ?? 'Unknown'}', style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: Icon(Icons.edit_outlined, color: AppColors.primaryOrange, size: 22), onPressed: _navigateToEditProfile),
                  ],
                ),
              ),
            ),

            // Chatbot Card
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DisputeChatbotScreen())),
                child: Container(
                  margin: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.25),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      TweenAnimationBuilder(
                        duration: Duration(milliseconds: 1500),
                        tween: Tween<double>(begin: 0, end: 1),
                        curve: Curves.elasticOut,
                        builder: (context, double value, child) {
                          return Transform.rotate(
                            angle: 0.3 * (1 - value),
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.smart_toy_outlined,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Need Help?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Start a live chat',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),

            // Menu Items
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.only(top: 8),
                color: AppColors.getCardBackground(context),
                child: Column(
                  children: [
                    _buildMenuItem(Icons.shopping_bag_outlined, 'My Orders', () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen()))),
                    _buildMenuItem(Icons.favorite_outline, 'My Wishlist', () => Navigator.push(context, MaterialPageRoute(builder: (_) => WishlistScreen()))),
                    _buildMenuItem(Icons.star_outline, 'My Reviews', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsScreen()))),
                    _buildMenuItem(Icons.notifications_outlined, 'Notifications', () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen()))),
                    _buildMenuItem(Icons.location_on_outlined, 'My Addresses', () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyAddressesScreen())).then((_) => _loadUserProfile())),
                    _buildMenuItem(Icons.credit_card_outlined, 'Payment Methods', () {}),
                    _buildMenuItem(Icons.settings_outlined, 'Settings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()))),
                    _buildMenuItem(Icons.help_outline, 'Help & Support', () => Navigator.push(context, MaterialPageRoute(builder: (_) => HelpAndSupportScreen()))),
                  ],
                ),
              ),
            ),

            // Logout
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.only(top: 8),
                color: AppColors.getCardBackground(context),
                child: ListTile(
                  onTap: () => _showLogoutDialog(context),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(Icons.logout, color: AppColors.errorRed, size: 22),
                  title: Text('Log Out', style: TextStyle(color: AppColors.errorRed, fontSize: 15, fontWeight: FontWeight.w500)),
                ),
              ),
            ),

            // Footer
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text('UniHub v1.0.0', style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context), fontWeight: FontWeight.w500)),
                    SizedBox(height: 4),
                    Text('Making campus commerce easier', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
                    SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5))),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, size: 22, color: AppColors.primaryOrange),
        title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context))),
        trailing: Icon(Icons.chevron_right, color: AppColors.getTextMuted(context), size: 20),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
        content: Text('Are you sure you want to log out?', style: TextStyle(color: AppColors.getTextMuted(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.getTextMuted(context)))),
          TextButton(onPressed: () {
            Navigator.pop(context);
            _handleLogout();
          }, child: Text('Log Out', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}