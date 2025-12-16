import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/address_model.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current user profile
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('profiles')
          .select('''
            *,
            university_id, 
            universities!profiles_university_id_fkey(id, name, short_name)
          ''')
          .eq('id', userId)
          .single();

      final university = response['universities'] as Map<String, dynamic>?;
      
      return UserModel.fromJson({
        ...response,
        'university_name': university?['name'],
        'university_id': response['university_id'],
      });
    } catch (e) {
      print('Error fetching user profile: $e');
      rethrow;
    }
  }

  /// Get user's default delivery address
  Future<Map<String, dynamic>?> getDefaultDeliveryAddress(String userId) async {
    try {
      final response = await _supabase
          .from('delivery_addresses')
          .select('*')
          .eq('user_id', userId)
          .eq('is_default', true)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching delivery address: $e');
      return null;
    }
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    required String userId,
    String? fullName,
    String? phoneNumber,
    String? state,
    String? profileImageUrl,
    String? universityId,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (state != null) updates['state'] = state;
      if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;
      if (universityId != null) updates['university_id'] = universityId;

      final response = await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select('''
            *,
            university_id,
            universities!profiles_university_id_fkey(id, name, short_name)
          ''')
          .single();

      final university = response['universities'] as Map<String, dynamic>?;
      
      return UserModel.fromJson({
        ...response,
        'university_name': university?['name'],
        'university_id': response['university_id'],
      });
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  /// Upload profile image
  Future<String> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = fileName;

      await _supabase.storage
          .from('profile-images')
          .upload(filePath, imageFile);

      final publicUrl = _supabase.storage
          .from('profile-images')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      rethrow;
    }
  }

  /// Delete old profile image
  Future<void> deleteProfileImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('profile-images');
      
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final path = pathSegments.sublist(bucketIndex + 1).join('/');
        await _supabase.storage
            .from('profile-images')
            .remove([path]);
      }
    } catch (e) {
      print('Error deleting profile image: $e');
      // Don't throw - non-critical
    }
  }

  /// Update or create delivery address (legacy method - kept for backward compatibility)
  Future<void> updateDeliveryAddress({
    required String userId,
    required String addressLine,
    required String city,
    required String state,
    String? landmark,
    required String phoneNumber,
  }) async {
    try {
      // Check if user has existing default address
      final existing = await _supabase
          .from('delivery_addresses')
          .select('id')
          .eq('user_id', userId)
          .eq('is_default', true)
          .maybeSingle();

      final addressData = {
        'user_id': userId,
        'address_line': addressLine,
        'city': city,
        'state': state,
        'landmark': landmark,
        'phone_number': phoneNumber,
        'is_default': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing != null) {
        // Update existing
        await _supabase
            .from('delivery_addresses')
            .update(addressData)
            .eq('id', existing['id']);
      } else {
        // Create new
        addressData['created_at'] = DateTime.now().toIso8601String();
        await _supabase
            .from('delivery_addresses')
            .insert(addressData);
      }
    } catch (e) {
      print('Error updating delivery address: $e');
      rethrow;
    }
  }

  /// Fetch all states
  Future<List<String>> getStates() async {
    try {
      final response = await _supabase
          .from('states')
          .select('name')
          .order('name', ascending: true);
      
      return (response as List).map((item) => item['name'] as String).toList();
    } catch (e) {
      print('Error fetching states: $e');
      rethrow;
    }
  }

  /// Fetch universities for a specific state
  Future<List<Map<String, dynamic>>> getUniversitiesByState(String stateName) async {
    try {
      final response = await _supabase
          .from('universities')
          .select('id, name')
          .eq('state', stateName)
          .order('name', ascending: true);
      
      return (response as List).map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching universities by state: $e');
      rethrow;
    }
  }

  // ===================================================================
  // ADDRESS MANAGEMENT METHODS (NEW)
  // ===================================================================

  /// Get all delivery addresses for a user
  Future<List<DeliveryAddressModel>> getUserAddresses(String userId) async {
    try {
      final response = await _supabase
          .from('delivery_addresses')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => DeliveryAddressModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching addresses: $e');
      return [];
    }
  }

  /// Get a specific delivery address by ID
  Future<DeliveryAddressModel?> getAddressById(String addressId) async {
    try {
      final response = await _supabase
          .from('delivery_addresses')
          .select()
          .eq('id', addressId)
          .maybeSingle();

      if (response == null) return null;
      return DeliveryAddressModel.fromJson(response);
    } catch (e) {
      print('Error fetching address: $e');
      return null;
    }
  }

  /// Add a new delivery address
  Future<DeliveryAddressModel> addDeliveryAddress({
    required String userId,
    required String addressLine,
    required String city,
    required String state,
    String? landmark,
    String? phoneNumber,
    bool isDefault = false,
  }) async {
    try {
      // If this is set as default, first set all others to non-default
      if (isDefault) {
        await _supabase
            .from('delivery_addresses')
            .update({'is_default': false})
            .eq('user_id', userId);
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

  /// Update an existing delivery address
  Future<DeliveryAddressModel> updateAddress({
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
      // If this is being set as default, first set all others to non-default
      if (isDefault == true) {
        await _supabase
            .from('delivery_addresses')
            .update({'is_default': false})
            .eq('user_id', userId);
      }

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (addressLine != null) updates['address_line'] = addressLine;
      if (city != null) updates['city'] = city;
      if (state != null) updates['state'] = state;
      if (landmark != null) updates['landmark'] = landmark;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (isDefault != null) updates['is_default'] = isDefault;

      final response = await _supabase
          .from('delivery_addresses')
          .update(updates)
          .eq('id', addressId)
          .select()
          .single();

      return DeliveryAddressModel.fromJson(response);
    } catch (e) {
      print('Error updating address: $e');
      rethrow;
    }
  }

  /// Set an address as default
  Future<void> setDefaultAddress(String userId, String addressId) async {
    try {
      // First, set all addresses to non-default
      await _supabase
          .from('delivery_addresses')
          .update({'is_default': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId);

      // Then set the selected address as default
      await _supabase
          .from('delivery_addresses')
          .update({'is_default': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', addressId);
    } catch (e) {
      print('Error setting default address: $e');
      rethrow;
    }
  }

  /// Delete an address
  Future<void> deleteAddress(String addressId) async {
    try {
      await _supabase
          .from('delivery_addresses')
          .delete()
          .eq('id', addressId);
    } catch (e) {
      print('Error deleting address: $e');
      rethrow;
    }
  }

  /// Check if user has any addresses
  Future<bool> hasAddresses(String userId) async {
    try {
      final response = await _supabase
          .from('delivery_addresses')
          .select('id')
          .eq('user_id', userId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      print('Error checking addresses: $e');
      return false;
    }
  }

  /// Get address count for user
  Future<int> getAddressCount(String userId) async {
    try {
      final response = await _supabase
          .from('delivery_addresses')
          .select('id')
          .eq('user_id', userId);

      return (response as List).length;
    } catch (e) {
      print('Error getting address count: $e');
      return 0;
    }
  }
}