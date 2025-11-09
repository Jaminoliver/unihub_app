import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/address_model.dart';

/// Address Service - Manages delivery addresses
class AddressService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all addresses for a user
  Future<List<DeliveryAddressModel>> getAddresses(String userId) async {
    try {
      final response = await _supabase
          .from('delivery_addresses')
          .select('*')
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => DeliveryAddressModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching addresses: $e');
      rethrow;
    }
  }

  /// Get default address for a user
  Future<DeliveryAddressModel?> getDefaultAddress(String userId) async {
    try {
      final response = await _supabase
          .from('delivery_addresses')
          .select('*')
          .eq('user_id', userId)
          .eq('is_default', true)
          .maybeSingle();

      return response != null ? DeliveryAddressModel.fromJson(response) : null;
    } catch (e) {
      print('Error fetching default address: $e');
      return null;
    }
  }

  /// Get address by ID
  Future<DeliveryAddressModel?> getAddressById(String addressId) async {
    try {
      final response = await _supabase
          .from('delivery_addresses')
          .select('*')
          .eq('id', addressId)
          .maybeSingle();

      return response != null ? DeliveryAddressModel.fromJson(response) : null;
    } catch (e) {
      print('Error fetching address: $e');
      return null;
    }
  }

  /// Add new address
  Future<DeliveryAddressModel?> addAddress({
    required String userId,
    required String addressLine,
    required String city,
    required String state,
    String? landmark,
    String? phoneNumber,
    bool isDefault = false,
  }) async {
    try {
      // If setting as default, unset all other defaults first
      if (isDefault) {
        await _unsetAllDefaults(userId);
      }

      final response = await _supabase
          .from('delivery_addresses')
          .insert({
            'user_id': userId,
            'address_line': addressLine,
            'city': city,
            'state': state,
            'landmark': landmark,
            'phone_number': phoneNumber,
            'is_default': isDefault,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return DeliveryAddressModel.fromJson(response);
    } catch (e) {
      print('Error adding address: $e');
      rethrow;
    }
  }

  /// Update existing address
  Future<DeliveryAddressModel?> updateAddress({
    required String addressId,
    required String userId,
    String? addressLine,
    String? city,
    String? state,
    String? landmark,
    String? phoneNumber,
    bool? isDefault,
  }) async {
    try {
      // If setting as default, unset all other defaults first
      if (isDefault == true) {
        await _unsetAllDefaults(userId);
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (addressLine != null) updateData['address_line'] = addressLine;
      if (city != null) updateData['city'] = city;
      if (state != null) updateData['state'] = state;
      if (landmark != null) updateData['landmark'] = landmark;
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      if (isDefault != null) updateData['is_default'] = isDefault;

      final response = await _supabase
          .from('delivery_addresses')
          .update(updateData)
          .eq('id', addressId)
          .select()
          .single();

      return DeliveryAddressModel.fromJson(response);
    } catch (e) {
      print('Error updating address: $e');
      rethrow;
    }
  }

  /// Delete address
  Future<bool> deleteAddress(String addressId) async {
    try {
      await _supabase
          .from('delivery_addresses')
          .delete()
          .eq('id', addressId);

      return true;
    } catch (e) {
      print('Error deleting address: $e');
      return false;
    }
  }

  /// Set address as default
  Future<bool> setDefaultAddress(String addressId, String userId) async {
    try {
      // Unset all defaults first
      await _unsetAllDefaults(userId);

      // Set this address as default
      await _supabase
          .from('delivery_addresses')
          .update({
            'is_default': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', addressId);

      return true;
    } catch (e) {
      print('Error setting default address: $e');
      return false;
    }
  }

  /// Check if user has any addresses
  Future<bool> hasAddresses(String userId) async {
    try {
      final response = await _supabase
          .from('delivery_addresses')
          .select('id')
          .eq('user_id', userId)
          .count(CountOption.exact);

      return response.count > 0;
    } catch (e) {
      print('Error checking addresses: $e');
      return false;
    }
  }

  /// Get addresses count
  Future<int> getAddressesCount(String userId) async {
    try {
      final response = await _supabase
          .from('delivery_addresses')
          .select('id')
          .eq('user_id', userId)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error getting addresses count: $e');
      return 0;
    }
  }

  /// Private helper: Unset all default addresses for user
  Future<void> _unsetAllDefaults(String userId) async {
    try {
      await _supabase
          .from('delivery_addresses')
          .update({'is_default': false})
          .eq('user_id', userId)
          .eq('is_default', true);
    } catch (e) {
      print('Error unsetting defaults: $e');
      // Don't throw - this is a helper function
    }
  }

  /// Validate address fields (client-side validation)
  String? validateAddressLine(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address is required';
    }
    if (value.trim().length < 10) {
      return 'Please enter a more detailed address';
    }
    return null;
  }

  String? validateCity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'City is required';
    }
    if (value.trim().length < 3) {
      return 'Please enter a valid city name';
    }
    return null;
  }

  String? validateState(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'State is required';
    }
    return null;
  }

  String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional
    }

    // Remove spaces and special characters
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check if it's a valid Nigerian phone number
    final phoneRegex = RegExp(r'^(\+234|0)[789][01]\d{8}$');
    if (!phoneRegex.hasMatch(cleaned)) {
      return 'Please enter a valid Nigerian phone number';
    }

    return null;
  }
}