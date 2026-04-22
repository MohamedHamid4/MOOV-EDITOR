import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  FileUtils._();

  static Future<Directory> getExportsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> getProjectsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/projects');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> getThumbnailsDir() async {
    final cache = await getTemporaryDirectory();
    final dir = Directory('${cache.path}/thumbnails');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  /// Recursively sums the size of all files in [dir].
  static Future<int> getDirSizeBytes(Directory dir) async {
    if (!dir.existsSync()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  /// Returns the total size of the app documents directory
  /// (projects JSON + exports + avatars + voiceovers).
  static Future<int> getDocumentsDirSizeBytes() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      return getDirSizeBytes(docs);
    } catch (_) {
      return 0;
    }
  }

  /// Returns the combined size of the temporary and application cache directories.
  /// Deduplicates if both resolve to the same path (common on Android).
  static Future<int> getCacheSizeBytes() async {
    int total = 0;
    final visited = <String>{};
    for (final getter in <Future<Directory> Function()>[
      getTemporaryDirectory,
      getApplicationCacheDirectory,
    ]) {
      try {
        final dir = await getter();
        if (visited.add(dir.path)) {
          total += await getDirSizeBytes(dir);
        }
      } catch (_) {}
    }
    return total;
  }

  /// Deletes all files and sub-directories inside the temporary directory.
  static Future<void> clearAllCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (final entity in tempDir.listSync()) {
          try {
            if (entity is File) await entity.delete();
            if (entity is Directory) await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Deletes only files inside the thumbnail sub-directory of the temp dir.
  static Future<void> clearThumbnailCache() async {
    final dir = await getThumbnailsDir();
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        if (f is File) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }
  }
}
