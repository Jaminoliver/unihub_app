import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_video_model.dart';
import '../models/video_comment_model.dart';
import 'dart:developer' as developer;

class VideoService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =========================================
  // ENHANCED ERROR LOGGING HELPER
  // =========================================
  void _logError(String operation, dynamic error, [StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    print('');
    print('❌❌❌ ========================================');
    print('❌ OPERATION: $operation');
    print('❌ TIMESTAMP: $timestamp');
    print('❌ ERROR TYPE: ${error.runtimeType}');
    print('❌ ERROR MESSAGE: $error');
    
    if (error is PostgrestException) {
      print('❌ [POSTGREST ERROR]');
      print('❌   Code: ${error.code}');
      print('❌   Message: ${error.message}');
      print('❌   Details: ${error.details}');
      print('❌   Hint: ${error.hint}');
    }
    
    if (error is StorageException) {
      print('❌ [STORAGE ERROR]');
      print('❌   Message: ${error.message}');
      print('❌   Status Code: ${error.statusCode}');
    }
    
    if (stackTrace != null) {
      print('❌ STACK TRACE:');
      print(stackTrace.toString().split('\n').take(5).join('\n'));
    }
    
    print('❌❌❌ ========================================');
    print('');
    
    // Also log to developer console for easier debugging
    developer.log(
      '[$operation] Error: $error',
      name: 'VideoService',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _logSuccess(String operation, [String? details]) {
    print('✅ [$operation] ${details ?? 'Success'}');
    developer.log(
      '[$operation] ${details ?? 'Success'}',
      name: 'VideoService',
    );
  }

  void _logInfo(String operation, String message) {
    print('ℹ️  [$operation] $message');
    developer.log(
      '[$operation] $message',
      name: 'VideoService',
    );
  }

  // =========================================
  // VIDEO URL VALIDATION & DEBUGGING
  // =========================================
  bool _isValidVideoUrl(String url) {
    if (url.isEmpty) {
      _logError('URL Validation', 'Empty URL detected');
      return false;
    }
    
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _logError('URL Validation', 'URL does not start with http/https: $url');
      return false;
    }
    
    // Check if it's a signed URL (temporary)
    if (url.contains('/storage/v1/object/sign/')) {
      print('⚠️  [URL Warning] Signed URL detected (may expire): $url');
    }
    
    // Check if it's a public URL (permanent)
    if (url.contains('/storage/v1/object/public/')) {
      print('✅ [URL Validation] Public URL detected: $url');
    }
    
    return true;
  }

  /// Fetch all active videos with product and seller info
  Future<List<ProductVideoModel>> getAllVideos({
    int limit = 50,
    int offset = 0,
  }) async {
    final operation = 'getAllVideos';
    try {
      _logInfo(operation, 'Fetching videos: limit=$limit, offset=$offset');
      _logInfo(operation, 'Auth user: ${_supabase.auth.currentUser?.id ?? "NOT LOGGED IN"}');

      final response = await _supabase
          .from('product_videos')
          .select('''
            *,
            products(id, name, price, colors, sizes),
            sellers(id, business_name, full_name)
          ''')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final videos = (response as List)
          .map((json) => ProductVideoModel.fromJson(json as Map<String, dynamic>))
          .toList();

      _logSuccess(operation, 'Fetched ${videos.length} videos');
      
      // Validate video URLs
      int invalidUrls = 0;
      for (var video in videos) {
        if (!_isValidVideoUrl(video.videoUrl)) {
          invalidUrls++;
          _logError('URL Validation', 'Invalid URL for video ${video.id}: ${video.videoUrl}');
        }
      }
      
      if (invalidUrls > 0) {
        print('⚠️  Found $invalidUrls videos with invalid URLs out of ${videos.length}');
      }
      
      return videos;
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      throw Exception('Failed to fetch videos: $e');
    }
  }

  /// Fetch videos by university (for state-based filtering)
  Future<List<ProductVideoModel>> getVideosByState({
    required String state,
    int limit = 50,
    int offset = 0,
  }) async {
    final operation = 'getVideosByState';
    try {
      _logInfo(operation, 'Fetching videos for state: $state');

      final response = await _supabase
          .from('product_videos')
          .select('''
            *,
            products!inner(id, name, price, colors, sizes, university_id),
            sellers(id, business_name, full_name),
            products.universities!inner(state)
          ''')
          .eq('is_active', true)
          .eq('products.universities.state', state)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final videos = (response as List)
          .map((json) => ProductVideoModel.fromJson(json as Map<String, dynamic>))
          .toList();

      _logSuccess(operation, 'Fetched ${videos.length} videos for state: $state');
      return videos;
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      throw Exception('Failed to fetch videos by state: $e');
    }
  }

  /// Fetch videos for a specific product
  Future<List<ProductVideoModel>> getVideosByProduct(String productId) async {
    final operation = 'getVideosByProduct';
    try {
      _logInfo(operation, 'Fetching videos for product: $productId');
      
      final response = await _supabase
          .from('product_videos')
          .select('''
            *,
            products(id, name, price, colors, sizes),
            sellers(id, business_name, full_name)
          ''')
          .eq('product_id', productId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final videos = (response as List)
          .map((json) => ProductVideoModel.fromJson(json as Map<String, dynamic>))
          .toList();
      
      _logSuccess(operation, 'Fetched ${videos.length} videos for product');
      return videos;
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      throw Exception('Failed to fetch product videos: $e');
    }
  }

  /// Fetch single video by ID
  Future<ProductVideoModel?> getVideoById(String videoId) async {
    final operation = 'getVideoById';
    try {
      _logInfo(operation, 'Fetching video: $videoId');
      
      final response = await _supabase
          .from('product_videos')
          .select('''
            *,
            products(id, name, price, colors, sizes),
            sellers(id, business_name, full_name)
          ''')
          .eq('id', videoId)
          .single();

      final video = ProductVideoModel.fromJson(response);
      _logSuccess(operation, 'Fetched video: ${video.id}');
      _isValidVideoUrl(video.videoUrl);
      
      return video;
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      return null;
    }
  }

  /// Increment video views count - NO RPC, direct update
  Future<void> incrementViews(String videoId) async {
    final operation = 'incrementViews';
    try {
      _logInfo(operation, 'Incrementing views for video: $videoId');
      
      // Get current views count
      final current = await _supabase
          .from('product_videos')
          .select('views_count')
          .eq('id', videoId)
          .single();
      
      final currentCount = (current['views_count'] as int?) ?? 0;
      
      // Update with new count
      await _supabase
          .from('product_videos')
          .update({'views_count': currentCount + 1})
          .eq('id', videoId);
      
      _logSuccess(operation, 'Views: $currentCount → ${currentCount + 1}');
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      // Don't throw - views increment is not critical
    }
  }

  /// Check if user has liked a video
  Future<bool> hasUserLikedVideo({
    required String userId,
    required String videoId,
  }) async {
    final operation = 'hasUserLikedVideo';
    try {
      _logInfo(operation, 'Checking like status for user: $userId, video: $videoId');
      
      final response = await _supabase
          .from('video_likes')
          .select('id')
          .eq('user_id', userId)
          .eq('video_id', videoId)
          .maybeSingle();

      final hasLiked = response != null;
      _logSuccess(operation, 'User has ${hasLiked ? "liked" : "not liked"} video');
      return hasLiked;
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      return false;
    }
  }

  /// ✅ ENHANCED: Toggle like with COMPREHENSIVE ERROR LOGGING
  Future<bool> toggleLike({
    required String userId, 
    required String videoId,
  }) async {
    final operation = 'toggleLike';
    try {
      print('');
      print('💝 ========================================');
      print('💝 TOGGLE LIKE STARTED');
      print('💝 Timestamp: ${DateTime.now().toIso8601String()}');
      print('💝 User ID: $userId');
      print('💝 Video ID: $videoId');
      print('💝 Auth UID: ${_supabase.auth.currentUser?.id}');
      print('💝 Auth Email: ${_supabase.auth.currentUser?.email}');
      print('💝 ========================================');
      
      // Validate inputs
      if (userId.isEmpty || videoId.isEmpty) {
        throw Exception('User ID or Video ID is empty');
      }
      
      // Check if like exists
      print('💝 Step 1: Checking if like already exists...');
      final existing = await _supabase
          .from('video_likes')
          .select('id')
          .eq('user_id', userId)
          .eq('video_id', videoId)
          .maybeSingle();
      
      if (existing != null) {
        // Unlike: Delete the like
        print('💝 Like exists with ID: ${existing['id']}');
        print('💝 Step 2: Attempting to DELETE like...');
        
        try {
          await _supabase
              .from('video_likes')
              .delete()
              .eq('user_id', userId)
              .eq('video_id', videoId);
          
          print('💝 ✅ Successfully DELETED like');
          print('💝 ========================================');
          print('');
          _logSuccess(operation, 'Unlike successful');
          return false; // Not liked anymore
        } catch (deleteError, deleteStack) {
          print('💝 ❌ DELETE FAILED!');
          _logError('toggleLike:DELETE', deleteError, deleteStack);
          rethrow;
        }
      } else {
        // Like: Insert the like
        print('💝 Like does not exist');
        print('💝 Step 2: Attempting to INSERT like...');
        
        final insertData = {
          'user_id': userId,
          'video_id': videoId,
          'created_at': DateTime.now().toIso8601String(),
        };
        print('💝 Insert data: $insertData');
        
        try {
          final result = await _supabase
              .from('video_likes')
              .insert(insertData)
              .select()
              .single();
          
          print('💝 ✅ Successfully INSERTED like');
          print('💝 Result: $result');
          print('💝 ========================================');
          print('');
          _logSuccess(operation, 'Like successful');
          return true; // Now liked
        } catch (insertError, insertStack) {
          print('💝 ❌ INSERT FAILED!');
          _logError('toggleLike:INSERT', insertError, insertStack);
          rethrow;
        }
      }
    } catch (e, stackTrace) {
      print('💝 ❌ TOGGLE LIKE COMPLETELY FAILED!');
      print('💝 ========================================');
      print('');
      _logError(operation, e, stackTrace);
      throw Exception('Failed to toggle like: $e');
    }
  }

  /// Get user's liked video IDs
  Future<Set<String>> getUserLikedVideoIds(String userId) async {
    final operation = 'getUserLikedVideoIds';
    try {
      _logInfo(operation, 'Fetching liked videos for user: $userId');
      
      final response = await _supabase
          .from('video_likes')
          .select('video_id')
          .eq('user_id', userId);
      
      final ids = <String>{};
      for (var item in response as List) {
        ids.add(item['video_id'] as String);
      }
      
      _logSuccess(operation, 'User has liked ${ids.length} videos');
      return ids;
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      return {};
    }
  }

  /// ✅ ENHANCED: Fetch comments with COMPREHENSIVE ERROR LOGGING
  Future<List<VideoCommentModel>> getVideoComments({
    required String videoId,
    int limit = 50,
  }) async {
    final operation = 'getVideoComments';
    try {
      print('');
      print('💬 ========================================');
      print('💬 FETCHING COMMENTS');
      print('💬 Timestamp: ${DateTime.now().toIso8601String()}');
      print('💬 Video ID: $videoId');
      print('💬 Limit: $limit');
      print('💬 ========================================');
      
      final response = await _supabase
          .from('video_comments')
          .select('''
            id,
            user_id,
            video_id,
            comment_text,
            created_at,
            profiles!inner(
              id,
              full_name,
              profile_image_url
            )
          ''')
          .eq('video_id', videoId)
          .order('created_at', ascending: false)
          .limit(limit);

      final comments = <VideoCommentModel>[];
      for (var item in response as List) {
        final profile = item['profiles'] as Map<String, dynamic>?;
        
        comments.add(VideoCommentModel(
          id: item['id'] as String,
          videoId: item['video_id'] as String,
          userId: item['user_id'] as String,
          commentText: item['comment_text'] as String,
          createdAt: DateTime.parse(item['created_at'] as String),
          userName: profile?['full_name'] as String? ?? 'User',
          userImageUrl: profile?['profile_image_url'] as String?,
        ));
      }

      print('💬 ✅ Fetched ${comments.length} comments');
      print('💬 ========================================');
      print('');
      _logSuccess(operation, 'Fetched ${comments.length} comments');
      return comments;
    } catch (e, stackTrace) {
      print('💬 ❌ FETCH COMMENTS FAILED!');
      print('💬 ========================================');
      print('');
      _logError(operation, e, stackTrace);
      return [];
    }
  }

  /// ✅ ENHANCED: Add comment with COMPREHENSIVE ERROR LOGGING
  Future<VideoCommentModel> addComment({
    required String userId,
    required String videoId,
    required String commentText,
  }) async {
    final operation = 'addComment';
    try {
      print('');
      print('💬 ========================================');
      print('💬 ADD COMMENT STARTED');
      print('💬 Timestamp: ${DateTime.now().toIso8601String()}');
      print('💬 User ID: $userId');
      print('💬 Video ID: $videoId');
      print('💬 Comment text length: ${commentText.length}');
      print('💬 Auth UID: ${_supabase.auth.currentUser?.id}');
      print('💬 Auth Email: ${_supabase.auth.currentUser?.email}');
      print('💬 ========================================');
      
      if (commentText.trim().isEmpty) {
        throw Exception('Comment cannot be empty');
      }

      // Step 1: Check if user profile exists
      print('💬 Step 1: Checking if user profile exists...');
      try {
        final profileCheck = await _supabase
            .from('profiles')
            .select('id, full_name')
            .eq('id', userId)
            .maybeSingle();
        
        if (profileCheck == null) {
          print('💬 ❌ User profile does NOT exist!');
          throw Exception('User profile not found. Please complete your profile first.');
        }
        print('💬 ✅ User profile exists: ${profileCheck['full_name']}');
      } catch (profileError, profileStack) {
        print('💬 ❌ Profile check failed!');
        _logError('addComment:profileCheck', profileError, profileStack);
        rethrow;
      }

      // Step 2: Check if video exists
      print('💬 Step 2: Checking if video exists...');
      try {
        final videoCheck = await _supabase
            .from('product_videos')
            .select('id')
            .eq('id', videoId)
            .maybeSingle();
        
        if (videoCheck == null) {
          print('💬 ❌ Video does NOT exist!');
          throw Exception('Video not found');
        }
        print('💬 ✅ Video exists');
      } catch (videoError, videoStack) {
        print('💬 ❌ Video check failed!');
        _logError('addComment:videoCheck', videoError, videoStack);
        rethrow;
      }

      // Step 3: Insert comment
      print('💬 Step 3: Inserting comment...');
      final insertData = {
        'user_id': userId,
        'video_id': videoId,
        'comment_text': commentText.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };
      print('💬 Insert data: $insertData');
      
      try {
        final insertResponse = await _supabase
            .from('video_comments')
            .insert(insertData)
            .select('id, user_id, video_id, comment_text, created_at')
            .single();

        print('💬 ✅ Comment inserted successfully');
        print('💬 Insert result: $insertResponse');

        // Step 4: Fetch user profile
        print('💬 Step 4: Fetching user profile...');
        final profileResponse = await _supabase
            .from('profiles')
            .select('id, full_name, profile_image_url')
            .eq('id', userId)
            .single();

        print('💬 ✅ Comment added successfully');
        print('💬 ========================================');
        print('');
        _logSuccess(operation, 'Comment added successfully');
        
        return VideoCommentModel(
          id: insertResponse['id'] as String,
          videoId: insertResponse['video_id'] as String,
          userId: insertResponse['user_id'] as String,
          commentText: insertResponse['comment_text'] as String,
          createdAt: DateTime.parse(insertResponse['created_at'] as String),
          userName: profileResponse['full_name'] as String? ?? 'User',
          userImageUrl: profileResponse['profile_image_url'] as String?,
        );
      } catch (insertError, insertStack) {
        print('💬 ❌ COMMENT INSERT FAILED!');
        _logError('addComment:INSERT', insertError, insertStack);
        rethrow;
      }
    } catch (e, stackTrace) {
      print('💬 ❌ ADD COMMENT COMPLETELY FAILED!');
      print('💬 ========================================');
      print('');
      _logError(operation, e, stackTrace);
      throw Exception('Failed to add comment: $e');
    }
  }

  /// Delete a comment
  Future<void> deleteComment({
    required String commentId,
    required String userId,
  }) async {
    final operation = 'deleteComment';
    try {
      _logInfo(operation, 'Deleting comment: $commentId by user: $userId');
      
      await _supabase
          .from('video_comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', userId);
      
      _logSuccess(operation, 'Comment deleted');
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      throw Exception('Failed to delete comment: $e');
    }
  }

  /// Get total comments count for a video
  Future<int> getCommentsCount(String videoId) async {
    final operation = 'getCommentsCount';
    try {
      final response = await _supabase
          .from('video_comments')
          .select('id')
          .eq('video_id', videoId);

      final count = (response as List).length;
      _logSuccess(operation, 'Video has $count comments');
      return count;
    } catch (e, stackTrace) {
      _logError(operation, e, stackTrace);
      return 0;
    }
  }

  /// Stream real-time updates for video likes
  Stream<int> watchVideoLikes(String videoId) {
    _logInfo('watchVideoLikes', 'Starting stream for video: $videoId');
    return _supabase
        .from('video_likes')
        .stream(primaryKey: ['id'])
        .eq('video_id', videoId)
        .map((data) => data.length);
  }

  /// Stream real-time updates for video comments
  Stream<List<VideoCommentModel>> watchVideoComments(String videoId) {
    _logInfo('watchVideoComments', 'Starting stream for video: $videoId');
    return _supabase
        .from('video_comments')
        .stream(primaryKey: ['id'])
        .eq('video_id', videoId)
        .order('created_at', ascending: false)
        .map((data) => data
            .map((json) => VideoCommentModel.fromJson(json))
            .toList());
  }
}