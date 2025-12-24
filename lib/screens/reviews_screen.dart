import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/review_model.dart';
import '../services/reviews_service.dart';
import '../services/auth_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/unihub_loading_widget.dart';
import 'product_details_screen.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _reviewService = ReviewService();
  final _authService = AuthService();
  
  List<ReviewModel> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        final reviews = await _reviewService.getUserReviews(userId);
        if (mounted) {
          setState(() {
            _reviews = reviews;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'User not logged in';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToProduct(ReviewModel review) {
    if (review.productId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(productId: review.productId!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Reviews',
          style: AppTextStyles.heading.copyWith(fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(child: UniHubLoader(size: 60))
          : _errorMessage != null
              ? _buildErrorState()
              : _reviews.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadReviews,
                      color: AppColors.primaryOrange,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          return _ReviewCard(
                            review: _reviews[index],
                            onTap: () => _navigateToProduct(_reviews[index]),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.errorRed,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Error Loading Reviews',
              style: AppTextStyles.heading.copyWith(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: AppTextStyles.body.copyWith(color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadReviews,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryOrange.withOpacity(0.1),
                    Color(0xFFFF8C42).withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rate_review_outlined,
                size: 64,
                color: AppColors.primaryOrange,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Reviews Yet',
              style: AppTextStyles.heading.copyWith(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Your product reviews will appear here',
              style: AppTextStyles.body.copyWith(color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.shopping_bag_outlined, size: 18),
              label: Text('Start Shopping'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                side: BorderSide(color: AppColors.primaryOrange, width: 1.5),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final VoidCallback onTap;

  const _ReviewCard({
    required this.review,
    required this.onTap,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return DateFormat('d MMM yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: AppColors.lightGrey.withOpacity(0.3),
                    child: review.productImageUrl != null
                        ? Image.network(
                            review.productImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.image,
                              color: AppColors.textLight,
                              size: 32,
                            ),
                          )
                        : Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.textLight,
                            size: 32,
                          ),
                  ),
                ),
                SizedBox(width: 14),
                
                // Review Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        review.productName ?? 'Product',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      
                      // Star Rating
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < review.ratingInt
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: AppColors.primaryOrange,
                            );
                          }),
                          SizedBox(width: 6),
                          if (review.isVerifiedPurchase) ...[
                            Icon(
                              Icons.verified,
                              size: 14,
                              color: AppColors.successGreen,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 8),
                      
                      // Review Comment
                      Text(
                        review.comment,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      
                      // Date and Helpful Count
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppColors.textLight,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatDate(review.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                          if (review.helpfulCount > 0) ...[
                            SizedBox(width: 12),
                            Icon(
                              Icons.thumb_up,
                              size: 12,
                              color: AppColors.infoBlue,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${review.helpfulCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.infoBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          Spacer(),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.textLight,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}