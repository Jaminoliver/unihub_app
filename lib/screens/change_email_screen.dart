import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'auth/otp_verification_screen.dart';

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newEmailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  String? _currentEmail;

  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentEmail() async {
    final user = _authService.currentUser;
    if (user != null) {
      setState(() => _currentEmail = user.email);
    }
  }

  Future<void> _changeEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newEmail = _newEmailController.text.trim();
      
      await _authService.sendEmailChangeOTP(newEmail);

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPVerificationScreen(
            email: newEmail,
            otpType: 'email_change',
            title: 'Verify New Email',
            subtitle: 'Enter the code sent to',
            onVerify: (otp) async {
              try {
                await _authService.verifyEmailChangeOTP(
                  newEmail: newEmail,
                  otp: otp,
                );

                if (!mounted) return;

                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Dialog(
                    backgroundColor: AppColors.getCardBackground(context),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.successGreen,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check, color: Colors.white, size: 48),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Email Changed!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Your email has been updated successfully. You\'ll be logged out for security.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.getTextMuted(context),
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Continue to Login',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                if (!mounted) return;

                await _authService.signOut();

                if (!mounted) return;

                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              } catch (e) {
                rethrow;
              }
            },
            onResend: () async {
              await _authService.sendEmailChangeOTP(newEmail);
            },
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text(e.message)),
            ],
          ),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('An error occurred. Please try again.')),
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an email address';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    if (_currentEmail != null && value.toLowerCase() == _currentEmail!.toLowerCase()) {
      return 'New email must be different from current email';
    }
    
    return null;
  }

  String? _validateConfirmEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your email address';
    }
    if (value != _newEmailController.text) {
      return 'Email addresses do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getCardBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Change Email',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Email Card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.getCardBackground(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.email_outlined, color: AppColors.primaryOrange, size: 22),
                    ),
                    title: Text(
                      'Current Email',
                      style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context), fontWeight: FontWeight.w500),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        _currentEmail ?? 'Loading...',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Info Notice
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryOrange.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primaryOrange, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You\'ll receive a verification code at your new email address',
                          style: TextStyle(fontSize: 13, color: AppColors.getTextPrimary(context), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32),

                // New Email Field
                Text(
                  'New Email Address',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.getCardBackground(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryOrange, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.errorRed),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.errorRed, width: 1.5),
                    ),
                    hintText: 'Enter new email address',
                    hintStyle: TextStyle(color: AppColors.getTextMuted(context), fontSize: 14),
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.getTextMuted(context), size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),

                SizedBox(height: 20),

                // Confirm Email Field
                Text(
                  'Confirm New Email',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _confirmEmailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateConfirmEmail,
                  style: TextStyle(color: AppColors.getTextPrimary(context)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.getCardBackground(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryOrange, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.errorRed),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.errorRed, width: 1.5),
                    ),
                    hintText: 'Confirm new email address',
                    hintStyle: TextStyle(color: AppColors.getTextMuted(context), fontSize: 14),
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.getTextMuted(context), size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),

                SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changeEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      disabledBackgroundColor: AppColors.primaryOrange.withOpacity(0.5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text('Change Email', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),

                SizedBox(height: 24),

                // Important Notes
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.getCardBackground(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.primaryOrange, size: 18),
                            SizedBox(width: 10),
                            Text(
                              'Important Information',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(14),
                        child: Column(
                          children: [
                            _buildInfoRow(Icons.mark_email_read, 'Verification code will be sent to your new email'),
                            SizedBox(height: 12),
                            _buildInfoRow(Icons.lock_outline, 'Your password remains unchanged'),
                            SizedBox(height: 12),
                            _buildInfoRow(Icons.login, 'Use new email for future logins'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.getTextMuted(context)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context), height: 1.4),
          ),
        ),
      ],
    );
  }
}