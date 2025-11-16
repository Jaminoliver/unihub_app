import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../models/user_model.dart';
import 'edit_profile_screen.dart';
import '../widgets/unihub_loading_widget.dart';

// Simplified theme constants
const kOrangeGradient = LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]);
const kNavyBlue = Color(0xFF1E3A8A);
const kTextLight = Color(0xFF6B7280);
const kTextDark = Color(0xFF1F2937);
const kAshGray = Color(0xFFF5F5F7);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  UserModel? _currentUser;
  Map<String, dynamic>? _deliveryAddress;
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _logoutAnimationController;

  @override
  void initState() {
    super.initState();
    _logoutAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadUserProfile();
  }

  @override
  void dispose() {
    _logoutAnimationController.dispose();
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
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Logout failed: ${e.toString()}', 
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _showLogoutAnimation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LogoutDialog(controller: _logoutAnimationController),
    );
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
      backgroundColor: kAshGray,
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: const Color(0xFFFF6B35),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 16),
                  _buildContactSection(),
                  const SizedBox(height: 12),
                  _buildSettingsSection(),
                  const SizedBox(height: 12),
                  _buildAccountTypeCard(),
                  const SizedBox(height: 12),
                  _buildLogoutButton(),
                  const SizedBox(height: 16),
                  _buildAppVersion(),
                  const SizedBox(height: 80),
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
      backgroundColor: kAshGray,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: const UniHubLoader(size: 80),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: kAshGray,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 64, color: Colors.red),
              ),
              const SizedBox(height: 24),
              const Text(
                'Error Loading Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kNavyBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error',
                style: const TextStyle(color: kTextLight, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
      backgroundColor: kAshGray,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: kOrangeGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Not Logged In',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kNavyBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please log in to view your profile',
                style: TextStyle(color: kTextLight, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _GradientButton(
                text: 'Log In',
                icon: Icons.login,
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/account_type',
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
      backgroundColor: Colors.white,
      expandedHeight: 0,
      toolbarHeight: 56,
      automaticallyImplyLeading: false,
      title: const Text(
        'Profile',
        style: TextStyle(
          color: kNavyBlue,
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
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildProfileHeader() {
    final user = _currentUser!;
    
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: kOrangeGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: user.profileImageUrl != null
                  ? Image.network(
                      user.profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            _getInitials(user.fullName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        _getInitials(user.fullName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kNavyBlue,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: kTextLight,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: kTextLight, size: 13),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${user.state ?? 'Unknown'} • ${user.universityName ?? 'Unknown University'}',
                        style: const TextStyle(color: kTextLight, fontSize: 11),
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

  Widget _buildContactSection() {
    final user = _currentUser!;
    final addressPhone = _deliveryAddress?['phone_number'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
                child: const Icon(Icons.contact_phone_outlined, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kNavyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoTile(
            icon: Icons.phone_outlined,
            iconColor: Colors.green,
            iconBgColor: Colors.green.shade50,
            title: 'Phone Number',
            subtitle: user.phoneNumber ?? 'Not provided',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.location_on_outlined,
            iconColor: Colors.blue,
            iconBgColor: Colors.blue.shade50,
            title: 'Delivery Address',
            subtitle: _formatAddress(),
          ),
          if (addressPhone != null) ...[
            const SizedBox(height: 12),
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
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
                child: const Icon(Icons.settings_outlined, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kNavyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            iconColor: Colors.amber,
            iconBgColor: Colors.amber.shade50,
            title: 'Notifications',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Coming soon!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.shield_outlined,
            iconColor: Colors.purple,
            iconBgColor: Colors.purple.shade50,
            title: 'Safety & Privacy',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Coming soon!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.help_outline,
            iconColor: Colors.teal,
            iconBgColor: Colors.teal.shade50,
            title: 'Help & Support',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Coming soon!'),
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
    
    if (user.isSeller) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_bag, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buyer Account',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: kNavyBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse and buy products from sellers at ${user.universityName ?? 'your university'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTextLight,
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
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () => _showLogoutDialog(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200, width: 1.5),
          ),
          child: const Row(
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
    return const Column(
      children: [
        Text(
          'UniHub v1.0.0',
          style: TextStyle(
            fontSize: 12,
            color: kTextLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Making campus commerce easier and safer',
          style: TextStyle(
            fontSize: 11,
            color: kTextLight,
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Log Out', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: kTextLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kTextLight)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: kTextLight),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextDark,
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kAshGray,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextDark,
                ),
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
              child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
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
        gradient: onPressed != null ? kOrangeGradient : null,
        color: onPressed == null ? kTextLight.withOpacity(0.3) : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
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

// Logout Animation Dialog
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
        padding: const EdgeInsets.all(32),
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
                decoration: const BoxDecoration(
                  gradient: kOrangeGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.waving_hand,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: widget.controller,
              child: const Column(
                children: [
                  Text(
                    'Logging Out...',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'See you soon!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: kTextLight,
                    ),
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