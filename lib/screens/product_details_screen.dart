import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/product_model.dart';
import '../models/review_model.dart';
import '../services/product_service.dart';
import '../services/reviews_service.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../services/product_view_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/related_product_card.dart';
import 'dart:async';
import 'dart:convert';

class ProductDetailsScreen extends StatefulWidget {
  final ProductModel? product;
  final String? productId;

  const ProductDetailsScreen({super.key, this.product, this.productId})
      : assert(product != null || productId != null);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _productService = ProductService();
  final _reviewService = ReviewService();
  final _cartService = CartService();
  final _authService = AuthService();
  final _viewService = ProductViewService();
  final _wishlistService = WishlistService();

  ProductModel? _product;
  List<ReviewModel> _reviews = [];
  bool _isLoading = true;
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  int _cartItemCount = 0;
  bool _isAddingToCart = false;
  bool _showSuccessMessage = false;
  Timer? _countdownTimer;
  Timer? _viewUpdateTimer;
  Duration? _flashSaleTimeLeft;
  bool _isDetailsExpanded = false;
  bool _isReviewsExpanded = false;
  int _totalViews = 0;
  
  // Color and Size Selection
  String? _selectedColor;
  String? _selectedSize;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _viewUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      _product = widget.product ?? await _productService.getProductById(widget.productId!);
      if (_product == null) throw Exception('Product not found');
      
      _productService.incrementViewCount(_product!.id);
      await _viewService.trackProductView(_product!.id);
      _startViewTracking();
      
      final userId = _authService.currentUserId;
      if (userId != null) {
        final isInWishlist = await _wishlistService.isInWishlist(
          userId: userId,
          productId: _product!.id,
        );
        if (mounted) setState(() => _isFavorite = isInWishlist);
      }
      
      if (_product!.isFlashSale && _product!.flashSaleEndsAt != null) {
        _startCountdown(_product!.flashSaleEndsAt!);
      }
      
      _loadReviews();
      _loadCartCount();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) Navigator.pop(context);
    }
  }

  void _startViewTracking() {
    _updateViewerCount();
    _viewUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return timer.cancel();
      _viewService.updateViewTimestamp(_product!.id);
      _updateViewerCount();
    });
  }

  Future<void> _updateViewerCount() async {
    final count = await _viewService.getTotalViews(_product!.id);
    if (mounted) setState(() => _totalViews = count);
  }

  Future<void> _loadReviews() async {
    final reviews = await _reviewService.getProductReviews(_product!.id, limit: 10);
    if (mounted) setState(() => _reviews = reviews);
  }

  Future<void> _loadCartCount() async {
    final userId = _authService.currentUserId;
    if (userId == null) return;
    final items = await _cartService.getCartItems(userId);
    if (mounted) setState(() => _cartItemCount = items.fold(0, (p, i) => p + i.quantity));
  }

  void _startCountdown(DateTime endTime) {
    _flashSaleTimeLeft = endTime.difference(DateTime.now());
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      final newTime = endTime.difference(DateTime.now());
      setState(() => _flashSaleTimeLeft = newTime.isNegative ? Duration.zero : newTime);
      if (newTime.isNegative) timer.cancel();
    });
  }

  Future<void> _toggleFavorite() async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    if (_isFavorite) {
      setState(() => _isFavorite = false);
      await _wishlistService.removeFromWishlist(userId: userId, productId: _product!.id);
    } else {
      setState(() => _isFavorite = true);
      await _wishlistService.addToWishlist(userId: userId, productId: _product!.id);
    }
  }

  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    
    // Validate selections if product has colors/sizes
    if (_product!.colors != null && _product!.colors!.isNotEmpty && _selectedColor == null) {
      _showSnackBar('Please select a color', isError: true);
      return;
    }
    if (_product!.sizes != null && _product!.sizes!.isNotEmpty && _selectedSize == null) {
      _showSnackBar('Please select a size', isError: true);
      return;
    }
    
    setState(() => _isAddingToCart = true);
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('Login required');
      
      await _cartService.addToCart(
        userId: userId,
        productId: _product!.id,
        selectedColor: _selectedColor,
        selectedSize: _selectedSize,
      );
      
      await _loadCartCount();
      
      setState(() {
        _isAddingToCart = false;
        _showSuccessMessage = true;
      });
      
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) setState(() => _showSuccessMessage = false);
      });
    } catch (e) {
      setState(() => _isAddingToCart = false);
      _showSnackBar('Failed: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Color(0xFFEF4444) : Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<String> _getImageUrls() {
    if (_product == null || _product!.imageUrls.isEmpty) return ['placeholder'];
    
    List<String> urls = [];
    final firstUrl = _product!.imageUrls.first;
    
    if (firstUrl.startsWith('[') || firstUrl.startsWith('"{')) {
      try {
        final cleanUrl = firstUrl.replaceAll('"{', '').replaceAll('}"', '').replaceAll(r'\', '');
        final List<dynamic> parsed = jsonDecode(cleanUrl);
        urls = parsed.map((e) => e.toString()).toList();
      } catch (e) {
        urls = _product!.imageUrls;
      }
    } else {
      urls = _product!.imageUrls;
    }
    
    final validUrls = urls.where((url) {
      return url.isNotEmpty && 
             !url.contains('placehold.co') && 
             (url.startsWith('http://') || url.startsWith('https://')) &&
             url.contains('supabase.co');
    }).toList();
    
    return validUrls.isEmpty ? ['placeholder'] : validUrls;
  }

  String _formatPrice(double price) => '₦${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();
    if (_product == null) return _buildErrorScreen();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildImageCarousel(),
                    SizedBox(height: 8),
                    if (_product!.isFlashSale && _flashSaleTimeLeft != null && !_flashSaleTimeLeft!.isNegative)
                      _buildFlashSaleBanner(),
                    _buildProductInfo(),
                    SizedBox(height: 8),
                    _buildUniversityCard(),
                    SizedBox(height: 8),
                    _buildPromoBanners(),
                    SizedBox(height: 16),
                    _buildDivider(),
                    SizedBox(height: 16),
                    _buildDetailsCard(),
                    SizedBox(height: 16),
                    _buildDivider(),
                    SizedBox(height: 16),
                    _buildReviewsCard(),
                    SizedBox(height: 16),
                    _buildDivider(),
                    SizedBox(height: 16),
                    _buildRelatedProducts(),
                    SizedBox(height: 90),
                  ],
                ),
              ),
            ],
          ),
          _buildBottomBar(),
          if (_showSuccessMessage) _buildSuccessOverlay(),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: Text('Product not found', style: AppTextStyles.body.copyWith(color: AppColors.textLight))),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      expandedHeight: 0,
      toolbarHeight: 56,
      leading: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
          ),
          child: IconButton(
            icon: Icon(Icons.share_rounded, color: Color(0xFFFF6B35), size: 20),
            onPressed: () {},
          ),
        ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildImageCarousel() {
    final images = _getImageUrls();
    final CarouselSliderController carouselController = CarouselSliderController();
    
    return Container(
      height: 300,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            CarouselSlider(
              carouselController: carouselController,
              options: CarouselOptions(
                height: 300,
                viewportFraction: 1.0,
                enableInfiniteScroll: images.length > 1,
                onPageChanged: (i, _) => setState(() => _currentImageIndex = i),
                scrollPhysics: BouncingScrollPhysics(),
              ),
              items: images.map((url) => url == 'placeholder'
                ? Center(child: Icon(Icons.shopping_bag_outlined, size: 60, color: AppColors.textLight.withOpacity(0.3)))
                : Image.network(url, fit: BoxFit.contain, width: double.infinity,
                    errorBuilder: (_, __, ___) => Center(child: Icon(Icons.image_not_supported_outlined, size: 50, color: AppColors.textLight.withOpacity(0.5))),
                    loadingBuilder: (_, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35), strokeWidth: 2)),
                  )).toList(),
            ),
            if (_product!.discountPercentage != null && _product!.discountPercentage! > 0)
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Color(0xFFFF6B35), borderRadius: BorderRadius.circular(12)),
                  child: Text('-${_product!.discountPercentage!}%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            if (images.length > 1)
              Positioned(
                bottom: 16, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (i) => AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 3),
                    width: _currentImageIndex == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == i ? Color(0xFFFF6B35) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashSaleBanner() {
    final h = _flashSaleTimeLeft!.inHours;
    final m = _flashSaleTimeLeft!.inMinutes % 60;
    final s = _flashSaleTimeLeft!.inSeconds % 60;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: Color(0xFFFF6B35), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.bolt, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FLASH SALE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                Text('Hurry! Limited time', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Text('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(_product!.name, style: AppTextStyles.heading.copyWith(fontSize: 16, color: Colors.black))),
              GestureDetector(
                onTap: _toggleFavorite,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _isFavorite ? Color(0xFFFF6B35) : AppColors.background, shape: BoxShape.circle),
                  child: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.white : Color(0xFFFF6B35), size: 18),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatPrice(_product!.price), style: AppTextStyles.price.copyWith(fontSize: 22, color: Color(0xFFFF6B35))),
              if (_product!.originalPrice != null && _product!.originalPrice! > _product!.price) ...[
                SizedBox(width: 8),
                Text(_formatPrice(_product!.originalPrice!), style: TextStyle(fontSize: 13, color: AppColors.textLight, decoration: TextDecoration.lineThrough)),
              ],
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 13),
                    SizedBox(width: 4),
                    Text('${(_product!.averageRating ?? 0.0).toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
                    Text(' (${_product!.reviewCount})', style: TextStyle(fontSize: 10, color: Colors.black87)),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility, size: 13, color: Color(0xFFFF6B35)),
                    SizedBox(width: 4),
                    Text('$_totalViews ${_totalViews == 1 ? 'view' : 'views'}', style: TextStyle(fontSize: 11, color: Color(0xFFFF6B35), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          if (_product!.stockQuantity <= 10) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, size: 13, color: Color(0xFFFF6B35)),
                  SizedBox(width: 5),
                  Text('Only ${_product!.stockQuantity} left!', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUniversityCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Color(0xFFFF6B35), size: 20),
          SizedBox(width: 8),
          Expanded(child: Text(_product!.universityAbbr ?? _product!.universityName ?? 'Unknown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black))),
        ],
      ),
    );
  }

  Widget _buildPromoBanners() {
    final promos = [
      {'icon': Icons.lock_rounded, 'title': 'Secure Payment', 'subtitle': 'Escrow protection'},
      {'icon': Icons.account_balance_wallet, 'title': 'Part Payment', 'subtitle': 'Available for ₦35k+'},
      {'icon': Icons.autorenew_rounded, 'title': 'Easy Returns', 'subtitle': 'Full refund guarantee'},
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: promos.map((promo) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(promo['icon'] as IconData, color: Color(0xFFFF6B35), size: 28),
            SizedBox(height: 6),
            Text(promo['title'] as String, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 10), textAlign: TextAlign.center),
            SizedBox(height: 2),
            Text(promo['subtitle'] as String, style: TextStyle(color: Colors.black54, fontSize: 9), textAlign: TextAlign.center),
          ],
        )).toList(),
      ),
    );
  }

  Widget _buildDivider() => Container(margin: EdgeInsets.symmetric(horizontal: 16), height: 1, color: Colors.grey.shade300);

  Widget _buildDetailsCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isDetailsExpanded = !_isDetailsExpanded),
            child: Row(
              children: [
                Text('Product Details', style: TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold)),
                Spacer(),
                Icon(_isDetailsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.black54, size: 24),
              ],
            ),
          ),
          SizedBox(height: 10),
          _buildDetailRow('Condition', _product!.condition.toUpperCase()),
          if (_product!.brand != null) _buildDetailRow('Brand', _product!.brand!),
          
          // Color Selection
          if (_product!.colors != null && _product!.colors!.isNotEmpty) ...[
            SizedBox(height: 12),
            Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
            SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _product!.colors!.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Color(0xFFFF6B35) : Colors.white,
                      border: Border.all(color: isSelected ? Color(0xFFFF6B35) : Colors.grey.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(color, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87)),
                  ),
                );
              }).toList(),
            ),
          ],
          
          // Size Selection
          if (_product!.sizes != null && _product!.sizes!.isNotEmpty) ...[
            SizedBox(height: 12),
            Text('Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
            SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _product!.sizes!.map((size) {
                final isSelected = _selectedSize == size;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSize = size),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? Color(0xFFFF6B35) : Colors.white,
                      border: Border.all(color: isSelected ? Color(0xFFFF6B35) : Colors.grey.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(size, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87)),
                  ),
                );
              }).toList(),
            ),
          ],
          
          if (_isDetailsExpanded) ...[
            if (_product!.color != null) _buildDetailRow('Color', _product!.color!),
            _buildDetailRow('Category', _product!.categoryName ?? 'N/A'),
            SizedBox(height: 10),
            Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
            SizedBox(height: 5),
            Text(_product!.description.isEmpty ? 'No description' : _product!.description, style: TextStyle(fontSize: 11, height: 1.4, color: Colors.black87)),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 11, color: Colors.black87))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black))),
        ],
      ),
    );
  }

  Widget _buildReviewsCard() {
    final avgRating = _reviews.isEmpty ? 0.0 : _reviews.fold<double>(0, (sum, r) => sum + r.rating) / _reviews.length;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isReviewsExpanded = !_isReviewsExpanded),
            child: Row(
              children: [
                Text('Reviews', style: TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Icon(Icons.star, color: Color(0xFFFF6B35), size: 16),
                SizedBox(width: 4),
                Text('${avgRating.toStringAsFixed(1)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                SizedBox(width: 4),
                Text('(${_reviews.length})', style: TextStyle(fontSize: 13, color: Colors.black54)),
                Spacer(),
                Icon(_isReviewsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.black54, size: 24),
              ],
            ),
          ),
          SizedBox(height: 12),
          if (_reviews.isEmpty)
            Center(child: Padding(padding: EdgeInsets.all(16), child: Column(children: [
              Icon(Icons.rate_review_outlined, size: 35, color: AppColors.textLight.withOpacity(0.5)),
              SizedBox(height: 8),
              Text('No reviews yet', style: TextStyle(color: AppColors.textLight, fontSize: 11)),
            ])))
          else
            ...(_isReviewsExpanded ? _reviews : _reviews.take(2)).map((r) => Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFFFF6B35).withOpacity(0.1),
                        child: Text((r.userName?.isNotEmpty == true) ? r.userName![0].toUpperCase() : 'A',
                          style: TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.userName ?? 'Anonymous', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                            Row(
                              children: [
                                ...List.generate(5, (i) => Icon(i < r.ratingInt ? Icons.star : Icons.star_border, color: Color(0xFFFF6B35), size: 12)),
                                SizedBox(width: 6),
                                Text(r.timeAgo, style: TextStyle(fontSize: 9, color: Colors.black54)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(r.comment, style: TextStyle(fontSize: 11, height: 1.4, color: Colors.black87)),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildRelatedProducts() {
    return FutureBuilder<List<ProductModel>>(
      future: _productService.getRelatedProducts(
        currentProductId: _product!.id,
        categoryId: _product!.categoryId,
        universityId: _product!.universityId,
        limit: 10,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You Might Also Like', style: TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    return RelatedProductCard(
                      product: snapshot.data![index],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: snapshot.data![index])),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.all(14).copyWith(bottom: 14 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/cart', (route) => false),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 24),
                    if (_cartItemCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]),
                          constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text('$_cartItemCount', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 54,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _product?.isAvailable == true ? LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                    color: _product?.isAvailable == true ? null : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _product?.isAvailable == true ? [BoxShadow(color: Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 12, offset: Offset(0, 4))] : null,
                  ),
                  child: ElevatedButton(
                    onPressed: _product?.isAvailable == true ? _addToCart : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isAddingToCart
                        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_bag_rounded, size: 20, color: Colors.white),
                              SizedBox(width: 10),
                              Text(_product?.isAvailable == true ? 'Add to Cart' : 'Out of Stock', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _showSuccessMessage ? 1.0 : 0.0,
          duration: Duration(milliseconds: 300),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 40),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Color(0xFF10B981).withOpacity(0.4), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text('Added to Cart!', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}