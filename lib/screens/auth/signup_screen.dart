import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/university_category_services.dart';
import '../../services/otp_service.dart';
import '../../models/university_category_models.dart';
import '../../main.dart';
import 'welcome_animation_screen.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();

  final AuthService _authService = AuthService();
  final UniversityService _universityService = UniversityService();
  final OTPService _otpService = OTPService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _selectedState;
  String? _selectedUniversityId;
  List<UniversityModel> _universities = [];
  List<UniversityModel> _filteredUniversities = [];
  bool _isLoadingUniversities = false;
  bool _hasTriedToSelectUniversity = false;

  late AnimationController _successAnimationController;
  late AnimationController _errorAnimationController;

  final Map<String, String> _stateMapping = {
    'Abia': 'Abia',
    'Adamawa': 'Adamawa',
    'Akwa Ibom': 'Akwa Ibom',
    'Anambra': 'Anambra',
    'Bauchi': 'Bauchi',
    'Bayelsa': 'Bayelsa',
    'Benue': 'Benue',
    'Borno': 'Borno',
    'Cross River': 'Cross River',
    'Delta': 'Delta',
    'Ebonyi': 'Ebonyi',
    'Edo': 'Edo',
    'Ekiti': 'Ekiti',
    'Enugu': 'Enugu',
    'Gombe': 'Gombe',
    'Imo': 'Imo',
    'Jigawa': 'Jigawa',
    'Kaduna': 'Kaduna',
    'Kano': 'Kano',
    'Katsina': 'Katsina',
    'Kebbi': 'Kebbi',
    'Kogi': 'Kogi',
    'Kwara': 'Kwara',
    'Lagos': 'Lagos',
    'Nasarawa': 'Nasarawa',
    'Niger': 'Niger',
    'Ogun': 'Ogun',
    'Ondo': 'Ondo',
    'Osun': 'Osun',
    'Oyo': 'Oyo',
    'Plateau': 'Plateau',
    'Rivers': 'Rivers',
    'Sokoto': 'Sokoto',
    'Taraba': 'Taraba',
    'Yobe': 'Yobe',
    'Zamfara': 'Zamfara',
    'Abuja (FCT)': 'FCT',
  };

  @override
  void initState() {
    super.initState();
    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _errorAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadUniversities();
  }

  Future<void> _loadUniversities() async {
    setState(() => _isLoadingUniversities = true);
    try {
      _universities = await _universityService.getAllUniversities();
      print('Loaded ${_universities.length} universities');
    } catch (e) {
      print('Error loading universities: $e');
      _showErrorSnackBar(
          'Failed to load universities. Please check your connection.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingUniversities = false);
      }
    }
  }

  void _filterUniversitiesByState(String displayState) {
    final dbState = _stateMapping[displayState] ?? displayState;

    setState(() {
      _filteredUniversities = _universities.where((uni) {
        return uni.state.trim().toLowerCase() == dbState.trim().toLowerCase();
      }).toList();

      _selectedUniversityId = null;
      _hasTriedToSelectUniversity = false;

      print('Filtering by display state: $displayState (DB: $dbState)');
      print('Found ${_filteredUniversities.length} universities');
    });

    if (_filteredUniversities.isEmpty && mounted) {
      _showErrorSnackBar('No universities found for $displayState');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _successAnimationController.dispose();
    _errorAnimationController.dispose();
    super.dispose();
  }

  /// NEW: Handle signup with OTP flow
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorAnimation();
      return;
    }

    if (_selectedState == null) {
      _showErrorSnackBar('Please select your state');
      _showErrorAnimation();
      return;
    }

    if (_selectedUniversityId == null) {
      setState(() => _hasTriedToSelectUniversity = true);
      _showErrorSnackBar('Please select your university');
      _showErrorAnimation();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      // Step 1: Send OTP
      await _authService.sendSignupOTP(email);

      if (mounted) {
        setState(() => _isLoading = false);

        // Step 2: Navigate to OTP screen
        final dbState = _stateMapping[_selectedState!] ?? _selectedState!;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OTPVerificationScreen(
              email: email,
              otpType: 'signup',
              title: 'Verify Your Email',
              subtitle: 'Enter the code we sent to',
             onVerify: (otp) async {
  // Step 3: Verify OTP and create account
  await _authService.verifySignupOTP(
    email: email,
    otp: otp,
    password: _passwordController.text,
    fullName: _fullNameController.text.trim(),
    phoneNumber: _phoneController.text.trim(),
    universityId: _selectedUniversityId!,
    state: dbState,
    deliveryAddress: _addressController.text.trim(),
  );

  if (mounted) {
    // Navigate to Welcome Animation Screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WelcomeAnimationScreen(
          userName: _fullNameController.text.trim(),
        ),
      ),
      (route) => false,
    );
  }
},
              onResend: () async {
                await _otpService.resendOTP(
                  email: email,
                  type: 'signup',
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Sign up failed: ${e.toString()}');
        _showErrorAnimation();
      }
    }
  }

  Future<void> _showSuccessAnimation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _SuccessDialog(controller: _successAnimationController),
    );
  }

  void _showErrorAnimation() {
    _errorAnimationController.forward().then((_) {
      _errorAnimationController.reverse();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _truncateUniversityName(String name, String shortName) {
    if (name.length <= 35) return name;
    return shortName.isNotEmpty ? shortName : '${name.substring(0, 32)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _errorAnimationController,
          builder: (context, child) {
            final offset = _errorAnimationController.value * 10;
            return Transform.translate(
              offset: Offset(
                offset *
                    ((_errorAnimationController.value * 4).round() % 2 == 0
                        ? 1
                        : -1),
                0,
              ),
              child: child,
            );
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'UniHub',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Join and start shopping',
                          style:
                              TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _buildTextField(
                    controller: _fullNameController,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    icon: FontAwesomeIcons.user,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    icon: FontAwesomeIcons.envelope,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'Enter your phone number',
                    icon: FontAwesomeIcons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (value.length < 10) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // State Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedState,
                    decoration: InputDecoration(
                      labelText: 'State',
                      hintText: 'Select your state first',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: const FaIcon(
                          FontAwesomeIcons.locationDot,
                          size: 20,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFFFF6B35), width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    items: _stateMapping.keys.map((state) {
                      return DropdownMenuItem(
                        value: state,
                        child: Text(
                          state,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedState = value;
                          _hasTriedToSelectUniversity = false;
                        });
                        _filterUniversitiesByState(value);
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select your state';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // University Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedUniversityId,
                    decoration: InputDecoration(
                      labelText: 'University',
                      hintText: _isLoadingUniversities
                          ? 'Loading universities...'
                          : _selectedState == null
                              ? 'Select state first ↑'
                              : _filteredUniversities.isEmpty
                                  ? 'No universities available'
                                  : 'Select your university',
                      hintStyle: TextStyle(
                        color: _selectedState == null
                            ? const Color(0xFFFF6B35).withOpacity(0.6)
                            : Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      prefixIcon: _isLoadingUniversities
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFF6B35)),
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(12),
                              child: FaIcon(
                                FontAwesomeIcons.graduationCap,
                                size: 20,
                                color: _selectedState == null
                                    ? Colors.grey.shade400
                                    : const Color(0xFFFF6B35),
                              ),
                            ),
                      suffixIcon: _selectedState != null &&
                              _filteredUniversities.isEmpty
                          ? const Icon(Icons.info_outline,
                              color: Color(0xFFFF6B35))
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: _hasTriedToSelectUniversity &&
                                  _selectedUniversityId == null
                              ? const Color(0xFFDC2626)
                              : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFFFF6B35), width: 2),
                      ),
                      filled: true,
                      fillColor: _selectedState == null
                          ? Colors.grey.shade100
                          : const Color(0xFFFAFAFA),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    items: (_filteredUniversities.isNotEmpty)
                        ? _filteredUniversities.map((uni) {
                            return DropdownMenuItem(
                              value: uni.id,
                              child: Tooltip(
                                message: uni.name,
                                child: Text(
                                  _truncateUniversityName(
                                      uni.name, uni.shortName),
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            );
                          }).toList()
                        : null,
                    onChanged: (_selectedState == null ||
                            _isLoadingUniversities ||
                            _filteredUniversities.isEmpty)
                        ? null
                        : (value) {
                            setState(() {
                              _selectedUniversityId = value;
                              _hasTriedToSelectUniversity = true;
                            });
                          },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select your university';
                      }
                      return null;
                    },
                    selectedItemBuilder: (context) {
                      return _filteredUniversities.map((uni) {
                        return Container(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _truncateUniversityName(uni.name, uni.shortName),
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList();
                    },
                  ),

                  if (_selectedState != null &&
                      _filteredUniversities.isEmpty &&
                      !_isLoadingUniversities)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 14, color: Color(0xFFFF6B35)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'No universities found in $_selectedState',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFFF6B35),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _addressController,
                    label: 'Delivery Address',
                    hint: 'Enter your campus/delivery address',
                    icon: FontAwesomeIcons.house,
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your delivery address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildPasswordField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Create a password',
                    obscureText: _obscurePassword,
                    onToggle: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please create a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hint: 'Re-enter your password',
                    obscureText: _obscureConfirmPassword,
                    onToggle: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        disabledBackgroundColor:
                            const Color(0xFFFF6B35).withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Container(
          padding: const EdgeInsets.all(12),
          child: FaIcon(icon, size: 20, color: const Color(0xFFFF6B35)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Container(
          padding: const EdgeInsets.all(12),
          child: const FaIcon(
            FontAwesomeIcons.lock,
            size: 20,
            color: Color(0xFFFF6B35),
          ),
        ),
        suffixIcon: IconButton(
          icon: FaIcon(
            obscureText ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
            size: 18,
            color: Colors.grey.shade600,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}

class _SuccessDialog extends StatefulWidget {
  final AnimationController controller;

  const _SuccessDialog({required this.controller});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog> {
  @override
  void initState() {
    super.initState();
    widget.controller.forward();
    Future.delayed(const Duration(milliseconds: 2000), () {
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
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
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
                    'Account Created!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Welcome to UniHub!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
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