import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/product_model.dart';
import '../models/review_model.dart';
import '../services/product_service.dart';
import '../services/reviews_service.dart';
import 'dart:async';
import 'dart:ui';

class ProductDetailsScreen extends StatefulWidget {
  // Can accept either a full product object or just an ID
  final ProductModel? product;
  final String? productId;

  const ProductDetailsScreen({super.key, this.product, this.productId})
    : assert(
        product != null || productId != null,
        'Either product or productId must be provided',
      );

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final ProductService _productService = ProductService();
  final ReviewService _reviewService = ReviewService();

  // State variables
  ProductModel? _product;
  List<ReviewModel> _reviews = [];
  bool _isLoading = true;
  bool _isLoadingReviews = true;
  String? _error;

  int _currentImageIndex = 0;
  bool _isFavorite = false;
  bool _isProductDetailsExpanded = false;

  // Flash sale countdown
  Timer? _countdownTimer;
  Duration? _flashSaleTimeLeft;

  // Mock cart count (will be connected to CartService later)
  int _cartItemCount = 3;

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProductData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // If we have a product object, use it; otherwise fetch by ID
      if (widget.product != null) {
        _product = widget.product;
      } else if (widget.productId != null) {
        _product = await _productService.getProductById(widget.productId!);
      }

      if (_product == null) {
        setState(() {
          _error = 'Product not found';
          _isLoading = false;
        });
        return;
      }

      // Increment view count
      _productService.incrementViewCount(_product!.id);

      // Start flash sale countdown if applicable
      if (_product!.isFlashSale && _product!.flashSaleEndsAt != null) {
        _startFlashSaleCountdown(_product!.flashSaleEndsAt!);
      }

      // Load reviews
      _loadReviews();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load product: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    if (_product == null) return;

    try {
      setState(() {
        _isLoadingReviews = true;
      });

      final reviews = await _reviewService.getProductReviews(
        _product!.id,
        limit: 10,
      );

      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() {
        _isLoadingReviews = false;
      });
    }
  }

  void _startFlashSaleCountdown(DateTime endTime) {
    _flashSaleTimeLeft = endTime.difference(DateTime.now());

    if (_flashSaleTimeLeft!.isNegative) {
      _flashSaleTimeLeft = Duration.zero;
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _flashSaleTimeLeft = endTime.difference(DateTime.now());
        if (_flashSaleTimeLeft!.isNegative) {
          _flashSaleTimeLeft = Duration.zero;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Product Details',
            style: AppTextStyles.heading.copyWith(fontSize: 16),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null || _product == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Product Details',
            style: AppTextStyles.heading.copyWith(fontSize: 16),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                _error ?? 'Product not found',
                style: AppTextStyles.body.copyWith(color: Colors.grey),
              ),
              SizedBox(height: 24),
              ElevatedButton(onPressed: _loadProductData, child: Text('Retry')),
            ],
          ),
        ),
      );
    }

    final product = _product!;
    final hasImages = product.imageUrls.isNotEmpty;
    final images = hasImages ? product.imageUrls : ['placeholder'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.white,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.textDark),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Product Details',
                  style: AppTextStyles.heading.copyWith(fontSize: 16),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.ios_share,
                        color: AppColors.textDark,
                        size: 20,
                      ),
                      onPressed: () => _showShareOptions(context),
                    ),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Carousel
                    _buildImageCarousel(images, product),

                    const SizedBox(height: 16),

                    // Flash Sale Banner
                    if (product.isFlashSale &&
                        _flashSaleTimeLeft != null &&
                        !_flashSaleTimeLeft!.isNegative)
                      _buildFlashSaleBanner(),

                    const SizedBox(height: 16),

                    // Product Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        product.name,
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Price Section
                    _buildPriceSection(product),

                    const SizedBox(height: 12),

                    // Stock & Views
                    _buildStockAndViews(product),

                    const SizedBox(height: 16),

                    // Rating
                    _buildRating(product),

                    const SizedBox(height: 16),

                    // University Location
                    _buildUniversityLocation(product),

                    const SizedBox(height: 24),

                    // Product Details (Expandable)
                    _buildProductDetails(product),

                    const SizedBox(height: 16),

                    // Reviews Section
                    _buildReviewsSection(product),

                    const SizedBox(height: 24),

                    // Similar Products (placeholder for now)
                    _buildSimilarProducts(),

                    const SizedBox(height: 100), // Space for bottom bar
                  ],
                ),
              ),
            ],
          ),

          // Bottom Action Bar
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images, ProductModel product) {
    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 320,
            viewportFraction: 1.0,
            enableInfiniteScroll: images.length > 1,
            onPageChanged: (index, reason) {
              setState(() {
                _currentImageIndex = index;
              });
            },
          ),
          items: images.map((imageUrl) {
            return Container(
              width: double.infinity,
              color: Colors.grey[100],
              child: imageUrl == 'placeholder'
                  ? _buildPlaceholderImage(product)
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage(product);
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
            );
          }).toList(),
        ),

        // Discount Badge
        if (product.discountPercentage != null &&
            product.discountPercentage! > 0)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-${product.discountPercentage}%',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

        // Favorite Button
        Positioned(
          top: 16,
          right: 16,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
              // TODO: Connect to favorites service
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: Color(0xFFFF6B35),
                size: 22,
              ),
            ),
          ),
        ),

        // Dots Indicator (only show if multiple images)
        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentImageIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentImageIndex == index
                        ? Color(0xFFFF6B35)
                        : Colors.grey[400],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderImage(ProductModel product) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag,
            size: 80,
            color: AppColors.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              product.name,
              style: AppTextStyles.body.copyWith(color: AppColors.textLight),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashSaleBanner() {
    if (_flashSaleTimeLeft == null) return SizedBox.shrink();

    final hours = _flashSaleTimeLeft!.inHours;
    final minutes = _flashSaleTimeLeft!.inMinutes % 60;
    final seconds = _flashSaleTimeLeft!.inSeconds % 60;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFFF6B35).withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bolt, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('⚡ ', style: TextStyle(fontSize: 14)),
                      Text(
                        'FLASH SALE ENDING SOON',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(' 🔥', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Grab this deal before time runs out!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFFF6B35),
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection(ProductModel product) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            product.formattedPrice,
            style: AppTextStyles.price.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (product.originalPrice != null &&
              product.originalPrice! > product.price) ...[
            const SizedBox(width: 12),
            Text(
              '₦${product.originalPrice!.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textLight,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStockAndViews(ProductModel product) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (product.stockQuantity <= 10) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(0xFFFF6B35),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Only ${product.stockQuantity} left in stock',
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                color: Color(0xFFFF6B35),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Spacer(),
          Icon(Icons.visibility, size: 16, color: AppColors.textLight),
          const SizedBox(width: 4),
          Text(
            '${product.viewCount} views',
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRating(ProductModel product) {
    final rating = product.averageRating ?? 0.0;
    final reviewCount = product.reviewCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: AppTextStyles.heading.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          ...List.generate(5, (index) {
            return Icon(
              index < rating.floor()
                  ? Icons.star
                  : (index < rating ? Icons.star_half : Icons.star_border),
              color: Colors.amber,
              size: 18,
            );
          }),
          const SizedBox(width: 8),
          Text(
            '($reviewCount ${reviewCount == 1 ? 'rating' : 'ratings'})',
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUniversityLocation(ProductModel product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.location_on, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  product.universityName ?? 'Unknown University',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.verified, size: 16, color: Color(0xFF10B981)),
            ],
          ),
        ),
        if (product.sellerName != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.person, size: 16, color: AppColors.textLight),
                const SizedBox(width: 6),
                Text(
                  'Sold by ${product.sellerName}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductDetails(ProductModel product) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isProductDetailsExpanded = !_isProductDetailsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Product Details',
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isProductDetailsExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_right,
                    color: AppColors.textDark,
                  ),
                ],
              ),
            ),
          ),
          if (_isProductDetailsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.brand != null)
                    _buildDetailRow('Brand', product.brand!),
                  if (product.brand != null) const SizedBox(height: 10),
                  _buildDetailRow('Condition', product.condition.toUpperCase()),
                  const SizedBox(height: 10),
                  if (product.color != null) ...[
                    _buildDetailRow('Color', product.color!),
                    const SizedBox(height: 10),
                  ],
                  _buildDetailRow('Category', product.categoryName ?? 'N/A'),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isEmpty
                        ? 'No description available'
                        : product.description,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(ProductModel product) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviews (${_reviews.length})',
            style: AppTextStyles.heading.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Overall Rating
          if (product.averageRating != null && product.averageRating! > 0)
            Row(
              children: [
                Text(
                  product.averageRating!.toStringAsFixed(1),
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[700],
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(5, (index) {
                  final rating = product.averageRating!;
                  return Icon(
                    index < rating.floor()
                        ? Icons.star
                        : (index < rating
                              ? Icons.star_half
                              : Icons.star_border),
                    color: Colors.amber,
                    size: 20,
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  'Based on ${product.reviewCount} ${product.reviewCount == 1 ? 'rating' : 'ratings'}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Individual Reviews
          if (_isLoadingReviews)
            Center(child: CircularProgressIndicator())
          else if (_reviews.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.rate_review, size: 48, color: Colors.grey[300]),
                    SizedBox(height: 12),
                    Text(
                      'No reviews yet',
                      style: AppTextStyles.body.copyWith(color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Be the first to review this product!',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(
              _reviews.length > 2 ? 2 : _reviews.length,
              (index) => _buildReviewCard(_reviews[index]),
            ),

          if (_reviews.length > 2) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                // TODO: Navigate to all reviews screen
              },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
                side: BorderSide(color: AppColors.textDark, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'See All ${_reviews.length} Reviews',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (review.userName ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.userName ?? 'Anonymous',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (review.isVerifiedPurchase) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Verified',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < review.rating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          );
                        }),
                        const SizedBox(width: 6),
                        Text(
                          review.timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: AppTextStyles.body.copyWith(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarProducts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Similar Products',
            style: AppTextStyles.heading.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Coming soon!',
                style: AppTextStyles.body.copyWith(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cart Button with Badge
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/cart');
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFFF6B35), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      color: Color(0xFFFF6B35),
                      size: 24,
                    ),
                    if (_cartItemCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Color(0xFFFF6B35),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$_cartItemCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Add to Cart Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _product?.isAvailable == true
                    ? () {
                        setState(() {
                          _cartItemCount++;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text('Added to cart!'),
                              ],
                            ),
                            duration: Duration(seconds: 2),
                            backgroundColor: Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                        // TODO: Add to cart service
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                icon: Icon(Icons.add_shopping_cart),
                label: Text(
                  _product?.isAvailable == true
                      ? 'Add to Cart'
                      : 'Out of Stock',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Share Product',
              style: AppTextStyles.heading.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  icon: Icons.copy,
                  label: 'Copy Link',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Link copied!')));
                  },
                ),
                _buildShareOption(
                  icon: Icons.message,
                  label: 'WhatsApp',
                  color: Color(0xFF25D366),
                  onTap: () => Navigator.pop(context),
                ),
                _buildShareOption(
                  icon: Icons.email,
                  label: 'Email',
                  color: Color(0xFF0072C6),
                  onTap: () => Navigator.pop(context),
                ),
                _buildShareOption(
                  icon: Icons.more_horiz,
                  label: 'More',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: (color ?? AppColors.primary).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color ?? AppColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.body.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
