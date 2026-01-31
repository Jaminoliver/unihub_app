import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full/log.dart';

class WatermarkService {
  // Generate watermark PNG with "UniHub" text
  static Future<String> generateWatermarkImage() async {
    try {
      print('🎨 ========================================');
      print('🎨 GENERATING WATERMARK IMAGE');
      print('🎨 ========================================');
      
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Watermark size (larger for better visibility)
      const width = 240.0;
      const height = 70.0;
      
      // Orange gradient background (rounded rectangle)
      final gradient = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(width, height),
        [const Color(0xFFFF6B35), const Color(0xFFFF8C42)],
      );
      
      final bgPaint = Paint()
        ..shader = gradient
        ..style = PaintingStyle.fill;
      
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(35),
      );
      
      canvas.drawRRect(rrect, bgPaint);
      
      // White text "UniHub"
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'UniHub',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: Colors.black38,
                offset: Offset(1.5, 1.5),
                blurRadius: 3,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // Center text in the rectangle
      final textOffset = Offset(
        (width - textPainter.width) / 2,
        (height - textPainter.height) / 2,
      );
      
      textPainter.paint(canvas, textOffset);
      
      // Convert to image
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();
      
      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final watermarkPath = '${tempDir.path}/watermark_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(watermarkPath);
      await file.writeAsBytes(buffer);
      
      // Verify file was created
      if (!await file.exists()) {
        throw Exception('Watermark file was not created');
      }
      
      final fileSize = await file.length();
      print('🎨 ✅ Watermark image created');
      print('🎨    Path: $watermarkPath');
      print('🎨    Size: ${fileSize / 1024} KB');
      print('🎨 ========================================');
      
      return watermarkPath;
      
    } catch (e, stackTrace) {
      print('🎨 ❌ Failed to generate watermark');
      print('🎨 Error: $e');
      print('🎨 Stack trace: $stackTrace');
      print('🎨 ========================================');
      rethrow;
    }
  }
  
  // Add watermark to video using FFmpeg
  static Future<bool> addWatermarkToVideo({
    required String inputVideoPath,
    required String outputVideoPath,
    required String watermarkImagePath,
  }) async {
    try {
      print('🎬 ========================================');
      print('🎬 ADDING WATERMARK TO VIDEO');
      print('🎬 ========================================');
      print('🎬 Input video: $inputVideoPath');
      print('🎬 Output video: $outputVideoPath');
      print('🎬 Watermark: $watermarkImagePath');
      
      // Verify input files exist
      if (!await File(inputVideoPath).exists()) {
        throw Exception('Input video does not exist: $inputVideoPath');
      }
      if (!await File(watermarkImagePath).exists()) {
        throw Exception('Watermark image does not exist: $watermarkImagePath');
      }
      
      final inputSize = await File(inputVideoPath).length();
      final watermarkSize = await File(watermarkImagePath).length();
      print('🎬 Input video size: ${inputSize / 1024 / 1024} MB');
      print('🎬 Watermark size: ${watermarkSize / 1024} KB');
      
      // Store all FFmpeg logs
      final logs = <String>[];
      
      // Enable FFmpeg logging
      FFmpegKitConfig.enableLogCallback((log) {
        final message = log.getMessage();
        if (message.isNotEmpty) {
          logs.add(message);
          print('🎬 FFmpeg: $message');
        }
      });
      
      // SIMPLIFIED FFmpeg command - more reliable
      // Using simpler overlay without complex filters
      final command = '-i "$inputVideoPath" -i "$watermarkImagePath" '
          '-filter_complex "[0:v][1:v]overlay=W-w-20:H-h-20:format=auto" '
          '-c:a copy '
          '-y "$outputVideoPath"';
      
      print('🎬 Executing FFmpeg command...');
      print('🎬 Command: ffmpeg $command');
      print('🎬 ========================================');
      
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput();
      final state = await session.getState();
      
      print('🎬 ========================================');
      print('🎬 FFmpeg execution completed');
      print('🎬 Return code: $returnCode');
      print('🎬 State: $state');
      
      if (ReturnCode.isSuccess(returnCode)) {
        // Verify output file was created
        if (!await File(outputVideoPath).exists()) {
          print('🎬 ❌ Output file was not created');
          print('🎬 FFmpeg output: $output');
          print('🎬 All logs:');
          logs.forEach((log) => print('  $log'));
          return false;
        }
        
        final outputSize = await File(outputVideoPath).length();
        
        if (outputSize < 1000) {
          print('🎬 ❌ Output file too small (${outputSize} bytes) - likely corrupted');
          print('🎬 FFmpeg output: $output');
          return false;
        }
        
        print('🎬 ✅ Watermark added successfully!');
        print('🎬 Output video size: ${outputSize / 1024 / 1024} MB');
        print('🎬 ========================================');
        
        // Cleanup watermark temp file
        try {
          await File(watermarkImagePath).delete();
          print('🎬 Watermark temp file cleaned up');
        } catch (e) {
          print('🎬 ⚠️  Could not delete watermark temp file: $e');
        }
        
        return true;
      } else {
        final failStackTrace = await session.getFailStackTrace();
        print('🎬 ❌ FFmpeg failed!');
        print('🎬 Return code: $returnCode');
        print('🎬 Return code value: ${returnCode?.getValue()}');
        print('🎬 Output: $output');
        print('🎬 Fail stack trace: $failStackTrace');
        print('🎬 All FFmpeg logs (${logs.length} lines):');
        logs.forEach((log) => print('  $log'));
        print('🎬 ========================================');
        return false;
      }
      
    } catch (e, stackTrace) {
      print('🎬 ========================================');
      print('🎬 ❌ WATERMARK ERROR');
      print('🎬 Error: $e');
      print('🎬 Error type: ${e.runtimeType}');
      print('🎬 Stack trace: $stackTrace');
      print('🎬 ========================================');
      return false;
    }
  }
  
  // Complete workflow: generate watermark + add to video
  static Future<bool> processVideoWithWatermark({
    required String inputVideoPath,
    required String outputVideoPath,
  }) async {
    try {
      print('');
      print('🎯 ========================================');
      print('🎯 STARTING WATERMARK PROCESS');
      print('🎯 ========================================');
      
      // Step 1: Generate watermark image
      print('🎯 Step 1: Generating watermark image...');
      final watermarkPath = await generateWatermarkImage();
      
      // Step 2: Add watermark to video
      print('🎯 Step 2: Adding watermark to video...');
      final success = await addWatermarkToVideo(
        inputVideoPath: inputVideoPath,
        outputVideoPath: outputVideoPath,
        watermarkImagePath: watermarkPath,
      );
      
      if (success) {
        print('🎯 ========================================');
        print('🎯 ✅ WATERMARK PROCESS COMPLETED');
        print('🎯 ========================================');
        print('');
      } else {
        print('🎯 ========================================');
        print('🎯 ❌ WATERMARK PROCESS FAILED');
        print('🎯 ========================================');
        print('');
      }
      
      return success;
      
    } catch (e, stackTrace) {
      print('🎯 ========================================');
      print('🎯 ❌ WATERMARK PROCESS FAILED');
      print('🎯 Error: $e');
      print('🎯 Stack trace: $stackTrace');
      print('🎯 ========================================');
      print('');
      return false;
    }
  }
}