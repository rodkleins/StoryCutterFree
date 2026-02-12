import 'dart:io';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class GalleryService {
  /// Saves a single video file to the device gallery.
  /// Returns true if successful.
  static Future<bool> saveToGallery(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final result = await ImageGallerySaver.saveFile(
      filePath,
      isReturnPathOfIOS: true,
    );

    if (result is Map) {
      return result['isSuccess'] == true;
    }
    return false;
  }

  /// Saves all video segments to the device gallery.
  /// Returns the number of successfully saved files.
  static Future<int> saveAllToGallery(
    List<String> filePaths, {
    void Function(int current, int total)? onProgress,
  }) async {
    int saved = 0;
    for (int i = 0; i < filePaths.length; i++) {
      onProgress?.call(i + 1, filePaths.length);
      final success = await saveToGallery(filePaths[i]);
      if (success) saved++;
    }
    return saved;
  }
}
