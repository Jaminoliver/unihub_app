import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/wishlist_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../models/product_model.dart';
import '../widgets/unihub_loading_widget.dart';
import '../widgets/empty_states.dart';
import './product_details_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final WishlistService _wishlistService = WishlistService();
  final AuthService _authService = AuthService();
  final CartService _cartService = CartService();

  List<ProductModel> _wishlistProducts = [];
  Set<String> _cartItems = {};
  bool _isLoading = true;
  String? _addingToCartId;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() => _isLoading = true);
    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        final products = await _wishlistService.getUserWishlist(userId);
        if (mounted) {
          setState(() {
            _wishlistProducts = products;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFromWishlist(ProductModel product) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return;

      setState(() => _wishlistProducts.removeWhere((p) => p.id == product.id));
      await _wishlistService.removeFromWishlist(userId: userId, productId: product.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed from wishlist'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      await _loadWishlist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: ${e.toString()}'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _clearWishlist() async {
    if (_wishlistProducts.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Wishlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
        content: Text('Are you sure you want to remove all items from your wishlist?', style: TextStyle(color: AppColors.getTextMuted(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.getTextMuted(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final userId = _authService.currentUserId;
    if (userId == null) return;

    final productsToRemove = List<ProductModel>.from(_wishlistProducts);
    setState(() => _wishlistProducts.clear());

    try {
      for (final product in productsToRemove) {
        await _wishlistService.removeFromWishlist(userId: userId, productId: product.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wishlist cleared'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() => _wishlistProducts = productsToRemove);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear wishlist'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _addToCart(ProductModel product) async {
    setState(() => _addingToCartId = product.id);
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('You must be logged in');

      await _cartService.addToCart(userId: userId, productId: product.id);
      setState(() {
        _cartItems.add(product.id);
        _addingToCartId = null;
      });

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
        setState(() => _addingToCartId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: ${e.toString()}'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  String _formatPrice(double price) => '₦${NumberFormat("#,##0", "en_US").format(price)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getCardBackground(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(context)),
        title: Text('My Wishlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),
        ),
        actions: _wishlistProducts.isNotEmpty
            ? [
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.errorRed, size: 22),
                  onPressed: _clearWishlist,
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? Center(child: UniHubLoader(size: 80))
          : _wishlistProducts.isEmpty
              ? NoProductsEmptyState(
                  message: 'Your Wishlist is Empty',
                  subtitle: 'Start adding items you love!',
                  icon: Icons.favorite_border,
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.58,
                  ),
                  itemCount: _wishlistProducts.length,
                  itemBuilder: (context, index) {
                    final product = _wishlistProducts[index];
                    return WishlistProductCard(
                      product: product,
                      isInCart: _cartItems.contains(product.id),
                      isAddingToCart: _addingToCartId == product.id,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: product)),
                      ),
                      onRemove: () => _removeFromWishlist(product),
                      onAddToCart: () => _addToCart(product),
                    );
                  },
                ),
    );
  }
}

class WishlistProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isInCart;
  final bool isAddingToCart;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onAddToCart;

  const WishlistProductCard({
    required this.product,
    required this.isInCart,
    required this.isAddingToCart,
    required this.onTap,
    required this.onRemove,
    required this.onAddToCart,
  });

  String _formatPrice(double price) => '₦${NumberFormat("#,##0", "en_US").format(price)}';

  Widget _buildRatingStars(BuildContext context, {double? rating, double size = 10}) {
    final displayRating = rating ?? 0.0;
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
        Text('${displayRating.toStringAsFixed(1)}', style: TextStyle(fontSize: size - 2, color: AppColors.getTextMuted(context), fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
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
                      imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.getBackground(context),
                        child: Icon(Icons.image, color: AppColors.getTextMuted(context)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.getBackground(context),
                        child: Icon(Icons.shopping_bag_outlined, size: 50, color: AppColors.primaryOrange.withOpacity(0.3)),
                      ),
                    ),
                  ),
                  if (product.hasDiscount || product.discountPercentage != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(6)),
                        child: Text('-${product.discountPercentage ?? ((product.originalPrice! - product.price) / product.originalPrice! * 100).round()}%', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.getCardBackground(context).withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.favorite, color: Colors.red, size: 15),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onAddToCart,
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
                    style: TextStyle(fontSize: 13, color: AppColors.getTextPrimary(context), fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatPrice(product.price),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                      ),
                      if (product.hasDiscount && product.originalPrice != null) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _formatPrice(product.originalPrice!),
                            style: TextStyle(fontSize: 10, color: AppColors.getTextMuted(context), decoration: TextDecoration.lineThrough),
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
                  _buildRatingStars(context, rating: product.averageRating, size: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}