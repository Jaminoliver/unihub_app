import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../constants/app_colors.dart';

class RelatedProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const RelatedProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  String _formatPrice(double price) {
    return '₦${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 145,
        margin: EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 120,
                width: double.infinity,
                color: AppColors.background,
                child: product.imageUrls.isNotEmpty
                    ? Image.network(
                        product.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.textLight.withOpacity(0.5),
                            size: 30,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.textLight.withOpacity(0.3),
                        size: 40,
                      ),
              ),
            ),
            
            // Product Info - Fixed overflow completely
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    
                    // Price
                    Text(
                      _formatPrice(product.price),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                    
                    Spacer(),
                    
                    // University - Fixed overflow completely with proper constraints
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 10,
                          color: Color(0xFFFF6B35),
                        ),
                        SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            product.universityName ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFFFF6B35),
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}