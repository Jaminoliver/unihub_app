import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/wishlist_service.dart';
import '../services/order_service.dart';
import '../models/user_model.dart';
import '../models/address_model.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'help_and_support_screen.dart';
import 'wishlist_screen.dart';
import 'orders_screen.dart';
import 'my_addresses_screen.dart';
import '../widgets/unihub_loading_widget.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

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
  List<DeliveryAddressModel> _addresses = [];
  int _wishlistCount = 0;
  int _ordersCount = 0;
  int _reviewsCount = 0;
  bool _isLoading = true;
  bool _showContactInfo = false;
  String? _errorMessage;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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
        final addresses = await _profileService.getUserAddresses(user.id);
        final wishlist = await _wishlistService.getUserWishlist(user.id);
        final orders = await _orderService.getBuyerOrders(user.id);
        
        if (mounted) {
          setState(() {
            _currentUser = user;
            _addresses = addresses;
            _wishlistCount = wishlist.length;
            _ordersCount = orders.length;
            _reviewsCount = 0; // TODO: Implement review count
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _showLogoutAnimation();
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/account_type',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Logout failed: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _showLogoutAnimation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LogoutDialog(controller: _animationController),
    );
  }

  Future<void> _navigateToEditProfile() async {
    if (_currentUser == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          user: _currentUser!,
          deliveryAddress: _addresses.isNotEmpty && _addresses.first.isDefault 
              ? _addresses.first.toJson() 
              : null,
        ),
      ),
    );
    if (result == true) _loadUserProfile();
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  void _showEnlargedPhoto(UserModel user) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _EnlargedPhotoView(
              user: user,
              onChangePhoto: () {
                Navigator.pop(context);
                _navigateToEditProfile();
              },
              getInitials: _getInitials,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: UniHubLoader(size: 80)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, size: 64, color: AppColors.errorRed),
                ),
                SizedBox(height: 24),
                Text('Error Loading Profile', style: AppTextStyles.heading.copyWith(fontSize: 20)),
                SizedBox(height: 8),
                Text(_errorMessage ?? 'Unknown error', style: AppTextStyles.body, textAlign: TextAlign.center),
                SizedBox(height: 24),
                _buildActionButton(
                  text: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _loadUserProfile,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_outline, size: 64, color: Colors.white),
                ),
                SizedBox(height: 24),
                Text('Not Logged In', style: AppTextStyles.heading.copyWith(fontSize: 20)),
                SizedBox(height: 8),
                Text('Please log in to view your profile', style: AppTextStyles.body, textAlign: TextAlign.center),
                SizedBox(height: 24),
                _buildActionButton(
                  text: 'Log In',
                  icon: Icons.login,
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/account_type', (route) => false);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Profile', style: AppTextStyles.heading.copyWith(fontSize: 20)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: AppColors.primaryOrange, size: 22),
            onPressed: _navigateToEditProfile,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: AppColors.primaryOrange,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildProfileHeader(),
            SizedBox(height: 16),
            _buildQuickStats(),
            SizedBox(height: 16),
            _buildMyAddressesSection(),
            SizedBox(height: 16),
            _buildPaymentMethodsSection(),
            SizedBox(height: 16),
            _buildQuickActions(),
            SizedBox(height: 16),
            _buildContactSection(),
            SizedBox(height: 16),
            _buildLogoutButton(),
            SizedBox(height: 16),
            _buildAppVersion(),
            SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final user = _currentUser!;
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showEnlargedPhoto(user),
            child: Hero(
              tag: 'profile_photo_${user.id}',
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: user.profileImageUrl != null
                      ? Image.network(
                          user.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              _getInitials(user.fullName),
                              style: TextStyle(
                                color: AppColors.primaryOrange,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _getInitials(user.fullName),
                            style: TextStyle(
                              color: AppColors.primaryOrange,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
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
                    Flexible(
                      child: Text(
                        user.fullName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isVerified) ...[
                      SizedBox(width: 6),
                      Icon(Icons.verified, color: Colors.white, size: 18),
                    ],
                    if (!user.isSeller) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'BUYER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white.withOpacity(0.9), size: 14),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${user.state ?? 'Unknown'} • ${user.universityName ?? 'Unknown University'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.85),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.shopping_bag_outlined,
            label: 'Orders',
            value: '$_ordersCount',
            color: AppColors.infoBlue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen())),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.favorite_outline,
            label: 'Wishlist',
            value: '$_wishlistCount',
            color: AppColors.errorRed,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WishlistScreen())),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.star_outline,
            label: 'Reviews',
            value: '$_reviewsCount',
            color: AppColors.warningYellow,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Reviews coming soon!'),
                  backgroundColor: AppColors.primaryOrange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: EdgeInsets.all(16),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyAddressesSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.location_on_outlined, color: AppColors.infoBlue, size: 20),
                  ),
                  SizedBox(width: 12),
                  Text('My Addresses', style: AppTextStyles.subheading.copyWith(fontSize: 15)),
                ],
              ),
              TextButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MyAddressesScreen()),
                  );
                  if (result == true) _loadUserProfile();
                },
                child: Text('View All', style: TextStyle(fontSize: 13, color: AppColors.primaryOrange)),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (_addresses.isEmpty)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGrey, style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_location_outlined, color: AppColors.textLight, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No saved addresses yet',
                      style: TextStyle(fontSize: 13, color: AppColors.textLight),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._addresses.take(2).map((address) => Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _buildAddressCard(address),
                )),
        ],
      ),
    );
  }

  Widget _buildAddressCard(DeliveryAddressModel address) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: address.isDefault ? Border.all(color: AppColors.primaryOrange, width: 1.5) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            address.isDefault ? Icons.location_on : Icons.location_on_outlined,
            color: address.isDefault ? AppColors.primaryOrange : AppColors.textLight,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        address.addressLine,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (address.isDefault)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '${address.city}, ${address.state}',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.credit_card_outlined, color: AppColors.successGreen, size: 20),
              ),
              SizedBox(width: 12),
              Text('Payment Methods', style: AppTextStyles.subheading.copyWith(fontSize: 15)),
            ],
          ),
          SizedBox(height: 12),
          _buildComingSoonCard('Saved cards will appear here'),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.apps_outlined, color: AppColors.primaryOrange, size: 20),
              ),
              SizedBox(width: 12),
              Text('Quick Actions', style: AppTextStyles.subheading.copyWith(fontSize: 15)),
            ],
          ),
          SizedBox(height: 12),
          _buildActionTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Notifications, privacy & more',
            color: AppColors.textLight,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen())),
          ),
          Divider(height: 20, indent: 48),
          _buildActionTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help with your orders',
            color: AppColors.successGreen,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HelpAndSupportScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    final user = _currentUser!;
    final defaultAddress = _addresses.firstWhere((a) => a.isDefault, orElse: () => _addresses.isNotEmpty ? _addresses.first : DeliveryAddressModel(
      id: '',
      userId: '',
      addressLine: 'Not provided',
      city: '',
      state: '',
      isDefault: false,
      createdAt: DateTime.now(),
    ));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showContactInfo = !_showContactInfo),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.contact_phone_outlined, color: AppColors.infoBlue, size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Contact Information', style: AppTextStyles.subheading.copyWith(fontSize: 15)),
                  ),
                  Icon(
                    _showContactInfo ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textLight,
                  ),
                ],
              ),
            ),
          ),
          if (_showContactInfo)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: user.phoneNumber ?? 'Not provided',
                  ),
                  Divider(height: 20),
                  _buildInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: defaultAddress.id.isNotEmpty 
                        ? '${defaultAddress.addressLine}, ${defaultAddress.city}' 
                        : 'Not provided',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.lightGrey.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.textLight),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
              SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComingSoonCard(String message) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.textLight, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: () => _showLogoutDialog(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.errorRed.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: AppColors.errorRed, size: 20),
            SizedBox(width: 12),
            Text(
              'Log Out',
              style: TextStyle(
                color: AppColors.errorRed,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppVersion() {
    return Column(
      children: [
        Text(
          'UniHub v1.0.0',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Making campus commerce easier and safer',
          style: TextStyle(fontSize: 11, color: AppColors.textLight),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? LinearGradient(
                colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: onPressed == null ? AppColors.textLight.withOpacity(0.3) : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout, color: AppColors.errorRed, size: 20),
            ),
            SizedBox(width: 12),
            Text('Log Out', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            child: Text(
              'Log Out',
              style: TextStyle(
                color: AppColors.errorRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutDialog extends StatefulWidget {
  final AnimationController controller;

  const _LogoutDialog({required this.controller});

  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog> {
  @override
  void initState() {
    super.initState();
    widget.controller.forward();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(
                parent: widget.controller,
                curve: Curves.elasticOut,
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.waving_hand, color: Colors.white, size: 48),
              ),
            ),
            SizedBox(height: 24),
            FadeTransition(
              opacity: widget.controller,
              child: Column(
                children: [
                  Text(
                    'Logging Out...',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'See you soon!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnlargedPhotoView extends StatelessWidget {
  final UserModel user;
  final VoidCallback onChangePhoto;
  final String Function(String) getInitials;

  const _EnlargedPhotoView({
    required this.user,
    required this.onChangePhoto,
    required this.getInitials,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),
          Center(
            child: Hero(
              tag: 'profile_photo_${user.id}',
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.width * 0.85,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.4),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: user.profileImageUrl != null
                      ? Image.network(
                          user.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              getInitials(user.fullName),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 80,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            getInitials(user.fullName),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
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
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.arrow_back, color: AppColors.primaryOrange, size: 24),
                  ),
                ),
                GestureDetector(
                  onTap: onChangePhoto,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Change Photo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isVerified) ...[
                        SizedBox(width: 8),
                        Icon(Icons.verified, color: AppColors.successGreen, size: 20),
                      ],
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 13, color: AppColors.textLight),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, color: AppColors.primaryOrange, size: 14),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${user.state ?? 'Unknown'} • ${user.universityName ?? 'Unknown University'}',
                          style: TextStyle(fontSize: 12, color: AppColors.textLight),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}