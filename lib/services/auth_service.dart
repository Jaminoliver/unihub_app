import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'otp_service.dart';
import 'device_service.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final OTPService _otpService = OTPService();
  final DeviceService _deviceService = DeviceService();

  User? get currentUser => _supabase.auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  String? get currentUserId => currentUser?.id;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // ============================================================================
  // SIGNUP WITH OTP FLOW
  // ============================================================================

  /// Step 1: Send OTP to email (before creating account)
  Future<void> sendSignupOTP(String email) async {
    try {
      debugPrint('📧 Sending signup OTP to: $email');

      // Check if email already exists
      final emailAlreadyExists = await emailExists(email);
      if (emailAlreadyExists) {
        throw AuthException(
          'This email is already registered. Please login instead.',
        );
      }

      // Send OTP
      await _otpService.sendOTP(
        email: email,
        type: 'signup',
      );

      debugPrint('✅ Signup OTP sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending signup OTP: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Failed to send verification code. Please try again.');
    }
  }

  /// Step 2: Verify OTP and create account
Future<AuthResponse> verifySignupOTP({
  required String email,
  required String otp,
  required String password,
  required String fullName,
  required String phoneNumber,
  required String universityId,
  required String state,
  required String deliveryAddress,
}) async {
  try {
    debugPrint('🔍 Verifying signup OTP for: $email');

    // 1. Verify OTP
    final isValid = await _otpService.verifyOTP(
      email: email,
      otp: otp,
      type: 'signup',
    );

    if (!isValid) {
      throw AuthException('Invalid or expired OTP code');
    }

    // 2. Ensure no one is logged in
    if (isLoggedIn) {
      debugPrint('⚠️ User already logged in, signing out first...');
      await signOut();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // 3. Validate university exists
    final universityExists = await _supabase
        .from('universities')
        .select()
        .eq('id', universityId)
        .maybeSingle();

    if (universityExists == null) {
      throw AuthException('Invalid university selected');
    }

    // 4. Create auth user
    debugPrint('📝 Creating auth user for: $email');
    final AuthResponse authResponse = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (authResponse.user == null) {
      throw AuthException('Failed to create user account');
    }

    debugPrint('✅ Auth user created: ${authResponse.user!.id}');

    // 5. SIGN IN to create active session
    debugPrint('🔐 Signing in to create session...');
    final signInResponse = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (signInResponse.session == null) {
      throw AuthException('Failed to create session');
    }

    debugPrint('✅ Session created successfully');

    // 6. Create/update profile
    try {
      debugPrint('📝 Creating user profile...');
      
      // Small delay to ensure session is fully propagated
      await Future.delayed(const Duration(milliseconds: 500));

      await _supabase.from('profiles').upsert({
        'id': authResponse.user!.id,
        'full_name': fullName,
        'email': email.toLowerCase(),
        'phone_number': phoneNumber,
        'university_id': universityId,
        'state': state,
        'delivery_address': deliveryAddress,
        'is_verified': true, // ✅ Already verified via OTP
        'is_seller': false,
        'total_sales': 0,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      debugPrint('✅ User profile created successfully');

      // 7. Register device
      await _deviceService.registerDevice(authResponse.user!.id);
      debugPrint('✅ Device registered for new user');
    } catch (e) {
      debugPrint('❌ Profile creation failed: $e');
      try {
        await _supabase.auth.signOut();
      } catch (_) {}
      throw AuthException('Failed to create user profile. Please try again.');
    }

    return signInResponse; // Return the sign-in response with active session
  } on AuthException {
    rethrow;
  } on AuthApiException catch (e) {
    debugPrint('❌ Supabase Auth error: ${e.message}');
    throw AuthException(e.message);
  } catch (e) {
    debugPrint('❌ Unexpected signup error: $e');
    throw AuthException('An unexpected error occurred. Please try again.');
  }
}

  // ============================================================================
  // LOGIN WITH DEVICE VERIFICATION
  // ============================================================================

  /// Step 1: Login and check if device verification is needed
  Future<Map<String, dynamic>> signInWithDeviceCheck({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Attempting login for: $email');

      // 1. Authenticate user
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null || response.user == null) {
        throw AuthException('Invalid email or password');
      }

      debugPrint('✅ User authenticated: ${response.user!.email}');

      // 2. Check if device is registered
      final isDeviceRegistered = await _deviceService.isDeviceRegistered(
        response.user!.id,
      );

      if (isDeviceRegistered) {
        // Device is known - update last login
        await _deviceService.updateLastLogin(response.user!.id);
        debugPrint('✅ Known device - login successful');

        return {
          'requires_otp': false,
          'user_id': response.user!.id,
          'email': response.user!.email,
        };
      } else {
        // New device detected - send OTP
        debugPrint('⚠️ New device detected - sending OTP');
        await _otpService.sendOTP(
          email: email,
          type: 'login',
        );

        return {
          'requires_otp': true,
          'user_id': response.user!.id,
          'email': response.user!.email,
        };
      }
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      debugPrint('❌ Login error: ${e.message}');
      throw AuthException('Invalid email or password');
    } catch (e) {
      debugPrint('❌ Login error: $e');
      throw AuthException('Login failed. Please try again.');
    }
  }

  /// Step 2: Verify OTP for new device and register it
  Future<void> verifyLoginOTP({
    required String email,
    required String otp,
  }) async {
    try {
      debugPrint('🔍 Verifying login OTP for: $email');

      // 1. Verify OTP
      final isValid = await _otpService.verifyOTP(
        email: email,
        otp: otp,
        type: 'login',
      );

      if (!isValid) {
        throw AuthException('Invalid or expired OTP code');
      }

      // 2. Register device
      if (currentUserId != null) {
        await _deviceService.registerDevice(currentUserId!);
        debugPrint('✅ Device registered and verified');
      } else {
        throw AuthException('User session not found. Please login again.');
      }
    } catch (e) {
      debugPrint('❌ Error verifying login OTP: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Failed to verify device. Please try again.');
    }
  }

  // ============================================================================
  // STANDARD AUTH METHODS (Kept for backwards compatibility)
  // ============================================================================

  /// Original signup method (for direct signup without OTP)
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
      if (isLoggedIn) {
        debugPrint('⚠️ User already logged in, signing out first...');
        await signOut();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final emailAlreadyExists = await emailExists(email);
      if (emailAlreadyExists) {
        throw AuthException(
          'This email is already registered. Please login instead.',
        );
      }

      final universityExists = await _supabase
          .from('universities')
          .select()
          .eq('id', universityId)
          .maybeSingle();

      if (universityExists == null) {
        throw AuthException('Invalid university selected');
      }

      debugPrint('📝 Creating auth user for: $email');
      final AuthResponse authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw AuthException('Failed to create user account');
      }

      debugPrint('✅ Auth user created: ${authResponse.user!.id}');

      try {
        debugPrint('📝 Creating/updating profile...');
        await Future.delayed(const Duration(milliseconds: 800));

        await _supabase.from('profiles').upsert({
          'id': authResponse.user!.id,
          'full_name': fullName,
          'email': email.toLowerCase(),
          'phone_number': phoneNumber,
          'university_id': universityId,
          'state': state,
          'delivery_address': deliveryAddress,
          'is_verified': false,
          'is_seller': false,
          'total_sales': 0,
          'created_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');

        debugPrint('✅ User profile created/updated successfully');
      } catch (e) {
        debugPrint('❌ Profile creation/update failed: $e');
        try {
          debugPrint('🔄 Attempting to rollback auth user...');
          await _supabase.auth.signOut();
        } catch (rollbackError) {
          debugPrint('⚠️ Rollback failed: $rollbackError');
        }
        throw AuthException('Failed to create user profile. Please try again.');
      }

      return authResponse;
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      debugPrint('❌ Supabase Auth error: ${e.message}');
      if (e.message.contains('already registered') ||
          e.message.contains('already exists')) {
        throw AuthException(
          'This email is already registered. Please login instead.',
        );
      }
      throw AuthException(e.message);
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error: ${e.message}');
      if (e.code == '23505') {
        throw AuthException('An account with this information already exists.');
      }
      throw AuthException('Database error. Please try again.');
    } catch (e) {
      debugPrint('❌ Unexpected signup error: $e');
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  /// Original login method (for direct login without device check)
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
    } on AuthException {
      rethrow;
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error: ${e.message}');
      throw AuthException('Database error: ${e.message}');
    } catch (e) {
      debugPrint('❌ Login error: $e');
      throw AuthException('Invalid email or password');
    }
  }

  // ============================================================================
  // PASSWORD RESET WITH OTP
  // ============================================================================

  /// Send password reset OTP
  Future<void> sendPasswordResetOTP(String email) async {
    try {
      debugPrint('📧 Sending password reset OTP to: $email');

      // Check if email exists
      final emailExists = await this.emailExists(email);
      if (!emailExists) {
        throw AuthException('No account found with this email address.');
      }

      await _otpService.sendOTP(
        email: email,
        type: 'password_reset',
      );

      debugPrint('✅ Password reset OTP sent');
    } catch (e) {
      debugPrint('❌ Error sending password reset OTP: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Failed to send reset code. Please try again.');
    }
  }
  
  // ============================================================================
// EMAIL CHANGE WITH OTP
// ============================================================================

/// Send OTP for email change
Future<void> sendEmailChangeOTP(String newEmail) async {
  try {
    debugPrint('📧 Sending email change OTP to: $newEmail');

    // Check if new email already exists
    final emailAlreadyExists = await emailExists(newEmail);
    if (emailAlreadyExists) {
      throw AuthException('This email is already registered.');
    }

    await _otpService.sendOTP(
      email: newEmail,
      type: 'email_change',
    );

    debugPrint('✅ Email change OTP sent');
  } catch (e) {
    debugPrint('❌ Error sending email change OTP: $e');
    if (e is AuthException) rethrow;
    throw AuthException('Failed to send verification code. Please try again.');
  }
}

  Future<void> verifyEmailChangeOTP({
  required String newEmail,
  required String otp,
}) async {
  try {
    debugPrint('🔍 Verifying email change OTP');

    final isValid = await _otpService.verifyOTP(
      email: newEmail,
      otp: otp,
      type: 'email_change',
    );

    if (!isValid) {
      throw AuthException('Invalid or expired OTP code');
    }

    if (currentUserId == null) {
      throw AuthException('No user logged in');
    }

    // Call Edge Function to change email
    final response = await _supabase.functions.invoke(
      'change-user-email',
      body: {'newEmail': newEmail},
    );

    if (response.status != 200) {
      throw AuthException('Failed to change email');
    }

    debugPrint('✅ Email changed successfully');
  } catch (e) {
    debugPrint('❌ Error changing email: $e');
    if (e is AuthException) rethrow;
    throw AuthException('Failed to change email. Please try again.');
  }
}

/// Send OTP for password change
Future<void> sendPasswordChangeOTP() async {
  try {
    final email = currentUser?.email;
    if (email == null) {
      throw AuthException('No user logged in');
    }

    debugPrint('📧 Sending password change OTP to: $email');

    await _otpService.sendOTP(
      email: email,
      type: 'password_change',
    );

    debugPrint('✅ Password change OTP sent');
  } catch (e) {
    debugPrint('❌ Error sending password change OTP: $e');
    if (e is AuthException) rethrow;
    throw AuthException('Failed to send verification code. Please try again.');
  }
}

/// Verify OTP and change password
Future<void> verifyPasswordChangeOTP({
  required String otp,
  required String newPassword,
}) async {
  try {
    final email = currentUser?.email;
    if (email == null) {
      throw AuthException('No user logged in');
    }

    debugPrint('🔍 Verifying password change OTP');

    // 1. Verify OTP
    final isValid = await _otpService.verifyOTP(
      email: email,
      otp: otp,
      type: 'password_change',
    );

    if (!isValid) {
      throw AuthException('Invalid or expired OTP code');
    }

    // 2. Update password
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));

    debugPrint('✅ Password changed successfully');
  } catch (e) {
    debugPrint('❌ Error changing password: $e');
    if (e is AuthException) rethrow;
    throw AuthException('Failed to change password. Please try again.');
  }
}


  /// Verify OTP and reset password
  Future<void> resetPasswordWithOTP({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      debugPrint('🔍 Verifying password reset OTP');

      // 1. Verify OTP
      final isValid = await _otpService.verifyOTP(
        email: email,
        otp: otp,
        type: 'password_reset',
      );

      if (!isValid) {
        throw AuthException('Invalid or expired OTP code');
      }

      // 2. Update password using admin API
      // Note: This requires admin privileges or a custom edge function
      // For now, we'll use the standard password reset
      await _supabase.auth.resetPasswordForEmail(email);
      
      debugPrint('✅ Password reset initiated');
    } catch (e) {
      debugPrint('❌ Error resetting password: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Failed to reset password. Please try again.');
    }
  }

  /// Send password reset email (original method)
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      debugPrint('✅ Password reset email sent to $email');
    } catch (e) {
      debugPrint('❌ Password reset error: $e');
      throw AuthException('Failed to send password reset email');
    }
  }

  // ============================================================================
  // USER PROFILE METHODS
  // ============================================================================

  /// Get current user profile from database
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      if (currentUserId == null) {
        debugPrint('❌ No user logged in');
        return null;
      }

      debugPrint('🔍 Fetching profile for user: $currentUserId');
final profileResponse = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', currentUserId!)
.maybeSingle(); // <--- Changed from .single() to .maybeSingle()

      if (profileResponse == null) {
        debugPrint('⚠️ User logged in, but profile row is missing in DB.');
        return null; // Handle gracefully instead of crashing
      }

      debugPrint('✅ Profile fetched: ${profileResponse['full_name']}');

      final universityId = profileResponse['university_id'] as String?;
      String? universityName;

      if (universityId != null) {
        try {
          final universityResponse = await _supabase
              .from('universities')
              .select('name, short_name')
              .eq('id', universityId)
              .single();

          universityName = universityResponse['short_name'] as String? ??
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

  /// Update user profile
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

  /// Change email address
  Future<void> changeEmail(String newEmail) async {
    try {
      if (!isLoggedIn) {
        throw AuthException('No user logged in');
      }

      final emailAlreadyExists = await emailExists(newEmail);
      if (emailAlreadyExists) {
        throw AuthException('This email is already registered.');
      }

      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      debugPrint(
          '✅ Email change initiated. Confirmation email sent to $newEmail');
    } on AuthApiException catch (e) {
      debugPrint('❌ Email change error: ${e.message}');
      if (e.message.contains('already registered') ||
          e.message.contains('already exists')) {
        throw AuthException('This email is already registered.');
      }
      throw AuthException(e.message);
    } catch (e) {
      debugPrint('❌ Email change error: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Failed to change email: $e');
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

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

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

  // ============================================================================
  // DEVICE MANAGEMENT (exposed for UI)
  // ============================================================================

  /// Get all user devices
  Future<List<Map<String, dynamic>>> getUserDevices() async {
    if (currentUserId == null) {
      throw AuthException('No user logged in');
    }
    return await _deviceService.getUserDevices(currentUserId!);
  }

  /// Remove a device
  Future<void> removeDevice(String deviceId) async {
    if (currentUserId == null) {
      throw AuthException('No user logged in');
    }
    await _deviceService.removeDevice(
      userId: currentUserId!,
      deviceId: deviceId,
    );
  }

  /// Check if device ID is current device
  Future<bool> isCurrentDevice(String deviceId) async {
    return await _deviceService.isCurrentDevice(deviceId);
  }
}