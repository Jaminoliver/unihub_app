import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../models/user_model.dart';
import 'auth/login_screen.dart';
import 'edit_profile_screen.dart';
import '../widgets/unihub_loading_widget.dart';

class AppTheme {
  static const orangeStart = Color(0xFFFF6B35);
  static const orangeEnd = Color(0xFFFF8C42);
  static const navyBlue = Color(0xFF1E3A8A);
  static const white = Colors.white;
  static const ashGray = Color(0xFFF5F5F7);
  static const textDark = Color(0xFF1F2937);
  static const textLight = Color(0xFF6B7280);
  
  static final gradient = LinearGradient(
    colors: [orangeStart, orangeEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  UserModel? _currentUser;
  Map<String, dynamic>? _deliveryAddress;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _profileService.getCurrentUserProfile();
      
      if (user != null) {
        final address = await _profileService.getDefaultDeliveryAddress(user.id);
        
        if (mounted) {
          setState(() {
            _currentUser = user;
            _deliveryAddress = address;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentUser = null;
            _isLoading = false;
          });
        }
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
      await _authService.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _navigateToEditProfile() async {
    if (_currentUser == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          user: _currentUser!,
          deliveryAddress: _deliveryAddress,
        ),
      ),
    );

    if (result == true) {
      _loadUserProfile();
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  String _formatAddress() {
    if (_deliveryAddress == null) return 'Not provided';
    
    final parts = <String>[];
    if (_deliveryAddress!['address_line'] != null) {
      parts.add(_deliveryAddress!['address_line']);
    }
    if (_deliveryAddress!['city'] != null) {
      parts.add(_deliveryAddress!['city']);
    }
    if (_deliveryAddress!['state'] != null) {
      parts.add(_deliveryAddress!['state']);
    }
    
    return parts.isEmpty ? 'Not provided' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();
    if (_errorMessage != null) return _buildErrorScreen();
    if (_currentUser == null) return _buildNotLoggedInScreen();

    return Scaffold(
      backgroundColor: AppTheme.ashGray,
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: AppTheme.orangeStart,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildProfileHeader(),
                  SizedBox(height: 16),
                  _buildContactSection(),
                  SizedBox(height: 12),
                  _buildSettingsSection(),
                  SizedBox(height: 12),
                  _buildAccountTypeCard(),
                  SizedBox(height: 12),
                  _buildLogoutButton(),
                  SizedBox(height: 16),
                  _buildAppVersion(),
                  SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppTheme.ashGray,
      body: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          child: UniHubLoader(size: 80),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: AppTheme.ashGray,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, size: 64, color: Colors.red),
              ),
              SizedBox(height: 24),
              Text(
                'Error Loading Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyBlue,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error',
                style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              _GradientButton(
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

  Widget _buildNotLoggedInScreen() {
    return Scaffold(
      backgroundColor: AppTheme.ashGray,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.gradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_outline, size: 64, color: Colors.white),
              ),
              SizedBox(height: 24),
              Text(
                'Not Logged In',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyBlue,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please log in to view your profile',
                style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              _GradientButton(
                text: 'Log In',
                icon: Icons.login,
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.white,
      expandedHeight: 0,
      toolbarHeight: 56,
      automaticallyImplyLeading: false,
      title: Text(
        'Profile',
        style: TextStyle(
          color: AppTheme.navyBlue,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        _CircleButton(
          icon: Icons.edit_outlined,
          onPressed: _navigateToEditProfile,
        ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildProfileHeader() {
    final user = _currentUser!;
    
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: AppTheme.gradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.orangeStart.withOpacity(0.3),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: user.profileImageUrl != null
                  ? Image.network(
                      user.profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            _getInitials(user.fullName),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        _getInitials(user.fullName),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          SizedBox(height: 16),
          
          // Name and verified
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyBlue,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (user.isVerified) ...[
                SizedBox(width: 8),
                Icon(Icons.verified, color: Color(0xFF10B981), size: 20),
              ],
            ],
          ),
          SizedBox(height: 6),
          
          // Email
          Text(
            user.email,
            style: TextStyle(
              color: AppTheme.textLight,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          
          // State and University
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, color: AppTheme.textLight, size: 14),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${user.state ?? 'Unknown'} • ${user.universityName ?? 'Unknown University'}',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    final user = _currentUser!;
    final addressPhone = _deliveryAddress?['phone_number'];
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                child: Icon(Icons.contact_phone_outlined, size: 18, color: Colors.white),
              ),
              SizedBox(width: 8),
              Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Phone
          _InfoTile(
            icon: Icons.phone_outlined,
            iconColor: Colors.green,
            iconBgColor: Colors.green.shade50,
            title: 'Phone Number',
            subtitle: user.phoneNumber ?? 'Not provided',
          ),
          
          SizedBox(height: 12),
          
          // Delivery Address
          _InfoTile(
            icon: Icons.location_on_outlined,
            iconColor: Colors.blue,
            iconBgColor: Colors.blue.shade50,
            title: 'Delivery Address',
            subtitle: _formatAddress(),
          ),
          
          if (addressPhone != null) ...[
            SizedBox(height: 12),
            _InfoTile(
              icon: Icons.phone_in_talk_outlined,
              iconColor: Colors.orange,
              iconBgColor: Colors.orange.shade50,
              title: 'Delivery Phone',
              subtitle: addressPhone,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                child: Icon(Icons.settings_outlined, size: 18, color: Colors.white),
              ),
              SizedBox(width: 8),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          _SettingsTile(
            icon: Icons.notifications_outlined,
            iconColor: Colors.amber,
            iconBgColor: Colors.amber.shade50,
            title: 'Notifications',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Coming soon!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          
          SizedBox(height: 12),
          
          _SettingsTile(
            icon: Icons.shield_outlined,
            iconColor: Colors.purple,
            iconBgColor: Colors.purple.shade50,
            title: 'Safety & Privacy',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Coming soon!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          
          SizedBox(height: 12),
          
          _SettingsTile(
            icon: Icons.help_outline,
            iconColor: Colors.teal,
            iconBgColor: Colors.teal.shade50,
            title: 'Help & Support',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Coming soon!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTypeCard() {
    final user = _currentUser!;
    
    if (user.isSeller) return SizedBox.shrink();
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_bag, color: Colors.blue, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buyer Account',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyBlue,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Browse and buy products from sellers at ${user.universityName ?? 'your university'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () => _showLogoutDialog(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
            color: AppTheme.textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Making campus commerce easier and safer',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textLight,
          ),
        ),
      ],
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
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout, color: Colors.red, size: 20),
            ),
            SizedBox(width: 12),
            Text('Log Out', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppTheme.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textLight)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            child: Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// Reusable Widgets
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: ShaderMask(
          shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, color: AppTheme.textLight),
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.ashGray,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
              child: Icon(Icons.chevron_right, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;

  const _GradientButton({
    required this.text,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: onPressed != null ? AppTheme.gradient : null,
        color: onPressed == null ? AppTheme.textLight.withOpacity(0.3) : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AppTheme.orangeStart.withOpacity(0.3),
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
            if (icon != null) ...[
              Icon(icon, size: 20, color: Colors.white),
              SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}