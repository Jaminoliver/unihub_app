// home_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../services/product_service.dart';
import '../services/auth_service.dart';
import '../services/university_category_services.dart';
import '../services/cart_service.dart';
import '../services/wishlist_service.dart';
import '../services/product_view_service.dart';
import '../models/product_model.dart';
import '../models/university_category_models.dart';
import '../widgets/unihub_loading_widget.dart';
import '../widgets/campus_pulse_widget.dart';
import './search_screen.dart';
import './notifications_screen.dart';
import './wishlist_screen.dart';
import 'special_deal_products_screen.dart';
import 'product_details_screen.dart';
import '../widgets/home_screen_widgets.dart';

const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class HomeScreen extends StatefulWidget {
  final ScrollController? scrollController;
  const HomeScreen({super.key, this.scrollController});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  
  final _productService = ProductService();
  final _authService = AuthService();
  final _cartService = CartService();
  final _universityService = UniversityService();
  final _wishlistService = WishlistService();
  final _viewService = ProductViewService();
  
  String _selectedCampus = 'University';
  String? _selectedUniversityId;
  String _selectedState = 'State';
  
  List<ProductModel> _allProducts = [];
  List<ProductModel> _featuredProducts = [];
  List<ProductModel> _lowestPriceProducts = [];
  List<UniversityModel> _universities = [];
  
  bool _isLoadingData = true;
  bool _isLoadingProducts = true;
  
  Set<String> _favorites = {};
  final Set<String> _cart = {};
  Timer? _viewCountTimer;
  String? _isAddingToCartId;
  Map<String, int> _viewerCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController = widget.scrollController ?? ScrollController();
    _initializeData();
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) _startViewCountUpdates();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (widget.scrollController == null) _scrollController.dispose();
    _viewCountTimer?.cancel();
    super.dispose();
  }

  void _startViewCountUpdates() {
    _loadViewerCounts();
    _viewCountTimer = Timer.periodic(Duration(seconds: 60), (_) {
      if (mounted) _loadViewerCounts();
    });
  }

  Future<void> _loadViewerCounts() async {
    try {
      final counts = <String, int>{};
      final allProductIds = [..._featuredProducts.map((p) => p.id), ..._allProducts.map((p) => p.id), ..._lowestPriceProducts.map((p) => p.id)].toSet().toList();
      
      await Future.wait(allProductIds.map((id) async {
        try {
          final count = await _viewService.getTotalViews(id).timeout(Duration(seconds: 2), onTimeout: () => 0);
          counts[id] = count;
        } catch (e) {
          counts[id] = 0;
        }
      }));
      
      if (mounted) setState(() => _viewerCounts = counts);
    } catch (e) {
      debugPrint('Error loading viewer counts: $e');
    }
  }

  Future<void> _initializeData() async {
    setState(() => _isLoadingData = true);
    try {
      await Future.wait([_loadUniversities(), _loadWishlistIds()]);
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

  Future<void> _refreshProductData() async {
    if (_selectedUniversityId == null) return;
    setState(() => _isLoadingProducts = true);
    try {
      await Future.wait([_loadAllProducts(), _loadFeaturedProducts(), _loadLowestPriceProducts()]);
      _loadViewerCounts();
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
      final products = await _productService.getTrendingProducts(universityId: _selectedUniversityId, limit: 12);
      if (mounted) setState(() => _featuredProducts = products);
    } catch (e) {
      debugPrint('Error loading featured products: $e');
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
      _lowestPriceProducts = [];
    });
    await _refreshProductData();
  }

  Future<void> _navigateToProductDetails(ProductModel product) async {
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: product)));
  if (mounted) _loadViewerCounts();
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
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add: ${e.toString()}'), backgroundColor: AppColors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _isAddingToCartId = null);
    }
  }

  void _navigateToSpecialDeal(String dealType, String dealTitle) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => SpecialDealProductsScreen(dealType: dealType, dealTitle: dealTitle, universityId: _selectedUniversityId, state: _selectedState)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return Scaffold(backgroundColor: AppColors.getBackground(context), body: Center(child: UniHubLoader(size: 80)));

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: CombinedHeaderDelegate(
                statusBarHeight: MediaQuery.of(context).padding.top,
                selectedCampus: _selectedCampus,
                selectedState: _selectedState,
                onLocationTap: () => _showCampusSelectorBottomSheet(),
                onSearchTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SearchScreen(universityId: _selectedUniversityId, universityName: _selectedCampus, state: _selectedState))),
                onCartTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WishlistScreen())),
                onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SizedBox(height: 4),
                  CategoriesDirectory(selectedUniversityId: _selectedUniversityId, selectedState: _selectedState),
                  SizedBox(height: 8),
                  _divider(),
                  TrendingSection(
                    selectedCampus: _selectedCampus,
                    selectedState: _selectedState,
                    featuredProducts: _featuredProducts,
                    isLoadingProducts: _isLoadingProducts,
                    favorites: _favorites,
                    cart: _cart,
                    isAddingToCartId: _isAddingToCartId,
                    viewerCounts: _viewerCounts,
                    onProductTap: _navigateToProductDetails,
                    onToggleFavorite: (id) => _toggleFavorite(id),
                    onToggleCart: _toggleCart,
                  ),
                  SizedBox(height: 8),
                  _divider(),
                  SizedBox(height: 12),
                  _isLoadingProducts ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SpecialDealsGridSkeleton()) : SpecialDealsGrid(onDealTap: _navigateToSpecialDeal),
                  SizedBox(height: 8),
                  _divider(),
                  SizedBox(height: 12),
                  CampusPulseWidget(universityId: _selectedUniversityId),
                  SizedBox(height: 8),
                ],
              ),
            ),
            SliverPersistentHeader(
              delegate: SliverAppBarDelegate(TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryOrange,
                unselectedLabelColor: AppColors.getTextMuted(context),
                indicatorColor: AppColors.primaryOrange,
                indicatorWeight: 2,
                labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                tabs: const [Tab(text: 'All Products'), Tab(text: 'Picked for You'), Tab(text: 'Lowest Price')],
              )),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            ProductGridPage(
              products: _allProducts,
              isLoading: _isLoadingProducts,
              emptyMessage: 'No products found',
              emptySubtitle: 'Check back later for new listings',
              favorites: _favorites,
              cart: _cart,
              isAddingToCartId: _isAddingToCartId,
              viewerCounts: _viewerCounts,
              onProductTap: _navigateToProductDetails,
              onToggleFavorite: (id) => _toggleFavorite(id),
              onToggleCart: _toggleCart,
            ),
            ProductGridPage(
              products: _featuredProducts,
              isLoading: _isLoadingProducts,
              emptyMessage: 'Nothing Picked For You... Yet!',
              emptySubtitle: 'Browse more items so we can learn what you like.',
              favorites: _favorites,
              cart: _cart,
              isAddingToCartId: _isAddingToCartId,
              viewerCounts: _viewerCounts,
              onProductTap: _navigateToProductDetails,
              onToggleFavorite: (id) => _toggleFavorite(id),
              onToggleCart: _toggleCart,
            ),
            ProductGridPage(
              products: _lowestPriceProducts,
              isLoading: _isLoadingProducts,
              emptyMessage: 'No Products Found',
              emptySubtitle: 'We couldn\'t find any items for this filter.',
              favorites: _favorites,
              cart: _cart,
              isAddingToCartId: _isAddingToCartId,
              viewerCounts: _viewerCounts,
              onProductTap: _navigateToProductDetails,
              onToggleFavorite: (id) => _toggleFavorite(id),
              onToggleCart: _toggleCart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3));

  void _showCampusSelectorBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getCardBackground(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => CampusSelectorBottomSheet(
        universities: _universities,
        selectedUniversityId: _selectedUniversityId,
        selectedState: _selectedState,
        isLoadingData: _isLoadingData,
        onCampusChanged: _onCampusChanged,
      ),
    );
  }
}

class SpecialDealsGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.getCardBackground(context),
          border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
        ),
        child: Center(child: UniHubLoader(size: 30)),
      ),
    );
  }
}