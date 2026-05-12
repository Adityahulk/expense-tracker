import 'dart:io';

import 'package:external_path/external_path.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helpers for finding the right place to drop user-facing files on Android.
class FilePaths {
  /// The subdirectory in Downloads where we put everything.
  static const String appFolderName = 'expense-tracker';

  /// Ensure pre-Android-11 storage permission is granted. On Android 11+ this
  /// is effectively a no-op for our use case.
  static Future<bool> ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.storage.status;
    if (status.isGranted) return true;
    final result = await Permission.storage.request();
    return result.isGranted;
  }

  /// Returns the path to `<Downloads>/expense-tracker/`, creating the dir if
  /// needed. Falls back to the app's documents folder if Downloads is not
  /// available (rare — only on some sandboxed environments).
  static Future<String> downloadsDir() async {
    String? base;
    try {
      base = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOWNLOADS,
      );
    } catch (_) {
      base = null;
    }
    base ??= (await getApplicationDocumentsDirectory()).path;
    final dir = Directory(p.join(base, appFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Timestamp suffix used in filenames.
  static String timestampSuffix() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
