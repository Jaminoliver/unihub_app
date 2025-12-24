// product_details_screen.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../constants/app_colors.dart';
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

const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ProductDetailsScreen extends StatefulWidget {
  final ProductModel? product;
  final String? productId;

  const ProductDetailsScreen({super.key, this.product, this.productId}) : assert(product != null || productId != null);

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
  Timer? _viewUpdateTimer;
  bool _isDetailsExpanded = false;
  bool _isReviewsExpanded = false;
  int _totalViews = 0;
  String? _selectedColor;
  String? _selectedSize;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
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
        final isInWishlist = await _wishlistService.isInWishlist(userId: userId, productId: _product!.id);
        if (mounted) setState(() => _isFavorite = isInWishlist);
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

      await _cartService.addToCart(userId: userId, productId: _product!.id, selectedColor: _selectedColor, selectedSize: _selectedSize);

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
        backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
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

    final validUrls = urls.where((url) => url.isNotEmpty && !url.contains('placehold.co') && (url.startsWith('http://') || url.startsWith('https://')) && url.contains('supabase.co')).toList();

    return validUrls.isEmpty ? ['placeholder'] : validUrls;
  }

  String _formatPrice(double price) => '₦${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: AppColors.getBackground(context), body: Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)));
    if (_product == null) return Scaffold(backgroundColor: AppColors.getBackground(context), body: Center(child: Text('Product not found', style: TextStyle(color: AppColors.getTextMuted(context)))));

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildImageCarousel(),
                    SizedBox(height: 12),
                    _buildProductInfo(),
                    SizedBox(height: 12),
                    _buildLocation(),
                    SizedBox(height: 12),
                    _buildPromos(),
                    SizedBox(height: 12),
                    _divider(),
                    SizedBox(height: 12),
                    _buildDetails(),
                    SizedBox(height: 12),
                    _divider(),
                    SizedBox(height: 12),
                    _buildReviews(),
                    SizedBox(height: 12),
                    _divider(),
                    SizedBox(height: 12),
                    _buildRelated(),
                    SizedBox(height: 90),
                  ],
                ),
              ),
            ],
          ),
          _buildBottomBar(),
          if (_showSuccessMessage) _buildSuccess(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.getCardBackground(context),
      expandedHeight: 0,
      toolbarHeight: 56,
      leading: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3)),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.getTextPrimary(context), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3)),
          ),
          child: IconButton(
            icon: Icon(Icons.share_rounded, color: AppColors.primaryOrange, size: 18),
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
      height: 280,
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            CarouselSlider(
              carouselController: carouselController,
              options: CarouselOptions(
                height: 280,
                viewportFraction: 1.0,
                enableInfiniteScroll: images.length > 1,
                onPageChanged: (i, _) => setState(() => _currentImageIndex = i),
              ),
              items: images.map((url) => url == 'placeholder'
                      ? Center(child: Icon(Icons.shopping_bag_outlined, size: 50, color: AppColors.getTextMuted(context).withOpacity(0.3)))
                      : Image.network(url, fit: BoxFit.contain, width: double.infinity,
                          errorBuilder: (_, __, ___) => Center(child: Icon(Icons.image, size: 40, color: AppColors.getTextMuted(context))),
                          loadingBuilder: (_, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(color: AppColors.primaryOrange, strokeWidth: 2)))).toList(),
            ),
            if (_product!.discountPercentage != null && _product!.discountPercentage! > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(8)),
                  child: Text('-${_product!.discountPercentage!}%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            if (images.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (i) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 3),
                      width: _currentImageIndex == i ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(color: _currentImageIndex == i ? AppColors.primaryOrange : AppColors.getBorder(context), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    final avgRating = _reviews.isEmpty ? 0.0 : _reviews.fold<double>(0, (sum, r) => sum + r.rating) / _reviews.length;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(_product!.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)))),
              GestureDetector(
                onTap: _toggleFavorite,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(color: _isFavorite ? AppColors.primaryOrange : AppColors.getBackground(context), shape: BoxShape.circle, border: _isFavorite ? null : Border.all(color: AppColors.getBorder(context).withOpacity(0.3))),
                  child: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.white : AppColors.primaryOrange, size: 18),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Text(_formatPrice(_product!.price), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
              if (_product!.originalPrice != null && _product!.originalPrice! > _product!.price) ...[
                SizedBox(width: 8),
                Text(_formatPrice(_product!.originalPrice!), style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context), decoration: TextDecoration.lineThrough)),
              ],
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 12),
                    SizedBox(width: 4),
                    Text('${avgRating.toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.getTextPrimary(context))),
                    Text(' (${_reviews.length})', style: TextStyle(fontSize: 10, color: AppColors.getTextMuted(context))),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 12, color: AppColors.primaryOrange),
                    SizedBox(width: 4),
                    Text('$_totalViews', style: TextStyle(fontSize: 11, color: AppColors.primaryOrange, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          if (_product!.stockQuantity <= 10) ...[
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.errorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, size: 12, color: AppColors.errorRed),
                  SizedBox(width: 4),
                  Text('Only ${_product!.stockQuantity} left!', style: TextStyle(color: AppColors.errorRed, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocation() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.location_on, color: AppColors.primaryOrange, size: 18),
          SizedBox(width: 6),
          Text(_product!.universityAbbr ?? _product!.universityName ?? 'Unknown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
        ],
      ),
    );
  }

  Widget _buildPromos() {
    final promos = [
      {'icon': Icons.lock_rounded, 'title': 'Secure', 'subtitle': 'Escrow'},
      {'icon': Icons.account_balance_wallet, 'title': 'Part Pay', 'subtitle': '₦35k+'},
      {'icon': Icons.autorenew_rounded, 'title': 'Returns', 'subtitle': 'Refund'},
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: promos
            .map((p) => Column(
                  children: [
                    Icon(p['icon'] as IconData, color: AppColors.primaryOrange, size: 24),
                    SizedBox(height: 4),
                    Text(p['title'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                    Text(p['subtitle'] as String, style: TextStyle(fontSize: 9, color: AppColors.getTextMuted(context))),
                  ],
                ))
            .toList(),
      ),
    );
  }

  Widget _divider() => Container(margin: EdgeInsets.symmetric(horizontal: 16), height: 0.5, color: AppColors.getBorder(context).withOpacity(0.3));

  Widget _buildDetails() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isDetailsExpanded = !_isDetailsExpanded),
            child: Row(
              children: [
                Text('Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                Spacer(),
                Icon(_isDetailsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.getTextMuted(context), size: 20),
              ],
            ),
          ),
          SizedBox(height: 8),
          _row('Condition', _product!.condition.toUpperCase()),
          if (_product!.brand != null) _row('Brand', _product!.brand!),
          if (_product!.colors != null && _product!.colors!.isNotEmpty) ...[
            SizedBox(height: 8),
            Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
            SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _product!.colors!
                  .map((color) => GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedColor == color ? AppColors.primaryOrange : AppColors.getCardBackground(context),
                            border: Border.all(color: _selectedColor == color ? AppColors.primaryOrange : AppColors.getBorder(context)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(color, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _selectedColor == color ? Colors.white : AppColors.getTextPrimary(context))),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (_product!.sizes != null && _product!.sizes!.isNotEmpty) ...[
            SizedBox(height: 8),
            Text('Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
            SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _product!.sizes!
                  .map((size) => GestureDetector(
                        onTap: () => setState(() => _selectedSize = size),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _selectedSize == size ? AppColors.primaryOrange : AppColors.getCardBackground(context),
                            border: Border.all(color: _selectedSize == size ? AppColors.primaryOrange : AppColors.getBorder(context)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(size, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _selectedSize == size ? Colors.white : AppColors.getTextPrimary(context))),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (_isDetailsExpanded) ...[
            _row('Category', _product!.categoryName ?? 'N/A'),
            SizedBox(height: 8),
            Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
            SizedBox(height: 4),
            Text(_product!.description.isEmpty ? 'No description' : _product!.description, style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.getTextMuted(context))),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context)))),
            Expanded(child: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)))),
          ],
        ),
      );

  Widget _buildReviews() {
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
                Text('Reviews', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                SizedBox(width: 6),
                Icon(Icons.star, color: AppColors.primaryOrange, size: 14),
                SizedBox(width: 3),
                Text('${avgRating.toStringAsFixed(1)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                Text(' (${_reviews.length})', style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context))),
                Spacer(),
                Icon(_isReviewsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.getTextMuted(context), size: 20),
              ],
            ),
          ),
          SizedBox(height: 8),
          if (_reviews.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 30, color: AppColors.getTextMuted(context).withOpacity(0.5)),
                  SizedBox(height: 6),
                  Text('No reviews yet', style: TextStyle(color: AppColors.getTextMuted(context), fontSize: 11)),
                ],
              ),
            )
          else
            ...(_isReviewsExpanded ? _reviews : _reviews.take(2)).map((r) => Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.getBackground(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primaryOrange.withOpacity(0.1),
                            child: Text((r.userName?.isNotEmpty == true) ? r.userName![0].toUpperCase() : 'A', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.userName ?? 'Anonymous', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.getTextPrimary(context))),
                                Row(
                                  children: [
                                    ...List.generate(5, (i) => Icon(i < r.ratingInt ? Icons.star : Icons.star_border, color: AppColors.primaryOrange, size: 11)),
                                    SizedBox(width: 4),
                                    Text(r.timeAgo, style: TextStyle(fontSize: 9, color: AppColors.getTextMuted(context))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(r.comment, style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.getTextPrimary(context))),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildRelated() {
    return FutureBuilder<List<ProductModel>>(
      future: _productService.getRelatedProducts(currentProductId: _product!.id, categoryId: _product!.categoryId, universityId: _product!.universityId, limit: 10),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You Might Like', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
              SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) => RelatedProductCard(
                    product: snapshot.data![index],
                    onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: snapshot.data![index]))),
                  ),
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
        padding: EdgeInsets.all(12).copyWith(bottom: 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          border: Border(top: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/cart', (route) => false),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 22),
                    if (_cartItemCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text('$_cartItemCount', style: TextStyle(color: AppColors.primaryOrange, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _product?.isAvailable == true ? _addToCart : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _product?.isAvailable == true ? AppColors.primaryOrange : AppColors.getBorder(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isAddingToCart
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(_product?.isAvailable == true ? 'Add to Cart' : 'Out of Stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 30),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: AppColors.successGreen, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Added to Cart!', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}