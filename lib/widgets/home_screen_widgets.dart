import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/product_model.dart';
import '../models/university_category_models.dart';
import '../widgets/empty_states.dart';
import '../screens/category_products_screen.dart';

// ============= HEADER DELEGATE =============
class CombinedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double statusBarHeight;
  final String selectedCampus;
  final String selectedState;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;
  final VoidCallback onCartTap;
  final VoidCallback onNotificationTap;
  static const double headerHeight = 110.0;

  CombinedHeaderDelegate({
    required this.statusBarHeight,
    required this.selectedCampus,
    required this.selectedState,
    required this.onLocationTap,
    required this.onSearchTap,
    required this.onCartTap,
    required this.onNotificationTap,
  });

  @override
  double get minExtent => statusBarHeight + headerHeight;
  @override
  double get maxExtent => statusBarHeight + headerHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(height: statusBarHeight),
          Container(
            height: headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onLocationTap,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, size: 16, color: Color(0xFFFF6B35)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$selectedCampus, $selectedState',
                                  style: AppTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textDark),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text('UniHub', style: AppTextStyles.heading.copyWith(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(icon: Icon(Icons.favorite_border, color: Colors.black, size: 22), onPressed: onCartTap, padding: EdgeInsets.all(8), constraints: BoxConstraints()),
                          Stack(
                            children: [
                              IconButton(icon: Icon(Icons.notifications_outlined, color: Colors.black, size: 22), onPressed: onNotificationTap, padding: EdgeInsets.all(8), constraints: BoxConstraints()),
                              Positioned(right: 6, top: 6, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF6B35), shape: BoxShape.circle))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onSearchTap,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(color: Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(Icons.search, color: Colors.grey.shade600, size: 18),
                        const SizedBox(width: 8),
                        Text('Search products...', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(CombinedHeaderDelegate oldDelegate) =>
      statusBarHeight != oldDelegate.statusBarHeight ||
      selectedCampus != oldDelegate.selectedCampus ||
      selectedState != oldDelegate.selectedState;
}

// ============= TAB BAR DELEGATE =============
class SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: AppColors.white, child: _tabBar);
  @override
  bool shouldRebuild(SliverAppBarDelegate oldDelegate) => false;
}

// ============= CATEGORIES SECTION =============
class CategoriesSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ShimmerWidget(child: Container(height: 18, width: 140, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))))),
        const SizedBox(height: 12),
        SizedBox(height: 110, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 6), itemCount: 6, itemBuilder: (context, index) => Container(width: 90, margin: const EdgeInsets.symmetric(horizontal: 6), child: Column(children: [ShimmerWidget(child: Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade300))), const SizedBox(height: 8), ShimmerWidget(child: Container(height: 12, width: 70, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))))])))),
      ],
    );
  }
}

class CategoriesErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const CategoriesErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600, size: 32),
            const SizedBox(height: 8),
            Text('Failed to load categories', style: AppTextStyles.subheading.copyWith(color: Colors.red.shade800, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Please check your connection and try again', style: AppTextStyles.body.copyWith(fontSize: 12, color: Colors.red.shade700), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
          ],
        ),
      ),
    );
  }
}

class CategoriesDirectory extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedUniversityId;
  final String selectedState;

  const CategoriesDirectory({
    required this.categories,
    required this.selectedUniversityId,
    required this.selectedState,
  });

  static final List<Map<String, dynamic>> _categoryVisuals = [
    {'key': 'fashion_clothing', 'name': 'Fashion & Clothing', 'imageUrl': 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=200', 'icon': Icons.checkroom},
    {'key': 'footwear', 'name': 'Shoes', 'imageUrl': 'https://images.unsplash.com/photo-1560769629-975ec94e6a86?w=200', 'icon': Icons.shopping_bag},
    {'key': 'electronics', 'name': 'Electronics', 'imageUrl': 'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=200', 'icon': Icons.devices},
    {'key': 'books_stationery', 'name': 'Books & Stationery', 'imageUrl': 'https://images.unsplash.com/photo-1495446815901-a7297e633e8d?w=200', 'icon': Icons.menu_book},
    {'key': 'beauty_personal_care', 'name': 'Beauty & Personal Care', 'imageUrl': 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=200', 'icon': Icons.spa},
    {'key': 'kitchen_utensils', 'name': 'Kitchen & Utensils', 'imageUrl': 'https://images.unsplash.com/photo-1556911220-bff31c812dba?w=200', 'icon': Icons.restaurant},
    {'key': 'sports_fitness', 'name': 'Sports & Fitness', 'imageUrl': 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=200', 'icon': Icons.sports_basketball},
    {'key': 'accessories', 'name': 'Accessories', 'imageUrl': 'https://images.unsplash.com/photo-1523293182086-7651a899d37f?w=200', 'icon': Icons.watch},
    {'key': 'home_decor', 'name': 'Home Decor', 'imageUrl': 'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=200', 'icon': Icons.home},
    {'key': 'phones_tablets', 'name': 'Phones & Tablets', 'imageUrl': 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=200', 'icon': Icons.phone_android},
  ];

  static final Map<String, String> _categoryNameMap = {
    'fashion_clothing': 'Clothes',
    'footwear': 'Shoes',
    'electronics': 'Electronics',
    'books_stationery': 'Books & Stationery',
    'beauty_personal_care': 'Beauty',
    'kitchen_utensils': 'Utensils',
    'sports_fitness': 'Sports & Fitness',
    'accessories': 'Accessories',
    'home_decor': 'Home & Living',
    'phones_tablets': 'Phones & Tablets',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Shop by Category', style: AppTextStyles.heading.copyWith(fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categoryVisuals.length,
            itemBuilder: (context, index) {
              final categoryData = _categoryVisuals[index];
              final targetName = _categoryNameMap[categoryData['key']];
              
              CategoryModel? matchedCategory;
              if (targetName != null) {
                try {
                  matchedCategory = categories.firstWhere((cat) => cat.name == targetName);
                } catch (_) {}
              }
              
              return GestureDetector(
                onTap: () {
                  if (matchedCategory != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryProductsScreen(
                          categoryId: matchedCategory!.id,
                          categoryName: matchedCategory.name,
                          universityId: selectedUniversityId,
                          state: selectedState,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Category "${categoryData['name']}" not available yet'), duration: const Duration(seconds: 2)),
                    );
                  }
                },
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Color(0xFFFF6B35).withOpacity(matchedCategory != null ? 0.3 : 0.1), width: 2),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: categoryData['imageUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppColors.background, child: Icon(categoryData['icon'], color: Color(0xFFFF6B35).withOpacity(matchedCategory != null ? 1.0 : 0.3), size: 28)),
                            errorWidget: (context, url, error) => Container(color: AppColors.background, child: Icon(categoryData['icon'], color: Color(0xFFFF6B35).withOpacity(matchedCategory != null ? 1.0 : 0.3), size: 28)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(categoryData['name'], style: AppTextStyles.body.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: matchedCategory != null ? AppColors.textDark : AppColors.textLight), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============= TRENDING SECTION =============
class TrendingSection extends StatelessWidget {
  final String selectedCampus;
  final String selectedState;
  final List<ProductModel> featuredProducts;
  final bool isLoadingProducts;
  final Set<String> favorites;
  final Set<String> cart;
  final String? isAddingToCartId;
  final Map<String, int> viewerCounts;
  final Function(ProductModel) onProductTap;
  final Function(String) onToggleFavorite;
  final Function(ProductModel) onToggleCart;

  const TrendingSection({
    required this.selectedCampus,
    required this.selectedState,
    required this.featuredProducts,
    required this.isLoadingProducts,
    required this.favorites,
    required this.cart,
    required this.isAddingToCartId,
    required this.viewerCounts,
    required this.onProductTap,
    required this.onToggleFavorite,
    required this.onToggleCart,
  });

  String _getFlashSaleCountdown(ProductModel product) {
    if (!product.isFlashSaleActive) return '';
    final remaining = product.flashSaleTimeRemaining;
    if (remaining == null) return '';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final location = selectedCampus != 'University' ? selectedCampus : selectedState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.8, end: 1.2),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                builder: (context, double scale, child) => Transform.scale(scale: scale, child: Icon(Icons.local_fire_department, color: Color(0xFFFF6B35), size: 24)),
                onEnd: () {},
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trending in $location', style: AppTextStyles.heading.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                    if (featuredProducts.isNotEmpty && featuredProducts.first.isFlashSaleActive)
                      Text('Flash Sale ends in ${_getFlashSaleCountdown(featuredProducts.first)}', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 260,
          child: isLoadingProducts
              ? HorizontalSkeleton(width: 145)
              : featuredProducts.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No trending products yet', style: AppTextStyles.body.copyWith(color: AppColors.textLight))))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: featuredProducts.length > 12 ? 12 : featuredProducts.length,
                      itemBuilder: (context, index) => TrendingProductCard(
                        product: featuredProducts[index],
                        isHero: index == 0,
                        isFavorite: favorites.contains(featuredProducts[index].id),
                        isInCart: cart.contains(featuredProducts[index].id),
                        isAddingToCart: isAddingToCartId == featuredProducts[index].id,
                        activeViewers: viewerCounts[featuredProducts[index].id] ?? 0,
                        onTap: () => onProductTap(featuredProducts[index]),
                        onToggleFavorite: () => onToggleFavorite(featuredProducts[index].id),
                        onToggleCart: () => onToggleCart(featuredProducts[index]),
                      ),
                    ),
        ),
      ],
    );
  }
}

class TrendingProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isHero;
  final bool isFavorite;
  final bool isInCart;
  final bool isAddingToCart;
  final int activeViewers;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleCart;

  const TrendingProductCard({
    required this.product,
    required this.isHero,
    required this.isFavorite,
    required this.isInCart,
    required this.isAddingToCart,
    required this.activeViewers,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onToggleCart,
  });

  String _formatPrice(double price) => '₦${NumberFormat("#,##0", "en_US").format(price)}';

  Widget _buildRatingStars({required ProductModel product, double size = 9}) {
    final displayRating = product.averageRating ?? 0.0;
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

  @override
  Widget build(BuildContext context) {
    final discount = product.discountPercentage ?? ((product.originalPrice! - product.price) / product.originalPrice! * 100).round();
    final savings = product.originalPrice != null ? product.originalPrice! - product.price : 0.0;

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.95, end: 1.0),
      duration: Duration(milliseconds: 300 + (isHero ? 200 : 0)),
      curve: Curves.easeOut,
      builder: (context, double scale, child) => Transform.scale(
        scale: scale,
        child: Container(
          width: isHero ? 160 : 145,
          margin: EdgeInsets.only(right: 12, top: isHero ? 0 : 8, bottom: isHero ? 0 : 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: isHero ? Color(0xFFFF6B35).withOpacity(0.3) : Colors.black.withOpacity(0.08), blurRadius: isHero ? 12 : 8, spreadRadius: isHero ? 2 : 0)],
            border: isHero ? Border.all(color: Color(0xFFFF6B35).withOpacity(0.4), width: 2) : null,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image',
                        height: isHero ? 135 : 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(height: isHero ? 135 : 120, color: AppColors.background, child: Icon(Icons.image, color: AppColors.textLight.withOpacity(0.5))),
                        errorWidget: (context, url, error) => Container(height: isHero ? 135 : 120, color: AppColors.background, child: Icon(Icons.shopping_bag_outlined, size: 40, color: Color(0xFFFF6B35).withOpacity(0.3))),
                      ),
                    ),
                    if (product.hasDiscount || product.discountPercentage != null)
                      Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 6)]), child: Text('-$discount%', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                    if (isHero)
                      Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)]), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(Icons.whatshot, color: Colors.white, size: 10), SizedBox(width: 2), Text('HOT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))]))),
                    Positioned(bottom: 8, left: 8, child: GestureDetector(onTap: onToggleFavorite, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]), child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey.shade600, size: 14)))),
                    Positioned(bottom: 8, right: 8, child: GestureDetector(onTap: onToggleCart, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isInCart ? Color(0xFFFF6B35) : Colors.white.withOpacity(0.95), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]), child: isAddingToCart ? Container(width: 14, height: 14, padding: const EdgeInsets.all(2.0), child: CircularProgressIndicator(color: isInCart ? Colors.white : Color(0xFFFF6B35), strokeWidth: 2)) : Icon(isInCart ? Icons.check : Icons.add_shopping_cart, color: isInCart ? Colors.white : Color(0xFFFF6B35), size: 14)))),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(_formatPrice(product.price), style: AppTextStyles.price.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                          const SizedBox(width: 4),
                          if (product.hasDiscount && product.originalPrice != null) Flexible(child: Text(_formatPrice(product.originalPrice!), style: TextStyle(fontSize: 9, color: AppColors.textLight, decoration: TextDecoration.lineThrough), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      if (savings > 0) ...[const SizedBox(height: 3), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(5)), child: Text('Save ${_formatPrice(savings)}', style: TextStyle(color: Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.w600)))],
                      const SizedBox(height: 4),
                      Row(children: [Icon(Icons.visibility, size: 9, color: AppColors.textLight), const SizedBox(width: 3), Text('$activeViewers viewing', style: TextStyle(fontSize: 8, color: AppColors.textLight))]),
                      const SizedBox(height: 2),
                      _buildRatingStars(product: product, size: 9),
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

// ============= SPECIAL DEALS GRID =============
class SpecialDealsGrid extends StatelessWidget {
  final Function(String) onDealTap;

  const SpecialDealsGrid({required this.onDealTap});

  static final List<Map<String, dynamic>> _specialDeals = [
    {'icon': Icons.bolt, 'title': 'Flash Sales', 'subtitle': 'Limited time!', 'color': Color(0xFFFF6B35), 'imageUrl': 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400'},
    {'icon': Icons.local_offer, 'title': 'Discounted', 'subtitle': 'Save big now', 'color': Color(0xFF10B981), 'imageUrl': 'https://images.unsplash.com/photo-1607083206325-caf1edba7a0f?w=400'},
    {'icon': Icons.access_time, 'title': 'Last Chance', 'subtitle': 'Almost gone!', 'color': Color(0xFFEF4444), 'imageUrl': 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400'},
    {'icon': Icons.attach_money, 'title': 'Under ₦10k', 'subtitle': 'Affordable!', 'color': Color(0xFF3B82F6), 'imageUrl': 'https://images.unsplash.com/photo-1472851294608-062f824d29cc?w=400'},
    {'icon': Icons.star, 'title': 'Top Deals', 'subtitle': 'Bestsellers', 'color': Color(0xFFF59E0B), 'imageUrl': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400'},
    {'icon': Icons.fiber_new, 'title': 'New This Week', 'subtitle': 'Fresh stock', 'color': Color(0xFF8B5CF6), 'imageUrl': 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=400'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.35),
        itemCount: _specialDeals.length,
        itemBuilder: (context, index) {
          final deal = _specialDeals[index];
          return SpecialDealCard(icon: deal['icon'], title: deal['title'], subtitle: deal['subtitle'], color: deal['color'], imageUrl: deal['imageUrl'], onTap: () => onDealTap(deal['title']));
        },
      ),
    );
  }
}

class SpecialDealCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String imageUrl;
  final VoidCallback onTap;

  const SpecialDealCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3), width: 1.5), boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned.fill(child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: color.withOpacity(0.1)), errorWidget: (context, url, error) => Container(color: color.withOpacity(0.1)))),
              Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.85), color.withOpacity(0.65)], begin: Alignment.topLeft, end: Alignment.bottomRight)))),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))]), child: Icon(icon, color: color, size: 22)),
                  const SizedBox(height: 8),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(title, style: AppTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)]), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)]), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============= PRODUCT GRID PAGE =============
class ProductGridPage extends StatelessWidget {
  final List<ProductModel> products;
  final bool isLoading;
  final String emptyMessage;
  final String emptySubtitle;
  final Set<String> favorites;
  final Set<String> cart;
  final String? isAddingToCartId;
  final Map<String, int> viewerCounts;
  final Function(ProductModel) onProductTap;
  final Function(String) onToggleFavorite;
  final Function(ProductModel) onToggleCart;

  const ProductGridPage({
    required this.products,
    required this.isLoading,
    required this.emptyMessage,
    required this.emptySubtitle,
    required this.favorites,
    required this.cart,
    required this.isAddingToCartId,
    required this.viewerCounts,
    required this.onProductTap,
    required this.onToggleFavorite,
    required this.onToggleCart,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return ProductGridSkeleton();
    if (products.isEmpty) return NoProductsEmptyState(message: emptyMessage, subtitle: emptySubtitle);

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.58),
      itemCount: products.length,
      itemBuilder: (context, index) => GridProductCard(
        product: products[index],
        isFavorite: favorites.contains(products[index].id),
        isInCart: cart.contains(products[index].id),
        isAddingToCart: isAddingToCartId == products[index].id,
        activeViewers: viewerCounts[products[index].id] ?? 0,
        onTap: () => onProductTap(products[index]),
        onToggleFavorite: () => onToggleFavorite(products[index].id),
        onToggleCart: () => onToggleCart(products[index]),
      ),
    );
  }
}

class GridProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isFavorite;
  final bool isInCart;
  final bool isAddingToCart;
  final int activeViewers;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleCart;

  const GridProductCard({
    required this.product,
    required this.isFavorite,
    required this.isInCart,
    required this.isAddingToCart,
    required this.activeViewers,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onToggleCart,
  });

  String _formatPrice(double price) => '₦${NumberFormat("#,##0", "en_US").format(price)}';

  Widget _buildRatingStars({required ProductModel product, double size = 10}) {
    final displayRating = product.averageRating ?? 0.0;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
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
                    Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: Color(0xFFFF6B35), borderRadius: BorderRadius.circular(8)), child: Text('-${product.discountPercentage ?? ((product.originalPrice! - product.price) / product.originalPrice! * 100).round()}%', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                  Positioned(top: 8, left: 8, child: GestureDetector(onTap: onToggleFavorite, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle), child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey.shade600, size: 16)))),
                  Positioned(bottom: 8, right: 8, child: GestureDetector(onTap: onToggleCart, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isInCart ? Color(0xFFFF6B35) : Colors.white.withOpacity(0.9), shape: BoxShape.circle), child: isAddingToCart ? Container(width: 16, height: 16, padding: const EdgeInsets.all(2.0), child: CircularProgressIndicator(color: isInCart ? Colors.white : Color(0xFFFF6B35), strokeWidth: 2)) : Icon(isInCart ? Icons.check : Icons.add_shopping_cart, color: isInCart ? Colors.white : Color(0xFFFF6B35), size: 16)))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(_formatPrice(product.price), style: AppTextStyles.price.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                      if (product.hasDiscount && product.originalPrice != null) ...[const SizedBox(width: 3), Flexible(child: Text(_formatPrice(product.originalPrice!), style: TextStyle(fontSize: 10, color: AppColors.textLight, decoration: TextDecoration.lineThrough), overflow: TextOverflow.ellipsis, maxLines: 1))],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 10, color: Color(0xFFFF6B35)),
                      const SizedBox(width: 2),
                      Text(
                        product.universityAbbr ?? product.universityName ?? 'N/A',
                        style: TextStyle(fontSize: 9, color: AppColors.textDark, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

// ============= SKELETONS =============
class ProductGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.58),
      itemCount: 8,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: ShimmerWidget(child: Container(width: double.infinity, color: Colors.grey[300])))),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerWidget(child: Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 6),
                  ShimmerWidget(child: Container(height: 14, width: 80, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 6),
                  ShimmerWidget(child: Container(height: 10, width: 120, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HorizontalSkeleton extends StatelessWidget {
  final double width;
  const HorizontalSkeleton({required this.width});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        width: width,
        margin: const EdgeInsets.only(right: 12),
        child: ShimmerWidget(child: Container(decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(14)))),
      ),
    );
  }
}

class ShimmerWidget extends StatefulWidget {
  final Widget child;
  const ShimmerWidget({required this.child});
  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: const [Color(0xFFE0E0E0), Color(0xFFF5F5F5), Color(0xFFE0E0E0)],
                  stops: [_controller.value - 0.3, _controller.value, _controller.value + 0.3])
              .createShader(bounds),
          child: widget.child));
}

// ============= CAMPUS SELECTOR =============
class CampusSelectorBottomSheet extends StatelessWidget {
  final List<UniversityModel> universities;
  final String? selectedUniversityId;
  final String selectedState;
  final bool isLoadingData;
  final Function(UniversityModel) onCampusChanged;

  const CampusSelectorBottomSheet({
    required this.universities,
    required this.selectedUniversityId,
    required this.selectedState,
    required this.isLoadingData,
    required this.onCampusChanged,
  });

  List<UniversityModel> _getFilteredUniversities() {
    if (selectedState.isEmpty || selectedState == 'State') return universities;
    return universities.where((u) => u.state.toLowerCase() == selectedState.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        final filteredUniversities = _getFilteredUniversities();
        final hasState = selectedState.isNotEmpty && selectedState != 'State';
        final stateDisplayName = hasState ? selectedState.toUpperCase() : 'Select State';

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Select university — $stateDisplayName', style: AppTextStyles.heading.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (!hasState) ...[
                    const SizedBox(height: 8),
                    Text('Please set your state first', style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textLight)),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filteredUniversities.isEmpty
                  ? Center(
                      child: isLoadingData
                          ? const CircularProgressIndicator()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.school_outlined, size: 64, color: AppColors.textLight.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                Text('No universities found in this state', style: AppTextStyles.body.copyWith(color: AppColors.textLight)),
                              ],
                            ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filteredUniversities.length,
                      itemBuilder: (context, index) {
                        final uni = filteredUniversities[index];
                        final isSelected = uni.id == selectedUniversityId;
                        return ListTile(
                          leading: Icon(Icons.school, color: isSelected ? Color(0xFFFF6B35) : AppColors.textLight),
                          title: Text(uni.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text(uni.shortName, style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                          trailing: isSelected ? Icon(Icons.check_circle, color: Color(0xFFFF6B35)) : null,
                          onTap: () => onCampusChanged(uni),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}