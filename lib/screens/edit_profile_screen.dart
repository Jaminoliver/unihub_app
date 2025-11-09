import 'dart:io';
import 'package:flutter/material.dart'; // <-- FIX for 'Color' errors
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../models/user_model.dart';

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

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  final Map<String, dynamic>? deliveryAddress;

  const EditProfileScreen({
    super.key,
    required this.user,
    this.deliveryAddress,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  
  // Delivery address controllers
  late TextEditingController _addressLineController;
  late TextEditingController _cityController;
  late TextEditingController _deliveryStateController;
  late TextEditingController _landmarkController;
  late TextEditingController _deliveryPhoneController;
  
  File? _imageFile;
  String? _imageUrl;
  bool _isLoading = false;

  // --- NEW STATE FOR DROPDOWNS ---
  bool _isStatesLoading = true;
  bool _isUniversitiesLoading = false;
  List<String> _states = [];
  List<Map<String, dynamic>> _universities = [];
  String? _selectedState;
  String? _selectedUniversityId;
  // --- END NEW STATE ---

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phoneNumber); // Fixed typo here just in case
    _imageUrl = widget.user.profileImageUrl;

    // Set initial dropdown values from user
    _selectedState = widget.user.state;
    _selectedUniversityId = widget.user.universityId;
    
    // Initialize delivery address fields
    _addressLineController = TextEditingController(
      text: widget.deliveryAddress?['address_line'],
    );
    _cityController = TextEditingController(
      text: widget.deliveryAddress?['city'],
    );
    _deliveryStateController = TextEditingController(
      text: widget.deliveryAddress?['state'],
    );
    _landmarkController = TextEditingController(
      text: widget.deliveryAddress?['landmark'],
    );
    _deliveryPhoneController = TextEditingController(
      text: widget.deliveryAddress?['phone_number'],
    );

    // Load initial data for dropdowns
    _loadStates();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    // _stateController is removed
    _addressLineController.dispose();
    _cityController.dispose();
    _deliveryStateController.dispose();
    _landmarkController.dispose();
    _deliveryPhoneController.dispose();
    super.dispose();
  }

  // --- MODIFIED DATA LOADING METHOD ---
  Future<void> _loadStates() async {
    setState(() => _isStatesLoading = true);
    try {
      final states = await _profileService.getStates();
      String? correctlyCasedState;
      
      if (widget.user.state != null) {
        try {
          correctlyCasedState = states.firstWhere(
            (stateInList) => stateInList.toLowerCase() == widget.user.state!.toLowerCase(),
          );
        } catch (e) {
          correctlyCasedState = null;
        }
      }

      // If a state is now selected, load its universities *before* leaving this function
      if (correctlyCasedState != null) {
          // Set state to show states are loaded and universities are *about* to load
          if (mounted) {
            setState(() {
              _states = states;
              _isStatesLoading = false;
              _selectedState = correctlyCasedState;
              _isUniversitiesLoading = true; // Show loading spinner
            });
          }
          
          // NOW, await the university loading
          await _loadUniversities(correctlyCasedState, retainSelection: true);
          
      } else {
          // No state selected, just set states and finish
          if(mounted) {
            setState(() {
              _states = states;
              _isStatesLoading = false;
              _selectedState = null;
              _isUniversitiesLoading = false;
            });
          }
      }

    } catch (e) {
      if (mounted) {
        setState(() {
           _isStatesLoading = false;
           _isUniversitiesLoading = false; // Stop all loading on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading states: $e')),
        );
      }
    }
  }

  // This is the one and only _loadUniversities method
  Future<void> _loadUniversities(String stateName, {bool retainSelection = false}) async {
    // We no longer set loading state here, _loadStates does it
    
    try {
      final universities = await _profileService.getUniversitiesByState(stateName);
      
      String? finalUniversityId;
      
      // If we are retaining selection, check if the ID is valid
      if (retainSelection && _selectedUniversityId != null) {
        if (universities.any((uni) => uni['id'] == _selectedUniversityId)) {
          // The ID is valid and exists in the list
          finalUniversityId = _selectedUniversityId;
        } else {
          // The user's saved ID is not in the list for this state
          finalUniversityId = null;
        }
      } else {
        finalUniversityId = null; // Not retaining, so clear it
      }

      if (mounted) {
        setState(() {
          _universities = universities;
          _isUniversitiesLoading = false; // Done loading
          _selectedUniversityId = finalUniversityId; // Set the final, validated ID
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUniversitiesLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading universities: $e')),
        );
      }
    }
  }
  
  // --- DUPLICATE _loadUniversities HAS BEEN REMOVED ---

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    // --- ADDED VALIDATION FOR DROPDOWNS ---
    if (_selectedState == null || _selectedUniversityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select your state and university'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // --- END VALIDATION ---

    setState(() => _isLoading = true);

    try {
      String? newImageUrl = _imageUrl;

      // Upload new image if selected
      if (_imageFile != null) {
        if (_imageUrl != null) {
          await _profileService.deleteProfileImage(_imageUrl!);
        }
        
        newImageUrl = await _profileService.uploadProfileImage(
          userId: widget.user.id,
          imageFile: _imageFile!,
        );
      }

      // --- MODIFIED updateProfile CALL ---
      await _profileService.updateProfile(
        userId: widget.user.id,
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        state: _selectedState, // <-- CHANGED
        universityId: _selectedUniversityId, // <-- ADDED
        profileImageUrl: newImageUrl,
      );
      // --- END MODIFICATION ---

      // Update delivery address if any field is filled
      if (_addressLineController.text.trim().isNotEmpty ||
          _cityController.text.trim().isNotEmpty ||
          _deliveryStateController.text.trim().isNotEmpty) {
        await _profileService.updateDeliveryAddress(
          userId: widget.user.id,
          addressLine: _addressLineController.text.trim(),
          city: _cityController.text.trim(),
          state: _deliveryStateController.text.trim(),
          landmark: _landmarkController.text.trim().isEmpty 
              ? null 
              : _landmarkController.text.trim(),
          phoneNumber: _deliveryPhoneController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile updated successfully'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ashGray,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: ShaderMask(
            shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
            child: Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_isLoading)
            Center(
              child: Container(
                margin: EdgeInsets.only(right: 16),
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppTheme.orangeStart),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 12),
              _buildProfileImageSection(),
              SizedBox(height: 20),
              _buildPersonalInfoSection(),
              SizedBox(height: 12),
              _buildDeliveryAddressSection(),
              SizedBox(height: 12),
              _buildReadOnlyEmailSection(),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: AppTheme.gradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.orangeStart.withOpacity(0.3),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : _imageUrl != null
                          ? Image.network(
                              _imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    _getInitials(widget.user.fullName),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                _getInitials(widget.user.fullName),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.gradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.orangeStart.withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Tap camera icon to change photo',
            style: TextStyle(
              color: AppTheme.textLight,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
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
                child: Icon(Icons.person_outline, size: 18, color: Colors.white),
              ),
              SizedBox(width: 8),
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          
          SizedBox(height: 16),
          
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                if (value.trim().length < 10) {
                  return 'Phone number must be at least 10 digits';
                }
              }
              return null;
            },
          ),
          
          SizedBox(height: 16),
          
          // --- NEW STATE DROPDOWN ---
          _buildDropdown(
            label: 'State',
            icon: Icons.map_outlined,
            value: _selectedState,
            isLoading: _isStatesLoading,
            hint: 'Select your state',
            items: _states.map((String state) {
              return DropdownMenuItem<String>(
                value: state,
                child: Text(state),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null && newValue != _selectedState) {
                setState(() {
                  _selectedState = newValue;
                  _universities = []; // Clear old universities
                  _selectedUniversityId = null; // Clear old selection
                });
                // Load universities for the new state
                _loadUniversities(newValue);
              }
            },
            validator: (value) {
              if (value == null) return 'Please select a state';
              return null;
            },
          ),
          // --- END STATE DROPDOWN ---

          SizedBox(height: 16),
          
          // --- NEW UNIVERSITY DROPDOWN ---
          _buildDropdown(
            label: 'University',
            icon: Icons.school_outlined,
            value: _selectedUniversityId,
            isLoading: _isUniversitiesLoading,
            // Disable if no state is selected or if universities are loading
            isEnabled: _selectedState != null && !_isUniversitiesLoading,
            hint: _selectedState == null 
                ? 'Select a state first' 
                : 'Select your university',
            items: _universities.map((Map<String, dynamic> university) {
              return DropdownMenuItem<String>(
                value: university['id'] as String,
                child: Text(university['name'] as String),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedUniversityId = newValue;
              });
            },
            validator: (value) {
              if (value == null) return 'Please select a university';
              return null;
            },
          ),
          // --- END UNIVERSITY DROPDOWN ---
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressSection() {
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
                child: Icon(Icons.location_on_outlined, size: 18, color: Colors.white),
              ),
              SizedBox(width: 8),
              Text(
                'Delivery Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          _buildTextField(
            controller: _addressLineController,
            label: 'Address Line',
            icon: Icons.home_outlined,
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your address';
              }
              return null;
            },
          ),
          
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _cityController,
                  label: 'City',
                  icon: Icons.location_city_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _deliveryStateController,
                  label: 'State',
                  icon: Icons.map_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          _buildTextField(
            controller: _landmarkController,
            label: 'Landmark (Optional)',
            icon: Icons.place_outlined,
            validator: (value) { // Added missing validator from your previous logic
              return null; // It's optional, so always valid
            },
          ),
          
          SizedBox(height: 16),
          
          _buildTextField(
            controller: _deliveryPhoneController,
            label: 'Delivery Phone',
            icon: Icons.phone_in_talk_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter delivery phone number';
              }
              if (value.trim().length < 10) {
                return 'Phone number must be at least 10 digits';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyEmailSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade300, Colors.grey.shade200],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.email_outlined, color: Colors.grey.shade700, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email Address',
                  style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                ),
                SizedBox(height: 2),
                Text(
                  widget.user.email,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, color: AppTheme.textLight, size: 18),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textLight, fontSize: 13),
        prefixIcon: ShaderMask(
          shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.orangeStart, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.ashGray,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // --- NEW WIDGET FOR DROPDOWNS ---
  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?)? onChanged,
    required String? Function(String?)? validator,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: isEnabled ? onChanged : null,
      validator: validator,
      isExpanded: true,
      style: TextStyle(fontSize: 14, color: AppTheme.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isEnabled ? AppTheme.textLight : Colors.grey,
          fontSize: 13,
        ),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: ShaderMask(
          shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        suffixIcon: isLoading
            ? Container(
                padding: EdgeInsets.all(16),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.orangeStart,
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.orangeStart, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: isEnabled ? AppTheme.ashGray : Colors.grey.shade200,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}