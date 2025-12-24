import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../models/address_model.dart';
import '../services/address_service.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'add_address_screen.dart';
import 'checkout_review_screen.dart';

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
          SnackBar(content: Text('Please log in to continue'), backgroundColor: AppColors.errorRed),
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
        SnackBar(content: Text('Error loading addresses: $e'), backgroundColor: AppColors.errorRed),
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
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

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
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getCardBackground(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(context)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.getCardBackground(context),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                _buildStep('Cart', true),
                _buildLine(true),
                _buildStep('Address', true),
                _buildLine(false),
                _buildStep('Review', false),
                _buildLine(false),
                _buildStep('Payment', false),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
                : _addresses.isEmpty
                    ? _buildEmptyState()
                    : _buildAddressesList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStep(String label, bool active) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: active ? AppColors.primaryOrange : AppColors.getBorder(context).withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? AppColors.primaryOrange : AppColors.getTextMuted(context),
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLine(bool active) {
    return Container(
      width: 8,
      height: 3,
      margin: EdgeInsets.only(bottom: 18),
      color: active ? AppColors.primaryOrange : AppColors.getBorder(context).withOpacity(0.3),
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
              child: Icon(Icons.location_off_outlined, size: 60, color: AppColors.primaryOrange),
            ),
            SizedBox(height: 24),
            Text('No Delivery Addresses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            SizedBox(height: 8),
            Text('Add a delivery address to continue with your order', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.getTextMuted(context))),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToAddAddress,
              icon: Icon(Icons.add_location_alt, size: 20),
              label: Text('Add Delivery Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
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
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryOrange, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_location_alt, color: Colors.white, size: 22),
            ),
            SizedBox(width: 14),
            Text('Add New Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryOrange)),
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
          color: AppColors.getCardBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : AppColors.getBorder(context).withOpacity(0.3),
            width: isSelected ? 2 : 0.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primaryOrange.withOpacity(0.15), blurRadius: 12, offset: Offset(0, 4))]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.only(top: 2),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primaryOrange : AppColors.getTextMuted(context),
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
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                        ),
                      ),
                      if (address.isDefault)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Default', style: TextStyle(fontSize: 10, color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text('${address.city}, ${address.state}', style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context))),
                  if (address.landmark != null && address.landmark!.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.near_me, size: 12, color: AppColors.primaryOrange),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text('Near ${address.landmark}', style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context))),
                        ),
                      ],
                    ),
                  ],
                  if (address.phoneNumber != null && address.phoneNumber!.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 12, color: AppColors.primaryOrange),
                        SizedBox(width: 4),
                        Text(address.phoneNumber!, style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context))),
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
        color: AppColors.getCardBackground(context),
        border: Border(top: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3))),
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _selectedAddress != null ? _proceedToReview : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            disabledBackgroundColor: AppColors.getBorder(context),
            foregroundColor: Colors.white,
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
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}