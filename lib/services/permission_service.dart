import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Requests the necessary permissions for picking and saving videos.
  /// Returns true if all required permissions are granted.
  static Future<bool> requestStoragePermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ uses granular media permissions
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 33) {
        final status = await Permission.videos.request();
        return status.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  /// Checks if storage permissions are already granted.
  static Future<bool> hasStoragePermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 33) {
        return await Permission.videos.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  static Future<int> _getAndroidSdkVersion() async {
    // permission_handler handles this internally, but we use a safe default
    // For API level detection we rely on the permission_handler behavior
    // Android 13 = API 33
    try {
      if (await Permission.videos.status != PermissionStatus.permanentlyDenied) {
        return 33; // Assume 33+ if the permission exists
      }
    } catch (_) {}
    return 29; // Fallback to legacy storage
  }

  /// Opens the app settings page so the user can manually grant permissions.
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
