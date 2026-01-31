import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../models/product_video_model.dart';
import '../services/video_service.dart';
import '../services/download_manager.dart';
import '../constants/app_colors.dart';

const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class VideoPlayerWidget extends StatefulWidget {
  final ProductVideoModel video;
  final VideoPlayerController? controller;
  final bool isLiked;
  final String? userId;
  final VoidCallback onLike;
  final VoidCallback onCommentAdded;
  final VoidCallback onCommentDeleted;
  final VoidCallback onProductTap;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    required this.controller,
    required this.isLiked,
    required this.userId,
    required this.onLike,
    required this.onCommentAdded,
    required this.onCommentDeleted,
    required this.onProductTap,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> 
    with SingleTickerProviderStateMixin {
  final _videoService = VideoService();
  final _downloadManager = DownloadManager();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String? _selectedColor;
  String? _selectedSize;
  List<String> _availableColors = [];
  List<String> _availableSizes = [];
  bool _isLoadingOptions = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 300)
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
    _loadProductOptions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProductOptions() async {
    try {
      setState(() {
        _availableColors = widget.video.colors ?? [];
        _availableSizes = widget.video.sizes ?? [];
        
        if (_availableColors.length == 1) _selectedColor = _availableColors.first;
        if (_availableSizes.length == 1) _selectedSize = _availableSizes.first;
        
        _isLoadingOptions = false;
      });
    } catch (e) {
      setState(() => _isLoadingOptions = false);
    }
  }

  bool _canAddToCart() {
    if (_availableColors.isNotEmpty && _selectedColor == null) return false;
    if (_availableSizes.isNotEmpty && _selectedSize == null) return false;
    return true;
  }

  Future<void> _handleAddToCart() async {
    if (!_canAddToCart()) {
      _showSnackBar('Please select all options');
      return;
    }

    try {
      _showSnackBar('Added to cart!');
    } catch (e) {
      _showSnackBar('Failed to add to cart');
    }
  }

  void _togglePlayPause() {
    if (widget.controller == null || !widget.controller!.value.isInitialized) return;

    setState(() {
      if (widget.controller!.value.isPlaying) {
        widget.controller!.pause();
      } else {
        widget.controller!.play();
      }
    });
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        videoId: widget.video.id,
        userId: widget.userId,
        onCommentAdded: widget.onCommentAdded,
        onCommentDeleted: widget.onCommentDeleted,
      ),
    );
  }

  void _showShareMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCardBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getTextMuted(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: ShaderMask(
                  shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
                  child: const Text(
                    'Share Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Download Video Option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: kOrangeGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                ),
                title: Text(
                  'Download Video',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                subtitle: Text(
                  'Save to your gallery with watermark',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextMuted(context),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _downloadVideo();
                },
              ),
              
              // Share Link Option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: kOrangeGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 20),
                ),
                title: Text(
                  'Share Video',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                subtitle: Text(
                  'Share with friends',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextMuted(context),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _shareLink();
                },
              ),
              
              // Copy Link Option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: kOrangeGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.link, color: Colors.white, size: 20),
                ),
                title: Text(
                  'Copy Link',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                subtitle: Text(
                  'Copy to clipboard',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextMuted(context),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _copyLink();
                },
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadVideo() async {
    print('');
    print('📥 ========================================');
    print('📥 DOWNLOAD REQUESTED');
    print('📥 Video ID: ${widget.video.id}');
    print('📥 Video URL: ${widget.video.videoUrl}');
    print('📥 ========================================');
    
    try {
      // Check if already downloading
      if (_downloadManager.isDownloading) {
        _showSnackBar('⏳ Another download is in progress');
        return;
      }

      // Check and request permissions
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        print('📥 ❌ Storage permission denied');
        _showSnackBar('❌ Storage permission required');
        return;
      }

      // Start download using global download manager
      // Video will continue playing - no pause!
      await _downloadManager.downloadVideo(
        videoId: widget.video.id,
        videoUrl: widget.video.videoUrl,
        onComplete: (message) {
          if (mounted) {
            _showSnackBar(message);
          }
        },
        onError: (message) {
          if (mounted) {
            _showSnackBar(message);
          }
        },
      );
      
    } catch (e, stackTrace) {
      print('📥 ❌ Download request failed!');
      print('📥 Error: $e');
      print('📥 Stack trace: $stackTrace');
      
      _showSnackBar('❌ Failed to start download');
    }
  }

  // FIXED: Permission handler with proper device_info_plus usage
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ (API 33+): Use granular media permissions
        print('📥 Android 13+ detected (SDK ${androidInfo.version.sdkInt}), checking media permissions');
        
        if (await Permission.photos.isGranted || await Permission.videos.isGranted) {
          print('📥 ✅ Media permission already granted');
          return true;
        }

        // Request permissions
        final photoStatus = await Permission.photos.request();
        final videoStatus = await Permission.videos.request();
        
        if (photoStatus.isGranted || videoStatus.isGranted) {
          print('📥 ✅ Media permission granted');
          return true;
        }
        
        if (photoStatus.isPermanentlyDenied || videoStatus.isPermanentlyDenied) {
          print('📥 ⚠️  Permission permanently denied, showing settings dialog');
          return await _showPermissionDialog();
        }

        print('📥 ❌ Permission denied');
        return false;
        
      } else {
        // Android 12 and below: Use storage permission
        print('📥 Android 12 or below detected (SDK ${androidInfo.version.sdkInt}), checking storage permission');
        
        if (await Permission.storage.isGranted) {
          print('📥 ✅ Storage permission already granted');
          return true;
        }

        final status = await Permission.storage.request();
        
        if (status.isGranted) {
          print('📥 ✅ Storage permission granted');
          return true;
        }
        
        if (status.isPermanentlyDenied) {
          print('📥 ⚠️  Permission permanently denied, showing settings dialog');
          return await _showPermissionDialog();
        }

        print('📥 ❌ Permission denied');
        return false;
      }
    } catch (e) {
      print('📥 ⚠️  Permission error: $e');
      return false;
    }
  }

  Future<bool> _showPermissionDialog() async {
    if (!mounted) return false;
    
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Storage permission is required to save videos. '
          'Please grant permission in app settings.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await openAppSettings();
    }
    
    return false;
  }

  Future<void> _shareLink() async {
    print('');
    print('🔗 ========================================');
    print('🔗 SHARE VIDEO STARTED');
    print('🔗 Video ID: ${widget.video.id}');
    print('🔗 Product: ${widget.video.productName}');
    print('🔗 ========================================');
    
    try {
      final videoLink = 'https://unihub.app/video/${widget.video.id}';
      final productName = widget.video.productName ?? 'product';
      final price = widget.video.formattedPrice;
      
      final shareMessage = '🛍️ Check out this amazing $productName on UniHub!\n\n'
          '💰 Price: $price\n\n'
          '🎥 Watch the video: $videoLink\n\n'
          '📱 Download UniHub to explore more campus deals!';
      
      print('🔗 Share message prepared');
      
      final result = await Share.share(
        shareMessage,
        subject: 'Check out $productName on UniHub!',
      );
      
      if (result.status == ShareResultStatus.success) {
        print('🔗 ✅ Shared successfully');
        _showSnackBar('✅ Shared successfully!');
      } else if (result.status == ShareResultStatus.dismissed) {
        print('🔗 Share dismissed by user');
      }
      
      print('🔗 ========================================');
      print('');
    } catch (e, stackTrace) {
      print('🔗 ❌ Share failed!');
      print('🔗 Error: $e');
      print('🔗 Stack trace: $stackTrace');
      print('🔗 ========================================');
      print('');
      
      _showSnackBar('❌ Failed to share');
    }
  }

  Future<void> _copyLink() async {
    try {
      final videoLink = 'https://unihub.app/video/${widget.video.id}';
      
      await Clipboard.setData(ClipboardData(text: videoLink));
      
      print('🔗 ✅ Link copied to clipboard');
      _showSnackBar('✅ Link copied to clipboard!');
    } catch (e) {
      print('🔗 ❌ Failed to copy link: $e');
      _showSnackBar('❌ Failed to copy link');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (message.contains('✅'))
              const Icon(Icons.check_circle, color: Colors.white, size: 20)
            else if (message.contains('❌'))
              const Icon(Icons.error_outline, color: Colors.white, size: 20)
            else if (message.contains('⏳'))
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            if (message.contains('✅') || message.contains('❌') || message.contains('⏳'))
              const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: message.contains('✅') ? Colors.green : 
                         message.contains('❌') ? Colors.red : 
                         const Color(0xFFFF6B35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized = widget.controller?.value.isInitialized ?? false;
    final isPlaying = widget.controller?.value.isPlaying ?? false;

    return GestureDetector(
      onTap: _togglePlayPause,
      onLongPress: _showShareMenu,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isInitialized && widget.controller != null)
            FadeTransition(
              opacity: _fadeAnimation,
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: widget.controller!.value.size.width,
                    height: widget.controller!.value.size.height,
                    child: VideoPlayer(widget.controller!),
                  ),
                ),
              ),
            )
          else
            _buildThumbnail(),

          if (isInitialized && !isPlaying) _buildPlayPauseIndicator(),

          _buildActionButtons(),
          _buildProductInfo(),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: widget.video.thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[900],
            child: const ShimmerEffect(),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[900],
            child: const Icon(Icons.error_outline, color: Colors.white, size: 50),
          ),
        ),
        if (widget.controller != null && !(widget.controller!.value.isInitialized))
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: kOrangeGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayPauseIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: kOrangeGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      right: 12,
      bottom: 90,
      child: Column(
        children: [
          // Like Button
          GestureDetector(
            onTap: widget.onLike,
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(8),
              child: ActionButton(
                icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
                label: _formatCount(widget.video.likesCount),
                isActive: widget.isLiked,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Comment Button
          GestureDetector(
            onTap: _openComments,
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(8),
              child: ActionButton(
                icon: Icons.mode_comment_outlined,
                label: _formatCount(widget.video.commentsCount),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Views Button
          ActionButton(
            icon: Icons.remove_red_eye_outlined,
            label: _formatCount(widget.video.viewsCount),
          ),
          const SizedBox(height: 16),
          
          // Share Button - Opens menu with download option
          GestureDetector(
            onTap: _showShareMenu,
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(8),
              child: const ActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Positioned(
      left: 12,
      right: 70,
      bottom: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onProductTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.video.productName != null)
                        Text(
                          widget.video.productName!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
                            child: Text(
                              widget.video.formattedPrice,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  '4.5',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  ' (23)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_availableColors.isNotEmpty) _buildColorSelector(),
          if (_availableSizes.isNotEmpty) _buildSizeSelector(),
          _buildAddToCartButton(),
        ],
      ),
    );
  }

  Widget _buildColorSelector() {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'COLOR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _availableColors.map((colorName) {
                    final isSelected = _selectedColor == colorName;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = colorName),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFFFF6B35) 
                              : Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          colorName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey[800],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSizeSelector() {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'SIZE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _availableSizes.map((size) {
                    final isSelected = _selectedSize == size;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSize = size),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Colors.grey[800] 
                              : Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          size,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey[800],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAddToCartButton() {
    return GestureDetector(
      onTap: _handleAddToCart,
      child: Opacity(
        opacity: _canAddToCart() ? 1.0 : 0.5,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 18, color: Colors.grey[800]),
              const SizedBox(width: 10),
              Text(
                _canAddToCart() ? 'Add to Cart' : 'Select Options',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Supporting Widgets

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: isActive ? const Color(0xFFFF6B35) : Colors.white,
          size: 28,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class ShimmerEffect extends StatefulWidget {
  const ShimmerEffect({super.key});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.05),
                Colors.transparent,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ),
          ),
        );
      },
    );
  }
}

class CommentsBottomSheet extends StatefulWidget {
  final String videoId;
  final String? userId;
  final VoidCallback onCommentAdded;
  final VoidCallback onCommentDeleted;

  const CommentsBottomSheet({
    super.key,
    required this.videoId,
    this.userId,
    required this.onCommentAdded,
    required this.onCommentDeleted,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final _videoService = VideoService();
  final _commentController = TextEditingController();
  bool _isPosting = false;
  int _refreshKey = 0;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      await _videoService.addComment(
        userId: widget.userId!,
        videoId: widget.videoId,
        commentText: text,
      );

      _commentController.clear();
      widget.onCommentAdded();
      
      setState(() {
        _isPosting = false;
        _refreshKey++;
      });
    } catch (e) {
      setState(() => _isPosting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    if (widget.userId == null) return;

    try {
      await _videoService.deleteComment(
        commentId: commentId,
        userId: widget.userId!,
      );

      widget.onCommentDeleted();
      setState(() => _refreshKey++);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete comment')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getTextMuted(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
                      child: const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.getTextSecondary(context)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.getBorder(context).withOpacity(0.3)),
              Expanded(
                child: FutureBuilder(
                  key: ValueKey(_refreshKey),
                  future: _videoService.getVideoComments(videoId: widget.videoId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
                          child: const CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    }

                    final comments = snapshot.data!;

                    if (comments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: TextStyle(
                                color: AppColors.getTextSecondary(context),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Be the first to comment!',
                              style: TextStyle(
                                color: AppColors.getTextMuted(context),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final isMyComment = comment.userId == widget.userId;

                        return Dismissible(
                          key: Key(comment.id),
                          direction: isMyComment 
                              ? DismissDirection.endToStart 
                              : DismissDirection.none,
                          confirmDismiss: (direction) async {
                            if (!isMyComment) return false;
                            return await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Comment'),
                                content: const Text(
                                  'Are you sure you want to delete this comment?'
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) => _deleteComment(comment.id),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primaryOrange.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundImage: comment.userImageUrl != null
                                        ? CachedNetworkImageProvider(comment.userImageUrl!)
                                        : null,
                                    backgroundColor: AppColors.getBackground(context),
                                    child: comment.userImageUrl == null
                                        ? Icon(
                                            Icons.person,
                                            size: 18,
                                            color: AppColors.getTextMuted(context),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            comment.displayName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.getTextPrimary(context),
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            comment.timeSinceComment,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.getTextMuted(context),
                                            ),
                                          ),
                                          if (isMyComment) ...[
                                            const Spacer(),
                                            Icon(
                                              Icons.swipe_left,
                                              size: 14,
                                              color: AppColors.getTextMuted(context),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        comment.commentText,
                                        style: TextStyle(
                                          color: AppColors.getTextSecondary(context),
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getCardBackground(context),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.getBorder(context).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(color: AppColors.getTextMuted(context)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: AppColors.getBorder(context)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: AppColors.getBorder(context).withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF6B35),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isPosting ? null : _postComment,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: _isPosting ? null : kOrangeGradient,
                            color: _isPosting ? Colors.grey : null,
                            shape: BoxShape.circle,
                          ),
                          child: _isPosting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}