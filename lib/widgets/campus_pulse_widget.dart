import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../screens/product_details_screen.dart';

class CampusPulseWidget extends StatefulWidget {
  final String? universityId;

  const CampusPulseWidget({super.key, this.universityId});

  @override
  State<CampusPulseWidget> createState() => _CampusPulseWidgetState();
}

class _CampusPulseWidgetState extends State<CampusPulseWidget>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _productService = ProductService();
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _loadActivities();
    _subscribeToActivities();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    if (widget.universityId == null) return;

    try {
      final response = await _supabase
          .from('campus_activity_feed')
          .select('*')
          .eq('university_id', widget.universityId!)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _activities = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading campus activities: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToActivities() {
    if (widget.universityId == null) return;

    _supabase
        .channel('campus_pulse')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'campus_activity_feed',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'university_id',
            value: widget.universityId,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                _activities.insert(0, payload.newRecord);
                if (_activities.length > 10) {
                  _activities = _activities.sublist(0, 10);
                }
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _navigateToProduct(String productId) async {
    try {
      final product = await _productService.getProductById(productId);
      if (product != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(product: product),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading product: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.universityId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.3),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFFD700)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFFF6B35).withOpacity(0.5),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.bolt, color: Colors.white, size: 14),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Campus Pulse',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '🔥',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  Text(
                    'Hot deals in your state!',
                    style: TextStyle(fontSize: 9, color: AppColors.textLight),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF1744)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFF6B35).withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_isLoading)
          SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
                strokeWidth: 2,
              ),
            ),
          )
        else if (_activities.isEmpty)
          SizedBox(
            height: 100,
            child: Center(
              child: Text(
                '💤 Quiet right now',
                style: TextStyle(color: AppColors.textLight, fontSize: 12),
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                return _CompactActivityCard(
                  activity: _activities[index],
                  onTap: () => _navigateToProduct(_activities[index]['product_id']),
                  index: index,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CompactActivityCard extends StatefulWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onTap;
  final int index;

  const _CompactActivityCard({
    required this.activity,
    required this.onTap,
    required this.index,
  });

  @override
  State<_CompactActivityCard> createState() => _CompactActivityCardState();
}

class _CompactActivityCardState extends State<_CompactActivityCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + (widget.index * 50)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyerName = widget.activity['buyer_name'] as String? ?? 'Someone';
    final productName = widget.activity['product_name'] as String;
    final productImage = widget.activity['product_image'] as String?;
    final createdAt = DateTime.parse(widget.activity['created_at'] as String);

    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0.3, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Color(0xFFFFF8F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF6B35).withOpacity(0.15),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Color(0xFFFF6B35).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Sparkle decoration
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Text('✨', style: TextStyle(fontSize: 12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: productImage != null
                              ? CachedNetworkImage(
                                  imageUrl: productImage,
                                  height: 48,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppColors.background,
                                    child: Icon(Icons.image, size: 20, color: AppColors.textLight),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: AppColors.background,
                                    child: Icon(Icons.shopping_bag_outlined, size: 20, color: AppColors.textLight),
                                  ),
                                )
                              : Container(
                                  height: 48,
                                  color: AppColors.background,
                                  child: Icon(Icons.shopping_bag_outlined, size: 20, color: AppColors.textLight),
                                ),
                        ),
                        const SizedBox(height: 5),
                        // Product name
                        Text(
                          productName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        // Buyer info
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFFF6B35), Color(0xFFFFD700)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  buyerName[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '$buyerName  bought this',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Time badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            timeago.format(createdAt, locale: 'en_short'),
                            style: TextStyle(
                              fontSize: 8,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}