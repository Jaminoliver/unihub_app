// product_view_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductViewService {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _currentViewId;

  /// Track a new product view (creates a session)
  Future<void> trackProductView(String productId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Generate a session ID (you can use a better method if needed)
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final response = await _supabase.from('product_views').insert({
        'product_id': productId,
        'user_id': userId,
        'session_id': sessionId,
        'viewed_at': DateTime.now().toUtc().toIso8601String(),
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
      }).select('id').single();

      _currentViewId = response['id'] as String;
    } catch (e) {
      print('Error tracking product view: $e');
    }
  }

  /// Update the last_active_at timestamp for the current viewing session
  Future<void> updateViewTimestamp(String productId) async {
    try {
      if (_currentViewId == null) return;

      await _supabase.from('product_views').update({
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _currentViewId!);
    } catch (e) {
      print('Error updating view timestamp: $e');
    }
  }

  /// Get the number of ACTIVE viewers (viewed in last 5 minutes)
  Future<int> getActiveViewers(String productId) async {
    try {
      final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5)).toUtc().toIso8601String();
      
      final response = await _supabase
          .from('product_views')
          .select('id')
          .eq('product_id', productId)
          .gte('last_active_at', fiveMinutesAgo)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error getting active viewers: $e');
      return 0;
    }
  }

  /// Get the TOTAL number of views (all time)
  Future<int> getTotalViews(String productId) async {
    try {
      final response = await _supabase
          .from('product_views')
          .select('id')
          .eq('product_id', productId)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error getting total views: $e');
      return 0;
    }
  }

  /// Clear the current view session (call when leaving product details screen)
  void clearCurrentView() {
    _currentViewId = null;
  }
}