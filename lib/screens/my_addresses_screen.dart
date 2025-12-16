import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../models/address_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/unihub_loading_widget.dart';

class MyAddressesScreen extends StatefulWidget {
  const MyAddressesScreen({super.key});

  @override
  State<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends State<MyAddressesScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  List<DeliveryAddressModel> _addresses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        final addresses = await _profileService.getUserAddresses(userId);
        if (mounted) {
          setState(() {
            _addresses = addresses;
            _isLoading = false;
          });
        }
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

  Future<void> _setDefaultAddress(String addressId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;

      await _profileService.setDefaultAddress(userId, addressId);
      _loadAddresses();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Default address updated'),
              ],
            ),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteAddress(DeliveryAddressModel address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline, color: AppColors.errorRed, size: 20),
            ),
            SizedBox(width: 12),
            Text('Delete Address', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this address?',
          style: TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: AppColors.errorRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _profileService.deleteAddress(address.id);
      _loadAddresses();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Address deleted'),
              ],
            ),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _showAddEditDialog({DeliveryAddressModel? address}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditAddressSheet(
        address: address,
        onSaved: () {
          Navigator.pop(context);
          _loadAddresses();
        },
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
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text('My Addresses', style: AppTextStyles.heading.copyWith(fontSize: 18)),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(child: UniHubLoader(size: 80))
          : _errorMessage != null
              ? _buildErrorState()
              : _addresses.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadAddresses,
                      color: AppColors.primaryOrange,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _addresses.length,
                        itemBuilder: (context, index) => Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _buildAddressCard(_addresses[index]),
                        ),
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primaryOrange,
        icon: Icon(Icons.add_location_outlined, color: Colors.white),
        label: Text(
          'Add Address',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAddressCard(DeliveryAddressModel address) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: address.isDefault
            ? Border.all(color: AppColors.primaryOrange, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: address.isDefault
                            ? AppColors.primaryOrange.withOpacity(0.1)
                            : AppColors.lightGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        address.isDefault
                            ? Icons.location_on
                            : Icons.location_on_outlined,
                        color: address.isDefault
                            ? AppColors.primaryOrange
                            : AppColors.textLight,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  address.addressLine,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (address.isDefault) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryOrange,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'DEFAULT',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${address.city}, ${address.state}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (address.landmark != null) ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          size: 16, color: AppColors.textLight),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Landmark: ${address.landmark}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (address.phoneNumber != null) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined,
                          size: 16, color: AppColors.textLight),
                      SizedBox(width: 6),
                      Text(
                        address.phoneNumber!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!address.isDefault)
                  TextButton.icon(
                    onPressed: () => _setDefaultAddress(address.id),
                    icon: Icon(Icons.check_circle_outline, size: 18),
                    label: Text('Set Default'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryOrange,
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => _showAddEditDialog(address: address),
                  icon: Icon(Icons.edit_outlined, size: 18),
                  label: Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.infoBlue,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _deleteAddress(address),
                  icon: Icon(Icons.delete_outline, size: 18),
                  label: Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.errorRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_off_outlined,
                size: 64,
                color: AppColors.primaryOrange,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Saved Addresses',
              style: AppTextStyles.heading.copyWith(fontSize: 20),
            ),
            SizedBox(height: 8),
            Text(
              'Add delivery addresses for faster checkout',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: Icon(Icons.add_location_outlined),
              label: Text('Add Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.errorRed,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Error Loading Addresses',
              style: AppTextStyles.heading.copyWith(fontSize: 20),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAddresses,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add/Edit Address Bottom Sheet
class AddEditAddressSheet extends StatefulWidget {
  final DeliveryAddressModel? address;
  final VoidCallback onSaved;

  const AddEditAddressSheet({
    this.address,
    required this.onSaved,
  });

  @override
  State<AddEditAddressSheet> createState() => _AddEditAddressSheetState();
}

class _AddEditAddressSheetState extends State<AddEditAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  late TextEditingController _addressLineController;
  late TextEditingController _cityController;
  late TextEditingController _landmarkController;
  late TextEditingController _phoneController;
  
  String? _selectedState;
  List<String> _states = [];
  bool _isDefault = false;
  bool _isLoading = false;
  bool _isLoadingStates = true;

  @override
  void initState() {
    super.initState();
    _addressLineController = TextEditingController(
      text: widget.address?.addressLine,
    );
    _cityController = TextEditingController(text: widget.address?.city);
    _landmarkController = TextEditingController(text: widget.address?.landmark);
    _phoneController = TextEditingController(
      text: widget.address?.phoneNumber,
    );
    _selectedState = widget.address?.state;
    _isDefault = widget.address?.isDefault ?? false;
    _loadStates();
  }

  @override
  void dispose() {
    _addressLineController.dispose();
    _cityController.dispose();
    _landmarkController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    try {
      final states = await _profileService.getStates();
      if (mounted) {
        setState(() {
          _states = states;
          _isLoadingStates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStates = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load states: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not logged in');

      if (widget.address != null) {
        // Update existing address
        await _profileService.updateAddress(
          addressId: widget.address!.id,
          userId: userId,
          addressLine: _addressLineController.text.trim(),
          city: _cityController.text.trim(),
          state: _selectedState!,
          landmark: _landmarkController.text.trim().isEmpty
              ? null
              : _landmarkController.text.trim(),
          phoneNumber: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          isDefault: _isDefault,
        );
      } else {
        // Add new address
        await _profileService.addDeliveryAddress(
          userId: userId,
          addressLine: _addressLineController.text.trim(),
          city: _cityController.text.trim(),
          state: _selectedState!,
          landmark: _landmarkController.text.trim().isEmpty
              ? null
              : _landmarkController.text.trim(),
          phoneNumber: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          isDefault: _isDefault,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text(widget.address != null
                    ? 'Address updated'
                    : 'Address added'),
              ],
            ),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.address != null ? 'Edit Address' : 'Add Address',
                      style: AppTextStyles.heading.copyWith(fontSize: 20),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                      color: AppColors.textLight,
                    ),
                  ],
                ),
                SizedBox(height: 24),
                TextFormField(
                  controller: _addressLineController,
                  decoration: InputDecoration(
                    labelText: 'Street Address *',
                    hintText: 'e.g., 123 Main Street',
                    prefixIcon: Icon(Icons.home_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) =>
                      val?.trim().isEmpty ?? true ? 'Required' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'City *',
                    hintText: 'e.g., Lagos',
                    prefixIcon: Icon(Icons.location_city_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) =>
                      val?.trim().isEmpty ?? true ? 'Required' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 16),
                _isLoadingStates
                    ? Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: _selectedState,
                        decoration: InputDecoration(
                          labelText: 'State *',
                          prefixIcon: Icon(Icons.map_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _states
                            .map((state) => DropdownMenuItem(
                                  value: state,
                                  child: Text(state),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedState = val),
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _landmarkController,
                  decoration: InputDecoration(
                    labelText: 'Landmark (Optional)',
                    hintText: 'e.g., Near City Mall',
                    prefixIcon: Icon(Icons.place_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    hintText: 'e.g., 080XXXXXXXX',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16),
                CheckboxListTile(
                  value: _isDefault,
                  onChanged: (val) => setState(() => _isDefault = val ?? false),
                  title: Text(
                    'Set as default address',
                    style: TextStyle(fontSize: 14),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.primaryOrange,
                  contentPadding: EdgeInsets.zero,
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.textLight.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            widget.address != null
                                ? 'Update Address'
                                : 'Add Address',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}