/// Misc filename / timestamp helpers. The actual save-to-disk goes through
/// `file_picker` and Android's Storage Access Framework — there's no fixed
/// "Downloads" folder anymore.
class FilePaths {
  static String timestampSuffix() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
