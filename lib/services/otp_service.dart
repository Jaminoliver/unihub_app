import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

/// Service for managing OTP generation, sending, and verification
class OTPService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Generate a 6-digit OTP
  String _generateOTP() {
    final random = Random.secure();
    final otp = List.generate(6, (_) => random.nextInt(10)).join();
    debugPrint('🔑 Generated OTP: $otp');
    return otp;
  }

  /// Send OTP email via Supabase Edge Function
  /// 
  /// [email] - User's email address
  /// [type] - OTP type: 'signup', 'login', 'password_reset', 'email_change'
  /// [newEmail] - Optional: new email for email_change type
  Future<void> sendOTP({
    required String email,
    required String type,
    String? newEmail,
  }) async {
    try {
      debugPrint('📧 Sending OTP to $email (type: $type)');

      // 1. Generate OTP
      final otp = _generateOTP();

      // 2. Calculate expiry time (10 minutes from now)
      final expiryTime = DateTime.now().add(const Duration(minutes: 10));

      debugPrint('🕐 OTP expiry time: $expiryTime');

      // 3. Delete any existing unverified OTPs for this email and type
      debugPrint('🗑️ Deleting old OTPs for $email (type: $type)');
      await _supabase
          .from('otps')
          .delete()
          .eq('email', email.toLowerCase())
          .eq('type', type)
          .eq('verified', false);

      // 4. Store OTP in database
      debugPrint('💾 Storing OTP in database');
      final insertResult = await _supabase.from('otps').insert({
        'email': email.toLowerCase(),
        'otp': otp,
        'type': type,
        'expiry_time': expiryTime.toIso8601String(),
        'verified': false,
        'new_email': newEmail?.toLowerCase(),
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      debugPrint('✅ OTP stored in database: $insertResult');

      // 5. Send OTP email via Edge Function
      debugPrint('📤 Calling Edge Function: send-otp');
      final response = await _supabase.functions.invoke(
        'send-otp',
        body: {
          'email': email,
          'otp': otp,
          'type': type,
        },
      );

      debugPrint('📥 Edge Function response status: ${response.status}');
      debugPrint('📥 Edge Function response data: ${response.data}');

      if (response.status == 200) {
        debugPrint('✅ OTP email sent successfully');
      } else {
        throw Exception('Failed to send OTP email: ${response.data}');
      }
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error: ${e.message}');
      debugPrint('❌ Error code: ${e.code}');
      debugPrint('❌ Error details: ${e.details}');
      throw Exception('Failed to generate OTP. Please try again.');
    } catch (e) {
      debugPrint('❌ Error sending OTP: $e');
      throw Exception('Failed to send OTP. Please check your connection.');
    }
  }

  /// Verify OTP code
  /// 
  /// Returns true if OTP is valid and not expired
  Future<bool> verifyOTP({
    required String email,
    required String otp,
    required String type,
  }) async {
    try {
      debugPrint('=================================');
      debugPrint('🔍 STARTING OTP VERIFICATION');
      debugPrint('=================================');
      debugPrint('📧 Email: $email');
      debugPrint('🔢 OTP: $otp');
      debugPrint('📝 Type: $type');
      debugPrint('🕐 Current time: ${DateTime.now()}');

      // 1. First, check if ANY OTP exists for this email and type
      debugPrint('\n--- Checking for ANY OTP records ---');
      final allOtps = await _supabase
          .from('otps')
          .select()
          .eq('email', email.toLowerCase())
          .eq('type', type)
          .order('created_at', ascending: false);

      debugPrint('📊 Found ${allOtps.length} OTP record(s) for this email/type');
      
      if (allOtps.isNotEmpty) {
        for (var i = 0; i < allOtps.length; i++) {
          final record = allOtps[i];
          debugPrint('\nRecord ${i + 1}:');
          debugPrint('  - OTP: ${record['otp']}');
          debugPrint('  - Verified: ${record['verified']}');
          debugPrint('  - Expiry: ${record['expiry_time']}');
          debugPrint('  - Created: ${record['created_at']}');
        }
      }

      // 2. Find the specific unverified OTP
      debugPrint('\n--- Looking for UNVERIFIED matching OTP ---');
      final response = await _supabase
          .from('otps')
          .select()
          .eq('email', email.toLowerCase())
          .eq('otp', otp)
          .eq('type', type)
          .eq('verified', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      debugPrint('🔍 Query result: $response');

      if (response == null) {
        debugPrint('\n❌ NO MATCHING UNVERIFIED OTP FOUND');
        
        // Check if OTP matches but is already verified
        final verifiedCheck = await _supabase
            .from('otps')
            .select()
            .eq('email', email.toLowerCase())
            .eq('otp', otp)
            .eq('type', type)
            .eq('verified', true)
            .maybeSingle();
        
        if (verifiedCheck != null) {
          debugPrint('⚠️ OTP WAS ALREADY VERIFIED');
          debugPrint('⚠️ Verified at: ${verifiedCheck['verified_at']}');
        } else {
          debugPrint('⚠️ OTP does not match or does not exist');
        }
        
        debugPrint('=================================\n');
        return false;
      }

      // 3. Check if OTP has expired
      final expiryTime = DateTime.parse(response['expiry_time'] as String);
      final now = DateTime.now();
      
      debugPrint('\n--- Checking Expiry ---');
      debugPrint('🕐 Current time: $now');
      debugPrint('🕐 Expiry time: $expiryTime');
      debugPrint('⏱️ Time difference: ${expiryTime.difference(now)}');
      
      if (now.isAfter(expiryTime)) {
        debugPrint('❌ OTP HAS EXPIRED');
        debugPrint('=================================\n');
        return false;
      }

      debugPrint('✅ OTP is still valid');

      // 4. Mark OTP as verified
      debugPrint('\n--- Marking OTP as verified ---');
      final updateResult = await _supabase
          .from('otps')
          .update({
            'verified': true,
            'verified_at': DateTime.now().toIso8601String(),
          })
          .eq('id', response['id'])
          .select();

      debugPrint('✅ OTP marked as verified: $updateResult');
      debugPrint('=================================');
      debugPrint('✅ OTP VERIFICATION SUCCESSFUL');
      debugPrint('=================================\n');
      
      return true;
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error during OTP verification: ${e.message}');
      debugPrint('❌ Error code: ${e.code}');
      debugPrint('❌ Error details: ${e.details}');
      debugPrint('=================================\n');
      return false;
    } catch (e) {
      debugPrint('❌ Error verifying OTP: $e');
      debugPrint('=================================\n');
      return false;
    }
  }

  /// Check if a valid OTP exists for the email and type
  Future<bool> hasValidOTP({
    required String email,
    required String type,
  }) async {
    try {
      debugPrint('🔍 Checking for valid OTP: $email (type: $type)');
      
      final response = await _supabase
          .from('otps')
          .select()
          .eq('email', email.toLowerCase())
          .eq('type', type)
          .eq('verified', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No OTP found');
        return false;
      }

      // Check if OTP has expired
      final expiryTime = DateTime.parse(response['expiry_time'] as String);
      final isExpired = DateTime.now().isAfter(expiryTime);
      
      debugPrint('OTP exists: ${!isExpired ? "Valid" : "Expired"}');
      
      return !isExpired;
    } catch (e) {
      debugPrint('❌ Error checking OTP existence: $e');
      return false;
    }
  }

  /// Get time remaining until OTP expires
  /// 
  /// Returns Duration or null if no valid OTP exists
  Future<Duration?> getOTPTimeRemaining({
    required String email,
    required String type,
  }) async {
    try {
      final response = await _supabase
          .from('otps')
          .select('expiry_time')
          .eq('email', email.toLowerCase())
          .eq('type', type)
          .eq('verified', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final expiryTime = DateTime.parse(response['expiry_time'] as String);
      final now = DateTime.now();

      if (now.isAfter(expiryTime)) {
        return null;
      }

      final remaining = expiryTime.difference(now);
      debugPrint('⏱️ OTP time remaining: ${remaining.inMinutes}m ${remaining.inSeconds % 60}s');
      
      return remaining;
    } catch (e) {
      debugPrint('❌ Error getting OTP time remaining: $e');
      return null;
    }
  }

  /// Clean up expired OTPs (optional - can be called periodically)
  Future<void> cleanupExpiredOTPs() async {
    try {
      debugPrint('🧹 Cleaning up expired OTPs');
      
      final result = await _supabase
          .from('otps')
          .delete()
          .lt('expiry_time', DateTime.now().toIso8601String())
          .select();
      
      debugPrint('✅ Cleaned up ${result.length} expired OTP(s)');
    } catch (e) {
      debugPrint('❌ Error cleaning up OTPs: $e');
    }
  }

  /// Resend OTP (same as sendOTP but with better naming)
  Future<void> resendOTP({
    required String email,
    required String type,
    String? newEmail,
  }) async {
    debugPrint('🔄 Resending OTP');
    await sendOTP(email: email, type: type, newEmail: newEmail);
  }
}