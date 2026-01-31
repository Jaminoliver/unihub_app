import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/product_video_model.dart';
import '../services/video_service.dart';
import '../services/auth_service.dart';
import '../services/download_manager.dart';
import '../constants/app_colors.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/global_download_indicator.dart';
import 'product_details_screen.dart';
import 'dart:developer' as developer;

const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class TikTokScrollPhysics extends ClampingScrollPhysics {
  const TikTokScrollPhysics({super.parent});

  @override
  TikTokScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TikTokScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 50.0;
  
  @override
  double get minFlingDistance => 25.0;
  
  @override
  double get maxFlingVelocity => 8000.0;
  
  @override
  Tolerance get tolerance => const Tolerance(
    velocity: 1.0,
    distance: 0.5,
  );
  
  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}

class VideoFeedScreen extends StatefulWidget {
  final String? userState;
  final bool isVisible;
  
  const VideoFeedScreen({
    super.key, 
    this.userState,
    this.isVisible = false,
  });

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> 
    with WidgetsBindingObserver {
  final _videoService = VideoService();
  final _authService = AuthService();
  final _downloadManager = DownloadManager();
  late PageController _pageController;

  List<ProductVideoModel> _videos = [];
  Set<String> _likedVideoIds = {};
  Map<int, VideoPlayerController> _controllers = {};
  
  bool _isInitialLoad = true;
  bool _isRefreshing = false;
  int _currentIndex = 0;
  String? _userId;

  // =========================================
  // ENHANCED ERROR LOGGING
  // =========================================
  void _logError(String operation, dynamic error, [StackTrace? stackTrace]) {
    print('');
    print('🎬❌ ========================================');
    print('🎬❌ VIDEO FEED ERROR');
    print('🎬❌ Operation: $operation');
    print('🎬❌ Timestamp: ${DateTime.now().toIso8601String()}');
    print('🎬❌ Error: $error');
    if (stackTrace != null) {
      print('🎬❌ Stack trace:');
      print(stackTrace.toString().split('\n').take(5).join('\n'));
    }
    print('🎬❌ ========================================');
    print('');
    
    developer.log(
      '[$operation] Error: $error',
      name: 'VideoFeedScreen',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _logVideoPlayerError(int index, String videoUrl, dynamic error) {
    print('');
    print('🎥❌ ========================================');
    print('🎥❌ VIDEO PLAYER INITIALIZATION FAILED');
    print('🎥❌ Timestamp: ${DateTime.now().toIso8601String()}');
    print('🎥❌ Video Index: $index');
    print('🎥❌ Video ID: ${index < _videos.length ? _videos[index].id : "N/A"}');
    print('🎥❌ Video URL: $videoUrl');
    print('🎥❌ URL Length: ${videoUrl.length}');
    print('🎥❌ URL Protocol: ${videoUrl.startsWith('https://') ? "HTTPS" : videoUrl.startsWith('http://') ? "HTTP" : "INVALID"}');
    print('🎥❌ Contains "public": ${videoUrl.contains('/public/')}');
    print('🎥❌ Contains "sign": ${videoUrl.contains('/sign/')}');
    print('🎥❌ Error: $error');
    print('🎥❌ Error Type: ${error.runtimeType}');
    print('🎥❌ ========================================');
    print('');
    
    developer.log(
      '[Video $index] Player error: $error',
      name: 'VideoPlayer',
      error: error,
    );
  }

  void _logInfo(String operation, String message) {
    print('ℹ️  [VideoFeed:$operation] $message');
    developer.log(
      '[$operation] $message',
      name: 'VideoFeedScreen',
    );
  }

  void _logSuccess(String operation, String message) {
    print('✅ [VideoFeed:$operation] $message');
    developer.log(
      '[$operation] $message',
      name: 'VideoFeedScreen',
    );
  }

  @override
  void initState() {
    super.initState();
    _logInfo('initState', 'Initializing VideoFeedScreen');
    _pageController = PageController(viewportFraction: 1.0, keepPage: true);
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
  }

  @override
  void didUpdateWidget(VideoFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible && !oldWidget.isVisible) {
      _logInfo('didUpdateWidget', 'Screen became visible - playing video $_currentIndex');
      _controllers[_currentIndex]?.play();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _logInfo('didUpdateWidget', 'Screen hidden - pausing all videos');
      _pauseAllVideos();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _logInfo('didChangeAppLifecycleState', 'App lifecycle: $state');
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseAllVideos();
    } else if (state == AppLifecycleState.resumed) {
      _controllers[_currentIndex]?.play();
    }
  }

  @override
  void dispose() {
    _logInfo('dispose', 'Disposing VideoFeedScreen');
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _pauseAllVideos();
    for (var controller in _controllers.values) {
      controller.pause();
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  void _pauseAllVideos() {
    _logInfo('_pauseAllVideos', 'Pausing ${_controllers.length} videos');
    for (var controller in _controllers.values) {
      controller.pause();
    }
  }

  Future<void> _initializeData() async {
    final operation = '_initializeData';
    if (_isRefreshing) {
      _logInfo(operation, 'Already refreshing, skipping');
      return;
    }
    
    try {
      _logInfo(operation, 'Starting data initialization');
      
      _userId = _authService.currentUserId;
      _logInfo(operation, 'User ID: ${_userId ?? "NOT LOGGED IN"}');
      
      _logInfo(operation, 'Fetching videos...');
      final videos = await _videoService.getAllVideos(limit: 50);
      _logSuccess(operation, 'Fetched ${videos.length} videos');

      if (_userId != null) {
        _logInfo(operation, 'Fetching liked videos...');
        final likedIds = await _videoService.getUserLikedVideoIds(_userId!);
        _logSuccess(operation, 'User has liked ${likedIds.length} videos');
        if (mounted) setState(() => _likedVideoIds = likedIds);
      }

      if (mounted) {
        setState(() {
          _videos = videos;
          _isInitialLoad = false;
          _isRefreshing = false;
        });

        if (videos.isNotEmpty) {
          _logInfo(operation, 'Initializing first video');
          _initializeVideoAt(0);
        } else {
          _logInfo(operation, 'No videos to display');
        }
      }
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refreshVideos() async {
    final operation = '_refreshVideos';
    if (_isRefreshing || _isInitialLoad) {
      _logInfo(operation, 'Already refreshing or loading, skipping');
      return;
    }

    _logInfo(operation, 'Starting video refresh');
    setState(() => _isRefreshing = true);

    try {
      final oldVideoIds = _videos.map((v) => v.id).toSet();
      final currentVideoId = _currentIndex < _videos.length ? _videos[_currentIndex].id : null;
      
      _controllers[_currentIndex]?.pause();

      _logInfo(operation, 'Fetching new videos...');
      final newVideos = await _videoService.getAllVideos(limit: 50);
      _logSuccess(operation, 'Fetched ${newVideos.length} new videos');
      
      if (_userId != null) {
        final likedIds = await _videoService.getUserLikedVideoIds(_userId!);
        if (mounted) setState(() => _likedVideoIds = likedIds);
      }

      final newVideoIds = newVideos.map((v) => v.id).toSet();
      final hasNewVideos = newVideoIds.difference(oldVideoIds).isNotEmpty;

      if (mounted) {
        // Dispose old controllers
        _logInfo(operation, 'Disposing ${_controllers.length} old controllers');
        for (var controller in _controllers.values) {
          controller.dispose();
        }
        _controllers.clear();

        setState(() {
          _videos = newVideos;
          _isRefreshing = false;
        });

        if (hasNewVideos && newVideos.isNotEmpty) {
          _logSuccess(operation, 'New videos found, jumping to start');
          _pageController.jumpToPage(0);
          _currentIndex = 0;
          _initializeVideoAt(0);
          _showSnackBar('New videos loaded!');
        } else {
          _logInfo(operation, 'No new videos, maintaining position');
          if (currentVideoId != null) {
            final newIndex = _videos.indexWhere((v) => v.id == currentVideoId);
            if (newIndex != -1) {
              _pageController.jumpToPage(newIndex);
              _currentIndex = newIndex;
              _initializeVideoAt(newIndex);
            } else {
              final safeIndex = _currentIndex < _videos.length ? _currentIndex : 0;
              _pageController.jumpToPage(safeIndex);
              _currentIndex = safeIndex;
              _initializeVideoAt(safeIndex);
            }
          }
          _showSnackBar('No new videos available');
        }
      }
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      if (mounted) {
        setState(() => _isRefreshing = false);
        _showSnackBar('Failed to refresh videos');
      }
    }
  }

  void _initializeVideoAt(int index) {
    final operation = '_initializeVideoAt';
    
    if (index < 0 || index >= _videos.length) {
      _logError(operation, 'Invalid index: $index (total videos: ${_videos.length})');
      return;
    }
    
    if (_controllers.containsKey(index)) {
      _logInfo(operation, 'Controller already exists for index $index');
      return;
    }

    final video = _videos[index];
    _logInfo(operation, 'Initializing video at index $index');
    _logInfo(operation, 'Video ID: ${video.id}');
    _logInfo(operation, 'Video URL: ${video.videoUrl}');
    _logInfo(operation, 'Video URL length: ${video.videoUrl.length}');
    _logInfo(operation, 'URL starts with HTTPS: ${video.videoUrl.startsWith('https://')}');
    
    // Validate URL format
    if (!video.videoUrl.startsWith('http://') && !video.videoUrl.startsWith('https://')) {
      _logError(operation, 'Invalid URL protocol for video $index: ${video.videoUrl}');
      return;
    }
    
    if (video.videoUrl.contains('/sign/')) {
      print('⚠️  WARNING: Video $index uses signed URL (may expire): ${video.videoUrl}');
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(video.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      _logInfo(operation, 'VideoPlayerController created for index $index');

      controller.initialize().then((_) {
        _logSuccess(operation, 'Video $index initialized successfully');
        _logInfo(operation, 'Video $index duration: ${controller.value.duration}');
        _logInfo(operation, 'Video $index size: ${controller.value.size}');
        _logInfo(operation, 'Video $index aspect ratio: ${controller.value.aspectRatio}');
        
        if (mounted) {
          controller.setLooping(true);
          if (_currentIndex == index && widget.isVisible) {
            _logInfo(operation, 'Playing video $index');
            controller.play();
          }
          setState(() {});
        }
      }).catchError((error, stackTrace) {
        _logVideoPlayerError(index, video.videoUrl, error);
        
        // Try to get more detailed error information
        if (error is Exception) {
          print('🎥❌ Exception details: ${error.toString()}');
        }
        
        // Log controller state
        print('🎥❌ Controller state:');
        print('🎥❌   isInitialized: ${controller.value.isInitialized}');
        print('🎥❌   hasError: ${controller.value.hasError}');
        print('🎥❌   errorDescription: ${controller.value.errorDescription}');
      });

      _controllers[index] = controller;
      _logSuccess(operation, 'Controller stored for index $index');
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      _logVideoPlayerError(index, video.videoUrl, e);
    }
  }

  void _onPageChanged(int index) {
    final operation = '_onPageChanged';
    _logInfo(operation, 'Page changed to index $index');
    
    // Pause all other videos
    for (var entry in _controllers.entries) {
      if (entry.key != index) entry.value.pause();
    }

    if (_controllers.containsKey(index)) {
      _logInfo(operation, 'Playing video at index $index');
      _controllers[index]?.play();
    } else {
      _logInfo(operation, 'Initializing video at index $index');
      _initializeVideoAt(index);
    }

    // Preload next video
    if (index + 1 < _videos.length && !_controllers.containsKey(index + 1)) {
      _logInfo(operation, 'Preloading next video at index ${index + 1}');
      _initializeVideoAt(index + 1);
    }

    // Cleanup far videos
    _controllers.removeWhere((key, controller) {
      if ((key - index).abs() > 1) {
        _logInfo(operation, 'Disposing video at index $key (too far from current)');
        controller.pause();
        controller.dispose();
        return true;
      }
      return false;
    });

    setState(() => _currentIndex = index);
    _videoService.incrementViews(_videos[index].id);
  }

  Future<void> _toggleLike(ProductVideoModel video) async {
    if (_userId == null) {
      _showSnackBar('Please log in to like videos');
      return;
    }

    try {
      final isNowLiked = await _videoService.toggleLike(userId: _userId!, videoId: video.id);
      setState(() {
        if (isNowLiked) {
          _likedVideoIds.add(video.id);
        } else {
          _likedVideoIds.remove(video.id);
        }
      });

      final index = _videos.indexWhere((v) => v.id == video.id);
      if (index != -1) {
        setState(() {
          _videos[index] = _videos[index].copyWith(
            likesCount: isNowLiked ? _videos[index].likesCount + 1 : _videos[index].likesCount - 1,
          );
        });
      }
    } catch (e) {
      _logError('_toggleLike', e);
      _showSnackBar('Failed to update like');
    }
  }

  void _onCommentAdded(String videoId) {
    final index = _videos.indexWhere((v) => v.id == videoId);
    if (index != -1) {
      setState(() {
        _videos[index] = _videos[index].copyWith(
          commentsCount: _videos[index].commentsCount + 1,
        );
      });
    }
  }

  void _onCommentDeleted(String videoId) {
    final index = _videos.indexWhere((v) => v.id == videoId);
    if (index != -1) {
      setState(() {
        _videos[index] = _videos[index].copyWith(
          commentsCount: _videos[index].commentsCount - 1,
        );
      });
    }
  }

  void _navigateToProduct(ProductVideoModel video) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: video.productId)),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoad) {
      return WillPopScope(
        onWillPop: () async {
          _pauseAllVideos();
          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
                  child: const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading feed...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return WillPopScope(
        onWillPop: () async {
          _pauseAllVideos();
          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(),
          body: RefreshIndicator(
            onRefresh: _refreshVideos,
            color: const Color(0xFFFF6B35),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
                        child: const Icon(Icons.videocam_off, size: 80, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No Videos Available',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pull down to refresh',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        _pauseAllVideos();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: _buildAppBar(),
        body: RefreshIndicator(
          onRefresh: _refreshVideos,
          color: const Color(0xFFFF6B35),
          backgroundColor: Colors.white,
          displacement: 40,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                onPageChanged: _onPageChanged,
                itemCount: _videos.length,
                physics: const TikTokScrollPhysics(),
                pageSnapping: true,
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  final isLiked = _likedVideoIds.contains(video.id);
                  final controller = _controllers[index];

                  return VideoPlayerWidget(
                    key: ValueKey(video.id),
                    video: video,
                    controller: controller,
                    isLiked: isLiked,
                    userId: _userId,
                    onLike: () => _toggleLike(video),
                    onCommentAdded: () => _onCommentAdded(video.id),
                    onCommentDeleted: () => _onCommentDeleted(video.id),
                    onProductTap: () => _navigateToProduct(video),
                  );
                },
              ),
              if (_isRefreshing) _buildRefreshIndicator(),
              
              // GLOBAL DOWNLOAD INDICATOR - Always visible, persists across video swipes
              const GlobalDownloadIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: ShaderMask(
        shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
        child: const Text(
          'Vibe',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildRefreshIndicator() {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: kOrangeGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text(
                'Refreshing...',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}