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
  List<String> _autocompleteResults = [];

  bool _isLoading = false;
  bool _hasSearched = false;
  String _currentSearchQuery = '';
  bool _showAutocomplete = false;
  bool _isLoadingAutocomplete = false;

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
      setState(() {});
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
      final suggestions = await _productService.getSearchSuggestions(
        partialQuery: query,
        state: widget.state,
        universityId: widget.universityId,
        limit: 8,
      );

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
      _showAutocomplete = false;
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
            return Icon(Icons.star, size: size, color: AppColors.primaryOrange);
          } else if (index == fullStars && hasHalfStar) {
            return Icon(Icons.star_half, size: size, color: AppColors.primaryOrange);
          } else {
            return Icon(
              Icons.star_border,
              size: size,
              color: AppColors.getBorder(context),
            );
          }
        }),
        if (reviewCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '${displayRating.toStringAsFixed(1)} ($reviewCount)',
            style: TextStyle(fontSize: size - 2, color: AppColors.getTextMuted(context)),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: AppColors.getCardBackground(context),
            elevation: 0,
            toolbarHeight: 60,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.getBackground(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3)),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search in ${widget.universityName}...",
                  hintStyle: TextStyle(
                    color: AppColors.getTextMuted(context),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.getTextMuted(context),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18, color: AppColors.getTextMuted(context)),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: _performSearch,
                onChanged: _handleTextChange,
                textInputAction: TextInputAction.search,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),
            ),
          ),

          // Autocomplete Dropdown
          if (_showAutocomplete && !_hasSearched)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.getCardBackground(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                ),
                child: _isLoadingAutocomplete
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ),
                      )
                    : _autocompleteResults.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No suggestions found',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.getTextMuted(context),
                                fontSize: 13,
                              ),
                            ),
                          )
                        : Column(
                            children: _autocompleteResults.asMap().entries.map((entry) {
                              final index = entry.key;
                              final result = entry.value;
                              final isFromRecent = _recentSearches.contains(result);
                              final isLast = index == _autocompleteResults.length - 1;
                              
                              return Container(
                                decoration: BoxDecoration(
                                  border: isLast ? null : Border(
                                    bottom: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: Icon(
                                    isFromRecent ? Icons.history : Icons.search,
                                    size: 18,
                                    color: isFromRecent
                                        ? AppColors.getTextMuted(context)
                                        : AppColors.primaryOrange,
                                  ),
                                  title: RichText(
                                    text: TextSpan(
                                      children: _highlightMatch(result, _searchController.text),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.getTextPrimary(context),
                                      ),
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.north_west,
                                    size: 16,
                                    color: AppColors.getTextMuted(context),
                                  ),
                                  onTap: () {
                                    _searchController.text = result;
                                    _performSearch(result);
                                  },
                                ),
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
                    Icon(Icons.search, size: 18, color: AppColors.primaryOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Results for "${_currentSearchQuery}"',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_searchResults.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
              )
            else if (_searchResults.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: AppColors.getTextMuted(context).withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No results found',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Try different keywords',
                        style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context)),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = _searchResults[index];
                      return _buildProductCard(product);
                    },
                    childCount: _searchResults.length,
                  ),
                ),
              ),
          ] else ...[
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_recentSearches.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.getCardBackground(context),
                        border: Border(
                          bottom: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 18, color: AppColors.getTextMuted(context)),
                          const SizedBox(width: 8),
                          Text(
                            'Recent',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _clearRecentSearches,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Clear',
                              style: TextStyle(fontSize: 13, color: AppColors.primaryOrange, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      color: AppColors.getCardBackground(context),
                      child: Column(
                        children: _recentSearches.asMap().entries.map((entry) {
                          final index = entry.key;
                          final search = entry.value;
                          final isLast = index == _recentSearches.length - 1;
                          
                          return Container(
                            decoration: BoxDecoration(
                              border: isLast ? null : Border(
                                bottom: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Icon(Icons.history, size: 18, color: AppColors.getTextMuted(context)),
                              title: Text(
                                search,
                                style: TextStyle(fontSize: 14, color: AppColors.getTextPrimary(context)),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.north_west, size: 16, color: AppColors.getTextMuted(context)),
                                onPressed: () {
                                  _searchController.text = search;
                                  _performSearch(search);
                                },
                              ),
                              onTap: () => _performSearch(search),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 8),
                  ],

                  if (_suggestions.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.getCardBackground(context),
                        border: Border(
                          bottom: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.trending_up, size: 18, color: AppColors.successGreen),
                          const SizedBox(width: 8),
                          Text(
                            'Popular',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      color: AppColors.getCardBackground(context),
                      child: Column(
                        children: _suggestions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final suggestion = entry.value;
                          final isLast = index == _suggestions.length - 1;
                          
                          return Container(
                            decoration: BoxDecoration(
                              border: isLast ? null : Border(
                                bottom: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Icon(Icons.search, size: 18, color: AppColors.primaryOrange),
                              title: Text(
                                suggestion,
                                style: TextStyle(fontSize: 14, color: AppColors.getTextPrimary(context)),
                              ),
                              trailing: Icon(Icons.north_west, size: 16, color: AppColors.getTextMuted(context)),
                              onTap: () => _performSearch(suggestion),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

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
        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
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
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
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
                      imageUrl: product.imageUrls.isNotEmpty
                          ? product.imageUrls.first
                          : 'https://placehold.co/600x400/eeeeee/cccccc?text=No+Image',
                      width: double.infinity,
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
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Material(
                      color: AppColors.getCardBackground(context).withOpacity(0.9),
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
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : AppColors.getTextMuted(context),
                            size: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: isInCart ? AppColors.primaryOrange : AppColors.getCardBackground(context).withOpacity(0.9),
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
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            Icons.add_shopping_cart,
                            color: isInCart ? Colors.white : AppColors.primaryOrange,
                            size: 15,
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (product.isFeatured || product.isTopSeller) ...[
                        Icon(Icons.check_circle, size: 10, color: AppColors.successGreen),
                        const SizedBox(width: 3),
                        Text(
                          'verified',
                          style: TextStyle(fontSize: 9, color: AppColors.successGreen, fontWeight: FontWeight.w500),
                        ),
                        Text(' | ', style: TextStyle(fontSize: 9, color: AppColors.getTextMuted(context))),
                      ],
                      Flexible(
                        child: Text(
                          product.universityName ?? 'N/A',
                          style: TextStyle(fontSize: 9, color: AppColors.getTextMuted(context)),
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