import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../models/user_model.dart';

const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

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
  final _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _deliveryStateController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _deliveryPhoneController = TextEditingController();

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
    _nameController.text = widget.user.fullName;
    _phoneController.text = widget.user.phoneNumber ?? '';
    _imageUrl = widget.user.profileImageUrl;
    _selectedState = widget.user.state;
    _selectedUniversityId = widget.user.universityId;

    _addressController.text = widget.deliveryAddress?['address_line'] ?? '';
    _cityController.text = widget.deliveryAddress?['city'] ?? '';
    _deliveryStateController.text = widget.deliveryAddress?['state'] ?? widget.user.state ?? '';
    _landmarkController.text = widget.deliveryAddress?['landmark'] ?? '';
    _deliveryPhoneController.text = widget.deliveryAddress?['phone_number'] ?? '';

    _loadStates();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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
      String? matchedState;

      if (widget.user.state != null) {
        try {
          matchedState = states.firstWhere(
            (s) => s.toLowerCase() == widget.user.state!.toLowerCase(),
          );
        } catch (_) {}
      }

      setState(() {
        _states = states;
        _isStatesLoading = false;
        _selectedState = matchedState;
      });

      if (matchedState != null) {
        setState(() => _isUniversitiesLoading = true);
        await _loadUniversities(matchedState, retainSelection: true);
      }
    } catch (e) {
      setState(() {
        _isStatesLoading = false;
        _isUniversitiesLoading = false;
      });
      _showSnackBar('Error loading states: $e', isError: true);
    }
  }

  Future<void> _loadUniversities(String stateName, {bool retainSelection = false}) async {
    try {
      final universities = await _profileService.getUniversitiesByState(stateName);
      String? finalUniversityId;

      if (retainSelection && _selectedUniversityId != null) {
        if (universities.any((uni) => uni['id'] == _selectedUniversityId)) {
          finalUniversityId = _selectedUniversityId;
        }
      }

      setState(() {
        _universities = universities;
        _isUniversitiesLoading = false;
        _selectedUniversityId = finalUniversityId;
      });
    } catch (e) {
      setState(() => _isUniversitiesLoading = false);
      _showSnackBar('Error loading universities: $e', isError: true);
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
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        state: _selectedState,
        universityId: _selectedUniversityId,
        profileImageUrl: newImageUrl,
      );

      if (_addressController.text.trim().isNotEmpty || _cityController.text.trim().isNotEmpty) {
        await _profileService.updateDeliveryAddress(
          userId: widget.user.id,
          addressLine: _addressController.text.trim(),
          city: _cityController.text.trim(),
          state: _deliveryStateController.text.trim(),
          landmark: _landmarkController.text.trim().isEmpty ? null : _landmarkController.text.trim(),
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
            Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
      border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6B35), width: 2)),
      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
      focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      errorStyle: const TextStyle(fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: const Text(
            'Edit Profile',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3),
          ),
        ),
        centerTitle: true,
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
              child: const Text('Done', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 16, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            const SizedBox(height: 20),
            
            // Profile Picture
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(gradient: kOrangeGradient, borderRadius: BorderRadius.circular(8)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _imageFile != null
                          ? Image.file(_imageFile!, fit: BoxFit.cover)
                          : _imageUrl != null
                              ? Image.network(
                                  _imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(_getInitials(widget.user.fullName),
                                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                                  ),
                                )
                              : Center(
                                  child: Text(_getInitials(widget.user.fullName),
                                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                                ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickImage,
                    child: const Text('Change photo', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // PROFILE INFORMATION Section
            _buildSectionHeader('PROFILE INFORMATION'),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _nameController,
              label: 'Name',
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null,
            ),

            _buildTextField(
              controller: _phoneController,
              label: 'Phone',
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty && v.trim().length < 10) {
                  return 'Phone number must be at least 10 digits';
                }
                return null;
              },
            ),

            _buildDropdown(
              label: 'State',
              value: _selectedState,
              isLoading: _isStatesLoading,
              hint: 'Select state',
              items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (newValue) {
                if (newValue != null && newValue != _selectedState) {
                  setState(() {
                    _selectedState = newValue;
                    _universities = [];
                    _selectedUniversityId = null;
                    _isUniversitiesLoading = true;
                    _deliveryStateController.text = newValue; // Auto-sync delivery state
                  });
                  _loadUniversities(newValue);
                }
              },
              validator: (v) => v == null ? 'Required' : null,
            ),

            _buildDropdown(
              label: 'University',
              value: _selectedUniversityId,
              isLoading: _isUniversitiesLoading,
              isEnabled: _selectedState != null && !_isUniversitiesLoading,
              hint: _selectedState == null ? 'Select state first' : 'Select university',
              items: _universities.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(u['name'] as String))).toList(),
              onChanged: (v) => setState(() => _selectedUniversityId = v),
              validator: (v) => v == null ? 'Required' : null,
            ),

            const SizedBox(height: 30),

            // DELIVERY ADDRESS Section
            _buildSectionHeader('DELIVERY ADDRESS'),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _deliveryStateController,
              label: 'State',
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),

            _buildTextField(
              controller: _cityController,
              label: 'City',
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),

            _buildTextField(
              controller: _addressController,
              label: 'Address Line',
              maxLines: 2,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),

            _buildTextField(
              controller: _landmarkController,
              label: 'Landmark (Optional)',
            ),

            _buildTextField(
              controller: _deliveryPhoneController,
              label: 'Phone Number',
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().length < 10) return 'Must be at least 10 digits';
                return null;
              },
            ),

            const SizedBox(height: 30),

            // ACCOUNT Section
            _buildSectionHeader('ACCOUNT'),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text(widget.user.email, style: const TextStyle(fontSize: 15, color: Colors.black87)),
                      ],
                    ),
                  ),
                  Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 20),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(fontSize: 15),
        decoration: _inputDecoration(label),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?)? onChanged,
    required String? Function(String?)? validator,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items,
        onChanged: isEnabled ? onChanged : null,
        validator: validator,
        isExpanded: true,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: _inputDecoration(label).copyWith(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          suffixIcon: isLoading
              ? Container(
                  padding: const EdgeInsets.all(12),
                  width: 20,
                  height: 20,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B35)),
                )
              : null,
        ),
      ),
    );
  }
}