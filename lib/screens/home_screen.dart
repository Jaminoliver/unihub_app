import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:math';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/home_service.dart';
import '../services/product_service.dart';
import '../services/auth_service.dart';
import '../services/university_category_services.dart';
import '../services/cart_service.dart';
import '../models/product_model.dart';
import '../models/university_category_models.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/empty_states.dart';
import './product_details_screen.dart';
import './search_screen.dart';
import './category_products_screen.dart';

class HomeScreen extends StatefulWidget {
  final ScrollController? scrollController;
  const HomeScreen({super.key, this.scrollController});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  late ScrollController _scrollController;
  PageController? _adBannerController;
  
  final _homeService = HomeService();
  final _productService = ProductService();
  final _authService = AuthService();
  final CartService _cartService = CartService();
  final _universityService = UniversityService();
  final _categoryService = CategoryService();
  
  String _selectedCampus = 'University';
  String? _selectedUniversityId;
  String _selectedState = 'State';
  
  List<ProductModel> _allProducts = [];
  List<ProductModel> _featuredProducts = [];
  List<ProductModel> _topSellers = [];
  List<ProductModel> _recommendedProducts = [];
  List<ProductModel> _topInState = [];
  List<ProductModel> _lowestPriceProducts = [];
  List<UniversityModel> _universities = [];
  List<CategoryModel> _categories = [];
  List<Map<String, dynamic>> _recentPurchases = [];
  
  bool _isLoadingData = true;
  bool _isLoadingProducts = true;
  bool _categoriesError = false;
  
  final Set<String> _favorites = {};
  final Set<String> _cart = {};
  final Map<String, bool> _likes = {};
  final Map<String, int> _likeCounts = {};
  
  Timer? _adBannerTimer;
  Timer? _flashSaleTimer;
  int _currentAdPage = 0;
  int _viewingCount = 0;
  String? _isAddingToCartId;

  final List<Map<String, dynamic>> _adBanners = [
    {'title': 'New Collection', 'subtitle': 'Flash Sale Up to 40%\noff this weekend.', 'buttonText': 'Shop Now', 'gradient': [Color(0xFFFF6B35), Color(0xFFFF8C42)], 'icon': Icons.shopping_bag_outlined},
    {'title': 'AWOOF DEALS', 'subtitle': 'Get up to 70% OFF\non selected items!', 'buttonText': 'Grab Deals', 'gradient': [Color(0xFF1E3A8A), Color(0xFF3B82F6)], 'icon': Icons.local_offer},
    {'title': 'FLASH SALE', 'subtitle': 'Limited time offer\n50% OFF everything!', 'buttonText': 'Shop Now', 'gradient': [Color(0xFFFF6B35), Color(0xFFFD7E14)], 'icon': Icons.flash_on},
    {'title': 'MEGA DEALS', 'subtitle': 'Biggest discounts ever\nUP TO 80% OFF!', 'buttonText': 'Shop Deals', 'gradient': [Color(0xFF1E40AF), Color(0xFF2563EB)], 'icon': Icons.stars},
  ];

  final List<Map<String, dynamic>> _categoryVisuals = [
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pageController = PageController(initialPage: 0);
    _adBannerController = PageController(initialPage: 0);
    _scrollController = widget.scrollController ?? ScrollController();
    _startAdBannerAutoSlide();
    _startFlashSaleTimer();
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    if (widget.scrollController == null) _scrollController.dispose();
    _adBannerController?.dispose();
    _adBannerTimer?.cancel();
    _flashSaleTimer?.cancel();
    super.dispose();
  }

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  String _formatCount(int count) => count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}k' : count.toString();
  String _formatPrice(double price) => '₦${NumberFormat("#,##0", "en_US").format(price)}';

  Widget _buildRatingStars({double? rating, required int reviewCount, double size = 12}) {
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

  void _toggleLike(String productId) {
    setState(() {
      final currentLikeStatus = _likes[productId] ?? false;
      _likes[productId] = !currentLikeStatus;
      final currentCount = _likeCounts[productId] ?? 0;
      _likeCounts[productId] = currentLikeStatus ? currentCount - 1 : currentCount + 1;
    });
  }

  int _getLikeCount(String productId) => _likeCounts[productId] ?? (50 + (productId.hashCode % 200));
  
  List<UniversityModel> _getFilteredUniversities() {
    if (_selectedState.isEmpty || _selectedState == 'State') return _universities;
    return _universities.where((u) => u.state.toLowerCase() == _selectedState.toLowerCase()).toList();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoadingData = true);
    try {
      await Future.wait([_loadUniversities(), _loadCategories()]);
      await _refreshProductData();
    } catch (e) {
      debugPrint('Error initializing data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _loadUniversities() async {
    try {
      final universities = await _universityService.getAllUniversities();
      final userProfile = await _authService.getCurrentUserProfile();
      if (mounted && userProfile != null) {
        setState(() {
          _universities = universities;
          if (universities.isNotEmpty) {
            final userUniversity = universities.firstWhere((u) => u.id == userProfile.universityId, orElse: () => universities.first);
            _selectedUniversityId = userUniversity.id;
            _selectedCampus = userUniversity.shortName;
            _selectedState = userUniversity.state;
          }
        });
      } else if (mounted) {
        setState(() => _universities = universities);
      }
    } catch (e) {
      debugPrint('Error loading universities: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getAllCategories();
      if (mounted) setState(() { _categories = categories; _categoriesError = false; });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) setState(() => _categoriesError = true);
    }
  }

  Future<void> _refreshProductData() async {
    if (_selectedUniversityId == null) return;
    setState(() => _isLoadingProducts = true);
    try {
      await Future.wait([
        _loadAllProducts(), _loadFeaturedProducts(), _loadTopSellers(),
        _loadRecommendedProducts(), _loadTrendingActivity(), _loadRecentPurchases(), 
        _loadTopInState(), _loadLowestPriceProducts(),
      ]);
    } catch (e) {
      debugPrint('Error refreshing product data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadAllProducts() async {
    try {
      final products = await _productService.getProductsByState(state: _selectedState, priorityUniversityId: _selectedUniversityId, limit: 50);
      if (mounted) setState(() => _allProducts = products);
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
  }

  Future<void> _loadFeaturedProducts() async {
    try {
      final products = await _homeService.getFeaturedProducts(universityId: _selectedUniversityId, limit: 12);
      if (mounted) setState(() => _featuredProducts = products);
    } catch (e) {
      debugPrint('Error loading featured products: $e');
    }
  }

  Future<void> _loadTopSellers() async {
    try {
      final products = await _homeService.getTopSellingProducts(universityId: _selectedUniversityId, limit: 6);
      if (mounted) setState(() => _topSellers = products);
    } catch (e) {
      debugPrint('Error loading top sellers: $e');
    }
  }

  Future<void> _loadRecommendedProducts() async {
    try {
      final userId = _authService.currentUserId;
      final products = await _homeService.getRecommendedProducts(universityId: _selectedUniversityId, userId: userId, limit: 6);
      if (mounted) setState(() => _recommendedProducts = products);
    } catch (e) {
      debugPrint('Error loading recommended products: $e');
    }
  }

  Future<void> _loadTrendingActivity() async {
    if (_selectedUniversityId == null) return;
    try {
      final activity = await _homeService.getTrendingActivity(_selectedUniversityId!);
      if (mounted) setState(() => _viewingCount = activity['products_viewed'] ?? 0);
    } catch (e) {
      debugPrint('Error loading trending activity: $e');
    }
  }

  Future<void> _loadRecentPurchases() async {
    if (_selectedUniversityId == null) return;
    try {
      final purchases = await _homeService.getRecentPurchases(_selectedUniversityId!, limit: 5);
      if (mounted) setState(() => _recentPurchases = purchases);
    } catch (e) {
      debugPrint('Error loading recent purchases: $e');
    }
  }

  Future<void> _loadTopInState() async {
    if (_selectedState.isEmpty || _selectedState == 'State') return;
    try {
      final topProductsRaw = await _homeService.getTopProductsByState(state: _selectedState, limit: 3);
      final topProducts = topProductsRaw.map((data) => ProductModel.fromJson(data as Map<String, dynamic>)).toList();
      if (mounted) setState(() => _topInState = topProducts);
    } catch (e) {
      debugPrint('Error loading top in state: $e');
      if (mounted) setState(() => _topInState = []);
    }
  }

  Future<void> _loadLowestPriceProducts() async {
    try {
      final products = await _productService.getProductsByLowestPrice(state: _selectedState, limit: 50);
      if (mounted) setState(() => _lowestPriceProducts = products);
    } catch (e) {
      debugPrint('Error loading lowest price products: $e');
    }
  }

  Future<void> _onCampusChanged(UniversityModel university) async {
    Navigator.pop(context);
    setState(() {
      _selectedCampus = university.shortName;
      _selectedUniversityId = university.id;
      _selectedState = university.state;
      _isLoadingProducts = true;
      _allProducts = [];
      _featuredProducts = [];
      _topSellers = [];
      _recommendedProducts = [];
      _lowestPriceProducts = [];
    });
    await _refreshProductData();
  }

  void _startAdBannerAutoSlide() {
    _adBannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_adBannerController != null && _adBannerController!.hasClients) {
        final nextPage = (_currentAdPage + 1) % _adBanners.length;
        _adBannerController!.animateToPage(nextPage, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
    });
  }

  void _startFlashSaleTimer() {
    _flashSaleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {});
    });
  }

  String _getFlashSaleCountdown(ProductModel product) {
    if (!product.isFlashSaleActive) return '';
    final remaining = product.flashSaleTimeRemaining;
    if (remaining == null) return '';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _CombinedHeaderDelegate(
                statusBarHeight: MediaQuery.of(context).padding.top,
                selectedCampus: _selectedCampus,
                selectedState: _selectedState,
                onLocationTap: _showCampusSelectorBottomSheet,
                onSearchTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SearchScreen(universityId: _selectedUniversityId, universityName: _selectedCampus, state: _selectedState))),
                onCartTap: () {},
                onNotificationTap: () {},
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _buildUnifiedAdBanner()),
                  const SizedBox(height: 28),
                  _isLoadingData ? _buildCategoriesSkeleton() : _categoriesError ? _buildCategoriesErrorState() : _buildCategoriesDirectory(),
                  const SizedBox(height: 20),
                  _buildTrendingSection(),
                  const SizedBox(height: 20),
                  _buildTopInState(),
                  const SizedBox(height: 20),
                  _buildTopSellersSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(TabBar(
                controller: _tabController,
                labelColor: Color(0xFFFF6B35),
                unselectedLabelColor: AppColors.textLight,
                indicatorColor: Color(0xFFFF6B35),
                tabs: const [Tab(text: 'All Products'), Tab(text: 'Picked for You'), Tab(text: 'Lowest Price')],
              )),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [_buildProductGridPage(0), _buildProductGridPage(1), _buildProductGridPage(2)],
        ),
      ),
    );
  }

  List<ProductModel> _getFilteredProductsForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: return _allProducts;
      case 1: return _featuredProducts;
      case 2: return _lowestPriceProducts;
      default: return _allProducts;
    }
  }

  Widget _buildProductGridPage(int pageIndex) {
    if (_isLoadingProducts) return _buildProductGridShimmer();
    final products = _getFilteredProductsForTab(pageIndex);
    if (products.isEmpty) {
      String message = 'No products found';
      String subtitle = 'Check back later for new listings';
      if (pageIndex == 1) {
        message = 'Nothing Picked For You... Yet!';
        subtitle = 'Browse more items so we can learn what you like.';
      } else if (pageIndex == 2) {
        message = 'No Products Found';
        subtitle = 'We couldn\'t find any items for this filter.';
      }
      return NoProductsEmptyState(message: message, subtitle: subtitle);
    }
    return GridView.builder(
      key: PageStorageKey<String>('tab_$pageIndex'),
      padding: const EdgeInsets.all(8),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.58,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => _buildGridProductCard(products[index]),
    );
  }

  Widget _buildProductGridShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.58,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: _ShimmerWidget(child: Container(width: double.infinity, color: Colors.grey[300])))),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerWidget(child: Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 6),
                _ShimmerWidget(child: Container(height: 14, width: 80, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 6),
                _ShimmerWidget(child: Container(height: 10, width: 120, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridProductCard(ProductModel product) {
    final isFavorite = _favorites.contains(product.id);
    final isInCart = _cart.contains(product.id);
    
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
                        child: Text('-${product.discountPercentage ?? ((product.originalPrice! - product.price) / product.originalPrice! * 100).round()}%', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => isFavorite ? _favorites.remove(product.id) : _favorites.add(product.id)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                        child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey.shade600, size: 16),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleCart(product),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: isInCart ? Color(0xFFFF6B35) : Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                        child: (_isAddingToCartId == product.id)
                            ? Container(width: 16, height: 16, padding: const EdgeInsets.all(2.0), child: CircularProgressIndicator(color: isInCart ? Colors.white : Color(0xFFFF6B35), strokeWidth: 2))
                            : Icon(isInCart ? Icons.check : Icons.add_shopping_cart, color: isInCart ? Colors.white : Color(0xFFFF6B35), size: 16),
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
                  Text(product.name, style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(_formatPrice(product.price), style: AppTextStyles.price.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                      if (product.hasDiscount && product.originalPrice != null) ...[
                        const SizedBox(width: 3),
                        Flexible(child: Text(_formatPrice(product.originalPrice!), style: TextStyle(fontSize: 10, color: AppColors.textLight, decoration: TextDecoration.lineThrough), overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                    ],
                  ),
                  if (product.isTrending || product.isTopSeller) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(5)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [Icon(Icons.verified, color: Colors.white, size: 7), SizedBox(width: 2), Text('Verified', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w600))],
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 10, color: AppColors.textLight),
                      const SizedBox(width: 2),
                      Expanded(child: Text(product.universityAbbr?.isNotEmpty == true ? product.universityAbbr! : product.universityName ?? 'UniHub', style: TextStyle(fontSize: 9, color: AppColors.textLight), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  _buildRatingStars(rating: product.averageRating, reviewCount: product.reviewCount, size: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedAdBanner() {
    _adBannerController ??= PageController(initialPage: 0);
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _adBannerController,
            onPageChanged: (index) => setState(() => _currentAdPage = index),
            itemCount: _adBanners.length,
            itemBuilder: (context, index) {
              final banner = _adBanners[index];
              return Container(
                decoration: BoxDecoration(gradient: LinearGradient(colors: banner['gradient'], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14)),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(banner['title'], style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text(banner['subtitle'], style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, height: 1.3)),
                          const SizedBox(height: 6),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Text(banner['buttonText'], style: TextStyle(color: banner['gradient'][0], fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    Positioned(right: 10, top: 0, bottom: 0, child: Icon(banner['icon'], size: 70, color: Colors.white.withOpacity(0.3))),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_adBanners.length, (index) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: _currentAdPage == index ? 24 : 8, height: 8, decoration: BoxDecoration(color: _currentAdPage == index ? Color(0xFFFF6B35) : AppColors.textLight.withOpacity(0.3), borderRadius: BorderRadius.circular(4)))),
        ),
      ],
    );
  }

  Widget _buildCategoriesSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _ShimmerWidget(child: Container(height: 18, width: 140, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))))),
        const SizedBox(height: 12),
        SizedBox(height: 110, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: 6, itemBuilder: (context, index) => Container(width: 90, margin: const EdgeInsets.symmetric(horizontal: 6), child: Column(children: [_ShimmerWidget(child: Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade300))), const SizedBox(height: 8), _ShimmerWidget(child: Container(height: 12, width: 70, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))), const SizedBox(height: 4), _ShimmerWidget(child: Container(height: 12, width: 50, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))))])))),
      ],
    );
  }

  Widget _buildCategoriesErrorState() {
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
            ElevatedButton.icon(onPressed: () async { setState(() { _isLoadingData = true; _categoriesError = false; }); await _loadCategories(); setState(() => _isLoadingData = false); }, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesDirectory() {
    if (_categoryVisuals.isEmpty) return const SizedBox.shrink();
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
              CategoryModel? matchedCategory;
              try { matchedCategory = _categories.firstWhere((cat) => cat.name.toLowerCase().contains(categoryData['key'].toString().split('_').first.toLowerCase())); } catch (_) {}
              return GestureDetector(
                onTap: () { if (matchedCategory != null) { Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryProductsScreen(categoryId: matchedCategory!.id, categoryName: matchedCategory.name, universityId: _selectedUniversityId, state: _selectedState))); }},
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Color(0xFFFF6B35).withOpacity(0.3), width: 2)), child: ClipOval(child: CachedNetworkImage(imageUrl: categoryData['imageUrl'], fit: BoxFit.cover, placeholder: (context, url) => Container(color: AppColors.background, child: Icon(categoryData['icon'], color: Color(0xFFFF6B35), size: 28)), errorWidget: (context, url, error) => Container(color: AppColors.background, child: Icon(categoryData['icon'], color: Color(0xFFFF6B35), size: 28))))),
                      const SizedBox(height: 8),
                      Text(matchedCategory?.name ?? categoryData['name'], style: AppTextStyles.body.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
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

  Widget _buildTrendingSection() {
    final location = _selectedCampus != 'University' ? _selectedCampus : _selectedState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              TweenAnimationBuilder(tween: Tween<double>(begin: 0.8, end: 1.2), duration: const Duration(milliseconds: 1000), curve: Curves.easeInOut, builder: (context, double scale, child) => Transform.scale(scale: scale, child: Icon(Icons.local_fire_department, color: Color(0xFFFF6B35), size: 24)), onEnd: () => setState(() {})),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Trending in $location', style: AppTextStyles.heading.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))), if (_featuredProducts.isNotEmpty && _featuredProducts.first.isFlashSaleActive) Text('Flash Sale ends in ${_getFlashSaleCountdown(_featuredProducts.first)}', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600))])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 260, child: _isLoadingProducts ? _buildHorizontalSkeleton(145) : _featuredProducts.isEmpty ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No trending products yet', style: AppTextStyles.body.copyWith(color: AppColors.textLight)))) : ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _featuredProducts.length > 12 ? 12 : _featuredProducts.length, itemBuilder: (context, index) => _buildHeroTrendingCard(_featuredProducts[index], index == 0))),
      ],
    );
  }

  Widget _buildHeroTrendingCard(ProductModel product, bool isHero) {
    final isFavorite = _favorites.contains(product.id);
    final isInCart = _cart.contains(product.id);
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: isHero ? Color(0xFFFF6B35).withOpacity(0.3) : Colors.black.withOpacity(0.08), blurRadius: isHero ? 12 : 8, spreadRadius: isHero ? 2 : 0)], border: isHero ? Border.all(color: Color(0xFFFF6B35).withOpacity(0.4), width: 2) : null),
          child: InkWell(
            onTap: () => _navigateToProductDetails(product),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: CachedNetworkImage(imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image', height: isHero ? 135 : 120, width: double.infinity, fit: BoxFit.cover, placeholder: (context, url) => Container(height: isHero ? 135 : 120, color: AppColors.background, child: Icon(Icons.image, color: AppColors.textLight.withOpacity(0.5))), errorWidget: (context, url, error) => Container(height: isHero ? 135 : 120, color: AppColors.background, child: Icon(Icons.shopping_bag_outlined, size: 40, color: Color(0xFFFF6B35).withOpacity(0.3))))),
                    if (isHero) Positioned(top: -20, right: -20, child: Container(width: 80, height: 80, decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF6B35).withOpacity(0.3), Color(0xFFFF8C42).withOpacity(0.2)]), shape: BoxShape.circle))),
                    if (product.hasDiscount || product.discountPercentage != null) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 6)]), child: Text('-$discount%', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                    if (isHero) Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)]), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(Icons.whatshot, color: Colors.white, size: 10), SizedBox(width: 2), Text('HOT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))]))),
                    Positioned(bottom: 8, left: 8, child: GestureDetector(onTap: () => setState(() => isFavorite ? _favorites.remove(product.id) : _favorites.add(product.id)), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]), child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey.shade600, size: 14)))),
                    Positioned(bottom: 8, right: 8, child: GestureDetector(onTap: () => _toggleCart(product), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isInCart ? Color(0xFFFF6B35) : Colors.white.withOpacity(0.95), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]), child: (_isAddingToCartId == product.id) ? Container(width: 14, height: 14, padding: const EdgeInsets.all(2.0), child: CircularProgressIndicator(color: isInCart ? Colors.white : Color(0xFFFF6B35), strokeWidth: 2)) : Icon(isInCart ? Icons.check : Icons.add_shopping_cart, color: isInCart ? Colors.white : Color(0xFFFF6B35), size: 14)))),
                  ],
                ),
                Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(product.name, style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Row(children: [Text(_formatPrice(product.price), style: AppTextStyles.price.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))), const SizedBox(width: 4), if (product.hasDiscount && product.originalPrice != null) Flexible(child: Text(_formatPrice(product.originalPrice!), style: TextStyle(fontSize: 9, color: AppColors.textLight, decoration: TextDecoration.lineThrough), overflow: TextOverflow.ellipsis))]), if (savings > 0) ...[const SizedBox(height: 3), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(5)), child: Text('Save ${_formatPrice(savings)}', style: TextStyle(color: Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.w600)))], const SizedBox(height: 4), Row(children: [Icon(Icons.visibility, size: 9, color: AppColors.textLight), const SizedBox(width: 3), Text('${120 + (product.id.hashCode % 300)} viewing', style: TextStyle(fontSize: 8, color: AppColors.textLight))]), const SizedBox(height: 2), _buildRatingStars(rating: product.averageRating, reviewCount: product.reviewCount, size: 9)])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopInState() {
    if (_selectedState == 'State') return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [TweenAnimationBuilder(tween: Tween<double>(begin: 1.0, end: 1.3), duration: const Duration(milliseconds: 800), curve: Curves.elasticOut, builder: (context, double scale, child) => Transform.scale(scale: scale, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFA500), Color(0xFFFFD700)]), shape: BoxShape.circle), child: Icon(Icons.emoji_events, color: Colors.white, size: 16))), onEnd: () => setState(() {})), const SizedBox(width: 8), Text('This week in $_selectedState', style: AppTextStyles.subheading.copyWith(fontSize: 14, fontWeight: FontWeight.bold))])),
        const SizedBox(height: 12),
        SizedBox(height: 220, child: _isLoadingProducts ? _buildHorizontalSkeleton(145) : _featuredProducts.isEmpty ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No products found for this state yet.', style: AppTextStyles.body.copyWith(color: AppColors.textLight)))) : ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _featuredProducts.length > 6 ? 6 : _featuredProducts.length, itemBuilder: (context, index) => Padding(padding: EdgeInsets.only(right: 12), child: _buildCompactCard(_featuredProducts[index])))),
      ],
    );
  }

  Widget _buildTopSellersSection() {
    if (_selectedState == 'State') return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFF4E6), Color(0xFFFAFAFA)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(children: [TweenAnimationBuilder(tween: Tween<double>(begin: 0.0, end: 2 * 3.14159), duration: const Duration(milliseconds: 1500), curve: Curves.easeInOut, builder: (context, double angle, child) => Transform.rotate(angle: angle, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF6B35)]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0xFF1E40AF).withOpacity(0.3), blurRadius: 8, spreadRadius: 2)]), child: Icon(Icons.auto_awesome, color: Colors.white, size: 16))), onEnd: () => setState(() {})), const SizedBox(width: 12), Expanded(child: Text('Top Deals in $_selectedState', style: AppTextStyles.subheading.copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35)))), TextButton(onPressed: () {}, child: Text('See All', style: AppTextStyles.body.copyWith(color: Color(0xFF001F3F), fontSize: 12, fontWeight: FontWeight.w600)))]),
          const SizedBox(height: 16),
          SizedBox(height: 220, child: _isLoadingProducts ? _buildHorizontalSkeleton(145) : _topSellers.isEmpty ? Center(child: Text('No top sellers yet.', style: AppTextStyles.body.copyWith(color: AppColors.textLight))) : ListView.builder(scrollDirection: Axis.horizontal, itemCount: _topSellers.length, itemBuilder: (context, index) => Padding(padding: EdgeInsets.only(right: 12), child: _buildCompactCard(_topSellers[index])))),
        ],
      ),
    );
  }

  Widget _buildCompactCard(ProductModel product) {
    final isFavorite = _favorites.contains(product.id);
    final isInCart = _cart.contains(product.id);
    return Container(
      width: 145,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)]),
      child: InkWell(
        onTap: () => _navigateToProductDetails(product),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), child: CachedNetworkImage(imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image', height: 120, width: double.infinity, fit: BoxFit.cover, placeholder: (context, url) => Container(height: 120, color: AppColors.background, child: Icon(Icons.image, color: AppColors.textLight.withOpacity(0.5))), errorWidget: (context, url, error) => Container(height: 120, color: AppColors.background, child: Icon(Icons.shopping_bag_outlined, size: 40, color: Color(0xFFFF6B35).withOpacity(0.3))))),
                if (product.hasDiscount || product.discountPercentage != null) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: Color(0xFFFF6B35), borderRadius: BorderRadius.circular(8)), child: Text('-${product.discountPercentage ?? ((product.originalPrice! - product.price) / product.originalPrice! * 100).round()}%', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                Positioned(top: 8, left: 8, child: GestureDetector(onTap: () => setState(() => isFavorite ? _favorites.remove(product.id) : _favorites.add(product.id)), child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle), child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey.shade600, size: 14)))),
                Positioned(bottom: 8, right: 8, child: GestureDetector(onTap: () => _toggleCart(product), child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: isInCart ? Color(0xFFFF6B35) : Colors.white.withOpacity(0.9), shape: BoxShape.circle), child: (_isAddingToCartId == product.id) ? Container(width: 14, height: 14, padding: const EdgeInsets.all(2.0), child: CircularProgressIndicator(color: isInCart ? Colors.white : Color(0xFFFF6B35), strokeWidth: 2)) : Icon(isInCart ? Icons.check : Icons.add_shopping_cart, color: isInCart ? Colors.white : Color(0xFFFF6B35), size: 14)))),
              ],
            ),
            Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(product.name, style: AppTextStyles.body.copyWith(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Row(children: [Text(_formatPrice(product.price), style: AppTextStyles.price.copyWith(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))), if (product.hasDiscount && product.originalPrice != null) ...[const SizedBox(width: 3), Flexible(child: Text(_formatPrice(product.originalPrice!), style: TextStyle(fontSize: 9, color: AppColors.textLight, decoration: TextDecoration.lineThrough), overflow: TextOverflow.ellipsis))]]), const SizedBox(height: 3), Row(children: [Icon(Icons.location_on, size: 9, color: AppColors.textLight), const SizedBox(width: 2), Expanded(child: Text(product.universityAbbr?.isNotEmpty == true ? product.universityAbbr! : product.universityName ?? 'UniHub', style: TextStyle(fontSize: 8, color: AppColors.textLight), maxLines: 1, overflow: TextOverflow.ellipsis))]), const SizedBox(height: 2), _buildRatingStars(rating: product.averageRating, reviewCount: product.reviewCount, size: 9)])),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalSkeleton(double width) => ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: 4, itemBuilder: (context, index) => Container(width: width, margin: const EdgeInsets.only(right: 12), child: _ShimmerWidget(child: Container(decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(14))))));

  void _showCampusSelectorBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(expand: false, initialChildSize: 0.6, maxChildSize: 0.9, builder: (context, scrollController) {
        final filteredUniversities = _getFilteredUniversities();
        final hasState = _selectedState.isNotEmpty && _selectedState != 'State';
        final stateDisplayName = hasState ? _selectedState.toUpperCase() : 'Select State';
        return Column(children: [Padding(padding: const EdgeInsets.all(16), child: Column(children: [Text('Select university — $stateDisplayName', style: AppTextStyles.heading.copyWith(fontSize: 18, fontWeight: FontWeight.bold)), if (!hasState) ...[const SizedBox(height: 8), Text('Please set your state first', style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textLight))]])), const Divider(height: 1), Expanded(child: filteredUniversities.isEmpty ? Center(child: _isLoadingData ? const CircularProgressIndicator() : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.school_outlined, size: 64, color: AppColors.textLight.withOpacity(0.5)), const SizedBox(height: 16), Text('No universities found in this state', style: AppTextStyles.body.copyWith(color: AppColors.textLight)), if (!hasState) ...[const SizedBox(height: 24), ElevatedButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('State selection coming soon'))); }, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: const Text('Set my state'))]])) : ListView.builder(controller: scrollController, itemCount: filteredUniversities.length, itemBuilder: (context, index) { final uni = filteredUniversities[index]; final isSelected = uni.id == _selectedUniversityId; return ListTile(leading: Icon(Icons.school, color: isSelected ? Color(0xFFFF6B35) : AppColors.textLight), title: Text(uni.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), subtitle: Text(uni.shortName, style: TextStyle(color: AppColors.textLight, fontSize: 12)), trailing: isSelected ? Icon(Icons.check_circle, color: Color(0xFFFF6B35)) : null, onTap: () => _onCampusChanged(uni)); })), if (!hasState) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.textLight.withOpacity(0.2)))), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('State selection coming soon'))); }, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Set my state', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))))]);
      }),
    );
  }
}

class _ShimmerWidget extends StatefulWidget {
  final Widget child;
  const _ShimmerWidget({required this.child});
  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget> with SingleTickerProviderStateMixin {
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
  Widget build(BuildContext context) => AnimatedBuilder(animation: _controller, builder: (context, child) => ShaderMask(shaderCallback: (bounds) => LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: const [Color(0xFFE0E0E0), Color(0xFFF5F5F5), Color(0xFFE0E0E0)], stops: [_controller.value - 0.3, _controller.value, _controller.value + 0.3]).createShader(bounds), child: widget.child));
}

class _CombinedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double statusBarHeight;
  final String selectedCampus;
  final String selectedState;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;
  final VoidCallback onCartTap;
  final VoidCallback onNotificationTap;
  static const double uniHubTitleBarHeight = 56.0;
  static const double locationSearchHeight = 85.0;

  _CombinedHeaderDelegate({required this.statusBarHeight, required this.selectedCampus, required this.selectedState, required this.onLocationTap, required this.onSearchTap, required this.onCartTap, required this.onNotificationTap});

  @override
  double get minExtent => statusBarHeight + locationSearchHeight;
  @override
  double get maxExtent => statusBarHeight + uniHubTitleBarHeight + locationSearchHeight;

  @override
Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
  final scrollProgress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
  final titleBarOpacity = (1.0 - scrollProgress).clamp(0.0, 1.0);
  return Container(
    color: Colors.white,
    child: Stack(
      children: [
        Positioned(
          top: statusBarHeight,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: titleBarOpacity,
            child: IgnorePointer(
              ignoring: scrollProgress > 0.5,
              child: Container(
                height: uniHubTitleBarHeight,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Text('UniHub', style: AppTextStyles.heading.copyWith(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const Spacer(),
                    IconButton(icon: Icon(Icons.shopping_bag_outlined, color: Colors.black, size: 24), onPressed: onCartTap),
                    Stack(
                      children: [
                        IconButton(icon: Icon(Icons.notifications_outlined, color: Colors.black, size: 24), onPressed: onNotificationTap),
                        Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF6B35), shape: BoxShape.circle))),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: statusBarHeight + (uniHubTitleBarHeight * (1.0 - scrollProgress)),
          left: 0,
          right: 0,
          child: Container(
            height: locationSearchHeight,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onLocationTap,
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 18, color: Color(0xFFFF6B35)),
                        const SizedBox(width: 6),
                        Text('$selectedCampus, $selectedState', style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFF6B35))),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFFFF6B35)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onSearchTap,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(color: Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search, color: Colors.grey.shade600, size: 18),
                          const SizedBox(width: 10),
                          Text('Search for products, sellers, or ...', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
  @override
  bool shouldRebuild(_CombinedHeaderDelegate oldDelegate) => statusBarHeight != oldDelegate.statusBarHeight || selectedCampus != oldDelegate.selectedCampus || selectedState != oldDelegate.selectedState;
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: AppColors.white, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}