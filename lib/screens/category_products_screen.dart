import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/product_model.dart';
import '../models/university_category_models.dart';
import '../services/product_service.dart';
import '../widgets/empty_states.dart';
import '../widgets/skeleton_loaders.dart';
import './product_details_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String? universityId;
  final String state;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.universityId,
    required this.state,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final ProductService _productService = ProductService();
  List<ProductModel> _products = [];
  bool _isLoading = true;

  // --- State copied from home_screen.dart for helper widgets ---
  // These are local to this screen
  final Set<String> _favorites = {};
  final Set<String> _cart = {};
  final Map<String, bool> _likes = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, bool> _verifiedStatus = {};
  // --- End of copied state ---

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productService.getProductsByState(
        categoryId: widget.categoryId,
        state: widget.state,
        priorityUniversityId: widget.universityId,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _products = products;
        });
      }
    } catch (e) {
      debugPrint('Error loading category products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: AppTextStyles.heading.copyWith(fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0.3,
      ),
      body: _buildProductGrid(_products), // Use the helper from home_screen
    );
  }

  // --- ALL HELPER METHODS COPIED FROM home_screen.dart ---
  // These are needed for _buildGridProductCard to work.

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  String _formatPrice(double price) {
    return '₦${NumberFormat("#,##0", "en_US").format(price)}';
  }

  Widget _buildRatingStars({
    double? rating,
    required int reviewCount,
    double size = 12,
  }) {
    final displayRating = rating ?? 0.0;
    final fullStars = displayRating.floor();
    final hasHalfStar = (displayRating - fullStars) >= 0.5;

    return Row(
      children: [
        ...List.generate(5, (index) {
          if (index < fullStars) {
            return Icon(Icons.star, size: size, color: Color(0xFFFF6B35));
          } else if (index == fullStars && hasHalfStar) {
            return Icon(Icons.star_half, size: size, color: Color(0xFFFF6B35));
          } else {
            return Icon(
              Icons.star_border,
              size: size,
              color: Colors.grey.shade400,
            );
          }
        }),
        const SizedBox(width: 4),
        Text(
          '${displayRating.toStringAsFixed(1)} ${reviewCount > 0 ? '($reviewCount)' : ''}',
          style: TextStyle(fontSize: size - 2, color: AppColors.textLight),
        ),
      ],
    );
  }

  void _toggleLike(String productId) {
    setState(() {
      final currentLikeStatus = _likes[productId] ?? false;
      _likes[productId] = !currentLikeStatus;
      final currentCount = _likeCounts[productId] ?? 0;
      _likeCounts[productId] = currentLikeStatus
          ? currentCount - 1
          : currentCount + 1;
    });
  }

  int _getLikeCount(String productId) {
    return _likeCounts[productId] ?? (50 + (productId.hashCode % 200));
  }

  bool _isVerified(String productId) {
    if (!_verifiedStatus.containsKey(productId)) {
      _verifiedStatus[productId] = (productId.hashCode % 10) < 4;
    }
    return _verifiedStatus[productId] ?? false;
  }

  void _navigateToProductDetails(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: product),
      ),
    );
  }

  void _toggleCart(ProductModel product) {
    setState(() {
      if (_cart.contains(product.id)) {
        _cart.remove(product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from cart'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        _cart.add(product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Added to cart'),
            duration: const Duration(seconds: 1),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    });
  }

  // This is the main build method for the grid, copied from home_screen
  Widget _buildProductGrid(List<ProductModel> products) {
    if (_isLoading) {
      return const ProductGridSkeleton(itemCount: 8);
    }

    if (products.isEmpty) {
      return const NoProductsEmptyState(
        message: 'No Products in this Category',
        subtitle: 'Be the first to list one!',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadProducts();
      },
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) => _buildGridProductCard(products[index]),
      ),
    );
  }

  // This is the product card widget, copied from home_screen
  Widget _buildGridProductCard(ProductModel product) {
    final isFavorite = _favorites.contains(product.id);
    final isInCart = _cart.contains(product.id);
    final isLiked = _likes[product.id] ?? false;
    final likeCount = _getLikeCount(product.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToProductDetails(product),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrls.isNotEmpty
                          ? product.imageUrls.first
                          : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.background,
                        child: Icon(
                          Icons.image,
                          color: AppColors.textLight.withOpacity(0.5),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.background,
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 50,
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (isFavorite)
                          _favorites.remove(product.id);
                        else
                          _favorites.add(product.id);
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.grey.shade600,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleCart(product),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isInCart
                              ? AppColors.primary
                              : Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_shopping_cart,
                          color: isInCart ? Colors.white : AppColors.primary,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  if (_isVerified(product.id))
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified, color: Colors.white, size: 9),
                            SizedBox(width: 3),
                            Text(
                              'Verified Seller',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatPrice(product.price),
                    style: AppTextStyles.price.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 10,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          product.universityName ??
                              'UniHub', // FIXED: Changed from widget.universityId
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _toggleLike(product.id),
                        child: Icon(
                          Icons.thumb_up,
                          size: 10,
                          color: isLiked
                              ? const Color(0xFFFF6B35)
                              : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _formatCount(likeCount),
                        style: TextStyle(
                          fontSize: 9,
                          color: isLiked
                              ? const Color(0xFFFF6B35)
                              : AppColors.textLight,
                          fontWeight: isLiked
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _buildRatingStars(
                    rating: product.averageRating,
                    reviewCount: product.reviewCount,
                    size: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
