import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _supabase.from('categories').select('id, name, description, icon_url, product_count, is_active').eq('is_active', true).order('sort_order', ascending: true);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('CategoryService Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCategoryByName(String name) async {
    try {
      final response = await _supabase.from('categories').select('*').eq('name', name).eq('is_active', true).maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }
}