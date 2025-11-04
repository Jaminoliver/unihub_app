import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/university_category_services.dart';
import '../../models/university_category_models.dart';
import '../../main.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();

  final AuthService _authService = AuthService();
  final UniversityService _universityService = UniversityService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // State and University selection
  String? _selectedState;
  String? _selectedUniversityId;
  List<UniversityModel> _universities = [];
  List<UniversityModel> _filteredUniversities = [];
  bool _isLoadingUniversities = false;

  // Nigerian states - FIX: Map display names to database values
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
    'Abuja (FCT)': 'FCT', // FIX: Map Abuja to FCT for database lookup
  };

  @override
  void initState() {
    super.initState();
    _loadUniversities();
  }

  Future<void> _loadUniversities() async {
    setState(() => _isLoadingUniversities = true);
    try {
      _universities = await _universityService.getAllUniversities();
      print(
        'Loaded ${_universities.length} universities',
      ); // FIX: Debug logging
    } catch (e) {
      print('Error loading universities: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load universities: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingUniversities = false);
      }
    }
  }

  void _filterUniversitiesByState(String displayState) {
    // FIX: Use mapped database state value for filtering
    final dbState = _stateMapping[displayState] ?? displayState;

    setState(() {
      // FIX: Case-insensitive comparison with trimming
      _filteredUniversities = _universities.where((uni) {
        return uni.state.trim().toLowerCase() == dbState.trim().toLowerCase();
      }).toList();

      _selectedUniversityId = null; // Reset university selection

      // FIX: Debug logging to help diagnose issues
      print('Filtering by display state: $displayState (DB: $dbState)');
      print('Found ${_filteredUniversities.length} universities');
      if (_filteredUniversities.isEmpty) {
        print(
          'Available states in data: ${_universities.map((u) => u.state).toSet()}',
        );
      }
    });

    // FIX: Show user-friendly message if no universities found
    if (_filteredUniversities.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No universities found for $displayState'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
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
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedState == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select your state')));
      return;
    }

    if (_selectedUniversityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your university')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // FIX: Use the mapped database state value
      final dbState = _stateMapping[_selectedState!] ?? _selectedState!;

      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        universityId: _selectedUniversityId!,
        state: dbState, // Use database state value
        deliveryAddress: _addressController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created successfully! Please check your email to verify.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BottomNavBar()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign up failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
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
                const Text(
                  'Join UniHub and start shopping',
                  style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 32),

                _buildTextField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  icon: Icons.person_outline,
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
                  icon: Icons.email_outlined,
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
                  icon: Icons.phone_outlined,
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
                    hintText: 'Select your state',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  // FIX: Use keys from state mapping
                  items: _stateMapping.keys.map((state) {
                    return DropdownMenuItem(value: state, child: Text(state));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedState = value);
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

                // University Dropdown - FIX: Better UX for empty/loading states
                DropdownButtonFormField<String>(
                  value: _selectedUniversityId,
                  decoration: InputDecoration(
                    labelText: 'University',
                    hintText: _isLoadingUniversities
                        ? 'Loading universities...'
                        : _selectedState == null
                        ? 'Select state first'
                        : _filteredUniversities.isEmpty
                        ? 'No universities available'
                        : 'Select your university',
                    prefixIcon: _isLoadingUniversities
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.school_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  // FIX: Guard against null and ensure non-empty list
                  items: (_filteredUniversities.isNotEmpty)
                      ? _filteredUniversities.map((uni) {
                          return DropdownMenuItem(
                            value: uni.id,
                            child: Text(
                              '${uni.shortName} - ${uni.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList()
                      : null, // FIX: Return null to disable dropdown when empty
                  onChanged:
                      (_selectedState == null ||
                          _isLoadingUniversities ||
                          _filteredUniversities.isEmpty)
                      ? null
                      : (value) {
                          setState(() => _selectedUniversityId = value);
                        },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select your university';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _addressController,
                  label: 'Delivery Address',
                  hint: 'Enter your campus/delivery address',
                  icon: Icons.home_outlined,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your delivery address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Create a password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
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

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
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
                      backgroundColor: const Color(0xFF0057D9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
                          color: Color(0xFF0057D9),
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
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
    );
  }
}
