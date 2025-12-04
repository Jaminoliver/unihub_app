import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../models/user_model.dart';

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
  late TextEditingController _addressLineController;
  late TextEditingController _cityController;
  late TextEditingController _deliveryStateController;
  late TextEditingController _landmarkController;
  late TextEditingController _deliveryPhoneController;

  File? _imageFile;
  String? _imageUrl;
  bool _isLoading = false;
  bool _isStatesLoading = true;
  bool _isUniversitiesLoading = false;
  List<String> _states = [];
  List<Map<String, dynamic>> _universities = [];
  String? _selectedState;
  String? _selectedUniversityId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
    _imageUrl = widget.user.profileImageUrl;
    _selectedState = widget.user.state;
    _selectedUniversityId = widget.user.universityId;

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

    _loadStates();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressLineController.dispose();
    _cityController.dispose();
    _deliveryStateController.dispose();
    _landmarkController.dispose();
    _deliveryPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    setState(() => _isStatesLoading = true);
    try {
      final states = await _profileService.getStates();
      String? correctlyCasedState;

      if (widget.user.state != null) {
        try {
          correctlyCasedState = states.firstWhere(
            (stateInList) =>
                stateInList.toLowerCase() == widget.user.state!.toLowerCase(),
          );
        } catch (e) {
          correctlyCasedState = null;
        }
      }

      if (correctlyCasedState != null) {
        if (mounted) {
          setState(() {
            _states = states;
            _isStatesLoading = false;
            _selectedState = correctlyCasedState;
            _isUniversitiesLoading = true;
          });
        }
        await _loadUniversities(correctlyCasedState, retainSelection: true);
      } else {
        if (mounted) {
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
          _isUniversitiesLoading = false;
        });
        _showSnackBar('Error loading states: $e', isError: true);
      }
    }
  }

  Future<void> _loadUniversities(String stateName,
      {bool retainSelection = false}) async {
    try {
      final universities =
          await _profileService.getUniversitiesByState(stateName);

      String? finalUniversityId;

      if (retainSelection && _selectedUniversityId != null) {
        if (universities.any((uni) => uni['id'] == _selectedUniversityId)) {
          finalUniversityId = _selectedUniversityId;
        } else {
          finalUniversityId = null;
        }
      } else {
        finalUniversityId = null;
      }

      if (mounted) {
        setState(() {
          _universities = universities;
          _isUniversitiesLoading = false;
          _selectedUniversityId = finalUniversityId;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUniversitiesLoading = false);
        _showSnackBar('Error loading universities: $e', isError: true);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedState == null || _selectedUniversityId == null) {
      _showSnackBar('Please select your state and university', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? newImageUrl = _imageUrl;

      if (_imageFile != null) {
        if (_imageUrl != null) {
          await _profileService.deleteProfileImage(_imageUrl!);
        }
        newImageUrl = await _profileService.uploadProfileImage(
          userId: widget.user.id,
          imageFile: _imageFile!,
        );
      }

      await _profileService.updateProfile(
        userId: widget.user.id,
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        state: _selectedState,
        universityId: _selectedUniversityId,
        profileImageUrl: newImageUrl,
      );

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
        _showSnackBar('Profile updated successfully', isError: false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: kWhite,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAshGray,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0,
        leading: IconButton(
          icon: ShaderMask(
            shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
            child: const Icon(Icons.arrow_back_ios_new, color: kWhite),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: const Text(
            'Edit Profile',
            style: TextStyle(
              color: kWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
        actions: [
          if (_isLoading)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                width: 24,
                height: 24,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Color(0xFFFF6B35)),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    kOrangeGradient.createShader(bounds),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: kWhite,
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
              const SizedBox(height: 12),
              _buildProfileImageSection(),
              const SizedBox(height: 16),
              _buildPersonalInfoSection(),
              const SizedBox(height: 12),
              _buildDeliveryAddressSection(),
              const SizedBox(height: 12),
              _buildReadOnlyEmailSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(20),
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
        children: [
          Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: kOrangeGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
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
                                    style: const TextStyle(
                                      color: kWhite,
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
                                style: const TextStyle(
                                  color: kWhite,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: kOrangeGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: kWhite,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap camera icon to change photo',
            style: TextStyle(color: kTextLight, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
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
                  Icons.person_outline,
                  size: 16,
                  color: kWhite,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kTextDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          _buildDropdown(
            label: 'State',
            icon: Icons.map_outlined,
            value: _selectedState,
            isLoading: _isStatesLoading,
            hint: 'Select your state',
            items: _states.map((String state) {
              return DropdownMenuItem<String>(
                value: state,
                child: Text(state, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null && newValue != _selectedState) {
                setState(() {
                  _selectedState = newValue;
                  _universities = [];
                  _selectedUniversityId = null;
                  _isUniversitiesLoading = true;
                });
                _loadUniversities(newValue);
              }
            },
            validator: (value) {
              if (value == null) return 'Please select a state';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildDropdown(
            label: 'University',
            icon: Icons.school_outlined,
            value: _selectedUniversityId,
            isLoading: _isUniversitiesLoading,
            isEnabled: _selectedState != null && !_isUniversitiesLoading,
            hint: _selectedState == null
                ? 'Select a state first'
                : 'Select your university',
            items: _universities.map((Map<String, dynamic> university) {
              return DropdownMenuItem<String>(
                value: university['id'] as String,
                child: Text(
                  university['name'] as String,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() => _selectedUniversityId = newValue);
            },
            validator: (value) {
              if (value == null) return 'Please select a university';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressSection() {
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
                  Icons.location_on_outlined,
                  size: 16,
                  color: kWhite,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Delivery Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kTextDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 14),
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
              const SizedBox(width: 12),
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
          const SizedBox(height: 14),
          _buildTextField(
            controller: _landmarkController,
            label: 'Landmark (Optional)',
            icon: Icons.place_outlined,
            validator: (value) => null,
          ),
          const SizedBox(height: 14),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.email_outlined,
              color: Colors.grey.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email Address',
                  style: TextStyle(fontSize: 11, color: kTextLight),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.user.email,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kTextDark,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, color: kTextLight, size: 18),
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
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kTextLight, fontSize: 13),
        prefixIcon: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: Icon(icon, color: kWhite, size: 20),
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
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: kAshGray,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

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
      style: const TextStyle(fontSize: 14, color: kTextDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isEnabled ? kTextLight : Colors.grey,
          fontSize: 13,
        ),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: Icon(icon, color: kWhite, size: 20),
        ),
        suffixIcon: isLoading
            ? Container(
                padding: const EdgeInsets.all(16),
                width: 20,
                height: 20,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF6B35),
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
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: isEnabled ? kAshGray : Colors.grey.shade200,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}