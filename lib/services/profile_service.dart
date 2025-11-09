import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

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
        'university_id': response['university_id'], // Pass the ID to the model
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
          .single();

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
    String? universityId, // <-- ADDED
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (state != null) updates['state'] = state;
      if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;
      if (universityId != null) updates['university_id'] = universityId; // <-- ADDED

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

  /// Update or create delivery address
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

  // --- NEW METHODS ---

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
}