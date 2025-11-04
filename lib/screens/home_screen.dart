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
import '../models/product_model.dart';
import '../models/university_category_models.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/empty_states.dart';
import './product_details_screen.dart';
import './search_screen.dart';
import './category_products_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  ScrollController _scrollController = ScrollController();
  PageController? _adBannerController;
  final _homeService = HomeService();
  final _productService = ProductService();
  final _authService = AuthService();
  final _universityService = UniversityService();
  final _categoryService = CategoryService();
  String _selectedCampus = 'Loading...';
  String? _selectedUniversityId;
  String _selectedState = 'Lagos';
  List<ProductModel> _allProducts = [];
  List<ProductModel> _featuredProducts = [];
  List<ProductModel> _topSellers = [];
  List<ProductModel> _recommendedProducts = [];
  List<ProductModel> _topInState = [];
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
  final Map<String, bool> _verifiedStatus = {};
  Timer? _adBannerTimer;
  int _currentAdPage = 0;
  int _viewingCount = 0;
  int _flashSaleHours = 2;
  int _flashSaleMinutes = 34;
  int _flashSaleSeconds = 15;
  int _mysteryDays = 14;
  int _mysteryHours = 46;
  int _mysteryMinutes = 25;
  int _mysterySeconds = 0;
 
  final List<Map<String, dynamic>> _adBanners = [
    {
      'title': 'New Collection',
      'subtitle': 'Flash Sale Up to 40%\noff this weekend.',
      'buttonText': 'Shop Now',
      'gradient': [Color(0xFFFFA726), Color(0xFFFB8C00)],
      'icon': Icons.shopping_bag_outlined,
    },
    {
      'title': 'AWOOF DEALS',
      'subtitle': 'Get up to 70% OFF\non selected items!',
      'buttonText': 'Grab Deals',
      'gradient': [Color(0xFFDC2626), Color(0xFF991B1B)],
      'icon': Icons.local_offer,
    },
    {
      'title': 'FLASH SALE',
      'subtitle': 'Limited time offer\n50% OFF everything!',
      'buttonText': 'Shop Now',
      'gradient': [Color(0xFFEC4899), Color(0xFF9D4EDD)],
      'icon': Icons.flash_on,
    },
    {
      'title': 'MEGA DEALS',
      'subtitle': 'Biggest discounts ever\nUP TO 80% OFF!',
      'buttonText': 'Shop Deals',
      'gradient': [Color(0xFFEF4444), Color(0xFFDC2626)],
      'icon': Icons.stars,
    },
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
    
    // Sync tab controller with page controller
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _pageController.animateToPage(
          _tabController.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
    
    _startAdBannerAutoSlide();
    _startCountdowns();
    _initializeData();
  }


  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    _adBannerController?.dispose();
    _adBannerTimer?.cancel();
    super.dispose();
  }


  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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
          return Icon(Icons.star_border, size: size, color: Colors.grey.shade400);
        }),
        const SizedBox(width: 4),
        Text('${displayRating.toStringAsFixed(1)} ${reviewCount > 0 ? '($reviewCount)' : ''}',
          style: TextStyle(fontSize: size - 2, color: AppColors.textLight)),
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
 
  bool _isVerified(String productId) {
    if (!_verifiedStatus.containsKey(productId)) {
      _verifiedStatus[productId] = (productId.hashCode % 10) < 4;
    }
    return _verifiedStatus[productId] ?? false;
  }


  List<ProductModel> _getFilteredProducts() {
    switch (_tabController.index) {
      case 0: return _allProducts;
      case 1: return _featuredProducts.isNotEmpty ? _featuredProducts : _allProducts.take(8).toList();
      case 2:
        if (_recommendedProducts.isNotEmpty) return _recommendedProducts;
        final sorted = List<ProductModel>.from(_allProducts);
        sorted.sort((a, b) => a.price.compareTo(b.price));
        return sorted;
      default: return _allProducts;
    }
  }


  List<UniversityModel> _getFilteredUniversities() {
    if (_selectedState.isEmpty) return _universities;
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
        _loadRecommendedProducts(), _loadTrendingActivity(), _loadRecentPurchases(), _loadTopInState(),
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
      final products = await _homeService.getFeaturedProducts(universityId: _selectedUniversityId, limit: 8);
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
    if (_selectedState.isEmpty) return;
    try {
      final topProductsRaw = await _homeService.getTopProductsByState(state: _selectedState, limit: 3);
      final topProducts = topProductsRaw.map((data) => ProductModel.fromJson(data as Map<String, dynamic>)).toList();
      if (mounted) setState(() => _topInState = topProducts);
    } catch (e) {
      debugPrint('Error loading top in state: $e');
      if (mounted) setState(() => _topInState = []);
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


  void _startCountdowns() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_flashSaleSeconds > 0) {
          _flashSaleSeconds--;
        } else if (_flashSaleMinutes > 0) {
          _flashSaleMinutes--; _flashSaleSeconds = 59;
        } else if (_flashSaleHours > 0) {
          _flashSaleHours--; _flashSaleMinutes = 59; _flashSaleSeconds = 59;
        }
        if (_mysterySeconds > 0) {
          _mysterySeconds--;
        } else if (_mysteryMinutes > 0) {
          _mysteryMinutes--; _mysterySeconds = 59;
        } else if (_mysteryHours > 0) {
          _mysteryHours--; _mysteryMinutes = 59; _mysterySeconds = 59;
        } else if (_mysteryDays > 0) {
          _mysteryDays--; _mysteryHours = 23; _mysteryMinutes = 59; _mysterySeconds = 59;
        }
      });
    });
  }


  void _navigateToProductDetails(ProductModel product) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: product)));
  }


  void _toggleCart(ProductModel product) {
    setState(() {
      if (_cart.contains(product.id)) {
        _cart.remove(product.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from cart'), duration: Duration(seconds: 1)));
      } else {
        _cart.add(product.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Added to cart'), duration: const Duration(seconds: 1), backgroundColor: AppColors.primary));
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    const double stickyContentHeight = 85;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // FIXED: Combined STICKY HEADER with proper positioning
          SliverPersistentHeader(
            pinned: true,
            delegate: _CombinedHeaderDelegate(
              statusBarHeight: MediaQuery.of(context).padding.top,
              selectedCampus: _selectedCampus,
              selectedState: _selectedState,
              onLocationTap: _showCampusSelectorBottomSheet,
              onSearchTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchScreen(
                    universityId: _selectedUniversityId,
                    universityName: _selectedCampus,
                  ),
                ),
              ),
              onCartTap: () {},
              onNotificationTap: () {},
            ),
          ),
          
          // Unified sliding ad banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildUnifiedAdBanner(),
            ),
          ),
          
          // Scrollable content sections
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 28),
                _isLoadingData ? const CategoryChipsSkeleton() : _categoriesError ? _buildCategoriesErrorState() : _buildCategoriesDirectory(),
                const SizedBox(height: 20),
                _buildCampusPulse(),
                const SizedBox(height: 20),
                _buildMysteryDeals(),
                const SizedBox(height: 12),
                _buildNotifyButton(),
                const SizedBox(height: 24),
                _buildTopInState(),
                const SizedBox(height: 20),
                _buildHotRightNowBanner(),
                const SizedBox(height: 20),
                _buildTopSellersSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          
          // MOVED: Product tabs (sticky when scrolled to this position)
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.primary,
              tabs: const [Tab(text: 'All Products'), Tab(text: 'Picked for You'), Tab(text: 'Your Department')],
            )),
            pinned: true,
          ),
          
          // SWIPEABLE Product Grid with PageView
         // SWIPEABLE Product Grid with PageView
_isLoadingProducts
    ? const SliverFillRemaining(child: ProductGridSkeleton(itemCount: 6))
    : SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8, // Adjust height as needed
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              _tabController.animateTo(index);
            },
            itemCount: 3,
            itemBuilder: (context, pageIndex) {
              final products = _getFilteredProductsForTab(pageIndex);
              
              if (products.isEmpty) {
                return const Center(
                  child: NoProductsEmptyState(
                    message: 'No products available',
                    subtitle: 'Check back later for new listings',
                  ),
                );
              }
              
              return GridView.builder(
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
              );
            },
          ),
        ),
      ),
        ],
      ),
    );
  }

  // Helper method to get products for specific tab
  List<ProductModel> _getFilteredProductsForTab(int tabIndex) {
    switch (tabIndex) {
      case 0: return _allProducts;
      case 1: return _featuredProducts.isNotEmpty ? _featuredProducts : _allProducts.take(8).toList();
      case 2:
        if (_recommendedProducts.isNotEmpty) return _recommendedProducts;
        final sorted = List<ProductModel>.from(_allProducts);
        sorted.sort((a, b) => a.price.compareTo(b.price));
        return sorted;
      default: return _allProducts;
    }
  }


  // NEW: Unified sliding ad banner with pagination dots
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: banner['gradient'],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            banner['title'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            banner['subtitle'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              banner['buttonText'],
                              style: TextStyle(
                                color: banner['gradient'][0],
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 0,
                      bottom: 0,
                      child: Icon(
                        banner['icon'],
                        size: 70,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Pagination dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _adBanners.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentAdPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentAdPage == index
                    ? AppColors.primary
                    : AppColors.textLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
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
            ElevatedButton.icon(
              onPressed: () async {
                setState(() { _isLoadingData = true; _categoriesError = false; });
                await _loadCategories();
                setState(() => _isLoadingData = false);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
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
              try {
                matchedCategory = _categories.firstWhere((cat) => cat.name.toLowerCase().contains(categoryData['key'].toString().split('_').first.toLowerCase()));
              } catch (_) {}
              return GestureDetector(
                onTap: () {
                  if (matchedCategory != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryProductsScreen(categoryId: matchedCategory!.id, categoryName: matchedCategory.name, universityId: _selectedUniversityId, state: _selectedState)));
                  }
                },
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2)),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: categoryData['imageUrl'], fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppColors.background, child: Icon(categoryData['icon'], color: AppColors.primary, size: 28)),
                            errorWidget: (context, url, error) => Container(color: AppColors.background, child: Icon(categoryData['icon'], color: AppColors.primary, size: 28)),
                          ),
                        ),
                      ),
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


  Widget _buildCampusPulse() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const FaIcon(FontAwesomeIcons.chartLine, color: Color(0xFF10B981), size: 18), const SizedBox(width: 6), Text('Campus Pulse', style: AppTextStyles.subheading.copyWith(fontSize: 14))]),
          const SizedBox(height: 12),
          _buildPulseItem(_recentPurchases.isNotEmpty ? 'Just bought by ${_recentPurchases.first['buyer_name'] ?? 'Student'}' : 'Be the first to buy!', _recentPurchases.isNotEmpty ? 'a moment ago' : 'Shop now'),
          const SizedBox(height: 8),
          _buildPulseItem('${_formatCount(_viewingCount)} students viewing', 'Hurry! Deals ending soon', isUrgent: true),
        ],
      ),
    );
  }


  Widget _buildPulseItem(String title, String subtitle, {bool isUrgent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: isUrgent ? const Color(0xFFFFF7ED) : AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: isUrgent ? const Color(0xFFFDBA74) : AppColors.background)),
      child: Row(
        children: [
          Icon(isUrgent ? Icons.local_offer : Icons.shopping_cart, size: 14, color: isUrgent ? const Color(0xFFF97316) : AppColors.textLight),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.body.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(subtitle, style: AppTextStyles.body.copyWith(fontSize: 11, color: isUrgent ? const Color(0xFFF97316) : AppColors.textLight, fontWeight: isUrgent ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }


  Widget _buildMysteryDeals() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Row(children: [const Icon(Icons.card_giftcard, color: Colors.white, size: 24), const SizedBox(width: 8), Text('Mystery Flash Deals', style: AppTextStyles.heading.copyWith(color: Colors.white, fontSize: 16))]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _buildCountdownBox('${_mysteryDays.toString().padLeft(2, '0')}', 'd'),
              _buildCountdownBox('${_mysteryHours.toString().padLeft(2, '0')}', 'h'),
              _buildCountdownBox('${_mysteryMinutes.toString().padLeft(2, '0')}', 'm'),
              _buildCountdownBox('${_mysterySeconds.toString().padLeft(2, '0')}', 's'),
            ]),
          ],
        ),
      ),
    );
  }


  Widget _buildCountdownBox(String value, String unit) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(value, style: AppTextStyles.heading.copyWith(fontSize: 18, color: const Color(0xFFFF6B35))),
        Text(unit, style: AppTextStyles.body.copyWith(fontSize: 10, color: const Color(0xFFFF6B35))),
      ]),
    );
  }


  Widget _buildNotifyButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFFF6B35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFFF6B35), width: 2)), minimumSize: const Size(double.infinity, 48)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.notifications_active, size: 18), const SizedBox(width: 8), Text("Get notified for tomorrow's deals", style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13))]),
      ),
    );
  }


  Widget _buildTopInState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [const Icon(Icons.emoji_events, color: Colors.amber, size: 18), const SizedBox(width: 6), Text('This week in $_selectedState', style: AppTextStyles.subheading.copyWith(fontSize: 14))])),
        const SizedBox(height: 12),
        _isLoadingProducts ? const Center(child: CircularProgressIndicator()) : _topInState.isEmpty ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No top products found for this state yet.'))) : Column(children: _topInState.asMap().entries.map((e) => _buildTopInStateItem(e.key + 1, e.value)).toList()),
      ],
    );
  }


  Widget _buildTopInStateItem(int rank, ProductModel product) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _navigateToProductDetails(product),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: rank <= 3 ? const Color(0xFFFF8C42).withOpacity(0.1) : AppColors.background, shape: BoxShape.circle),
              child: Center(child: Text('$rank', style: AppTextStyles.heading.copyWith(fontSize: 14, color: rank <= 3 ? const Color(0xFFFF8C42) : AppColors.textLight, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://placehold.co/100x100/eeeeee/cccccc?text=No+Image',
                width: 60, height: 60, fit: BoxFit.cover,
                placeholder: (context, url) => Container(width: 60, height: 60, color: AppColors.background, child: Icon(Icons.image, color: AppColors.textLight.withOpacity(0.5))),
                errorWidget: (context, url, error) => Container(width: 60, height: 60, color: AppColors.background, child: Icon(Icons.hide_image, color: AppColors.textLight)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatPrice(product.price), style: AppTextStyles.price.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFFF6B35))),
                  Text(product.name, style: AppTextStyles.subheading.copyWith(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  _buildRatingStars(rating: product.averageRating, reviewCount: product.reviewCount, size: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildHotRightNowBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B))),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department, color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 8),
            Text('Hot Right Now in $_selectedCampus', style: AppTextStyles.subheading.copyWith(fontSize: 13, color: const Color(0xFF92400E))),
            const Spacer(),
            Text('Flash Sale ends in', style: AppTextStyles.body.copyWith(fontSize: 11, color: const Color(0xFF92400E))),
            const SizedBox(width: 6),
            Text('${_flashSaleHours.toString().padLeft(2, '0')}:${_flashSaleMinutes.toString().padLeft(2, '0')}:${_flashSaleSeconds.toString().padLeft(2, '0')}', style: AppTextStyles.subheading.copyWith(fontSize: 13, color: const Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }


  Widget _buildTopSellersSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [const Icon(Icons.trending_up, color: Color(0xFF10B981), size: 18), const SizedBox(width: 6), Text('Top Deals in $_selectedState', style: AppTextStyles.subheading.copyWith(fontSize: 14)), const Spacer(), TextButton(onPressed: () {}, child: Text('See All', style: AppTextStyles.body.copyWith(color: AppColors.primary, fontSize: 12)))]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: _isLoadingProducts ? const HorizontalProductListSkeleton(itemCount: 3) : _topSellers.isEmpty ? Center(child: Text('No top sellers yet.', style: AppTextStyles.body.copyWith(color: AppColors.textLight))) : ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _topSellers.length, itemBuilder: (context, index) => _buildHorizontalProductCard(product: _topSellers[index], isFirst: index == 0, isLast: index == _topSellers.length - 1)),
        ),
        const SizedBox(height: 12),
      ],
    );
  }


  Widget _buildHorizontalProductCard({required ProductModel product, required bool isFirst, required bool isLast}) {
    final isFavorite = _favorites.contains(product.id);
    final isInCart = _cart.contains(product.id);
    final isLiked = _likes[product.id] ?? false;
    final likeCount = _getLikeCount(product.id);
    return Container(
      width: 170,
      margin: EdgeInsets.only(left: isFirst ? 16 : 8, right: isLast ? 16 : 8),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]),
      child: InkWell(
        onTap: () => _navigateToProductDetails(product),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image',
                    height: 160, width: double.infinity, fit: BoxFit.cover,
                    placeholder: (context, url) => Container(height: 160, color: AppColors.background, child: Icon(Icons.image, color: AppColors.textLight.withOpacity(0.5))),
                    errorWidget: (context, url, error) => Container(height: 160, color: AppColors.background, child: Icon(Icons.shopping_bag_outlined, size: 50, color: AppColors.primary.withOpacity(0.3))),
                  ),
                ),
                Positioned(top: 8, left: 8, child: GestureDetector(onTap: () => setState(() => isFavorite ? _favorites.remove(product.id) : _favorites.add(product.id)), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle), child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey.shade600, size: 18)))),
                Positioned(top: 8, right: 8, child: GestureDetector(onTap: () => _toggleCart(product), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isInCart ? AppColors.primary : Colors.white.withOpacity(0.9), shape: BoxShape.circle), child: Icon(Icons.add_shopping_cart, color: isInCart ? Colors.white : AppColors.primary, size: 18)))),
                if (_isVerified(product.id)) Positioned(bottom: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.verified, color: Colors.white, size: 10), SizedBox(width: 3), Text('Verified Seller', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600))]))),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(product.name, style: AppTextStyles.body.copyWith(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(_formatPrice(product.price), style: AppTextStyles.price.copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFFFF6B35))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 11, color: AppColors.textLight),
                      const SizedBox(width: 3),
                      Expanded(child: Text(product.universityName ?? 'UniHub', style: TextStyle(fontSize: 10, color: AppColors.textLight), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      GestureDetector(onTap: () => _toggleLike(product.id), child: Icon(Icons.thumb_up, size: 11, color: isLiked ? const Color(0xFFFF6B35) : Colors.grey.shade400)),
                      const SizedBox(width: 3),
                      Text(_formatCount(likeCount), style: TextStyle(fontSize: 10, color: isLiked ? const Color(0xFFFF6B35) : AppColors.textLight, fontWeight: isLiked ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildRatingStars(rating: product.averageRating, reviewCount: product.reviewCount, size: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildGridProductCard(ProductModel product) {
    final isFavorite = _favorites.contains(product.id);
    final isInCart = _cart.contains(product.id);
    final isLiked = _likes[product.id] ?? false;
    final likeCount = _getLikeCount(product.id);
    return Container(
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]),
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image',
                      width: double.infinity, fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AppColors.background, child: Icon(Icons.image, color: AppColors.textLight.withOpacity(0.5))),
                      errorWidget: (context, url, error) => Container(color: AppColors.background, child: Icon(Icons.shopping_bag_outlined, size: 50, color: AppColors.primary.withOpacity(0.3))),
                    ),
                  ),
                  Positioned(top: 8, left: 8, child: GestureDetector(onTap: () => setState(() => isFavorite ? _favorites.remove(product.id) : _favorites.add(product.id)), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle), child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey.shade600, size: 16)))),
                  Positioned(top: 8, right: 8, child: GestureDetector(onTap: () => _toggleCart(product), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isInCart ? AppColors.primary : Colors.white.withOpacity(0.9), shape: BoxShape.circle), child: Icon(Icons.add_shopping_cart, color: isInCart ? Colors.white : AppColors.primary, size: 16)))),
                  if (_isVerified(product.id)) Positioned(bottom: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.verified, color: Colors.white, size: 9), SizedBox(width: 3), Text('Verified Seller', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600))]))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(product.name, style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(_formatPrice(product.price), style: AppTextStyles.price.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFFF6B35))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 10, color: AppColors.textLight),
                      const SizedBox(width: 2),
                      Expanded(child: Text(product.universityAbbr?.isNotEmpty == true ? product.universityAbbr! : product.universityName ?? product.universityId, style: TextStyle(fontSize: 9, color: AppColors.textLight), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 4),
                      GestureDetector(onTap: () => _toggleLike(product.id), child: Icon(Icons.thumb_up, size: 10, color: isLiked ? const Color(0xFFFF6B35) : Colors.grey.shade400)),
                      const SizedBox(width: 2),
                      Text(_formatCount(likeCount), style: TextStyle(fontSize: 9, color: isLiked ? const Color(0xFFFF6B35) : AppColors.textLight, fontWeight: isLiked ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _buildRatingStars(rating: product.averageRating, reviewCount: product.reviewCount, size: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showCampusSelectorBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          final filteredUniversities = _getFilteredUniversities();
          final hasState = _selectedState.isNotEmpty;
          final stateDisplayName = hasState ? _selectedState.toUpperCase() : 'State unknown';
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Select university — $stateDisplayName', style: AppTextStyles.heading.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (!hasState) ...[const SizedBox(height: 8), Text('Please set your state first', style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textLight))],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filteredUniversities.isEmpty
                    ? Center(child: _isLoadingData ? const CircularProgressIndicator() : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.school_outlined, size: 64, color: AppColors.textLight.withOpacity(0.5)), const SizedBox(height: 16), Text('No universities found in this state', style: AppTextStyles.body.copyWith(color: AppColors.textLight)), if (!hasState) ...[const SizedBox(height: 24), ElevatedButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('State selection coming soon'))); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: const Text('Set my state'))]]))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filteredUniversities.length,
                        itemBuilder: (context, index) {
                          final uni = filteredUniversities[index];
                          final isSelected = uni.id == _selectedUniversityId;
                          return ListTile(
                            leading: Icon(Icons.school, color: isSelected ? AppColors.primary : AppColors.textLight),
                            title: Text(uni.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            subtitle: Text(uni.shortName, style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                            trailing: isSelected ? Icon(Icons.check_circle, color: AppColors.primary) : null,
                            onTap: () => _onCampusChanged(uni),
                          );
                        },
                      ),
              ),
              if (!hasState) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.textLight.withOpacity(0.2)))), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('State selection coming soon'))); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Set my state', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))))),
            ],
          );
        },
      ),
    );
  }
}


// FIXED: Combined header delegate with proper status bar handling
class _CombinedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double statusBarHeight;
  final String selectedCampus;
  final String selectedState;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;
  final VoidCallback onCartTap;
  final VoidCallback onNotificationTap;
  
  // Heights
  static const double uniHubTitleBarHeight = 56.0;
  static const double locationSearchHeight = 85.0;
 
  _CombinedHeaderDelegate({
    required this.statusBarHeight,
    required this.selectedCampus,
    required this.selectedState,
    required this.onLocationTap,
    required this.onSearchTap,
    required this.onCartTap,
    required this.onNotificationTap,
  });

  @override
  double get minExtent => statusBarHeight + locationSearchHeight;
  
  @override
  double get maxExtent => statusBarHeight + uniHubTitleBarHeight + locationSearchHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Calculate scroll progress (0.0 = fully expanded, 1.0 = fully collapsed)
    final scrollProgress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final titleBarOpacity = (1.0 - scrollProgress).clamp(0.0, 1.0);
    
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // 1. UniHub Title Bar (Fades out and collapses)
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
                      Text(
                        'UniHub',
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.shopping_bag_outlined, color: Colors.black, size: 24),
                        onPressed: onCartTap,
                      ),
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(Icons.notifications_outlined, color: Colors.black, size: 24),
                            onPressed: onNotificationTap,
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6B35),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Location/Search Section (Moves up to where UniHub title was)
          Positioned(
            // FIXED: Stays at statusBarHeight when fully collapsed, avoiding status bar clash
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
                          Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            '$selectedCampus, $selectedState',
                            style: AppTextStyles.body.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onSearchTap,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(Icons.search, color: Colors.grey.shade600, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'Search for products, sellers, or ...',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
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
  bool shouldRebuild(_CombinedHeaderDelegate oldDelegate) =>
    statusBarHeight != oldDelegate.statusBarHeight ||
    selectedCampus != oldDelegate.selectedCampus ||
    selectedState != oldDelegate.selectedState;
}


// Tab bar delegate (for sticky tabs above product grid)
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  
  @override
  double get minExtent => _tabBar.preferredSize.height;
  
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => 
    Container(color: AppColors.white, child: _tabBar);
  
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}