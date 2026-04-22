import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/utils/file_utils.dart';

class VideoThumbnailService {
  VideoThumbnailService._();

  // In-memory cache keyed by "filePath_positionMs"
  static final Map<String, Uint8List> _dataCache = {};

  /// Generates a thumbnail for [videoPath] at [positionMs] and saves it.
  /// Returns the thumbnail file path.
  static Future<String?> generateThumbnail({
    required String videoPath,
    int positionMs = 0,
    int maxWidth = 160,
    int quality = 80,
  }) async {
    final dir = await FileUtils.getThumbnailsDir();
    final fileName = '${videoPath.hashCode}_$positionMs.jpg';
    final outPath = '${dir.path}/$fileName';

    final path = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: outPath,
      imageFormat: ImageFormat.JPEG,
      timeMs: positionMs,
      maxWidth: maxWidth,
      quality: quality,
    );
    return path;
  }

  /// Returns thumbnail bytes from cache or generates them.
  static Future<Uint8List?> generateThumbnailData({
    required String videoPath,
    int positionMs = 0,
    int maxWidth = 160,
    int quality = 80,
  }) async {
    final key = '${videoPath}_$positionMs';
    if (_dataCache.containsKey(key)) return _dataCache[key];

    final data = await VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      timeMs: positionMs,
      maxWidth: maxWidth,
      quality: quality,
    );
    if (data != null) _dataCache[key] = data;
    return data;
  }

  /// Generates a filmstrip as a list of [Uint8List] frames, cached per clip.
  /// [frameCount] frames spread evenly across [videoDuration].
  static Future<List<Uint8List>> generateFilmstripData({
    required String videoPath,
    required Duration videoDuration,
    int frameCount = 5,
  }) async {
    final result = <Uint8List>[];
    final durationMs = videoDuration.inMilliseconds;
    for (int i = 0; i < frameCount; i++) {
      final ms = frameCount <= 1
          ? 0
          : ((durationMs * i) / (frameCount - 1)).round();
      final data = await generateThumbnailData(
        videoPath: videoPath,
        positionMs: ms.clamp(0, durationMs),
      );
      if (data != null) result.add(data);
    }
    return result;
  }

  /// Generates multiple thumbnails spread across the video duration for
  /// the filmstrip view (file-based version).
  static Future<List<String>> generateFilmstrip({
    required String videoPath,
    required Duration videoDuration,
    int frameCount = 8,
    int frameWidth = 160,
  }) async {
    final paths = <String>[];
    for (int i = 0; i < frameCount; i++) {
      final ms = (videoDuration.inMilliseconds * i / frameCount).round();
      final p = await generateThumbnail(
        videoPath: videoPath,
        positionMs: ms,
        maxWidth: frameWidth,
        quality: 80,
      );
      if (p != null) paths.add(p);
    }
    return paths;
  }
}
