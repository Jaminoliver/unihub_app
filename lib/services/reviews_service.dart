import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review_model.dart';

class ReviewService {
  final _supabase = Supabase.instance.client;

  // Submit a review (only for delivered orders)
  Future<bool> submitReview({
    required String productId,
    required String userId,
    required String orderId,
    required int rating,
    required String comment,
  }) async {
    try {
      // Verify the order is delivered and belongs to the user
      final order = await _supabase
          .from('orders')
          .select('order_status, buyer_id')
          .eq('id', orderId)
          .single();

      if (order['buyer_id'] != userId) {
        throw Exception('You can only review your own orders');
      }

      if (order['order_status'] != 'delivered') {
        throw Exception('You can only review delivered orders');
      }

      // Check if user already reviewed this order
      final existingReview = await _supabase
          .from('reviews')
          .select()
          .eq('order_id', orderId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingReview != null) {
        // Update existing review
        await _supabase
            .from('reviews')
            .update({
              'rating': rating.toDouble().toString(),
              'comment': comment,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingReview['id']);
      } else {
        // Insert new review
        await _supabase.from('reviews').insert({
          'product_id': productId,
          'user_id': userId,
          'order_id': orderId,
          'rating': rating.toDouble().toString(),
          'comment': comment,
          'is_verified_purchase': true,
          'helpful_count': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Update product's average rating and review count
      await _updateProductRating(productId);

      return true;
    } catch (e) {
      print('Error submitting review: $e');
      rethrow;
    }
  }

  // Get reviews for a product
  Future<List<ReviewModel>> getProductReviews(String productId, {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('''
            *,
            profiles:user_id ( 
              full_name,
              profile_image_url
            )
          ''')
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => ReviewModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting product reviews: $e');
      return [];
    }
  }

  // Get all reviews by a user - NEW METHOD
  Future<List<ReviewModel>> getUserReviews(String userId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('''
            *,
            profiles:user_id (
              full_name,
              profile_image_url
            ),
            products:product_id (
              name,
              image_urls
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReviewModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching user reviews: $e');
      rethrow;
    }
  }

  // Check if user has reviewed an order
  Future<ReviewModel?> getUserReviewForOrder(String userId, String orderId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('''
            *,
            profiles:user_id (
              full_name,
              profile_image_url
            )
          ''')
          .eq('user_id', userId)
          .eq('order_id', orderId)
          .maybeSingle();

      if (response == null) return null;
      return ReviewModel.fromJson(response);
    } catch (e) {
      print('Error checking user review: $e');
      return null;
    }
  }

  // Update product's average rating and review count
  Future<void> _updateProductRating(String productId) async {
    try {
      final reviews = await _supabase
          .from('reviews')
          .select('rating')
          .eq('product_id', productId);

      if (reviews.isEmpty) {
        await _supabase
            .from('products')
            .update({
              'average_rating': null,
              'review_count': 0,
            })
            .eq('id', productId);
        return;
      }

      // Parse ratings - handle both string and numeric types
      final ratings = (reviews as List).map((r) {
        if (r['rating'] is String) {
          return double.tryParse(r['rating']) ?? 0.0;
        } else if (r['rating'] is num) {
          return (r['rating'] as num).toDouble();
        }
        return 0.0;
      }).toList();

      final totalRating = ratings.fold<double>(0.0, (sum, rating) => sum + rating);
      final averageRating = totalRating / ratings.length;

      await _supabase
          .from('products')
          .update({
            'average_rating': averageRating,
            'review_count': reviews.length,
          })
          .eq('id', productId);
    } catch (e) {
      print('Error updating product rating: $e');
    }
  }

  // Delete a review (optional - for user to delete their own review)
  Future<bool> deleteReview(String reviewId, String userId) async {
    try {
      await _supabase
          .from('reviews')
          .delete()
          .eq('id', reviewId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('Error deleting review: $e');
      return false;
    }
  }

  // Increment helpful count on a review
  Future<bool> markReviewHelpful(String reviewId) async {
    try {
      await _supabase.rpc('increment_review_helpful', params: {'review_id': reviewId});
      return true;
    } catch (e) {
      print('Error marking review helpful: $e');
      return false;
    }
  }
}