import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';

class SavedFile {
  /// Path or content URI returned by the platform (Android: typically a file
  /// path inside Downloads or the user-picked tree).
  final String location;
  final String filename;
  final bool isContentUri;

  const SavedFile({
    required this.location,
    required this.filename,
    required this.isContentUri,
  });
}

class FileSave {
  /// Show the system "Save file" dialog and write [bytes] to the chosen
  /// location. Returns null if the user cancelled.
  ///
  /// On Android API 21+, this uses ACTION_CREATE_DOCUMENT (SAF) — user can
  /// pick Downloads, Drive, SD card, or any DocumentsProvider. No runtime
  /// permission needed.
  static Future<SavedFile?> save({
    required Uint8List bytes,
    required String defaultFilename,
    String dialogTitle = 'Save file',
  }) async {
    final params = SaveFileDialogParams(
      data: bytes,
      fileName: defaultFilename,
    );
    final result = await FlutterFileDialog.saveFile(params: params);
    if (result == null) return null; // cancelled

    return SavedFile(
      location: result,
      filename: defaultFilename,
      isContentUri: result.startsWith('content://'),
    );
  }
}
