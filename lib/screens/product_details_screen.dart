import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../models/product_model.dart';
import '../models/review_model.dart';
import '../services/product_service.dart';
import '../services/reviews_service.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';

// Modern Color Palette
class AppTheme {
  static const orangeStart = Color(0xFFFF6B35);
  static const orangeEnd = Color(0xFFFF8C42);
  static const navyBlue = Color(0xFF1E3A8A);
  static const slateStart = Color(0xFF64748B);
  static const slateEnd = Color(0xFF475569);
  static const white = Colors.white;
  static const ashGray = Color(0xFFF5F5F7);
  static const textDark = Color(0xFF1F2937);
  static const textLight = Color(0xFF6B7280);
  
  static final gradient = LinearGradient(
    colors: [orangeStart, orangeEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static final slateGradient = LinearGradient(
    colors: [slateStart, slateEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

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

  ProductModel? _product;
  List<ReviewModel> _reviews = [];
  bool _isLoading = true;
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  int _cartItemCount = 0;
  bool _isAddingToCart = false;
  bool _showSuccessMessage = false;
  Timer? _countdownTimer;
  Duration? _flashSaleTimeLeft;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      _product = widget.product ?? await _productService.getProductById(widget.productId!);
      if (_product == null) throw Exception('Product not found');
      
      _productService.incrementViewCount(_product!.id);
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

  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    setState(() => _isAddingToCart = true);
    try {
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('Login required');
      await _cartService.addToCart(userId: userId, productId: _product!.id);
      await _loadCartCount();
      
      // Show success animation
      setState(() {
        _isAddingToCart = false;
        _showSuccessMessage = true;
      });
      
      // Hide success message after 2 seconds
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) setState(() => _showSuccessMessage = false);
      });
    } catch (e) {
      setState(() => _isAddingToCart = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${e.toString()}', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  List<String> _getImageUrls() {
    if (_product == null) return ['placeholder'];
    
    // Handle if imageUrls is empty
    if (_product!.imageUrls.isEmpty) return ['placeholder'];
    
    List<String> urls = [];
    
    // Check if the first item is a JSON string that needs parsing
    final firstUrl = _product!.imageUrls.first;
    if (firstUrl.startsWith('[') || firstUrl.startsWith('"{')) {
      try {
        // Parse the JSON string
        final cleanUrl = firstUrl.replaceAll('"{', '').replaceAll('}"', '').replaceAll(r'\', '');
        final List<dynamic> parsed = jsonDecode(cleanUrl);
        urls = parsed.map((e) => e.toString()).toList();
      } catch (e) {
        print('Error parsing image URLs: $e');
        urls = _product!.imageUrls;
      }
    } else {
      urls = _product!.imageUrls;
    }
    
    // Filter out invalid placeholder URLs and validate URLs
    final validUrls = urls.where((url) {
      // Skip empty URLs
      if (url.isEmpty) return false;
      
      // Skip placeholder URLs
      if (url.contains('placehold.co')) {
        print('Skipping placeholder URL: $url');
        return false;
      }
      
      // Only allow valid HTTP(S) URLs
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        print('Skipping invalid URL (no http/https): $url');
        return false;
      }
      
      // Additional check: make sure it's from your Supabase storage
      if (!url.contains('supabase.co')) {
        print('Warning: URL not from Supabase: $url');
        return false; // Change to false to skip non-Supabase URLs
      }
      
      print('Valid image URL: $url');
      return true;
    }).toList();
    
    print('Total valid URLs found: ${validUrls.length}');
    return validUrls.isEmpty ? ['placeholder'] : validUrls;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _LoadingScreen();
    if (_product == null) return _ErrorScreen();

    return Scaffold(
      backgroundColor: AppTheme.ashGray,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _ImageCarousel(
                      images: _getImageUrls(),
                      discount: _product!.discountPercentage,
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      currentIndex: _currentImageIndex,
                    ),
                    SizedBox(height: 12),
                    if (_product!.isFlashSale && _flashSaleTimeLeft != null && !_flashSaleTimeLeft!.isNegative)
                      _FlashSaleBanner(timeLeft: _flashSaleTimeLeft!),
                    _ProductInfo(
                      product: _product!,
                      isFavorite: _isFavorite,
                      onFavoriteToggle: () => setState(() => _isFavorite = !_isFavorite),
                    ),
                    _UniversityCard(product: _product!),
                    _PromoBanners(),
                    _DetailsCard(product: _product!),
                    _ReviewsCard(reviews: _reviews),
                    _RelatedProducts(),
                    SizedBox(height: 100),
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

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.white,
      expandedHeight: 0,
      toolbarHeight: 56,
      leading: _CircleButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        _CircleButton(icon: Icons.share_rounded, onPressed: () {}),
        SizedBox(width: 8),
      ],
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
          color: AppTheme.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: Row(
          children: [
            _CartButton(count: _cartItemCount, onTap: () => Navigator.pushNamed(context, '/cart')),
            SizedBox(width: 10),
            Expanded(
              child: _GradientButton(
                text: _product?.isAvailable == true ? 'Add to Cart' : 'Out of Stock',
                icon: Icons.shopping_cart_outlined,
                isLoading: _isAddingToCart,
                onPressed: _product?.isAvailable == true ? _addToCart : null,
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
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Color(0xFF10B981).withOpacity(0.4), blurRadius: 20, offset: Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                ),
                SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Added to Cart!', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Item successfully added', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11)),
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

// Reusable Widgets
class _LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ashGray,
      body: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.gradient,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppTheme.orangeStart.withOpacity(0.3), blurRadius: 24)],
          ),
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ashGray,
      body: Center(child: Text('Product not found', style: TextStyle(color: AppTheme.textLight))),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: Offset(0, 2))],
      ),
      child: IconButton(
        icon: ShaderMask(
          shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _ImageCarousel extends StatelessWidget {
  final List<String> images;
  final int? discount;
  final Function(int) onPageChanged;
  final int currentIndex;

  const _ImageCarousel({
    required this.images,
    this.discount,
    required this.onPageChanged,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            CarouselSlider(
              options: CarouselOptions(
                height: 300,
                viewportFraction: 1.0,
                enableInfiniteScroll: images.length > 1,
                onPageChanged: (i, _) => onPageChanged(i),
              ),
              items: images.map((url) => url == 'placeholder'
                  ? Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                        child: Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.white),
                      ),
                    )
                  : Image.network(
                      url, 
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: 300,
                      errorBuilder: (context, error, stackTrace) {
                        print('❌ Image load error for URL: $url');
                        print('❌ Error details: $error');
                        return Container(
                          color: AppTheme.ashGray,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                                  child: Icon(Icons.image_not_supported_outlined, size: 60, color: Colors.white),
                                ),
                                SizedBox(height: 8),
                                Text('Image unavailable', style: TextStyle(color: AppTheme.textLight, fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppTheme.ashGray,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppTheme.orangeStart,
                              strokeWidth: 3,
                            ),
                          ),
                        );
                      },
                    )).toList(),
            ),
            if (discount != null && discount! > 0)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppTheme.gradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppTheme.orangeStart.withOpacity(0.3), blurRadius: 8)],
                  ),
                  child: Text('-${discount!}%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            if (images.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (i) => AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: 3),
                      width: currentIndex == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: currentIndex == i ? AppTheme.gradient : null,
                        color: currentIndex == i ? null : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
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
}

class _FlashSaleBanner extends StatelessWidget {
  final Duration timeLeft;

  const _FlashSaleBanner({required this.timeLeft});

  @override
  Widget build(BuildContext context) {
    final h = timeLeft.inHours;
    final m = timeLeft.inMinutes % 60;
    final s = timeLeft.inSeconds % 60;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppTheme.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.orangeStart.withOpacity(0.3), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: Colors.white, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FLASH SALE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
                Text('Hurry! Limited time', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.navyBlue, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductInfo extends StatelessWidget {
  final ProductModel product;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _ProductInfo({required this.product, required this.isFavorite, required this.onFavoriteToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyBlue, letterSpacing: -0.3),
                ),
              ),
              GestureDetector(
                onTap: onFavoriteToggle,
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isFavorite ? AppTheme.gradient : null,
                    color: isFavorite ? null : AppTheme.ashGray,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.white : AppTheme.orangeStart, size: 18),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                child: Text('₦${product.price.toStringAsFixed(0)}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              if (product.originalPrice != null && product.originalPrice! > product.price) ...[
                SizedBox(width: 10),
                Text('₦${product.originalPrice!.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, color: AppTheme.textLight, decoration: TextDecoration.lineThrough)),
              ],
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 14),
                    SizedBox(width: 5),
                    Text('${(product.averageRating ?? 0.0).toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue)),
                    Text(' (${product.reviewCount})', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                  ],
                ),
              ),
              Spacer(),
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                child: Icon(Icons.visibility_outlined, size: 14, color: Colors.white),
              ),
              SizedBox(width: 5),
              Text('${product.viewCount}', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
            ],
          ),
          if (product.stockQuantity <= 10) ...[
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.orangeStart.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, size: 14, color: AppTheme.orangeStart),
                  SizedBox(width: 6),
                  Text('Only ${product.stockQuantity} left!', style: TextStyle(color: AppTheme.orangeStart, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UniversityCard extends StatelessWidget {
  final ProductModel product;

  const _UniversityCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(gradient: AppTheme.gradient, shape: BoxShape.circle),
            child: Icon(Icons.location_on_outlined, color: Colors.white, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.universityName ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue)),
                if (product.sellerName != null) Text('by ${product.sellerName}', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
              ],
            ),
          ),
          Icon(Icons.verified, color: Color(0xFF10B981), size: 16),
        ],
      ),
    );
  }
}

class _PromoBanners extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final promos = [
      {'title': '🔒 Secure Payment', 'subtitle': 'Money held in escrow'},
      {'title': '💰 Part Payment', 'subtitle': 'Available for ₦35k+'},
      {'title': '↩️ Easy Returns', 'subtitle': 'Full refund guarantee'},
    ];

    return Container(
      height: 85,
      margin: EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12),
        itemCount: promos.length,
        itemBuilder: (_, i) {
          final promo = promos[i];
          return Container(
            width: 160,
            margin: EdgeInsets.only(right: 10),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.gradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: AppTheme.orangeStart.withOpacity(0.25), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(promo['title'] as String, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 3),
                Text(promo['subtitle'] as String, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailsCard extends StatefulWidget {
  final ProductModel product;

  const _DetailsCard({required this.product});

  @override
  State<_DetailsCard> createState() => _DetailsCardState();
}

class _DetailsCardState extends State<_DetailsCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                Text('Product Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
                Spacer(),
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                  child: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            SizedBox(height: 12),
            _DetailRow(label: 'Condition', value: widget.product.condition.toUpperCase()),
            if (widget.product.brand != null) _DetailRow(label: 'Brand', value: widget.product.brand!),
            if (widget.product.color != null) _DetailRow(label: 'Color', value: widget.product.color!),
            _DetailRow(label: 'Category', value: widget.product.categoryName ?? 'N/A'),
            SizedBox(height: 12),
            Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.navyBlue)),
            SizedBox(height: 6),
            Text(
              widget.product.description.isEmpty ? 'No description' : widget.product.description,
              style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textLight),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 85, child: Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textLight))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.navyBlue))),
        ],
      ),
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  final List<ReviewModel> reviews;

  const _ReviewsCard({required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reviews (${reviews.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
          SizedBox(height: 12),
          if (reviews.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                      child: Icon(Icons.rate_review_outlined, size: 40, color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    Text('No reviews yet', style: TextStyle(color: AppTheme.textLight, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ...reviews.take(2).map((r) => _ReviewItem(review: r)),
          if (reviews.length > 2)
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: _GradientButton(
                text: 'See All ${reviews.length} Reviews',
                onPressed: () {},
                isSmall: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final ReviewModel review;

  const _ReviewItem({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.ashGray, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.orangeStart.withOpacity(0.1),
                child: Text((review.userName ?? 'U')[0].toUpperCase(), style: TextStyle(color: AppTheme.orangeStart, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName ?? 'Anonymous', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyBlue)),
                    Row(
                      children: [
                        ...List.generate(5, (i) => Icon(i < review.rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 12)),
                        SizedBox(width: 6),
                        Text(review.timeAgo, style: TextStyle(fontSize: 10, color: AppTheme.textLight)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(review.comment, style: TextStyle(fontSize: 11, height: 1.4, color: AppTheme.textLight)),
        ],
      ),
    );
  }
}

class _RelatedProducts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                child: Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.white),
              ),
              SizedBox(width: 8),
              Text('You May Also Like', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (_, i) {
                return Container(
                  width: 130,
                  margin: EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.ashGray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: Center(
                          child: ShaderMask(
                            shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                            child: Icon(Icons.image_outlined, size: 35, color: Colors.white),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Product ${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.navyBlue), maxLines: 2),
                            SizedBox(height: 5),
                            ShaderMask(
                              shaderCallback: (bounds) => AppTheme.gradient.createShader(bounds),
                              child: Text('₦${(15000 + (i * 5000)).toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _CartButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.orangeStart, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, color: AppTheme.orangeStart, size: 24),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: AppTheme.gradient,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    '$count',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool isSmall;

  const _GradientButton({
    required this.text,
    this.icon,
    this.isLoading = false,
    this.onPressed,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isSmall ? 42 : 52,
      decoration: BoxDecoration(
        gradient: onPressed != null ? AppTheme.gradient : null,
        color: onPressed == null ? AppTheme.textLight.withOpacity(0.3) : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed != null
            ? [BoxShadow(color: AppTheme.orangeStart.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 4))]
            : [],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: isSmall ? 16 : 20, color: Colors.white),
                    SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: isSmall ? 13 : 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}