import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../services/wishlist_service.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../widgets/empty_states.dart';
import '../widgets/unihub_loading_widget.dart';
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
  final WishlistService _wishlistService = WishlistService();
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();

  List<ProductModel> _products = [];
  Set<String> _favorites = {};
  Set<String> _cart = {};
  bool _isLoading = true;
  String? _isAddingToCartId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadProducts(),
        _loadWishlistIds(),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productService.getProductsByState(
        categoryId: widget.categoryId,
        state: widget.state,
        priorityUniversityId: widget.universityId,
        limit: 50,
      );
      if (mounted) setState(() => _products = products);
    } catch (e) {
      debugPrint('Error loading category products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _loadWishlistIds() async {
    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        final wishlistIds = await _wishlistService.getUserWishlistIds(userId);
        if (mounted) setState(() => _favorites = wishlistIds);
      }
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
    }
  }

  Future<void> _toggleFavorite(String productId) async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    if (_favorites.contains(productId)) {
      setState(() => _favorites.remove(productId));
      await _wishlistService.removeFromWishlist(userId: userId, productId: productId);
    } else {
      setState(() => _favorites.add(productId));
      await _wishlistService.addToWishlist(userId: userId, productId: productId);
    }
  }

  void _toggleCart(ProductModel product) {
    if (_isAddingToCartId != null) return;
    if (_cart.contains(product.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item is already in your cart!'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      _addToCartFromCard(product);
    }
  }

  Future<void> _addToCartFromCard(ProductModel product) async {
    setState(() => _isAddingToCartId = product.id);
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('You must be logged in');
      await _cartService.addToCart(userId: userId, productId: product.id);
      setState(() => _cart.add(product.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${product.name}" added to cart!'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCartId = null);
    }
  }

  void _navigateToProductDetails(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: product),
      ),
    );
  }

  String _formatPrice(double price) => '₦${NumberFormat("#,##0", "en_US").format(price)}';

  Widget _buildRatingStars({required ProductModel product, double size = 10}) {
    final displayRating = product.averageRating ?? 0.0;
    final fullStars = displayRating.floor();
    final hasHalfStar = (displayRating - fullStars) >= 0.5;

    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < fullStars) return Icon(Icons.star, size: size, color: AppColors.primaryOrange);
          if (i == fullStars && hasHalfStar) return Icon(Icons.star_half, size: size, color: AppColors.primaryOrange);
          return Icon(Icons.star_border, size: size, color: AppColors.getBorder(context));
        }),
        const SizedBox(width: 3),
        Text(
          '${displayRating.toStringAsFixed(1)}',
          style: TextStyle(fontSize: size - 2, color: AppColors.getTextMuted(context), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
        ),
        backgroundColor: AppColors.getCardBackground(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(context)),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),
        ),
      ),
      body: _isLoading
          ? Center(child: UniHubLoader(size: 80))
          : _products.isEmpty
              ? NoProductsEmptyState(
                  message: 'No Products in this Category',
                  subtitle: 'Be the first to list one!',
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.primaryOrange,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.58,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, index) => _buildProductCard(_products[index]),
                  ),
                ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final isFavorite = _favorites.contains(product.id);
    final isInCart = _cart.contains(product.id);
    final isAddingToCart = _isAddingToCartId == product.id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
      ),
      child: InkWell(
        onTap: () => _navigateToProductDetails(product),
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrls.isNotEmpty
                          ? product.imageUrls.first
                          : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.getBackground(context),
                        child: Icon(Icons.image, color: AppColors.getTextMuted(context)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.getBackground(context),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 50,
                          color: AppColors.primaryOrange.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  if (product.hasDiscount || product.discountPercentage != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${product.discountPercentage ?? ((product.originalPrice! - product.price) / product.originalPrice! * 100).round()}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: () => _toggleFavorite(product.id),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.getCardBackground(context).withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : AppColors.getTextMuted(context),
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _toggleCart(product),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isInCart ? AppColors.primaryOrange : AppColors.getCardBackground(context).withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: isAddingToCart
                            ? SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  color: isInCart ? Colors.white : AppColors.primaryOrange,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isInCart ? Icons.check : Icons.add_shopping_cart,
                                color: isInCart ? Colors.white : AppColors.primaryOrange,
                                size: 15,
                              ),
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
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatPrice(product.price),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      if (product.hasDiscount && product.originalPrice != null) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _formatPrice(product.originalPrice!),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.getTextMuted(context),
                              decoration: TextDecoration.lineThrough,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 10, color: AppColors.primaryOrange),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          product.universityAbbr ?? product.universityName ?? 'N/A',
                          style: TextStyle(fontSize: 9, color: AppColors.getTextMuted(context), fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _buildRatingStars(product: product, size: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}