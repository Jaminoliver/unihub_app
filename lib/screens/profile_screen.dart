import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../models/user_model.dart';
import 'edit_profile_screen.dart';
import '../widgets/unihub_loading_widget.dart';

// Theme matching home screen
const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kNavyBlue = Color(0xFF1E3A8A);
const kTextLight = Color(0xFF6B7280);
const kTextDark = Color(0xFF1F2937);
const kAshGray = Color(0xFFF5F5F7);
const kWhite = Colors.white;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  UserModel? _currentUser;
  Map<String, dynamic>? _deliveryAddress;
  bool _isLoading = true;
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
        final address = await _profileService.getDefaultDeliveryAddress(user.id);
        if (mounted) {
          setState(() {
            _currentUser = user;
            _deliveryAddress = address;
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
                const Icon(Icons.error_outline, color: kWhite),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Logout failed: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
          deliveryAddress: _deliveryAddress,
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
        backgroundColor: kAshGray,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: const UniHubLoader(size: 80),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
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
                  child: const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
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

    if (_currentUser == null) {
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
                  child: const Icon(
                    Icons.person_outline,
                    size: 64,
                    color: kWhite,
                  ),
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

    return Scaffold(
      backgroundColor: kAshGray,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: const Text(
            'Profile',
            style: TextStyle(
              color: kWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: ShaderMask(
              shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
              child: const Icon(Icons.edit_outlined, color: kWhite),
            ),
            onPressed: _navigateToEditProfile,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: const Color(0xFFFF6B35),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildProfileHeader(),
              const SizedBox(height: 12),
              _buildContactSection(),
              const SizedBox(height: 12),
              _buildSettingsSection(),
              if (!_currentUser!.isSeller) ...[
                const SizedBox(height: 12),
                _buildAccountTypeCard(),
              ],
              const SizedBox(height: 12),
              _buildLogoutButton(),
              const SizedBox(height: 16),
              _buildAppVersion(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final user = _currentUser!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: kOrangeGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: user.profileImageUrl != null
                      ? Image.network(
                          user.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                _getInitials(user.fullName),
                                style: const TextStyle(
                                  color: kWhite,
                                  fontSize: 24,
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
                              color: kWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kTextDark,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF10B981),
                        size: 16,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(color: kTextLight, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFFFF6B35),
                      size: 12,
                    ),
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
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    kOrangeGradient.createShader(bounds),
                child: const Icon(
                  Icons.contact_phone_outlined,
                  size: 16,
                  color: kWhite,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kTextDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: user.phoneNumber ?? 'Not provided',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value: _formatAddress(),
            color: const Color(0xFF3B82F6),
          ),
          if (addressPhone != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.phone_in_talk_outlined,
              label: 'Delivery Phone',
              value: addressPhone,
              color: const Color(0xFFFF6B35),
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
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    kOrangeGradient.createShader(bounds),
                child: const Icon(
                  Icons.settings_outlined,
                  size: 16,
                  color: kWhite,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kTextDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            color: const Color(0xFFF59E0B),
            onTap: () => _showComingSoon(),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'Safety & Privacy',
            color: const Color(0xFF8B5CF6),
            onTap: () => _showComingSoon(),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            color: const Color(0xFF10B981),
            onTap: () => _showComingSoon(),
          ),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: kWhite),
            SizedBox(width: 12),
            Text('Coming soon!'),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildAccountTypeCard() {
    final user = _currentUser!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.1),
            const Color(0xFF3B82F6).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: kWhite,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag,
              color: Color(0xFF3B82F6),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buyer Account',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse and buy products from sellers at ${user.universityName ?? 'your university'}',
                  style: const TextStyle(fontSize: 11, color: kTextLight),
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
          style: TextStyle(fontSize: 11, color: kTextLight),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: kTextLight),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable Widgets
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: kTextLight),
              ),
              const SizedBox(height: 2),
              Text(
                value,
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
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kAshGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextDark,
                ),
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
              child: const Icon(Icons.chevron_right, color: kWhite, size: 18),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: kWhite),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: kWhite,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Logout Animation Dialog (reused from signup)
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
          color: kWhite,
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
                  color: kWhite,
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
                      color: kTextDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'See you soon!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: kTextLight),
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

// Enlarged Photo View
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
          // Dismiss on tap outside
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.transparent,
            ),
          ),
          // Centered photo
          Center(
            child: Hero(
              tag: 'profile_photo_${user.id}',
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.width * 0.85,
                decoration: BoxDecoration(
                  gradient: kOrangeGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: user.profileImageUrl != null
                      ? Image.network(
                          user.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                getInitials(user.fullName),
                                style: const TextStyle(
                                  color: kWhite,
                                  fontSize: 80,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            getInitials(user.fullName),
                            style: const TextStyle(
                              color: kWhite,
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          // Top controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          kOrangeGradient.createShader(bounds),
                      child: const Icon(
                        Icons.arrow_back,
                        color: kWhite,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                // Change photo button
                GestureDetector(
                  onTap: onChangePhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: kOrangeGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.camera_alt, color: kWhite, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Change Photo',
                          style: TextStyle(
                            color: kWhite,
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
          // Bottom user info
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kWhite.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
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
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kTextDark,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kTextLight,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFFFF6B35),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${user.state ?? 'Unknown'} • ${user.universityName ?? 'Unknown University'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kTextLight,
                          ),
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