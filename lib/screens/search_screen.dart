import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/product_service.dart';
import '../models/product_model.dart';
import './product_details_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? universityId;
  final String universityName;
  final String state; 

  const SearchScreen({
    super.key,
    this.universityId,
    required this.universityName,
    required this.state,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ProductService _productService = ProductService();

  List<ProductModel> _searchResults = [];
  List<String> _recentSearches = [];
  List<String> _suggestions = [];
  List<String> _autocompleteResults = []; // ✅ NEW: For autocomplete
  List<ProductModel> _allProducts =
      []; // ✅ NEW: Store all products for autocomplete

  bool _isLoading = false;
  bool _hasSearched = false;
  String _currentSearchQuery = '';
  bool _showAutocomplete = false; // ✅ NEW: Show/hide autocomplete
  bool _isLoadingAutocomplete = false; // ✅ NEW: Loading state for autocomplete

  final Set<String> _favorites = {};
  final Set<String> _cart = {};

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadSuggestions();
    _searchFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_searchFocusNode.hasFocus && !_hasSearched) {
      setState(() {}); // Rebuild to show suggestions/history
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList('recent_searches') ?? [];
      setState(() {
        _recentSearches = searches.take(5).toList();
      });
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList('recent_searches') ?? [];

      searches.remove(query);
      searches.insert(0, query);
      if (searches.length > 10) {
        searches.removeRange(10, searches.length);
      }

      await prefs.setStringList('recent_searches', searches);
      setState(() {
        _recentSearches = searches.take(5).toList();
      });
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_searches');
      setState(() {
        _recentSearches = [];
      });
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final products = await _productService.getAllProducts(
        universityId: widget.universityId,
        state: widget.state,
        limit: 20,
      );

      final suggestions = products.map((p) => p.name).toSet().take(5).toList();

      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
    }
  }

  // ✅ NEW: Autocomplete function
  Future<void> _handleTextChange(String query) async {
  if (query.trim().isEmpty) {
    setState(() {
      _showAutocomplete = false;
      _autocompleteResults = [];
    });
    return;
  }

  setState(() {
    _showAutocomplete = true;
    _isLoadingAutocomplete = true;
  });

  try {
    // ✅ Call the NEW method from ProductService
    final suggestions = await _productService.getSearchSuggestions(
      partialQuery: query,
      state: widget.state,
      universityId: widget.universityId,
      limit: 8,
    );

    // Also include matching recent searches
    final matchingRecent = _recentSearches
        .where((search) =>
            search.toLowerCase().contains(query.toLowerCase()) &&
            !suggestions.contains(search))
        .take(3)
        .toList();

    setState(() {
      _autocompleteResults = [...suggestions, ...matchingRecent];
      _isLoadingAutocomplete = false;
    });
  } catch (e) {
    debugPrint('Error loading autocomplete: $e');
    setState(() {
      _autocompleteResults = [];
      _isLoadingAutocomplete = false;
    });
  }
}

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _currentSearchQuery = query;
      _showAutocomplete = false; // Hide autocomplete when searching
    });

    await _saveRecentSearch(query);

    try {
      final results = await _productService.searchProducts(
        query,
        universityId: widget.universityId,
        state: widget.state,
        limit: 100,
      );

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error performing search: $e');
      setState(() {
        _isLoading = false;
        _searchResults = [];
      });
    }
  }
  
  


  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _hasSearched = false;
      _currentSearchQuery = '';
      _showAutocomplete = false;
      _autocompleteResults = [];
    });
    _searchFocusNode.requestFocus();
  }

  String _formatPrice(double price) {
    final priceStr = price.toStringAsFixed(0);
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '₦${priceStr.replaceAllMapped(regex, (Match m) => '${m[1]},')}';
  }

  Widget _buildRatingStars({
    double? rating,
    required int reviewCount,
    double size = 11,
  }) {
    final displayRating = rating ?? 0.0;
    final fullStars = displayRating.floor();
    final hasHalfStar = (displayRating - fullStars) >= 0.5;

    return Row(
      children: [
        ...List.generate(5, (index) {
          if (index < fullStars) {
            return Icon(Icons.star, size: size, color: Color(0xFFFF6B35));
          } else if (index == fullStars && hasHalfStar) {
            return Icon(Icons.star_half, size: size, color: Color(0xFFFF6B35));
          } else {
            return Icon(
              Icons.star_border,
              size: size,
              color: Colors.grey.shade400,
            );
          }
        }),
        if (reviewCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '${displayRating.toStringAsFixed(1)} ($reviewCount)',
            style: TextStyle(fontSize: size - 2, color: AppColors.textLight),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Sticky Search Bar
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: AppColors.white,
            elevation: 2,
            toolbarHeight: 70,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.textDark),
              onPressed: () => Navigator.pop(context),
            ),
            title: Container(
              height: 45,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search products in ${widget.universityName}...",
                  hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.textLight,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textLight,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 20),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: _performSearch,
                onChanged:
                    _handleTextChange, // ✅ CHANGED: Now triggers autocomplete
                textInputAction: TextInputAction.search,
              ),
            ),
          ),

          // ✅ NEW: Autocomplete Dropdown
          if (_showAutocomplete && !_hasSearched)  // ⬅️ Remove the isEmpty check
  SliverToBoxAdapter(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLoadingAutocomplete  // ⬅️ ADD THIS CONDITION
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          : _autocompleteResults.isEmpty  // ⬅️ ADD THIS CONDITION
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No suggestions found',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                )
              : Column(
                
                  children: _autocompleteResults.map((result) {
                    final isFromRecent = _recentSearches.contains(result);
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isFromRecent ? Icons.history : Icons.search,
                        size: 18,
                        color: isFromRecent
                            ? AppColors.textLight
                            : AppColors.primary,
                      ),
                      title: RichText(
                        text: TextSpan(
                          children: _highlightMatch(
                            result,
                            _searchController.text,
                          ),
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      trailing: Icon(
                        Icons.north_west,
                        size: 16,
                        color: AppColors.textLight,
                      ),
                      onTap: () {
                        _searchController.text = result;
                        _performSearch(result);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),

          // Search Results or Suggestions
          if (_hasSearched) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Results for "${_currentSearchQuery}"',
                        style: AppTextStyles.subheading.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_searchResults.length}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_searchResults.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 80,
                        color: AppColors.textLight.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No results found',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subheading.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = _searchResults[index];
                    return _buildProductCard(product);
                  }, childCount: _searchResults.length),
                ),
              ),
          ] else ...[
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_recentSearches.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history,
                            size: 20,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Recent',
                            style: AppTextStyles.subheading.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _clearRecentSearches,
                            child: Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...(_recentSearches.map(
                      (search) => ListTile(
                        leading: Icon(
                          Icons.history,
                          size: 20,
                          color: AppColors.textLight,
                        ),
                        title: Text(
                          search,
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.north_west,
                            size: 18,
                            color: AppColors.textLight,
                          ),
                          onPressed: () {
                            _searchController.text = search;
                            _performSearch(search);
                          },
                        ),
                        onTap: () => _performSearch(search),
                      ),
                    )),
                    const Divider(height: 24),
                  ],

                  if (_suggestions.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 20,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Popular',
                            style: AppTextStyles.subheading.copyWith(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...(_suggestions.map(
                      (suggestion) => ListTile(
                        leading: Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          suggestion,
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                        ),
                        trailing: Icon(
                          Icons.north_west,
                          size: 18,
                          color: AppColors.textLight,
                        ),
                        onTap: () => _performSearch(suggestion),
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ NEW: Helper to highlight matching text in autocomplete
  List<TextSpan> _highlightMatch(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return [TextSpan(text: text)];
    }

    return [
      if (index > 0) TextSpan(text: text.substring(0, index)),
      TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
      if (index + query.length < text.length)
        TextSpan(text: text.substring(index + query.length)),
    ];
  }

  Widget _buildProductCard(ProductModel product) {
    final isFavorite = _favorites.contains(product.id);
    final isInCart = _cart.contains(product.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(product: product),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    // ✅ FIXED: Now using CachedNetworkImage
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrls.isNotEmpty
                          ? product.imageUrls.first
                          : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.background,
                        child: Icon(
                          Icons.image,
                          color: AppColors.textLight.withOpacity(0.5),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.background,
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 50,
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isFavorite) {
                              _favorites.remove(product.id);
                            } else {
                              _favorites.add(product.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite
                                ? Colors.red
                                : Colors.grey.shade600,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: isInCart ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isInCart) {
                              _cart.remove(product.id);
                            } else {
                              _cart.add(product.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.add_shopping_cart,
                            color: isInCart
                                ? Colors.white
                                : Colors.grey.shade600,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatPrice(product.price),
                    style: AppTextStyles.price.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (product.isFeatured || product.isTopSeller) ...[
                        Icon(
                          Icons.check_circle,
                          size: 11,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'verified',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          ' | ',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                      Flexible(
                        child: Text(
                          product.universityName ?? 'N/A',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 9,
                            color: AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildRatingStars(
                    rating: product.averageRating,
                    reviewCount: product.reviewCount,
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
