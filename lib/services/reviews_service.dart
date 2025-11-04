import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review_model.dart';

class ReviewService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all reviews for a specific product
  Future<List<ReviewModel>> getProductReviews(
    String productId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('''
            *,
            profiles!user_id(full_name, profile_image_url)
          ''')
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response;
      return data
          .map((json) => ReviewModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching reviews: $e');
      throw Exception('Failed to fetch reviews: $e');
    }
  }

  /// Get average rating for a product
  Future<Map<String, dynamic>> getProductRatingStats(String productId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('rating')
          .eq('product_id', productId);

      final List<dynamic> data = response;

      if (data.isEmpty) {
        return {
          'averageRating': 0.0,
          'totalReviews': 0,
          'ratingDistribution': {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
        };
      }

      final ratings = data.map((r) => (r['rating'] as num).toDouble()).toList();
      final totalReviews = ratings.length;
      final averageRating = ratings.reduce((a, b) => a + b) / totalReviews;

      // Calculate rating distribution
      final distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      for (var rating in ratings) {
        final ratingInt = rating.floor();
        distribution[ratingInt] = (distribution[ratingInt] ?? 0) + 1;
      }

      return {
        'averageRating': averageRating,
        'totalReviews': totalReviews,
        'ratingDistribution': distribution,
      };
    } catch (e) {
      print('Error fetching rating stats: $e');
      return {
        'averageRating': 0.0,
        'totalReviews': 0,
        'ratingDistribution': {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      };
    }
  }

  /// Add a new review
  Future<ReviewModel?> addReview({
    required String productId,
    required String userId,
    required double rating,
    required String comment,
    bool isVerifiedPurchase = false,
  }) async {
    try {
      final response = await _supabase
          .from('reviews')
          .insert({
            'product_id': productId,
            'user_id': userId,
            'rating': rating,
            'comment': comment,
            'is_verified_purchase': isVerifiedPurchase,
          })
          .select('''
            *,
            profiles!user_id(full_name, profile_image_url)
          ''')
          .single();

      return ReviewModel.fromJson(response);
    } catch (e) {
      print('Error adding review: $e');
      return null;
    }
  }

  /// Update helpful count for a review
  Future<void> incrementHelpfulCount(String reviewId) async {
    try {
      await _supabase.rpc(
        'increment_review_helpful',
        params: {'review_id': reviewId},
      );
    } catch (e) {
      print('Error incrementing helpful count: $e');
    }
  }

  /// Get reviews by a specific user
  Future<List<ReviewModel>> getUserReviews(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('''
            *,
            profiles!user_id(full_name, profile_image_url),
            products(name, image_urls)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> data = response;
      return data
          .map((json) => ReviewModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching user reviews: $e');
      throw Exception('Failed to fetch user reviews: $e');
    }
  }
}
