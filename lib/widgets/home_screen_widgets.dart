// home_screen_widgets.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/product_model.dart';
import '../models/university_category_models.dart';
import '../widgets/empty_states.dart';
import '../screens/category_products_screen.dart';
import '../services/category_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ============= HEADER DELEGATE =============
class CombinedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double statusBarHeight;
  final String selectedCampus;
  final String selectedState;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;
  final VoidCallback onCartTap;
  final VoidCallback onNotificationTap;
  static const double headerHeight = 114.0;

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
      color: AppColors.getCardBackground(context),
      child: Column(
        children: [
          SizedBox(height: statusBarHeight),
          Container(
            height: headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onLocationTap,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, size: 16, color: AppColors.primaryOrange),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$selectedCampus, $selectedState',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.getTextMuted(context)),
                          ],
                        ),
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
                      child: Text('UniHub', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.favorite_border, color: AppColors.getTextPrimary(context), size: 22),
                            onPressed: onCartTap,
                            padding: EdgeInsets.all(8),
                            constraints: BoxConstraints(),
                          ),
                          Stack(
                            children: [
                              IconButton(
                                icon: Icon(Icons.notifications_outlined, color: AppColors.getTextPrimary(context), size: 22),
                                onPressed: onNotificationTap,
                                padding: EdgeInsets.all(8),
                                constraints: BoxConstraints(),
                              ),
                              Positioned(right: 6, top: 6, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primaryOrange, shape: BoxShape.circle))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                GestureDetector(
                  onTap: onSearchTap,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.getBackground(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 12),
                        Icon(Icons.search, color: AppColors.getTextMuted(context), size: 18),
                        SizedBox(width: 8),
                        Text('Search products...', style: TextStyle(color: AppColors.getTextMuted(context), fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(CombinedHeaderDelegate oldDelegate) => true;
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        color: AppColors.getCardBackground(context),
        child: Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5))),
          child: _tabBar,
        ),
      );
  @override
  bool shouldRebuild(SliverAppBarDelegate oldDelegate) => true;
}

// ============= CATEGORIES SECTION =============
class CategoriesDirectory extends StatefulWidget {
  final String? selectedUniversityId;
  final String selectedState;
  const CategoriesDirectory({super.key, required this.selectedUniversityId, required this.selectedState});
  @override
  State<CategoriesDirectory> createState() => _CategoriesDirectoryState();
}

class _CategoriesDirectoryState extends State<CategoriesDirectory> {
  final CategoryService _categoryService = CategoryService();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _categoryService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _getCategoryColor(String name) {
    final colors = {
      'electronics': Color(0xFF4A90E2), 'phones & tablets': Color(0xFF4A90E2),
      'clothes': Color(0xFFE94B3C), 'fashion & clothing': Color(0xFFE94B3C),
      'shoes': Color(0xFF6B4CE6), 'footwear': Color(0xFF6B4CE6),
      'books & stationery': Color(0xFF50C878), 'books': Color(0xFF50C878),
      'home & living': Color(0xFFFF6B6B), 'utensils': Color(0xFF95E1D3),
      'accessories': Color(0xFFFFA07A), 'beauty': Color(0xFFFF69B4),
      'sports & fitness': Color(0xFF32CD32), 'feed': Color(0xFFFFD700),
    };
    return colors[name.toLowerCase()] ?? Color(0xFF9B59B6);
  }

  IconData _getCategoryIcon(String name) {
    final icons = {
      'electronics': Icons.devices, 'phones & tablets': Icons.devices,
      'clothes': Icons.checkroom, 'fashion & clothing': Icons.checkroom,
      'shoes': Icons.shopping_bag, 'footwear': Icons.shopping_bag,
      'books & stationery': Icons.book, 'books': Icons.book,
      'home & living': Icons.home, 'utensils': Icons.restaurant,
      'accessories': Icons.watch, 'beauty': Icons.face,
      'sports & fitness': Icons.fitness_center, 'feed': Icons.pets,
    };
    return icons[name.toLowerCase()] ?? Icons.category;
  }

  Widget _buildFallbackIcon(String name) {
    final color = _getCategoryColor(name);
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)])),
      child: Center(child: Icon(_getCategoryIcon(name), color: Colors.white, size: 26)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerWidget(
              child: Container(
                height: 16,
                width: 120,
                decoration: BoxDecoration(
                  color: AppColors.getTextMuted(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              itemCount: 6,
              itemBuilder: (context, index) => Container(
                width: 80,
                margin: EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    ShimmerWidget(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.getTextMuted(context).withOpacity(0.3),
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    ShimmerWidget(
                      child: Container(
                        height: 10,
                        width: 60,
                        decoration: BoxDecoration(
                          color: AppColors.getTextMuted(context).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_categories.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Shop by Category', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)))),
        SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final name = category['name'] as String;
              final iconUrl = category['icon_url'] as String?;

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryProductsScreen(categoryId: category['id'] as String, categoryName: name, universityId: widget.selectedUniversityId, state: widget.selectedState))),
                child: Container(
                  width: 80,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3), width: 1.5),
                        ),
                        child: ClipOval(
                          child: iconUrl != null && iconUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: iconUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: _getCategoryColor(name).withOpacity(0.1), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _getCategoryColor(name)))),
                                  errorWidget: (context, url, error) => _buildFallbackIcon(name),
                                )
                              : _buildFallbackIcon(name),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
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

  @override
  Widget build(BuildContext context) {
    final location = selectedCampus != 'University' ? selectedCampus : selectedState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.local_fire_department, color: AppColors.primaryOrange, size: 22),
              SizedBox(width: 8),
              Text('Trending in $location', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
            ],
          ),
        ),
        SizedBox(height: 10),
        SizedBox(
          height: 240,
          child: isLoadingProducts
              ? HorizontalSkeleton(width: 135)
              : featuredProducts.isEmpty
                  ? Center(child: Text('No trending products yet', style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context))))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 16),
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

  @override
  Widget build(BuildContext context) {
    final discount = product.discountPercentage ?? ((product.originalPrice! - product.price) / product.originalPrice! * 100).round();
    final displayRating = product.averageRating ?? 0.0;
    final fullStars = displayRating.floor();
    final hasHalfStar = (displayRating - fullStars) >= 0.5;

    return Container(
      width: isHero ? 150 : 135,
      margin: EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHero ? AppColors.primaryOrange.withOpacity(0.5) : AppColors.getBorder(context).withOpacity(0.3), width: isHero ? 1.5 : 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image',
                    height: isHero ? 125 : 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(height: isHero ? 125 : 110, color: AppColors.getBackground(context)),
                    errorWidget: (context, url, error) => Container(height: isHero ? 125 : 110, color: AppColors.getBackground(context), child: Icon(Icons.image, color: AppColors.getTextMuted(context))),
                  ),
                ),
                if (product.hasDiscount || product.discountPercentage != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(6)),
                      child: Text('-$discount%', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (isHero)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: Color(0xFF3B82F6), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          Icon(Icons.whatshot, color: Colors.white, size: 9),
                          SizedBox(width: 2),
                          Text('HOT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: GestureDetector(
                    onTap: onToggleFavorite,
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(color: AppColors.getCardBackground(context).withOpacity(0.95), shape: BoxShape.circle),
                      child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : AppColors.getTextMuted(context), size: 13),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onToggleCart,
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(color: isInCart ? AppColors.primaryOrange : AppColors.getCardBackground(context).withOpacity(0.95), shape: BoxShape.circle),
                      child: isAddingToCart
                          ? SizedBox(width: 13, height: 13, child: CircularProgressIndicator(color: isInCart ? Colors.white : AppColors.primaryOrange, strokeWidth: 2))
                          : Icon(isInCart ? Icons.check : Icons.add_shopping_cart, color: isInCart ? Colors.white : AppColors.primaryOrange, size: 13),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(_formatPrice(product.price), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                      if (product.hasDiscount && product.originalPrice != null) ...[
                        SizedBox(width: 4),
                        Flexible(child: Text(_formatPrice(product.originalPrice!), style: TextStyle(fontSize: 9, color: AppColors.getTextMuted(context), decoration: TextDecoration.lineThrough), overflow: TextOverflow.ellipsis)),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.visibility, size: 9, color: AppColors.getTextMuted(context)),
                      SizedBox(width: 3),
                      Text('$activeViewers viewing', style: TextStyle(fontSize: 8, color: AppColors.getTextMuted(context))),
                    ],
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        if (i < fullStars) return Icon(Icons.star, size: 9, color: AppColors.primaryOrange);
                        if (i == fullStars && hasHalfStar) return Icon(Icons.star_half, size: 9, color: AppColors.primaryOrange);
                        return Icon(Icons.star_border, size: 9, color: AppColors.getBorder(context));
                      }),
                      SizedBox(width: 3),
                      Text('${displayRating.toStringAsFixed(1)}', style: TextStyle(fontSize: 7, color: AppColors.getTextMuted(context), fontWeight: FontWeight.w500)),
                    ],
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

// ============= SPECIAL DEALS GRID =============
class SpecialDealsGrid extends StatefulWidget {
  final Function(String dealType, String dealTitle) onDealTap;
  const SpecialDealsGrid({super.key, required this.onDealTap});
  @override
  State<SpecialDealsGrid> createState() => _SpecialDealsGridState();
}

class _SpecialDealsGridState extends State<SpecialDealsGrid> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _deals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeals();
  }

  Future<void> _loadDeals() async {
    try {
      final response = await _supabase.from('special_deals').select('*').eq('is_active', true).order('sort_order');
      _deals = (response is List && response.isNotEmpty) ? List<Map<String, dynamic>>.from(response) : _getFallbackDeals();
    } catch (e) {
      _deals = _getFallbackDeals();
    }
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _getFallbackDeals() => [
        {'name': 'Flash Sales', 'deal_type': 'flash_sale', 'icon_name': 'bolt', 'color': '#FF6B35', 'image_url': 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400'},
        {'name': 'Discounted', 'deal_type': 'discounted', 'icon_name': 'local_offer', 'color': '#10B981', 'image_url': 'https://images.unsplash.com/photo-1607083206325-caf1edba7a0f?w=400'},
        {'name': 'Last Chance', 'deal_type': 'last_chance', 'icon_name': 'access_time', 'color': '#EF4444', 'image_url': 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400'},
        {'name': 'Under ₦10k', 'deal_type': 'under_10k', 'icon_name': 'attach_money', 'color': '#3B82F6', 'image_url': 'https://images.unsplash.com/photo-1472851294608-062f824d29cc?w=400'},
        {'name': 'Top Deals', 'deal_type': 'top_deals', 'icon_name': 'star', 'color': '#F59E0B', 'image_url': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400'},
        {'name': 'New This Week', 'deal_type': 'new_this_week', 'icon_name': 'fiber_new', 'color': '#8B5CF6', 'image_url': 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=400'},
      ];

  IconData _getIcon(String name) {
    final icons = {'bolt': Icons.bolt, 'local_offer': Icons.local_offer, 'access_time': Icons.access_time, 'attach_money': Icons.attach_money, 'star': Icons.star, 'fiber_new': Icons.fiber_new};
    return icons[name] ?? Icons.local_offer;
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (e) {
      return AppColors.primaryOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange));
    if (_deals.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.35),
        itemCount: _deals.length,
        itemBuilder: (context, index) {
          final deal = _deals[index];
          return SpecialDealCard(
            icon: _getIcon(deal['icon_name']),
            title: deal['name'],
            color: _parseColor(deal['color']),
            imageUrl: deal['image_url'] ?? '',
            onTap: () => widget.onDealTap(deal['deal_type'], deal['name']),
          );
        },
      ),
    );
  }
}

class SpecialDealCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String imageUrl;
  final VoidCallback onTap;

  const SpecialDealCard({super.key, required this.icon, required this.title, required this.color, required this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: color.withOpacity(0.2)),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.1)])),
                  child: Center(child: Icon(icon, color: Colors.white, size: 28)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0), Colors.black.withOpacity(0.7)])),
                child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
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
      padding: EdgeInsets.all(8),
      physics: AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.58),
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

  @override
  Widget build(BuildContext context) {
    final displayRating = product.averageRating ?? 0.0;
    final fullStars = displayRating.floor();
    final hasHalfStar = (displayRating - fullStars) >= 0.5;

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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AppColors.getBackground(context)),
                      errorWidget: (context, url, error) => Container(color: AppColors.getBackground(context), child: Icon(Icons.image, color: AppColors.getTextMuted(context))),
                    ),
                  ),
                  if (product.hasDiscount || product.discountPercentage != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(6)),
                        child: Text('-${product.discountPercentage ?? ((product.originalPrice! - product.price) / product.originalPrice! * 100).round()}%', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: onToggleFavorite,
                      child: Container(
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(color: AppColors.getCardBackground(context).withOpacity(0.9), shape: BoxShape.circle),
                        child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : AppColors.getTextMuted(context), size: 15),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onToggleCart,
                      child: Container(
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(color: isInCart ? AppColors.primaryOrange : AppColors.getCardBackground(context).withOpacity(0.9), shape: BoxShape.circle),
                        child: isAddingToCart
                            ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: isInCart ? Colors.white : AppColors.primaryOrange, strokeWidth: 2))
                            : Icon(isInCart ? Icons.check : Icons.add_shopping_cart, color: isInCart ? Colors.white : AppColors.primaryOrange, size: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)), maxLines: 2, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(_formatPrice(product.price), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                      if (product.hasDiscount && product.originalPrice != null) ...[
                        SizedBox(width: 4),
                        Flexible(child: Text(_formatPrice(product.originalPrice!), style: TextStyle(fontSize: 10, color: AppColors.getTextMuted(context), decoration: TextDecoration.lineThrough), overflow: TextOverflow.ellipsis)),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 10, color: AppColors.primaryOrange),
                      SizedBox(width: 2),
                      Text(product.universityAbbr ?? product.universityName ?? 'N/A', style: TextStyle(fontSize: 9, color: AppColors.getTextMuted(context), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        if (i < fullStars) return Icon(Icons.star, size: 10, color: AppColors.primaryOrange);
                        if (i == fullStars && hasHalfStar) return Icon(Icons.star_half, size: 10, color: AppColors.primaryOrange);
                        return Icon(Icons.star_border, size: 10, color: AppColors.getBorder(context));
                      }),
                      SizedBox(width: 3),
                      Text('${displayRating.toStringAsFixed(1)}', style: TextStyle(fontSize: 8, color: AppColors.getTextMuted(context), fontWeight: FontWeight.w500)),
                    ],
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

// ============= SKELETONS =============
class ProductGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: EdgeInsets.all(8),
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.58),
        itemCount: 8,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
          ),
          child: Column(
            children: [
              Expanded(child: ShimmerWidget(child: Container(color: AppColors.getBackground(context)))),
              Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    ShimmerWidget(
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.getBackground(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    ShimmerWidget(
                      child: Container(
                        height: 12,
                        width: 70,
                        decoration: BoxDecoration(
                          color: AppColors.getBackground(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class HorizontalSkeleton extends StatelessWidget {
  final double width;
  const HorizontalSkeleton({required this.width});
  @override
  Widget build(BuildContext context) => ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (context, index) => Container(
          width: width,
          margin: EdgeInsets.only(right: 10),
          child: ShimmerWidget(child: Container(decoration: BoxDecoration(color: AppColors.getCardBackground(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5)))),
        ),
      );
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
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 1500))..repeat();
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
            colors: [AppColors.getBackground(context), AppColors.getCardBackground(context), AppColors.getBackground(context)],
            stops: [_controller.value - 0.3, _controller.value, _controller.value + 0.3],
          ).createShader(bounds),
          child: widget.child,
        ),
      );
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
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Select university — $stateDisplayName', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                  if (!hasState) ...[SizedBox(height: 6), Text('Please set your state first', style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context)))],
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),
            Expanded(
              child: filteredUniversities.isEmpty
                  ? Center(
                      child: isLoadingData
                          ? CircularProgressIndicator(color: AppColors.primaryOrange)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.school_outlined, size: 48, color: AppColors.getTextMuted(context)),
                                SizedBox(height: 12),
                                Text('No universities found in this state', style: TextStyle(color: AppColors.getTextMuted(context))),
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
                          leading: Icon(Icons.school, color: isSelected ? AppColors.primaryOrange : AppColors.getTextMuted(context)),
                          title: Text(uni.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppColors.getTextPrimary(context))),
                          subtitle: Text(uni.shortName, style: TextStyle(color: AppColors.getTextMuted(context), fontSize: 12)),
                          trailing: isSelected ? Icon(Icons.check_circle, color: AppColors.primaryOrange) : null,
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