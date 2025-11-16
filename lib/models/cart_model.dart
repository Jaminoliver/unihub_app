import 'product_model.dart';

/// Cart Item Model - Matches 'cart' table
class CartModel {
  final String id;
  final String userId;
  final String productId;
  final int quantity;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? selectedColor;
  final String? selectedSize;

  // Joined product data
  final ProductModel? product;

  CartModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.quantity,
    required this.createdAt,
    this.updatedAt,
    this.product,
    this.selectedColor,
    this.selectedSize,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['products'] as Map<String, dynamic>?;

    return CartModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int? ?? 1,
      selectedColor: json['selected_color'] as String?,   // ← ADD THIS
      selectedSize: json['selected_size'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      product: productJson != null ? ProductModel.fromJson(productJson) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Calculate total price for this cart item
  double get totalPrice {
    if (product == null) return 0;
    return product!.price * quantity;
  }

  // Formatted total price
  String get formattedTotalPrice {
    final total = totalPrice;
    return '₦${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  // Check if product is still available
  bool get isProductAvailable {
    return product?.isAvailable ?? false;
  }

  // Check if requested quantity is in stock
  bool get isInStock {
    if (product == null) return false;
    return product!.stockQuantity >= quantity;
  }

  CartModel copyWith({
    String? id,
    String? userId,
    String? productId,
    int? quantity,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProductModel? product,
    String? selectedColor,
    String? selectedSize,
  }) {
    return CartModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      product: product ?? this.product,
      selectedColor: selectedColor ?? this.selectedColor,
      selectedSize: selectedSize ?? this.selectedSize,
    );
  }
}
