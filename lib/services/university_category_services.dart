import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/university_category_models.dart';

class UniversityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all active universities
  Future<List<UniversityModel>> getAllUniversities() async {
    try {
      final response = await _supabase
          .from('universities')
          .select('*')
          .eq('is_active', true)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => UniversityModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching universities: $e');
      throw Exception('Failed to fetch universities: $e');
    }
  }

  /// Get university by ID
  Future<UniversityModel?> getUniversityById(String universityId) async {
    try {
      final response = await _supabase
          .from('universities')
          .select('*')
          .eq('id', universityId)
          .single();

      return UniversityModel.fromJson(response);
    } catch (e) {
      print('Error fetching university: $e');
      return null;
    }
  }

  /// Search universities by name
  Future<List<UniversityModel>> searchUniversities(String query) async {
    try {
      final response = await _supabase
          .from('universities')
          .select('*')
          .eq('is_active', true)
          .or('name.ilike.%$query%,short_name.ilike.%$query%')
          .order('name', ascending: true);

      return (response as List)
          .map((json) => UniversityModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error searching universities: $e');
      throw Exception('Failed to search universities: $e');
    }
  }
}

class CategoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all active categories
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((json) => CategoryModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching categories: $e');
      throw Exception('Failed to fetch categories: $e');
    }
  }

  /// Get category by ID
  Future<CategoryModel?> getCategoryById(String categoryId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('*')
          .eq('id', categoryId)
          .single();

      return CategoryModel.fromJson(response);
    } catch (e) {
      print('Error fetching category: $e');
      return null;
    }
  }
}
