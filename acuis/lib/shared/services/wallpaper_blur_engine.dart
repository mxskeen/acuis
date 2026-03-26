import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'wallpaper_service.dart';

class WallpaperBlurEngine {
  final WallpaperService _wallpaperService = WallpaperService();

  Future<String> applyBlurToImage(String originalImagePath, double blurIntensity) async {
    try {
      final originalFile = File(originalImagePath);
      if (!await originalFile.exists()) {
        throw Exception('Original image not found');
      }

      final bytes = await originalFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: blurIntensity,
          sigmaY: blurIntensity,
        );

      canvas.drawImage(image, Offset.zero, paint);
      final picture = recorder.endRecording();
      final blurredImage = await picture.toImage(image.width, image.height);

      final byteData = await blurredImage.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final blurredFile = File('${tempDir.path}/blurred_wallpaper_${DateTime.now().millisecondsSinceEpoch}.png');
      await blurredFile.writeAsBytes(buffer);

      return blurredFile.path;
    } catch (e) {
      print('Error applying blur: $e');
      rethrow;
    }
  }

  double calculateBlurIntensity(double progressPercentage) {
    const maxBlur = 25.0;
    const minBlur = 0.0;
    return maxBlur - (progressPercentage / 100.0) * (maxBlur - minBlur);
  }

  Future<bool> updateWallpaperWithProgress(String originalImagePath, double progressPercentage) async {
    try {
      final blurIntensity = calculateBlurIntensity(progressPercentage);
      final blurredImagePath = await applyBlurToImage(originalImagePath, blurIntensity);
      return await _wallpaperService.setWallpaper(blurredImagePath);
    } catch (e) {
      print('Error updating wallpaper: $e');
      return false;
    }
  }
}
