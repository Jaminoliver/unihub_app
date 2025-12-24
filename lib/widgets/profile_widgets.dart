import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../constants/app_colors.dart';
import '../screens/settings_screen.dart';
import '../screens/help_and_support_screen.dart';
import '../screens/reviews_screen.dart';

// ==================== PROFILE HEADER ====================
class ProfileHeader extends StatelessWidget {
  final UserModel user;
  final VoidCallback onPhotoTap;

  const ProfileHeader({super.key, required this.user, required this.onPhotoTap});

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      color: AppColors.getCardBackground(context),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPhotoTap,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
                ),
                borderRadius: BorderRadius.circular(35),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: user.profileImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: user.profileImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        errorWidget: (_, __, ___) => Center(child: Text(_getInitials(user.fullName), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                      )
                    : Center(child: Text(_getInitials(user.fullName), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isVerified) ...[SizedBox(width: 6), Icon(Icons.verified, color: AppColors.primaryOrange, size: 18)],
                  ],
                ),
                SizedBox(height: 4),
                Text(user.email, style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context)), overflow: TextOverflow.ellipsis),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.getTextMuted(context), size: 14),
                    SizedBox(width: 4),
                    Text('${user.state ?? 'Unknown'}', style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== MENU SECTION ====================
class ProfileMenuSection extends StatelessWidget {
  final VoidCallback onOrdersTap;
  final VoidCallback onWishlistTap;

  const ProfileMenuSection({
    super.key,
    required this.onOrdersTap,
    required this.onWishlistTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      color: AppColors.getCardBackground(context),
      child: Column(
        children: [
          _MenuItem(icon: Icons.shopping_bag_outlined, title: 'My Orders', onTap: onOrdersTap),
          _MenuItem(icon: Icons.favorite_outline, title: 'My Wishlist', onTap: onWishlistTap),
          _MenuItem(icon: Icons.star_outline, title: 'My Reviews', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsScreen()))),
          _MenuItem(icon: Icons.location_on_outlined, title: 'My Addresses', onTap: () {}),
          _MenuItem(icon: Icons.credit_card_outlined, title: 'Payment Methods', onTap: () {}),
          _MenuItem(icon: Icons.settings_outlined, title: 'Settings', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()))),
          _MenuItem(icon: Icons.help_outline, title: 'Help & Support', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HelpAndSupportScreen()))),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, size: 22, color: AppColors.getTextSecondary(context)),
        title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context))),
        trailing: Icon(Icons.chevron_right, color: AppColors.getTextMuted(context), size: 20),
      ),
    );
  }
}

// ==================== LOGOUT BUTTON ====================
class LogoutButton extends StatelessWidget {
  final VoidCallback onLogout;

  const LogoutButton({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      color: AppColors.getCardBackground(context),
      child: ListTile(
        onTap: onLogout,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(Icons.logout, color: AppColors.errorRed, size: 22),
        title: Text('Log Out', style: TextStyle(color: AppColors.errorRed, fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ==================== APP VERSION FOOTER ====================
class AppVersionFooter extends StatelessWidget {
  const AppVersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text('UniHub v1.0.0', style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context), fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('Making campus commerce easier', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
        ],
      ),
    );
  }
}

// ==================== LOGOUT DIALOG ====================
class LogoutDialog extends StatefulWidget {
  final AnimationController controller;
  const LogoutDialog({super.key, required this.controller});
  @override
  State<LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<LogoutDialog> {
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
        decoration: BoxDecoration(color: AppColors.getCardBackground(context), borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(parent: widget.controller, curve: Curves.elasticOut),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(color: AppColors.primaryOrange.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(Icons.waving_hand, color: AppColors.primaryOrange, size: 40),
              ),
            ),
            SizedBox(height: 20),
            FadeTransition(
              opacity: widget.controller,
              child: Column(
                children: [
                  Text('Logging Out...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                  SizedBox(height: 6),
                  Text('See you soon!', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ENLARGED PHOTO VIEW ====================
class EnlargedPhotoView extends StatelessWidget {
  final UserModel user;
  final VoidCallback onChangePhoto;

  const EnlargedPhotoView({super.key, required this.user, required this.onChangePhoto});

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(color: AppColors.primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: user.profileImageUrl != null
                    ? CachedNetworkImage(imageUrl: user.profileImageUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Center(child: Text(_getInitials(user.fullName), style: TextStyle(color: AppColors.primaryOrange, fontSize: 60, fontWeight: FontWeight.bold))))
                    : Center(child: Text(_getInitials(user.fullName), style: TextStyle(color: AppColors.primaryOrange, fontSize: 60, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
          Positioned(top: MediaQuery.of(context).padding.top + 16, left: 16, child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.close, color: Colors.black, size: 24)))),
          Positioned(top: MediaQuery.of(context).padding.top + 16, right: 16, child: GestureDetector(onTap: onChangePhoto, child: Container(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.camera_alt, color: Colors.white, size: 16), SizedBox(width: 6), Text('Change', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))])))),
        ],
      ),
    );
  }
}

// ==================== ERROR VIEW ====================
class ProfileErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const ProfileErrorView({super.key, required this.errorMessage, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.errorRed.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.error_outline, size: 60, color: AppColors.errorRed)),
              SizedBox(height: 20),
              Text('Error Loading Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
              SizedBox(height: 8),
              Text(errorMessage, style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context)), textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton.icon(onPressed: onRetry, icon: Icon(Icons.refresh), label: Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== NOT LOGGED IN VIEW ====================
class ProfileNotLoggedInView extends StatelessWidget {
  const ProfileNotLoggedInView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.primaryOrange.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.person_outline, size: 60, color: AppColors.primaryOrange)),
              SizedBox(height: 20),
              Text('Not Logged In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
              SizedBox(height: 8),
              Text('Please log in to view your profile', style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context)), textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton.icon(onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/account_type', (route) => false), icon: Icon(Icons.login), label: Text('Log In'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
            ],
          ),
        ),
      ),
    );
  }
}