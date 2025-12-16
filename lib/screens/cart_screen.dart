import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../models/cart_model.dart';
import '../models/product_model.dart';
import '../screens/checkout_address_screen.dart'; // NAVIGATE TO ADDRESS FIRST
import '../screens/product_details_screen.dart';
import '../widgets/unihub_loading_widget.dart';

const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class CartScreen extends StatefulWidget {
  final ValueNotifier<bool>? clearCartNotifier;
  const CartScreen({super.key, this.clearCartNotifier});

  @override
  State<CartScreen> createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen> {
  final _cartService = CartService();
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  List<CartModel> _cartItems = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _updatingItemId;

  final _selectedItemIds = <String>{};
  final _selectedPaymentMethods = <String, String>{};
  
  RealtimeChannel? _cartChannel;

  @override
  void initState() {
    super.initState();
    loadCartItems();
    _setupCartListener();
    widget.clearCartNotifier?.addListener(_onClearCartRequested);
  }

  void _onClearCartRequested() {
    if (widget.clearCartNotifier?.value == true) {
      clearCart().then((_) {
        if (mounted) {
          widget.clearCartNotifier?.value = false;
        }
      });
    }
  }

  void _setupCartListener() {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    _cartChannel = _supabase
        .channel('cart:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'cart',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) => _handleCartInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'cart',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) => _handleCartUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'cart',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) => _handleCartDelete(payload.oldRecord),
        )
        .subscribe();
  }

  Future<void> _handleCartInsert(Map<String, dynamic> newRecord) async {
    final cartItemId = newRecord['id'] as String;
    if (_cartItems.any((item) => item.id == cartItemId)) return;

    final newItem = await _fetchSingleCartItem(cartItemId);
    if (newItem != null && mounted) {
      setState(() => _cartItems.insert(0, newItem));
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
    }
  }

  void _handleCartUpdate(Map<String, dynamic> newRecord) {
    final cartItemId = newRecord['id'] as String;
    final quantity = newRecord['quantity'] as int;
    
    if (mounted) {
      final index = _cartItems.indexWhere((item) => item.id == cartItemId);
      if (index != -1) {
        setState(() {
          _cartItems[index] = _cartItems[index].copyWith(quantity: quantity);
        });
      }
    }
  }

  void _handleCartDelete(Map<String, dynamic> oldRecord) {
    final cartItemId = oldRecord['id'] as String;
    if (mounted) {
      final index = _cartItems.indexWhere((item) => item.id == cartItemId);
      if (index != -1) {
        final removed = _cartItems.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => _buildCartItemAnimated(removed, index, animation),
          duration: const Duration(milliseconds: 300),
        );
        setState(() {
          _selectedItemIds.remove(cartItemId);
          _selectedPaymentMethods.remove(cartItemId);
        });
      }
    }
  }

  Future<CartModel?> _fetchSingleCartItem(String cartItemId) async {
    try {
      return await _cartService.getCartItem(cartItemId);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    widget.clearCartNotifier?.removeListener(_onClearCartRequested);
    _cartChannel?.unsubscribe();
    super.dispose();
  }

  List<String> _getValidPaymentOptions(double price) {
    if (price >= 35000) return ['full', 'half'];
    if (price >= 20000) return ['full', 'half', 'pod'];
    return ['full', 'pod'];
  }

  String _getPaymentLabel(String key) => {'full': 'Pay Full', 'half': 'Pay Half', 'pod': 'Pay on Delivery'}[key] ?? 'Select Payment';
  IconData _getPaymentIcon(String key) => {'full': Icons.payments_rounded, 'half': Icons.account_balance_wallet_rounded, 'pod': Icons.local_shipping_rounded}[key] ?? Icons.payment;
  String _getPaymentDescription(String key, double price) {
    if (key == 'full') return 'Pay ${_formatPrice(price)} now';
    if (key == 'half') return 'Pay ${_formatPrice(price / 2)} now';
    return 'Pay ₦0 now';
  }

  String _formatPrice(double price) => '₦${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  double get _selectedTotal => _cartItems.where((i) => _selectedItemIds.contains(i.id)).fold(0.0, (sum, i) => sum + i.totalPrice);
  double get _escrowAmount {
    double escrow = 0.0;
    for (final item in _cartItems.where((i) => _selectedItemIds.contains(i.id))) {
      final method = _selectedPaymentMethods[item.id];
      if (method == 'full') escrow += item.totalPrice;
      if (method == 'half') escrow += item.totalPrice / 2;
    }
    return escrow;
  }
  bool get _canCheckout => _selectedItemIds.isNotEmpty && _selectedItemIds.every((id) => _selectedPaymentMethods.containsKey(id));

  void _toggleSelection(CartModel item) {
    setState(() {
      if (_selectedItemIds.contains(item.id)) {
        _selectedItemIds.remove(item.id);
        _selectedPaymentMethods.remove(item.id);
      } else {
        _selectedItemIds.add(item.id);
      }
    });
  }

  Future<void> loadCartItems() async {
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
          final allIds = items.map((i) => i.id).toSet();
          _selectedItemIds.removeWhere((id) => !allIds.contains(id));
          _selectedPaymentMethods.removeWhere((id, _) => !allIds.contains(id));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load cart items', isError: true);
      }
    }
  }

  Future<void> _updateQuantity(CartModel item, int newQuantity) async {
    if (_isProcessing) return;
    
    final oldQuantity = item.quantity;
    final index = _cartItems.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    setState(() {
      _cartItems[index] = item.copyWith(quantity: newQuantity);
      _updatingItemId = item.id;
    });

    try {
      await _cartService.updateCartItemQuantity(item.id, newQuantity);
    } catch (e) {
      setState(() {
        _cartItems[index] = item.copyWith(quantity: oldQuantity);
      });
      if (mounted) _showSnackBar('Failed to update quantity', isError: true);
    } finally {
      if (mounted) setState(() => _updatingItemId = null);
    }
  }

  Future<void> _removeItem(CartModel item) async {
    if (_isProcessing) return;

    final confirm = await _showConfirmDialog('Remove ${item.product?.name ?? 'this item'} from cart?', 'Remove');
    if (confirm != true) return;

    final index = _cartItems.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    final removedItem = _cartItems[index];
    setState(() {
      _cartItems.removeAt(index);
      _selectedItemIds.remove(item.id);
      _selectedPaymentMethods.remove(item.id);
    });
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildCartItemAnimated(removedItem, index, animation),
      duration: const Duration(milliseconds: 300),
    );

    setState(() => _isProcessing = true);
    try {
      await _cartService.removeFromCart(item.id);
      if (mounted) _showSnackBar('Item removed');
    } catch (e) {
      setState(() {
        _cartItems.insert(index, removedItem);
        _selectedItemIds.add(item.id);
      });
      _listKey.currentState?.insertItem(index, duration: const Duration(milliseconds: 300));
      if (mounted) _showSnackBar('Failed to remove item', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> clearCart() async {
    if (_cartItems.isEmpty || _isProcessing) return;

    final confirm = await _showConfirmDialog('Are you sure you want to remove all items from your cart?', 'Clear Cart');
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    
    final itemsToRemove = List<CartModel>.from(_cartItems);
    
    setState(() {
      _cartItems.clear();
      _selectedItemIds.clear();
      _selectedPaymentMethods.clear();
    });

    try {
      for (final item in itemsToRemove) {
        await _cartService.removeFromCart(item.id);
      }
      if (mounted) _showSnackBar('Cart cleared');
    } catch (e) {
      setState(() {
        _cartItems = itemsToRemove;
      });
      if (mounted) _showSnackBar('Failed to clear cart', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool?> _showConfirmDialog(String message, String confirmText) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm', style: AppTextStyles.heading.copyWith(fontSize: 18)),
        content: Text(message, style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: AppColors.textLight))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(confirmText),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: const Text(
            'Cart',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
        centerTitle: false,
        actions: _cartItems.isNotEmpty
            ? [
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 22),
                  onPressed: clearCart,
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: loadCartItems,
        color: Color(0xFFFF6B35),
        child: _isLoading ? _buildLoader() : _cartItems.isEmpty ? _buildEmptyCart() : _buildCartList(),
      ),
      bottomNavigationBar: _cartItems.isNotEmpty ? _buildCheckoutBar() : null,
    );
  }

  Widget _buildLoader() {
    return Center(child: UniHubLoader(size: 80));
  }

  Widget _buildEmptyCart() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.textLight.withOpacity(0.5)),
              SizedBox(height: 20),
              Text('Your cart is empty', style: AppTextStyles.heading.copyWith(fontSize: 20)),
              SizedBox(height: 8),
              Text('Add products to get started', style: AppTextStyles.body.copyWith(color: AppColors.textLight)),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.settings.name == '/home' || route.isFirst);
                },
                icon: Icon(Icons.shopping_bag_outlined, color: Colors.white),
                label: Text('Start Shopping', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartList() {
    return AnimatedList(
      key: _listKey,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 140),
      initialItemCount: _cartItems.length,
      itemBuilder: (context, index, animation) => _buildCartItemAnimated(_cartItems[index], index, animation),
    );
  }

  Widget _buildCartItemAnimated(CartModel item, int index, Animation<double> animation) {
    return SlideTransition(
      position: animation.drive(Tween(begin: Offset(0, -0.3), end: Offset.zero).chain(CurveTween(curve: Curves.easeOut))),
      child: FadeTransition(opacity: animation, child: _buildCartItem(item)),
    );
  }

  Widget _buildCartItem(CartModel item) {
    final product = item.product;
    if (product == null) return SizedBox.shrink();

    final isSelected = _selectedItemIds.contains(item.id);
    final currentPayment = _selectedPaymentMethods[item.id];
    final isUpdating = _updatingItemId == item.id;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? Color(0xFFFF6B35).withOpacity(0.5) : Colors.grey.shade200, width: isSelected ? 2 : 1),
        boxShadow: [BoxShadow(color: isSelected ? Color(0xFFFF6B35).withOpacity(0.1) : Colors.black.withOpacity(0.03), blurRadius: isSelected ? 12 : 6, offset: Offset(0, isSelected ? 4 : 2))],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleSelection(item),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isSelected ? Color(0xFFFF6B35) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSelected ? Color(0xFFFF6B35) : Colors.grey.shade300, width: 2),
                    ),
                    child: isSelected ? Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                ),
                SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: product.id))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 70,
                      height: 70,
                      color: AppColors.background,
                      child: product.mainImageUrl != null
                          ? Image.network(product.mainImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.image, color: AppColors.textLight))
                          : Icon(Icons.image, color: AppColors.textLight),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: product.id))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: AppTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black), maxLines: 2, overflow: TextOverflow.ellipsis),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Color(0xFFFF6B35).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(product.condition.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35))),
                        ),
                        SizedBox(height: 6),
                        Text(_formatPrice(item.totalPrice), style: AppTextStyles.price.copyWith(fontSize: 16, color: Color(0xFFFF6B35))),
                      ],
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildQtyButton(Icons.remove, item.quantity > 1 && !isUpdating ? () => _updateQuantity(item, item.quantity - 1) : null),
                          Container(
                            width: 32,
                            alignment: Alignment.center,
                            child: isUpdating
                                ? SizedBox(width: 14, height: 14, child: UniHubLoader(size: 14, backgroundColor: Colors.transparent))
                                : Text('${item.quantity}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                          _buildQtyButton(Icons.add, item.quantity < product.stockQuantity && !isUpdating ? () => _updateQuantity(item, item.quantity + 1) : null),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _removeItem(item),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isSelected) _buildPaymentSelector(item, product),
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(width: 28, height: 28, alignment: Alignment.center, child: Icon(icon, size: 16, color: onTap != null ? Color(0xFFFF6B35) : Colors.grey.shade400)),
    );
  }

  Widget _buildPaymentSelector(CartModel item, ProductModel product) {
    final validOptions = _getValidPaymentOptions(product.price);
    final currentSelection = _selectedPaymentMethods[item.id];

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, size: 14, color: Color(0xFFFF6B35)),
              SizedBox(width: 6),
              Text('Payment Method', style: AppTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: validOptions.map((option) {
              final isSelected = currentSelection == option;
              return InkWell(
                onTap: () => setState(() => _selectedPaymentMethods[item.id] = option),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFFFF6B35) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? Color(0xFFFF6B35) : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getPaymentIcon(option), size: 14, color: isSelected ? Colors.white : Color(0xFFFF6B35)),
                      SizedBox(width: 6),
                      Text(_getPaymentLabel(option), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textDark)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (currentSelection != null) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Color(0xFF10B981).withOpacity(0.3))),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                  SizedBox(width: 6),
                  Expanded(child: Text(_getPaymentDescription(currentSelection, item.totalPrice), style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -2))]),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canCheckout)
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                        Text(_formatPrice(_selectedTotal), style: AppTextStyles.price.copyWith(fontSize: 20, color: Color(0xFFFF6B35))),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Color(0xFFFCD34D).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Escrow', style: TextStyle(fontSize: 10, color: Color(0xFF92400E), fontWeight: FontWeight.bold)),
                          Text(_formatPrice(_escrowAmount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canCheckout && !_isProcessing
                    ? () {
                        final selectedItems = _cartItems.where((i) => _selectedItemIds.contains(i.id)).toList();
                        final payments = Map<String, String>.from(_selectedPaymentMethods)..removeWhere((k, _) => !_selectedItemIds.contains(k));
                        // NAVIGATE TO ADDRESS FIRST
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CheckoutAddressScreen(selectedItems: selectedItems, paymentMethods: payments)));
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B35),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? SizedBox(height: 24, width: 24, child: FittedBox(child: UniHubLoader(size: 24, backgroundColor: Colors.transparent)))
                    : Text(_canCheckout ? 'Checkout (${_selectedItemIds.length})' : 'Select items & payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}