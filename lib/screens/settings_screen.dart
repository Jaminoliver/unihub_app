import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  
  bool _isDarkMode = false;
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _marketingEmails = false;
  bool _orderUpdates = true;
  bool _promotions = true;
  bool _twoFactorEnabled = false;
  
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _smsNotifications = prefs.getBool('sms_notifications') ?? false;
      _marketingEmails = prefs.getBool('marketing_emails') ?? false;
      _orderUpdates = prefs.getBool('order_updates') ?? true;
      _promotions = prefs.getBool('promotions') ?? true;
      _twoFactorEnabled = prefs.getBool('two_factor_enabled') ?? false;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('$feature coming soon!'),
          ],
        ),
        backgroundColor: AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings', style: AppTextStyles.heading.copyWith(fontSize: 18)),
        centerTitle: false,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              _buildSwitchTile(
                title: 'Dark Mode',
                subtitle: 'Switch to dark theme',
                icon: Icons.dark_mode_outlined,
                value: _isDarkMode,
                onChanged: (val) {
                  setState(() => _isDarkMode = val);
                  _savePref('dark_mode', val);
                  _showComingSoon('Dark mode');
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildSection(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            children: [
              _buildSwitchTile(
                title: 'Push Notifications',
                subtitle: 'Receive notifications on your device',
                icon: Icons.notifications_active_outlined,
                value: _pushNotifications,
                onChanged: (val) {
                  setState(() => _pushNotifications = val);
                  _savePref('push_notifications', val);
                },
              ),
              Divider(height: 1, indent: 56),
              _buildSwitchTile(
                title: 'Order Updates',
                subtitle: 'Get notified about order status',
                icon: Icons.shopping_bag_outlined,
                value: _orderUpdates,
                onChanged: (val) {
                  setState(() => _orderUpdates = val);
                  _savePref('order_updates', val);
                },
              ),
              Divider(height: 1, indent: 56),
              _buildSwitchTile(
                title: 'Email Notifications',
                subtitle: 'Receive updates via email',
                icon: Icons.email_outlined,
                value: _emailNotifications,
                onChanged: (val) {
                  setState(() => _emailNotifications = val);
                  _savePref('email_notifications', val);
                },
              ),
              Divider(height: 1, indent: 56),
              _buildSwitchTile(
                title: 'SMS Notifications',
                subtitle: 'Get order alerts via SMS',
                icon: Icons.sms_outlined,
                value: _smsNotifications,
                onChanged: (val) {
                  setState(() => _smsNotifications = val);
                  _savePref('sms_notifications', val);
                },
              ),
              Divider(height: 1, indent: 56),
              _buildSwitchTile(
                title: 'Promotions & Offers',
                subtitle: 'Receive exclusive deals',
                icon: Icons.local_offer_outlined,
                value: _promotions,
                onChanged: (val) {
                  setState(() => _promotions = val);
                  _savePref('promotions', val);
                },
              ),
              Divider(height: 1, indent: 56),
              _buildSwitchTile(
                title: 'Marketing Emails',
                subtitle: 'Newsletter and updates',
                icon: Icons.campaign_outlined,
                value: _marketingEmails,
                onChanged: (val) {
                  setState(() => _marketingEmails = val);
                  _savePref('marketing_emails', val);
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildSection(
            title: 'Privacy & Security',
            icon: Icons.security_outlined,
            children: [
              _buildNavTile(
                title: 'Change Password',
                subtitle: 'Update your password',
                icon: Icons.lock_outline,
                onTap: () => _showComingSoon('Change password'),
              ),
              Divider(height: 1, indent: 56),
              _buildSwitchTile(
                title: 'Two-Factor Authentication',
                subtitle: 'Add extra security to your account',
                icon: Icons.verified_user_outlined,
                value: _twoFactorEnabled,
                onChanged: (val) {
                  setState(() => _twoFactorEnabled = val);
                  _savePref('two_factor_enabled', val);
                  _showComingSoon('Two-factor authentication');
                },
              ),
              Divider(height: 1, indent: 56),
              _buildNavTile(
                title: 'Privacy Settings',
                subtitle: 'Manage your data and privacy',
                icon: Icons.privacy_tip_outlined,
                onTap: () => _showComingSoon('Privacy settings'),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildSection(
            title: 'Preferences',
            icon: Icons.tune_outlined,
            children: [
              _buildNavTile(
                title: 'Language',
                subtitle: 'English (US)',
                icon: Icons.language_outlined,
                trailing: Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
                onTap: () => _showComingSoon('Language selection'),
              ),
              Divider(height: 1, indent: 56),
              _buildNavTile(
                title: 'Region',
                subtitle: 'Nigeria',
                icon: Icons.location_on_outlined,
                trailing: Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
                onTap: () => _showComingSoon('Region selection'),
              ),
              Divider(height: 1, indent: 56),
              _buildNavTile(
                title: 'Currency',
                subtitle: 'Nigerian Naira (₦)',
                icon: Icons.attach_money_outlined,
                trailing: Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
                onTap: () => _showComingSoon('Currency selection'),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildSection(
            title: 'About',
            icon: Icons.info_outline,
            children: [
              _buildNavTile(
                title: 'Terms of Service',
                icon: Icons.description_outlined,
                onTap: () => _showComingSoon('Terms of Service'),
              ),
              Divider(height: 1, indent: 56),
              _buildNavTile(
                title: 'Privacy Policy',
                icon: Icons.policy_outlined,
                onTap: () => _showComingSoon('Privacy Policy'),
              ),
              Divider(height: 1, indent: 56),
              _buildNavTile(
                title: 'About UniHub',
                icon: Icons.school_outlined,
                onTap: () => _showComingSoon('About UniHub'),
              ),
            ],
          ),
          SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primaryOrange, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: AppTextStyles.subheading.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: value ? AppColors.primaryOrange.withOpacity(0.1) : AppColors.lightGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: value ? AppColors.primaryOrange : AppColors.textLight, size: 20),
      ),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textLight)) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryOrange,
        activeTrackColor: AppColors.primaryOrange.withOpacity(0.3),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildNavTile({
    required String title,
    String? subtitle,
    required IconData icon,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.lightGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textLight, size: 20),
      ),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textLight)) : null,
      trailing: trailing ?? Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
    );
  }
}