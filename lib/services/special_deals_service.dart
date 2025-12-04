import 'package:supabase_flutter/supabase_flutter.dart';

class SpecialDealsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getActiveDeals() async {
    try {
      final response = await _supabase
          .from('special_deals')
          .select('*')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      print('🎉 Fetched ${(response as List).length} active special deals');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching special deals: $e');
      return [];
    }
  }

  // Fallback hardcoded deals (used if database returns empty)
  static List<Map<String, dynamic>> getFallbackDeals() {
    return [
      {
        'name': 'Flash Sales',
        'subtitle': 'Limited time!',
        'deal_type': 'flash_sale',
        'icon_name': 'bolt',
        'color': '#FF6B35',
        'image_url': 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400',
      },
      {
        'name': 'Discounted',
        'subtitle': 'Save big now',
        'deal_type': 'discounted',
        'icon_name': 'local_offer',
        'color': '#10B981',
        'image_url': 'https://images.unsplash.com/photo-1607083206325-caf1edba7a0f?w=400',
      },
      {
        'name': 'Last Chance',
        'subtitle': 'Almost gone!',
        'deal_type': 'last_chance',
        'icon_name': 'access_time',
        'color': '#EF4444',
        'image_url': 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400',
      },
      {
        'name': 'Under ₦10k',
        'subtitle': 'Affordable!',
        'deal_type': 'under_10k',
        'icon_name': 'attach_money',
        'color': '#3B82F6',
        'image_url': 'https://images.unsplash.com/photo-1472851294608-062f824d29cc?w=400',
      },
      {
        'name': 'Top Deals',
        'subtitle': 'Bestsellers',
        'deal_type': 'top_deals',
        'icon_name': 'star',
        'color': '#F59E0B',
        'image_url': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400',
      },
      {
        'name': 'New This Week',
        'subtitle': 'Fresh stock',
        'deal_type': 'new_this_week',
        'icon_name': 'fiber_new',
        'color': '#8B5CF6',
        'image_url': 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=400',
      },
    ];
  }
}