import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../models/address_model.dart';
import '../services/address_service.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'add_address_screen.dart';
import 'checkout_review_screen.dart'; // NAVIGATE TO REVIEW NEXT

class CheckoutAddressScreen extends StatefulWidget {
  final List<CartModel> selectedItems;
  final Map<String, String> paymentMethods;

  const CheckoutAddressScreen({
    super.key,
    required this.selectedItems,
    required this.paymentMethods,
  });

  @override
  State<CheckoutAddressScreen> createState() => _CheckoutAddressScreenState();
}

class _CheckoutAddressScreenState extends State<CheckoutAddressScreen> {
  final AddressService _addressService = AddressService();
  final AuthService _authService = AuthService();

  List<DeliveryAddressModel> _addresses = [];
  DeliveryAddressModel? _selectedAddress;
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to continue'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
        return;
      }

      _userId = user.id;
      final addresses = await _addressService.getAddresses(user.id);

      setState(() {
        _addresses = addresses;
        
        if (addresses.isEmpty) {
          _selectedAddress = null;
        } else {
          _selectedAddress = addresses.firstWhere(
            (addr) => addr.isDefault,
            orElse: () => addresses.first,
          );
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading addresses: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _navigateToAddAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddAddressScreen()),
    );

    if (result == true) {
      _loadAddresses();
    }
  }

  void _proceedToReview() {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a delivery address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // NAVIGATE TO REVIEW SCREEN
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutReviewScreen(
          selectedItems: widget.selectedItems,
          paymentMethods: widget.paymentMethods,
          deliveryAddress: _selectedAddress!,
        ),
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
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Delivery Address', style: AppTextStyles.heading.copyWith(fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress Steps
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStep('1', 'Cart', true, true),
                _buildLine(true),
                _buildStep('2', 'Address', true, true),
                _buildLine(false),
                _buildStep('3', 'Review', false, false),
                _buildLine(false),
                _buildStep('4', 'Payment', false, false),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                : _addresses.isEmpty
                    ? _buildEmptyState()
                    : _buildAddressesList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStep(String number, String label, bool active, bool completed) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active || completed ? Color(0xFFFF6B35) : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: completed
                ? Icon(Icons.check, color: Colors.white, size: 14)
                : Text(number, style: TextStyle(color: active ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: active ? Color(0xFFFF6B35) : Colors.grey[600])),
      ],
    );
  }

  Widget _buildLine(bool active) {
    return Container(
      width: 24,
      height: 2,
      margin: EdgeInsets.only(bottom: 20),
      color: active ? Color(0xFFFF6B35) : Colors.grey[300],
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
                color: Color(0xFFFF6B35).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_off_outlined, size: 60, color: Color(0xFFFF6B35)),
            ),
            SizedBox(height: 24),
            Text('No Delivery Addresses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            SizedBox(height: 8),
            Text('Add a delivery address to continue with your order', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToAddAddress,
              icon: Icon(Icons.add_location_alt, size: 20),
              label: Text('Add Delivery Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF6B35),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressesList() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildAddNewButton(),
        SizedBox(height: 16),
        ..._addresses.map((address) => _buildAddressCard(address)),
      ],
    );
  }

  Widget _buildAddNewButton() {
    return InkWell(
      onTap: _navigateToAddAddress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFFF6B35), width: 2),
          boxShadow: [BoxShadow(color: Color(0xFFFF6B35).withOpacity(0.1), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_location_alt, color: Colors.white, size: 22),
            ),
            SizedBox(width: 14),
            Text('Add New Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFFF6B35))),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(DeliveryAddressModel address) {
    final isSelected = _selectedAddress?.id == address.id;

    return InkWell(
      onTap: () => setState(() => _selectedAddress = address),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFFFF6B35) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Color(0xFFFF6B35).withOpacity(0.15), blurRadius: 12, offset: Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.only(top: 2),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Color(0xFFFF6B35) : Colors.grey[400],
                size: 24,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address.addressLine,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                      if (address.isDefault)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Default', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text('${address.city}, ${address.state}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  if (address.landmark != null && address.landmark!.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.near_me, size: 12, color: Color(0xFFFF6B35)),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text('Near ${address.landmark}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ),
                      ],
                    ),
                  ],
                  if (address.phoneNumber != null && address.phoneNumber!.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 12, color: Color(0xFFFF6B35)),
                        SizedBox(width: 4),
                        Text(address.phoneNumber!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _selectedAddress != null ? _proceedToReview : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFFF6B35),
            disabledBackgroundColor: Colors.grey[300],
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Continue to Review',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _selectedAddress != null ? Colors.white : Colors.grey[600],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: _selectedAddress != null ? Colors.white : Colors.grey[600], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}