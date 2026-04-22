/// App-wide constants shared across all layers.
class AppConstants {
  AppConstants._();

  static const String appName = 'Moov Editor';
  static const String packageId = 'com.moov.editor';

  // Timeline
  static const double defaultPixelsPerSecond = 60.0;
  static const double minPixelsPerSecond = 20.0;
  static const double maxPixelsPerSecond = 200.0;
  static const double trackHeight = 80.0;
  static const double rulerHeight = 28.0;
  static const double playheadWidth = 2.0;
  static const double clipHandleWidth = 12.0;
  static const int maxUndoHistory = 50;

  // Auto-save
  static const int autoSaveIntervalSeconds = 30;

  // Export
  static const String exportSubDir = 'exports';

  // Firestore collections
  static const String usersCollection = 'users';
  static const String projectsCollection = 'projects';

  // Storage paths
  static const String storageProjectsPath = 'projects';

  // Snap threshold in pixels
  static const double snapThresholdPx = 8.0;

  // Aspect ratios
  static const Map<String, double> aspectRatios = {
    '16:9': 16 / 9,
    '9:16': 9 / 16,
    '1:1': 1.0,
    '4:3': 4 / 3,
  };
}
