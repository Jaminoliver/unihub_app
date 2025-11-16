import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/empty_states.dart';
import '../widgets/unihub_loading_widget.dart';
import './product_details_screen.dart';

class SpecialDealProductsScreen extends StatefulWidget {
  final String dealType; // 'flash_sale', 'discounted', 'last_chance', 'under_10k', 'top_deals', 'new_this_week'
  final String dealTitle;
  final String? universityId;
  final String state;

  const SpecialDealProductsScreen({
    super.key,
    required this.dealType,
    required this.dealTitle,
    this.universityId,
    required this.state,
  });

  @override
  State<SpecialDealProductsScreen> createState() => _SpecialDealProductsScreenState();
}

class _SpecialDealProductsScreenState extends State<SpecialDealProductsScreen> {
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  final WishlistService _wishlistService = WishlistService();
  
  List<ProductModel> _products = [];
  bool _isLoading = true;

  Set<String> _favorites = {};
  Set<String> _cart = {};
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
      List<ProductModel> products = [];
      
      switch (widget.dealType) {
        case 'flash_sale':
          products = await _productService.getFlashSaleProducts(
            state: widget.state,
            priorityUniversityId: widget.universityId,
          );
          break;
        case 'discounted':
          products = await _productService.getDiscountedProducts(
            state: widget.state,
            priorityUniversityId: widget.universityId,
          );
          break;
        case 'last_chance':
          products = await _productService.getLastChanceProducts(
            state: widget.state,
            priorityUniversityId: widget.universityId,
          );
          break;
        case 'under_10k':
          products = await _productService.getUnder10kProducts(
            state: widget.state,
            priorityUniversityId: widget.universityId,
          );
          break;
        case 'top_deals':
          products = await _productService.getTopDealsProducts(
            state: widget.state,
            priorityUniversityId: widget.universityId,
          );
          break;
        case 'new_this_week':
          products = await _productService.getNewThisWeekProducts(
            state: widget.state,
            priorityUniversityId: widget.universityId,
          );
          break;
      }
      
      if (mounted) setState(() => _products = products);
    } catch (e) {
      debugPrint('Error loading special deal products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  String _formatPrice(double price) => '₦${NumberFormat("#,##0", "en_US").format(price)}';

  Widget _buildRatingStars({double? rating, required int reviewCount, double size = 10}) {
    final displayRating = rating ?? 0.0;
    final fullStars = displayRating.floor();
    final hasHalfStar = (displayRating - fullStars) >= 0.5;
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < fullStars) return Icon(Icons.star, size: size, color: Color(0xFFFF6B35));
          if (i == fullStars && hasHalfStar) return Icon(Icons.star_half, size: size, color: Color(0xFFFF6B35));
          return Icon(Icons.star_border, size: size, color: Colors.grey.shade300);
        }),
        const SizedBox(width: 3),
        Text('${displayRating.toStringAsFixed(1)}', style: TextStyle(fontSize: size - 2, color: AppColors.textLight, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _navigateToProductDetails(ProductModel product) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: product)));
  }

  void _toggleCart(ProductModel product) {
    if (_isAddingToCartId != null) return;
    if (_cart.contains(product.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item is already in your cart!'), duration: Duration(seconds: 1)));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${product.name}" added to cart!'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isAddingToCartId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.dealTitle, style: AppTextStyles.heading.copyWith(fontSize: 18)),
        backgroundColor: AppColors.white,
        elevation: 0.3,
      ),
      body: _isLoading
          ? Center(child: UniHubLoader(size: 80))
          : _products.isEmpty
              ? NoProductsEmptyState(
                  message: 'No ${widget.dealTitle} Available',
                  subtitle: 'Check back later for new deals!',
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.primary,
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
                    itemBuilder: (context, index) => _buildGridProductCard(_products[index]),
                  ),
                ),
    );
  }

  Widget _buildGridProductCard(ProductModel product) {
    final isFavorite = _favorites.contains(product.id);
    final isInCart = _cart.contains(product.id);
    final isAddingToCart = _isAddingToCartId == product.id;
    
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToProductDetails(product),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AppColors.background, child: Icon(Icons.image, color: AppColors.textLight.withOpacity(0.5))),
                      errorWidget: (context, url, error) => Container(color: AppColors.background, child: Icon(Icons.shopping_bag_outlined, size: 50, color: Color(0xFFFF6B35).withOpacity(0.3))),
                    ),
                  ),
                  if (product.hasDiscount || product.discountPercentage != null)
                    Positioned(
                      top: 8, 
                      right: 8, 
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), 
                        decoration: BoxDecoration(color: Color(0xFFFF6B35), borderRadius: BorderRadius.circular(8)), 
                        child: Text(
                          '-${product.discountPercentage ?? ((product.originalPrice! - product.price) / product.originalPrice! * 100).round()}%', 
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
                        )
                      )
                    ),
                  Positioned(
                    top: 8, 
                    left: 8, 
                    child: GestureDetector(
                      onTap: () => _toggleFavorite(product.id), 
                      child: Container(
                        padding: const EdgeInsets.all(6), 
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle), 
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border, 
                          color: isFavorite ? Colors.red : Colors.grey.shade600, 
                          size: 16
                        )
                      )
                    )
                  ),
                  Positioned(
                    bottom: 8, 
                    right: 8, 
                    child: GestureDetector(
                      onTap: () => _toggleCart(product), 
                      child: Container(
                        padding: const EdgeInsets.all(6), 
                        decoration: BoxDecoration(
                          color: isInCart ? Color(0xFFFF6B35) : Colors.white.withOpacity(0.9), 
                          shape: BoxShape.circle
                        ), 
                        child: isAddingToCart 
                          ? Container(
                              width: 16, 
                              height: 16, 
                              padding: const EdgeInsets.all(2.0), 
                              child: CircularProgressIndicator(
                                color: isInCart ? Colors.white : Color(0xFFFF6B35), 
                                strokeWidth: 2
                              )
                            ) 
                          : Icon(
                              isInCart ? Icons.check : Icons.add_shopping_cart, 
                              color: isInCart ? Colors.white : Color(0xFFFF6B35), 
                              size: 16
                            )
                      )
                    )
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
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13, 
                      color: AppColors.textDark, 
                      fontWeight: FontWeight.bold
                    ), 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        _formatPrice(product.price), 
                        style: AppTextStyles.price.copyWith(
                          fontSize: 14, 
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFFFF6B35)
                        )
                      ),
                      if (product.hasDiscount && product.originalPrice != null) ...[
                        const SizedBox(width: 3), 
                        Flexible(
                          child: Text(
                            _formatPrice(product.originalPrice!), 
                            style: TextStyle(
                              fontSize: 10, 
                              color: AppColors.textLight, 
                              decoration: TextDecoration.lineThrough
                            ), 
                            overflow: TextOverflow.ellipsis, 
                            maxLines: 1
                          )
                        )
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 10, color: AppColors.textLight), 
                      const SizedBox(width: 2), 
                      Expanded(
                        child: Text(
                          product.universityAbbr?.isNotEmpty == true 
                            ? product.universityAbbr! 
                            : product.universityName ?? 'UniHub', 
                          style: TextStyle(fontSize: 9, color: AppColors.textLight), 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis
                        )
                      )
                    ]
                  ),
                  const SizedBox(height: 2),
                  _buildRatingStars(
                    rating: product.averageRating, 
                    reviewCount: product.reviewCount, 
                    size: 10
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