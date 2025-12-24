// cart_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../models/cart_model.dart';
import '../models/product_model.dart';
import '../screens/checkout_address_screen.dart';
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
        if (mounted) widget.clearCartNotifier?.value = false;
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
        backgroundColor: AppColors.getCardBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
        content: Text(message, style: TextStyle(color: AppColors.getTextMuted(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: AppColors.getTextMuted(context)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(confirmText, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getCardBackground(context),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: const Text('Cart', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
        ),
        centerTitle: false,
        actions: _cartItems.isNotEmpty
            ? [
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.errorRed, size: 22),
                  onPressed: clearCart,
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: loadCartItems,
        color: AppColors.primaryOrange,
        child: _isLoading ? _buildLoader() : _cartItems.isEmpty ? _buildEmptyCart() : _buildCartList(),
      ),
      bottomNavigationBar: _cartItems.isNotEmpty ? _buildCheckoutBar() : null,
    );
  }

  Widget _buildLoader() => Center(child: UniHubLoader(size: 80));

  Widget _buildEmptyCart() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.primaryOrange.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.primaryOrange),
              ),
              SizedBox(height: 16),
              Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
              SizedBox(height: 6),
              Text('Add products to get started', style: TextStyle(fontSize: 14, color: AppColors.getTextMuted(context))),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).popUntil((route) => route.settings.name == '/home' || route.isFirst),
                icon: Icon(Icons.shopping_bag_outlined, size: 18),
                label: Text('Start Shopping'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      padding: EdgeInsets.fromLTRB(16, 12, 16, 140),
      initialItemCount: _cartItems.length,
      itemBuilder: (context, index, animation) => _buildCartItemAnimated(_cartItems[index], index, animation),
    );
  }

  Widget _buildCartItemAnimated(CartModel item, int index, Animation<double> animation) {
    return FadeTransition(opacity: animation, child: _buildCartItem(item));
  }

  Widget _buildCartItem(CartModel item) {
    final product = item.product;
    if (product == null) return SizedBox.shrink();

    final isSelected = _selectedItemIds.contains(item.id);
    final currentPayment = _selectedPaymentMethods[item.id];
    final isUpdating = _updatingItemId == item.id;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.primaryOrange.withOpacity(0.5) : AppColors.getBorder(context).withOpacity(0.3),
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleSelection(item),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryOrange : AppColors.getCardBackground(context),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isSelected ? AppColors.primaryOrange : AppColors.getBorder(context), width: 2),
                    ),
                    child: isSelected ? Icon(Icons.check, size: 12, color: Colors.white) : null,
                  ),
                ),
                SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: product.id))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: AppColors.getBackground(context),
                      child: product.mainImageUrl != null
                          ? Image.network(product.mainImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.image, color: AppColors.getTextMuted(context), size: 28))
                          : Icon(Icons.image, color: AppColors.getTextMuted(context), size: 28),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: product.id))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)), maxLines: 2, overflow: TextOverflow.ellipsis),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primaryOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(product.condition.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                        ),
                        SizedBox(height: 4),
                        Text(_formatPrice(item.totalPrice), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                      ],
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.getBackground(context),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildQtyButton(Icons.remove, item.quantity > 1 && !isUpdating ? () => _updateQuantity(item, item.quantity - 1) : null),
                          Container(
                            width: 30,
                            alignment: Alignment.center,
                            child: isUpdating
                                ? SizedBox(width: 12, height: 12, child: UniHubLoader(size: 12))
                                : Text('${item.quantity}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                          ),
                          _buildQtyButton(Icons.add, item.quantity < product.stockQuantity && !isUpdating ? () => _updateQuantity(item, item.quantity + 1) : null),
                        ],
                      ),
                    ),
                    SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _removeItem(item),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.errorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Icon(Icons.delete_outline, size: 16, color: AppColors.errorRed),
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
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: onTap != null ? AppColors.primaryOrange : AppColors.getTextMuted(context)),
      ),
    );
  }

  Widget _buildPaymentSelector(CartModel item, ProductModel product) {
    final validOptions = _getValidPaymentOptions(product.price);
    final currentSelection = _selectedPaymentMethods[item.id];

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.getBackground(context),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        border: Border(top: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, size: 14, color: AppColors.primaryOrange),
              SizedBox(width: 6),
              Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
            ],
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: validOptions.map((option) {
              final isSelected = currentSelection == option;
              return InkWell(
                onTap: () => setState(() => _selectedPaymentMethods[item.id] = option),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryOrange : AppColors.getCardBackground(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? AppColors.primaryOrange : AppColors.getBorder(context).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getPaymentIcon(option), size: 13, color: isSelected ? Colors.white : AppColors.primaryOrange),
                      SizedBox(width: 5),
                      Text(_getPaymentLabel(option), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.getTextPrimary(context))),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (currentSelection != null) ...[
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 12, color: AppColors.successGreen),
                  SizedBox(width: 5),
                  Expanded(child: Text(_getPaymentDescription(currentSelection, item.totalPrice), style: TextStyle(fontSize: 10, color: AppColors.successGreen, fontWeight: FontWeight.w600))),
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
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        border: Border(top: BorderSide(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canCheckout)
              Container(
                padding: EdgeInsets.all(10),
                margin: EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.getBackground(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.getBorder(context).withOpacity(0.3), width: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
                        Text(_formatPrice(_selectedTotal), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Color(0xFFFCD34D).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Escrow', style: TextStyle(fontSize: 9, color: Color(0xFF92400E), fontWeight: FontWeight.bold)),
                          Text(_formatPrice(_escrowAmount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _canCheckout && !_isProcessing
                    ? () {
                        final selectedItems = _cartItems.where((i) => _selectedItemIds.contains(i.id)).toList();
                        final payments = Map<String, String>.from(_selectedPaymentMethods)..removeWhere((k, _) => !_selectedItemIds.contains(k));
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CheckoutAddressScreen(selectedItems: selectedItems, paymentMethods: payments)));
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  disabledBackgroundColor: AppColors.getBorder(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _canCheckout ? 'Checkout (${_selectedItemIds.length})' : 'Select items & payment',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}