import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  String? get currentUserId => currentUser?.id;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// ✅ PROPER: Sign up NEW user only (rejects existing emails)
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String universityId,
    required String state,
    required String deliveryAddress,
  }) async {
    try {
      // 0. Ensure no one is logged in before signup
      if (isLoggedIn) {
        debugPrint('⚠️ User already logged in, signing out first...');
        await signOut();
        // Wait a bit for logout to complete
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 1. ✅ NEW: Check if email already exists
      final emailAlreadyExists = await emailExists(email);
      if (emailAlreadyExists) {
        throw AuthException(
          'This email is already registered. Please login instead.',
        );
      }

      // 2. Validate university exists
      final universityExists = await _supabase
          .from('universities')
          .select()
          .eq('id', universityId)
          .maybeSingle();

      if (universityExists == null) {
        throw AuthException('Invalid university selected');
      }

      // 3. Create auth user
      debugPrint('📝 Creating auth user for: $email');
      final AuthResponse authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw AuthException('Failed to create user account');
      }

      debugPrint('✅ Auth user created: ${authResponse.user!.id}');

      // 4. ✅ FIXED: Use UPSERT to handle auto-created profiles
      // Supabase may auto-create profile via trigger, so we UPDATE it with correct data
      try {
        debugPrint(
          '📝 Creating/updating profile for user: ${authResponse.user!.id}',
        );

        // Wait for potential trigger to complete
        await Future.delayed(const Duration(milliseconds: 800));

        await _supabase.from('profiles').upsert({
          'id': authResponse.user!.id,
          'full_name':
              fullName, // ← Will UPDATE auto-created profile with correct name
          'email': email.toLowerCase(),
          'phone_number': phoneNumber,
          'university_id': universityId,
          'state': state,
          'delivery_address': deliveryAddress,
          'is_verified': false,
          'is_seller': false,
          'total_sales': 0,
          'created_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id'); // ← KEY: Prevents duplicate key errors

        debugPrint('✅ User profile created/updated successfully');
      } catch (e) {
        debugPrint('❌ Profile creation/update failed: $e');

        // Rollback: Sign out (can't delete user with anon key)
        try {
          debugPrint('🔄 Attempting to rollback auth user...');
          await _supabase.auth.signOut();
        } catch (rollbackError) {
          debugPrint('⚠️ Rollback failed: $rollbackError');
        }

        throw AuthException('Failed to create user profile. Please try again.');
      }

      return authResponse;
    } on AuthException catch (e) {
      debugPrint('❌ Auth error: ${e.message}');
      rethrow;
    } on AuthApiException catch (e) {
      debugPrint('❌ Supabase Auth error: ${e.message}');

      // Handle specific Supabase auth errors
      if (e.message.contains('already registered') ||
          e.message.contains('already exists')) {
        throw AuthException(
          'This email is already registered. Please login instead.',
        );
      }

      throw AuthException(e.message);
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error: ${e.message}');

      // Handle duplicate key error
      if (e.code == '23505') {
        throw AuthException('An account with this information already exists.');
      }

      throw AuthException('Database error. Please try again.');
    } catch (e) {
      debugPrint('❌ Unexpected signup error: $e');
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  /// Login existing user
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null || response.user == null) {
        throw AuthException('Invalid email or password');
      }

      debugPrint('✅ User logged in: ${response.user!.email}');
      return response;
    } on AuthException catch (e) {
      debugPrint('❌ Auth error: ${e.message}');
      rethrow;
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error: ${e.message}');
      throw AuthException('Database error: ${e.message}');
    } catch (e) {
      debugPrint('❌ Login error: $e');
      throw AuthException('Invalid email or password');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      debugPrint('✅ Password reset email sent to $email');
    } catch (e) {
      debugPrint('❌ Password reset error: $e');
      throw AuthException('Failed to send password reset email');
    }
  }

  /// Get current user profile from database
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      if (currentUserId == null) {
        debugPrint('❌ No user logged in');
        return null;
      }

      debugPrint('🔍 Fetching profile for user: $currentUserId');

      // Step 1: Get user profile
      final profileResponse = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', currentUserId!)
          .single();

      debugPrint('✅ Profile fetched: ${profileResponse['full_name']}');

      // Step 2: Get university info separately
      final universityId = profileResponse['university_id'] as String?;
      String? universityName;

      if (universityId != null) {
        try {
          final universityResponse = await _supabase
              .from('universities')
              .select('name, short_name')
              .eq('id', universityId)
              .single();

          universityName =
              universityResponse['short_name'] as String? ??
              universityResponse['name'] as String?;

          debugPrint('✅ University fetched: $universityName');
        } catch (e) {
          debugPrint('⚠️ Could not fetch university: $e');
        }
      }

      return UserModel.fromJson({
        ...profileResponse,
        'university_name': universityName,
      });
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error fetching profile: ${e.message}');
      throw AuthException('Failed to fetch user profile: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      throw AuthException(
        'An unexpected error occurred while fetching profile',
      );
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      throw AuthException('Failed to sign out: $e');
    }
  }

  /// ✅ UPDATE PROFILE - Should ONLY be called from Edit Profile screen
  Future<void> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? profileImageUrl,
    String? deliveryAddress,
    String? campusLocation,
  }) async {
    try {
      if (currentUserId == null) {
        throw AuthException('No user logged in');
      }

      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (profileImageUrl != null)
        updates['profile_image_url'] = profileImageUrl;
      if (deliveryAddress != null)
        updates['delivery_address'] = deliveryAddress;
      if (campusLocation != null) updates['campus_location'] = campusLocation;

      await _supabase.from('profiles').update(updates).eq('id', currentUserId!);

      debugPrint('✅ Profile updated successfully');
    } on PostgrestException catch (e) {
      debugPrint('❌ Error updating profile: ${e.message}');
      throw AuthException('Failed to update profile: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      throw AuthException('An unexpected error occurred');
    }
  }

  /// Change password
  Future<void> updatePassword(String newPassword) async {
    try {
      if (!isLoggedIn) {
        throw AuthException('No user logged in');
      }

      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      debugPrint('✅ Password updated successfully');
    } catch (e) {
      debugPrint('❌ Password update error: $e');
      throw AuthException('Failed to update password: $e');
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    try {
      if (currentUserId == null) {
        throw AuthException('No user logged in');
      }

      await _supabase.from('profiles').delete().eq('id', currentUserId!);
      await _supabase.auth.signOut();

      debugPrint('✅ Account deleted successfully');
    } catch (e) {
      debugPrint('❌ Account deletion error: $e');
      throw AuthException('Failed to delete account: $e');
    }
  }

  /// Check if email already exists
  Future<bool> emailExists(String email) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', email.toLowerCase())
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Email check error: $e');
      return false;
    }
  }

  /// Refresh current session
  Future<void> refreshSession() async {
    try {
      await _supabase.auth.refreshSession();
      debugPrint('✅ Session refreshed');
    } catch (e) {
      debugPrint('❌ Session refresh error: $e');
      throw AuthException('Failed to refresh session');
    }
  }
}
