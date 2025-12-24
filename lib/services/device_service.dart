import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Service for managing user devices and device verification
class DeviceService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _deviceIdKey = 'unihub_device_id';

  /// Get unique device ID (persistent across app sessions)
  Future<String> getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if device ID already exists
      String? deviceId = prefs.getString(_deviceIdKey);
      
      if (deviceId != null) {
        debugPrint('📱 Using existing device ID: $deviceId');
        return deviceId;
      }

      // Generate new device ID based on device info
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id; // Android ID (unique per device)
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? _generateFallbackId();
      } else {
        deviceId = _generateFallbackId();
      }

      // Save device ID for future use
      await prefs.setString(_deviceIdKey, deviceId);
      debugPrint('📱 Generated new device ID: $deviceId');
      
      return deviceId;
    } catch (e) {
      debugPrint('❌ Error getting device ID: $e');
      return _generateFallbackId();
    }
  }

  /// Generate fallback device ID if platform detection fails
  String _generateFallbackId() {
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get device information (name, OS version, platform)
  Future<Map<String, String>> getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'device_name': '${androidInfo.brand} ${androidInfo.model}',
          'os_version': 'Android ${androidInfo.version.release}',
          'platform': 'Android',
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'device_name': '${iosInfo.name} (${iosInfo.model})',
          'os_version': 'iOS ${iosInfo.systemVersion}',
          'platform': 'iOS',
        };
      } else {
        return {
          'device_name': 'Unknown Device',
          'os_version': 'Unknown',
          'platform': 'Unknown',
        };
      }
    } catch (e) {
      debugPrint('❌ Error getting device info: $e');
      return {
        'device_name': 'Unknown Device',
        'os_version': 'Unknown',
        'platform': 'Unknown',
      };
    }
  }

  /// Check if current device is registered for the user
  Future<bool> isDeviceRegistered(String userId) async {
    try {
      final deviceId = await getDeviceId();
      
      debugPrint('🔍 Checking if device is registered for user $userId');
      
      final response = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .eq('device_id', deviceId)
          .eq('is_verified', true)
          .maybeSingle();

      final isRegistered = response != null;
      debugPrint(isRegistered 
          ? '✅ Device is registered' 
          : '❌ Device not registered (new device)');
      
      return isRegistered;
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error checking device: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Error checking device registration: $e');
      return false;
    }
  }

  /// Register current device for the user
  Future<void> registerDevice(String userId) async {
    try {
      final deviceId = await getDeviceId();
      final deviceInfo = await getDeviceInfo();
      
      debugPrint('📱 Registering device $deviceId for user $userId');

      // Use upsert to handle cases where device might already exist
      await _supabase.from('user_devices').upsert({
        'user_id': userId,
        'device_id': deviceId,
        'device_name': deviceInfo['device_name'],
        'os_version': deviceInfo['os_version'],
        'platform': deviceInfo['platform'],
        'is_verified': true,
        'last_login': DateTime.now().toIso8601String(),
        'registered_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_id');

      debugPrint('✅ Device registered successfully');
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error registering device: ${e.message}');
      throw Exception('Failed to register device: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error registering device: $e');
      throw Exception('Failed to register device. Please try again.');
    }
  }

  /// Update last login time for current device
  Future<void> updateLastLogin(String userId) async {
    try {
      final deviceId = await getDeviceId();
      
      await _supabase
          .from('user_devices')
          .update({
            'last_login': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('device_id', deviceId);

      debugPrint('✅ Last login time updated');
    } catch (e) {
      debugPrint('⚠️ Error updating last login: $e');
      // Don't throw error - this is not critical
    }
  }

  /// Get all registered devices for a user
  Future<List<Map<String, dynamic>>> getUserDevices(String userId) async {
    try {
      final response = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .order('last_login', ascending: false);

      debugPrint('📱 Found ${response.length} registered devices');
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error fetching devices: ${e.message}');
      throw Exception('Failed to fetch devices: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error fetching user devices: $e');
      throw Exception('Failed to fetch devices. Please try again.');
    }
  }

  /// Remove a specific device for a user
  Future<void> removeDevice({
    required String userId,
    required String deviceId,
  }) async {
    try {
      await _supabase
          .from('user_devices')
          .delete()
          .eq('user_id', userId)
          .eq('device_id', deviceId);

      debugPrint('✅ Device removed: $deviceId');
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error removing device: ${e.message}');
      throw Exception('Failed to remove device: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error removing device: $e');
      throw Exception('Failed to remove device. Please try again.');
    }
  }

  /// Check if this is the current device
  Future<bool> isCurrentDevice(String checkDeviceId) async {
    final currentDeviceId = await getDeviceId();
    return currentDeviceId == checkDeviceId;
  }

  /// Get current device name
  Future<String> getCurrentDeviceName() async {
    final deviceInfo = await getDeviceInfo();
    return deviceInfo['device_name'] ?? 'Unknown Device';
  }

  /// Clear all devices for a user (useful for logout/security)
  Future<void> clearAllDevices(String userId) async {
    try {
      await _supabase
          .from('user_devices')
          .delete()
          .eq('user_id', userId);

      debugPrint('✅ All devices cleared for user');
    } catch (e) {
      debugPrint('❌ Error clearing devices: $e');
      throw Exception('Failed to clear devices. Please try again.');
    }
  }
}