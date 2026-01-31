import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'watermark_service.dart';

enum DownloadStatus {
  idle,
  downloading,
  watermarking,
  saving,
  completed,
  failed,
}

class DownloadProgress {
  final String videoId;
  final String videoUrl;
  final DownloadStatus status;
  final double progress;
  final String statusMessage;
  final String? errorMessage;

  DownloadProgress({
    required this.videoId,
    required this.videoUrl,
    required this.status,
    this.progress = 0.0,
    this.statusMessage = '',
    this.errorMessage,
  });

  DownloadProgress copyWith({
    DownloadStatus? status,
    double? progress,
    String? statusMessage,
    String? errorMessage,
  }) {
    return DownloadProgress(
      videoId: videoId,
      videoUrl: videoUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final StreamController<DownloadProgress?> _progressController =
      StreamController<DownloadProgress?>.broadcast();

  Stream<DownloadProgress?> get progressStream => _progressController.stream;
  DownloadProgress? _currentDownload;

  DownloadProgress? get currentDownload => _currentDownload;

  bool get isDownloading => _currentDownload?.status == DownloadStatus.downloading ||
      _currentDownload?.status == DownloadStatus.watermarking ||
      _currentDownload?.status == DownloadStatus.saving;

  Future<void> downloadVideo({
    required String videoId,
    required String videoUrl,
    required Function(String) onComplete,
    required Function(String) onError,
  }) async {
    print('');
    print('📥 ========================================');
    print('📥 GLOBAL DOWNLOAD STARTED');
    print('📥 Video ID: $videoId');
    print('📥 Video URL: $videoUrl');
    print('📥 ========================================');

    // Check if already downloading
    if (isDownloading) {
      print('📥 ⚠️  Already downloading another video');
      onError('Another download is in progress');
      return;
    }

    try {
      _currentDownload = DownloadProgress(
        videoId: videoId,
        videoUrl: videoUrl,
        status: DownloadStatus.downloading,
        statusMessage: 'Preparing download...',
      );
      _progressController.add(_currentDownload);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalFile = '${tempDir.path}/original_$timestamp.mp4';
      final watermarkedFile = '${tempDir.path}/unihub_$timestamp.mp4';

      print('📥 Original file path: $originalFile');
      print('📥 Watermarked file path: $watermarkedFile');

      final dio = Dio();

      // Step 1: Download original video
      _updateProgress(
        status: DownloadStatus.downloading,
        progress: 0.0,
        statusMessage: 'Downloading video',
      );

      await dio.download(
        videoUrl,
        originalFile,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total) * 0.6; // 60% for download
            _updateProgress(
              status: DownloadStatus.downloading,
              progress: progress,
              statusMessage: 'Downloading video',
            );
            print('📥 Download progress: ${(progress * 100 / 0.6).toStringAsFixed(0)}%');
          }
        },
        options: Options(
          headers: {'Accept': '*/*'},
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      print('📥 ✅ Download complete');

      // Step 2: Add watermark
      _updateProgress(
        status: DownloadStatus.watermarking,
        progress: 0.6,
        statusMessage: 'Adding watermark',
      );

      print('📥 Adding watermark...');

      final watermarkAdded = await WatermarkService.processVideoWithWatermark(
        inputVideoPath: originalFile,
        outputVideoPath: watermarkedFile,
      );

      String fileToSave;
      if (watermarkAdded) {
        print('📥 ✅ Watermark added successfully');
        fileToSave = watermarkedFile;
        _updateProgress(
          status: DownloadStatus.watermarking,
          progress: 0.85,
          statusMessage: 'Watermark added',
        );
      } else {
        print('📥 ⚠️  Watermark failed, saving original video');
        fileToSave = originalFile;
        _updateProgress(
          status: DownloadStatus.watermarking,
          progress: 0.85,
          statusMessage: 'Saving video',
        );
      }

      // Step 3: Save to gallery
      _updateProgress(
        status: DownloadStatus.saving,
        progress: 0.9,
        statusMessage: 'Saving to gallery',
      );

      await Gal.putVideo(fileToSave, album: 'UniHub');

      print('📥 ✅ Video saved to gallery');

      // Step 4: Complete
      _updateProgress(
        status: DownloadStatus.completed,
        progress: 1.0,
        statusMessage: 'Download completed',
      );

      // Clean up temp files
      try {
        await File(originalFile).delete();
        if (watermarkAdded) {
          await File(watermarkedFile).delete();
        }
        print('📥 ✅ Temporary files cleaned up');
      } catch (e) {
        print('📥 ⚠️  Could not delete temp files: $e');
      }

      // Clear download state after 3 seconds
      await Future.delayed(const Duration(seconds: 3));
      _currentDownload = null;
      _progressController.add(null);

      onComplete('✅ Video saved to gallery!');

      print('📥 ========================================');
      print('📥 DOWNLOAD COMPLETED SUCCESSFULLY');
      print('📥 ========================================');
      print('');

    } catch (e, stackTrace) {
      print('📥 ❌ Download failed!');
      print('📥 Error: $e');
      print('📥 Stack trace: $stackTrace');
      print('📥 ========================================');
      print('');

      _updateProgress(
        status: DownloadStatus.failed,
        progress: 0.0,
        statusMessage: 'Download failed',
        errorMessage: e.toString(),
      );

      // Clear download state after 3 seconds
      await Future.delayed(const Duration(seconds: 3));
      _currentDownload = null;
      _progressController.add(null);

      onError('❌ Failed to download video');
    }
  }

  void _updateProgress({
    required DownloadStatus status,
    required double progress,
    required String statusMessage,
    String? errorMessage,
  }) {
    _currentDownload = _currentDownload?.copyWith(
      status: status,
      progress: progress,
      statusMessage: statusMessage,
      errorMessage: errorMessage,
    );
    _progressController.add(_currentDownload);
  }

  void dispose() {
    _progressController.close();
  }
}