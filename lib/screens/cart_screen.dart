import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../models/cart_model.dart';
import 'product_details_screen.dart';
import '../models/product_model.dart';
import 'dart:ui';
import '../screens/checkout_address_screen.dart'; 


class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();

  List<CartModel> _cartItems = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  // Tracks which item is being updated for skeleton loading
  String? _updatingItemId;

  // Tracks checked items by CartModel.id
  final Set<String> _selectedItemIds = {};
  // Tracks chosen payment method { 'cart_item_id': 'full' | 'half' | 'pod' }
  final Map<String, String> _selectedPaymentMethods = {};

  // Animation controllers
  late AnimationController _checkoutButtonController;
  late Animation<double> _checkoutButtonScale;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
    _checkoutButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _checkoutButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _checkoutButtonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _checkoutButtonController.dispose();
    super.dispose();
  }

  // PRD Section 7 Payment Logic
  List<String> _getValidPaymentOptions(double price) {
    if (price >= 35000) {
      return ['full', 'half'];
    } else if (price >= 20000) {
      return ['full', 'half', 'pod'];
    } else {
      return ['full', 'pod'];
    }
  }

  String _getPaymentMethodName(String key) {
    switch (key) {
      case 'full':
        return 'Pay Full';
      case 'half':
        return 'Pay Half';
      case 'pod':
        return 'Pay on Delivery';
      default:
        return 'Select Payment';
    }
  }

  IconData _getPaymentMethodIcon(String key) {
    switch (key) {
      case 'full':
        return Icons.payments_rounded;
      case 'half':
        return Icons.account_balance_wallet_rounded;
      case 'pod':
        return Icons.local_shipping_rounded;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodDescription(String key, double price) {
    switch (key) {
      case 'full':
        final formattedPrice = _formatPrice(price);
        return 'Pay $formattedPrice now';
      case 'half':
        final halfPrice = _formatPrice(price / 2);
        return 'Pay $halfPrice now';
      case 'pod':
        return 'Pay ₦0 now';
      default:
        return '';
    }
  }

  String _formatPrice(double price) {
    return '₦${price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  double get _selectedItemsTotal {
    double total = 0.0;
    for (final item in _cartItems) {
      if (_selectedItemIds.contains(item.id)) {
        total += item.totalPrice;
      }
    }
    return total;
  }

  double get _escrowAmount {
    double escrow = 0.0;
    for (final item in _cartItems) {
      if (_selectedItemIds.contains(item.id)) {
        final paymentMethod = _selectedPaymentMethods[item.id];
        if (paymentMethod == 'full') {
          escrow += item.totalPrice;
        } else if (paymentMethod == 'half') {
          escrow += item.totalPrice / 2;
        }
      }
    }
    return escrow;
  }

  bool get _canCheckout {
    if (_selectedItemIds.isEmpty) {
      return false;
    }
    for (final id in _selectedItemIds) {
      if (_selectedPaymentMethods[id] == null) {
        return false;
      }
    }
    return true;
  }

  void _toggleItemSelection(CartModel item) {
    setState(() {
      if (_selectedItemIds.contains(item.id)) {
        _selectedItemIds.remove(item.id);
        _selectedPaymentMethods.remove(item.id);
      } else {
        _selectedItemIds.add(item.id);
      }
    });
  }

  Future<void> _loadCartItems() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final items = await _cartService.getCartItems(userId);
      if (mounted) {
        setState(() {
          _cartItems = items;
          _isLoading = false;

          final allCartItemIds = items.map((i) => i.id).toSet();
          _selectedItemIds.removeWhere((id) => !allCartItemIds.contains(id));
          _selectedPaymentMethods
              .removeWhere((id, _) => !allCartItemIds.contains(id));
        });
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load cart items');
      }
    }
  }

  Future<void> _updateQuantity(CartModel item, int newQuantity) async {
    if (_isProcessing) return;

    setState(() {
      _updatingItemId = item.id;
    });

    try {
      await _cartService.updateCartItemQuantity(item.id, newQuantity);
      
      final index = _cartItems.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        setState(() {
          _cartItems[index] = CartModel(
            id: item.id,
            userId: item.userId,
            productId: item.productId,
            quantity: newQuantity,
            createdAt: item.createdAt,
            product: item.product,
          );
          _updatingItemId = null;
        });
      }
    } catch (e) {
      debugPrint('Error updating quantity: $e');
      setState(() => _updatingItemId = null);
      if (mounted) {
        _showErrorSnackBar('Failed to update quantity');
      }
    }
  }

  Future<void> _removeItem(CartModel item) async {
    if (_isProcessing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildModernDialog(
        title: 'Remove Item',
        content: 'Remove ${item.product?.name ?? 'this item'} from cart?',
        confirmText: 'Remove',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      final success = await _cartService.removeFromCart(item.id);
      if (success) {
        await _loadCartItems();
        if (mounted) {
          _showSuccessSnackBar('Item removed from cart');
        }
      }
    } catch (e) {
      debugPrint('Error removing item: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to remove item');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _clearCart() async {
    if (_isProcessing || _cartItems.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildModernDialog(
        title: 'Clear Cart',
        content: 'Remove all items from your cart?',
        confirmText: 'Clear All',
        isDestructive: true,
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        await _cartService.clearCart(userId);
        await _loadCartItems();
      }
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to clear cart');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildModernDialog({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF8B5CF6).withOpacity(0.2),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDestructive
                        ? [Color(0xFFEF4444), Color(0xFFDC2626)]
                        : [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDestructive ? Icons.warning_rounded : Icons.info_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDestructive
                              ? [Color(0xFFEF4444), Color(0xFFDC2626)]
                              : [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (isDestructive ? Color(0xFFEF4444) : Color(0xFFFF6B35))
                                .withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          confirmText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        elevation: 0,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_rounded, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFC),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.white.withOpacity(0.8),
              elevation: 0,
              leading: Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFF6B35).withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937), size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              titleSpacing: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'My Cart',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (_cartItems.isNotEmpty) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFFF6B35).withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${_cartItems.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              centerTitle: false,
              actions: [
                if (_cartItems.isNotEmpty)
                  Container(
                    margin: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFEF4444).withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                      onPressed: _clearCart,
                      tooltip: 'Clear cart',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFF6B35).withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Loading your cart...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : _cartItems.isEmpty
              ? _buildEmptyCart()
              : _buildCartList(),
      bottomNavigationBar: _cartItems.isNotEmpty ? _buildCheckoutBar() : null,
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              padding: EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8B5CF6).withOpacity(0.1),
                    Color(0xFF7C3AED).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF8B5CF6).withOpacity(0.1),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 80,
                color: Color(0xFF8B5CF6),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add products to get started',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFFF6B35).withOpacity(0.4),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 22),
              label: const Text('Start Shopping'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
                textStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: _cartItems.length,
      itemBuilder: (context, index) {
        final item = _cartItems[index];
        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOut,
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: _buildCartItem(item),
        );
      },
    );
  }

  Widget _buildCartItem(CartModel item) {
    final product = item.product;
    if (product == null) return SizedBox.shrink();

    final isAvailable = product.isAvailable && product.stockQuantity > 0;
    final bool isSelected = _selectedItemIds.contains(item.id);
    final String? currentPayment = _selectedPaymentMethods[item.id];
    final bool isUpdating = _updatingItemId == item.id;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFFF6B35).withOpacity(0.03),
                ],
              )
            : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected 
              ? Color(0xFFFF6B35).withOpacity(0.3)
              : Color(0xFFE5E7EB),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Color(0xFFFF6B35).withOpacity(0.15)
                : Colors.black.withOpacity(0.03),
            blurRadius: isSelected ? 20 : 10,
            offset: Offset(0, isSelected ? 8 : 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailsScreen(product: product),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modern Checkbox with animation
                  GestureDetector(
                    onTap: () => _toggleItemSelection(item),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                              )
                            : null,
                        color: isSelected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : Color(0xFFE5E7EB),
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(0xFF8B5CF6).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Product Image with gradient overlay
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF3F4F6),
                          Color(0xFFE5E7EB).withOpacity(0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          if (product.mainImageUrl != null)
                            Image.network(
                              product.mainImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.image_rounded,
                                    size: 32,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                );
                              },
                            )
                          else
                            Center(
                              child: Icon(
                                Icons.image_rounded,
                                size: 32,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Product Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                            letterSpacing: -0.3,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFF6B35).withOpacity(0.1),
                                Color(0xFFFF8C42).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.condition.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF6B35),
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              _formatPrice(product.price),
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                foreground: Paint()
                                  ..shader = LinearGradient(
                                    colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                                  ).createShader(Rect.fromLTWH(0, 0, 200, 70)),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        if (!isAvailable)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Color(0xFFEF4444).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Out of stock',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Quantity & Delete Column
                  Column(
                    children: [
                      // Quantity controls with neumorphic design
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFFAFAFC),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                            BoxShadow(
                              color: Colors.white,
                              blurRadius: 10,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildQuantityButton(
                              icon: Icons.remove_rounded,
                              onTap: item.quantity <= 1 || isUpdating
                                  ? null
                                  : () => _updateQuantity(item, item.quantity - 1),
                              enabled: item.quantity > 1 && !isUpdating,
                            ),
                            Container(
                              width: 40,
                              alignment: Alignment.center,
                              child: isUpdating
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFFF6B35),
                                        ),
                                      ),
                                    )
                                  : TweenAnimationBuilder(
                                      key: ValueKey(item.quantity),
                                      tween: Tween<double>(begin: 0.8, end: 1.0),
                                      duration: Duration(milliseconds: 200),
                                      curve: Curves.elasticOut,
                                      builder: (context, double scale, child) {
                                        return Transform.scale(
                                          scale: scale,
                                          child: Text(
                                            '${item.quantity}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            _buildQuantityButton(
                              icon: Icons.add_rounded,
                              onTap: item.quantity >= product.stockQuantity || isUpdating
                                  ? null
                                  : () => _updateQuantity(item, item.quantity + 1),
                              enabled: item.quantity < product.stockQuantity && !isUpdating,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _isProcessing ? null : () => _removeItem(item),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFEF4444).withOpacity(0.1),
                                Color(0xFFDC2626).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Payment Selector with smooth animation
          if (isSelected)
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, double value, child) {
                return SizeTransition(
                  sizeFactor: AlwaysStoppedAnimation(value),
                  child: FadeTransition(
                    opacity: AlwaysStoppedAnimation(value),
                    child: child,
                  ),
                );
              },
              child: _buildPaymentSelector(item, product),
            ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Color(0xFFFF6B35) : Color(0xFFD1D5DB),
        ),
      ),
    );
  }

  Widget _buildPaymentSelector(CartModel item, ProductModel product) {
    final validOptions = _getValidPaymentOptions(product.price);
    final String? currentSelection = _selectedPaymentMethods[item.id];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 1,
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFF6B35).withOpacity(0.1),
                  Color(0xFFFF6B35).withOpacity(0.3),
                  Color(0xFFFF6B35).withOpacity(0.1),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFF6B35).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.payments_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Choose Payment Method',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: validOptions.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = currentSelection == option;
              
              return TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + (index * 100)),
                curve: Curves.easeOut,
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethods[item.id] = option;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                            )
                          : null,
                      color: isSelected ? null : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : Color(0xFFE5E7EB),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: Color(0xFFFF6B35).withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getPaymentMethodIcon(option),
                          size: 18,
                          color: isSelected ? Colors.white : Color(0xFFFF6B35),
                        ),
                        SizedBox(width: 8),
                        Text(
                          _getPaymentMethodName(option),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Color(0xFF1F2937),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (currentSelection != null) ...[
            SizedBox(height: 12),
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF10B981).withOpacity(0.1),
                    Color(0xFF059669).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(0xFF10B981).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getPaymentMethodDescription(currentSelection, item.totalPrice),
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

 // Paste this entire function into cart_screen.dart, replacing the old one.

Widget _buildCheckoutBar() {
    final double selectedTotal = _selectedItemsTotal;
    final double escrowAmount = _escrowAmount;
    final bool canCheckout = _canCheckout;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.95),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF8B5CF6).withOpacity(0.1),
                blurRadius: 30,
                offset: Offset(0, -10),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canCheckout) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF8B5CF6).withOpacity(0.1),
                          Color(0xFF7C3AED).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Color(0xFF8B5CF6).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _formatPrice(selectedTotal),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                foreground: Paint()
                                  ..shader = LinearGradient(
                                    colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                                  ).createShader(Rect.fromLTWH(0, 0, 200, 70)),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFCD34D), Color(0xFFFBBF24)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFFCD34D).withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.shield_rounded,
                                    size: 14,
                                    color: Color(0xFF92400E),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Escrow',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text(
                                _formatPrice(escrowAmount),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                // Checkout Button with scale animation
                GestureDetector(
                  onTapDown: canCheckout && !_isProcessing
                      ? (_) => _checkoutButtonController.forward()
                      : null,
                  
                  // ----------------------------------------------------
                  // 🚀 THIS IS THE FIX 🚀
                  // ----------------------------------------------------
                  onTapUp: canCheckout && !_isProcessing
                      ? (_) {
                          _checkoutButtonController.reverse();

                          // 1. Get the list of the *actual* CartModel objects
                          final selectedItemsList = _cartItems
                              .where((item) => _selectedItemIds.contains(item.id))
                              .toList();

                          // 2. Filter the payment methods for only the selected items
                          // (And fix the Map<dynamic, dynamic> error)
                          final selectedPaymentsMap = Map<String, String>.from(_selectedPaymentMethods)
                            ..removeWhere((key, value) => !_selectedItemIds.contains(key));

                          // 3. NAVIGATE to the checkout screen
                          // These parameter names (selectedItems, paymentMethods)
                          // now EXACTLY match your CheckoutAddressScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckoutAddressScreen(
                                selectedItems: selectedItemsList,
                                paymentMethods: selectedPaymentsMap,
                              ),
                            ),
                          );
                        }
                      : null,
                  // ----------------------------------------------------
                  // 🚀 END OF FIX 🚀
                  // ----------------------------------------------------

                  onTapCancel: () => _checkoutButtonController.reverse(),
                  child: ScaleTransition(
                    scale: _checkoutButtonScale,
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: canCheckout && !_isProcessing
                            ? LinearGradient(
                                colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                              )
                            : LinearGradient(
                                colors: [Color(0xFFE5E7EB), Color(0xFFD1D5DB)],
                              ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: canCheckout && !_isProcessing
                            ? [
                                BoxShadow(
                                  color: Color(0xFFFF6B35).withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: _isProcessing
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (canCheckout)
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  SizedBox(width: 10),
                                  Text(
                                    canCheckout
                                        ? 'Proceed to Checkout (${_selectedItemIds.length})'
                                        : 'Select items and payment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: canCheckout ? Colors.white : Color(0xFF9CA3AF),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (canCheckout) ...[
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }}