import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import 'change_password_screen.dart';
import 'change_email_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _orderUpdates = true;
  bool _promotions = true;
  
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _orderUpdates = prefs.getBool('order_updates') ?? true;
      _promotions = prefs.getBool('promotions') ?? true;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance'),
          _buildSimpleTile(
            title: 'Dark Mode',
            icon: isDark ? Icons.dark_mode : Icons.light_mode,
            trailing: Switch(
              value: isDark,
              onChanged: (val) async {
                await themeProvider.setDarkMode(val);
              },
              activeColor: AppColors.primaryOrange,
            ),
          ),
          
          SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          _buildSimpleTile(
            title: 'Push Notifications',
            icon: Icons.notifications_outlined,
            trailing: Switch(
              value: _pushNotifications,
              onChanged: (val) {
                setState(() => _pushNotifications = val);
                _savePref('push_notifications', val);
              },
              activeColor: AppColors.primaryOrange,
            ),
          ),
          _buildSimpleTile(
            title: 'Order Updates',
            icon: Icons.shopping_bag_outlined,
            trailing: Switch(
              value: _orderUpdates,
              onChanged: (val) {
                setState(() => _orderUpdates = val);
                _savePref('order_updates', val);
              },
              activeColor: AppColors.primaryOrange,
            ),
          ),
          _buildSimpleTile(
            title: 'Email Notifications',
            icon: Icons.email_outlined,
            trailing: Switch(
              value: _emailNotifications,
              onChanged: (val) {
                setState(() => _emailNotifications = val);
                _savePref('email_notifications', val);
              },
              activeColor: AppColors.primaryOrange,
            ),
          ),
          _buildSimpleTile(
            title: 'Promotions & Offers',
            icon: Icons.local_offer_outlined,
            trailing: Switch(
              value: _promotions,
              onChanged: (val) {
                setState(() => _promotions = val);
                _savePref('promotions', val);
              },
              activeColor: AppColors.primaryOrange,
            ),
          ),
          
          SizedBox(height: 24),

          // Privacy & Security Section
          _buildSectionHeader('Privacy & Security'),
          _buildSimpleTile(
            title: 'Change Password',
            icon: Icons.lock_outline,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChangePasswordScreen()),
            ),
          ),
          _buildSimpleTile(
            title: 'Change Email',
            icon: Icons.email_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChangeEmailScreen()),
            ),
          ),
          _buildSimpleTile(
            title: 'Privacy Settings',
            icon: Icons.privacy_tip_outlined,
            onTap: () => _showComingSoon('Privacy settings'),
          ),
          
          SizedBox(height: 24),

          // Preferences Section
          _buildSectionHeader('Preferences'),
          _buildSimpleTile(
            title: 'Language',
            subtitle: 'English (US)',
            icon: Icons.language_outlined,
            onTap: () => _showComingSoon('Language selection'),
          ),
          _buildSimpleTile(
            title: 'Region',
            subtitle: 'Nigeria',
            icon: Icons.location_on_outlined,
            onTap: () => _showComingSoon('Region selection'),
          ),
          _buildSimpleTile(
            title: 'Currency',
            subtitle: 'Nigerian Naira (₦)',
            icon: Icons.attach_money_outlined,
            onTap: () => _showComingSoon('Currency selection'),
          ),
          
          SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          _buildSimpleTile(
            title: 'Terms of Service',
            icon: Icons.description_outlined,
            onTap: () => _showComingSoon('Terms of Service'),
          ),
          _buildSimpleTile(
            title: 'Privacy Policy',
            icon: Icons.policy_outlined,
            onTap: () => _showComingSoon('Privacy Policy'),
          ),
          _buildSimpleTile(
            title: 'About UniHub',
            icon: Icons.info_outline,
            onTap: () => _showComingSoon('About UniHub'),
          ),
          
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.getTextMuted(context),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSimpleTile({
    required String title,
    String? subtitle,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        border: Border(
          bottom: BorderSide(
            color: AppColors.getBorder(context).withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          icon,
          size: 22,
          color: AppColors.primaryOrange, // CHANGED TO ORANGE
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextMuted(context),
                ),
              )
            : null,
        trailing: trailing ??
            (onTap != null
                ? Icon(
                    Icons.chevron_right,
                    color: AppColors.getTextMuted(context),
                    size: 20,
                  )
                : null),
      ),
    );
  }
}