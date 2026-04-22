import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/project.dart';
import '../../services/export/video_export_service.dart';
import '../../services/firebase/cloud_storage_service.dart';

class ExportViewModel extends ChangeNotifier {
  ExportViewModel({CloudStorageService? cloudStorage})
      : _cloudStorage = cloudStorage ?? CloudStorageService();

  final CloudStorageService _cloudStorage;

  String _resolution = '1080p';
  String _aspectRatio = '16:9';
  int _fps = 30;
  String _quality = 'Medium';
  final String _format = 'MP4 (H.264)';

  bool _isExporting = false;
  double _progress = 0.0;
  String? _outputPath;
  String? _error;
  bool _isSavingToGallery = false;
  bool _isUploadingToCloud = false;
  bool _gallerySaved = false;

  String get resolution => _resolution;
  String get aspectRatio => _aspectRatio;
  int get fps => _fps;
  String get quality => _quality;
  String get format => _format;
  bool get isExporting => _isExporting;
  double get progress => _progress;
  String? get outputPath => _outputPath;
  String? get error => _error;
  bool get isComplete => _outputPath != null && !_isExporting;
  bool get isSavingToGallery => _isSavingToGallery;
  bool get isUploadingToCloud => _isUploadingToCloud;
  bool get gallerySaved => _gallerySaved;

  void setResolution(String v) { _resolution = v; notifyListeners(); }
  void setAspectRatio(String v) { _aspectRatio = v; notifyListeners(); }
  void setFps(int v) { _fps = v; notifyListeners(); }
  void setQuality(String v) { _quality = v; notifyListeners(); }

  /// Estimated output file size in MB.
  double get estimatedSizeMb {
    final bitrateMbps = switch (quality) {
      'Low' => 3.0,
      'High' => 10.0,
      'Ultra' => 20.0,
      _ => 6.0,
    };
    return bitrateMbps * 30 / 8;
  }

  ExportConfig _buildConfig() {
    return ExportConfig.fromSettings(
      resolution: _resolution,
      fps: _fps,
      quality: _quality,
      aspectRatio: _aspectRatio,
    );
  }

  Future<void> startExport(Project project) async {
    _isExporting = true;
    _progress = 0.0;
    _outputPath = null;
    _error = null;
    notifyListeners();

    final result = await VideoExportService.export(
      project: project,
      config: _buildConfig(),
      onProgress: (p) {
        // Guard: _isExporting may have been cleared by cancelExport() while
        // FFmpeg was still running; don't notify after cancellation.
        if (!_isExporting) return;
        _progress = p;
        notifyListeners();
      },
    );

    _isExporting = false;
    if (result.success) {
      _outputPath = result.outputPath;
      _progress = 1.0;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            'exports_count', (prefs.getInt('exports_count') ?? 0) + 1);
      } catch (e) {
        debugPrint('ExportViewModel: failed to persist exports count — $e');
      }
      // Bug 6: auto-save to gallery immediately after successful export.
      _gallerySaved = await _autoSaveToGallery(_outputPath!);
    } else {
      _error = result.error;
    }
    notifyListeners();
  }

  Future<void> cancelExport() async {
    await VideoExportService.cancel();
    _isExporting = false;
    _progress = 0.0;
    notifyListeners();
  }

  /// Called automatically after export. Saves to public Movies/Moov Editor folder.
  static Future<bool> _autoSaveToGallery(String path) async {
    try {
      // Do not attempt to save if the output file is missing or empty — gallery
      // saver would crash or silently fail and leave a corrupt entry.
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('ExportViewModel._autoSaveToGallery: file not found — $path');
        return false;
      }
      if (await file.length() == 0) {
        debugPrint('ExportViewModel._autoSaveToGallery: file is empty — $path');
        return false;
      }
      final result = await GallerySaver.saveVideo(
        path,
        albumName: 'Moov Editor',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('ExportViewModel._autoSaveToGallery: $e');
      return false;
    }
  }

  /// Manual retry if auto-save failed.
  Future<bool> saveToGallery() async {
    if (_outputPath == null) return false;
    _isSavingToGallery = true;
    notifyListeners();
    try {
      _gallerySaved = await _autoSaveToGallery(_outputPath!);
      return _gallerySaved;
    } finally {
      _isSavingToGallery = false;
      notifyListeners();
    }
  }

  Future<String?> uploadToCloud({required String uid, required String projectId}) async {
    if (_outputPath == null) return null;
    _isUploadingToCloud = true;
    notifyListeners();
    try {
      final url = await _cloudStorage.uploadExport(
        uid: uid,
        projectId: projectId,
        file: File(_outputPath!),
        onProgress: (p) {
          _progress = p;
          notifyListeners();
        },
      );
      return url;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isUploadingToCloud = false;
      notifyListeners();
    }
  }

  void reset() {
    _isExporting = false;
    _progress = 0.0;
    _outputPath = null;
    _error = null;
    _gallerySaved = false;
    notifyListeners();
  }
}
