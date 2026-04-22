import 'package:flutter/material.dart';
import '../../core/utils/file_utils.dart';
import '../../data/repositories/settings_repository.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({SettingsRepository? repo}) : _repo = repo ?? SettingsRepository();

  final SettingsRepository _repo;

  String _theme = 'system';
  String _language = 'en';
  bool _autoSave = true;

  // Cloud Sync is disabled until Firebase Storage (Blaze plan) is activated.
  // Never persists true — value is always false.
  bool _cloudSync = false;

  String _defaultAspectRatio = '16:9';
  String _defaultQuality = 'Medium';
  int _cacheSizeBytes = 0;
  bool _isLoading = false;
  String? _error;

  String get theme => _theme;
  String get language => _language;
  bool get autoSave => _autoSave;
  bool get cloudSync => _cloudSync;
  String get defaultAspectRatio => _defaultAspectRatio;
  String get defaultQuality => _defaultQuality;
  int get cacheSizeBytes => _cacheSizeBytes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ThemeMode get themeMode {
    switch (_theme) {
      case 'dark': return ThemeMode.dark;
      case 'light': return ThemeMode.light;
      default: return ThemeMode.system;
    }
  }

  Locale get locale => Locale(_language);

  Future<void> load() async {
    _theme = await _repo.getTheme();
    _language = await _repo.getLanguage();
    _autoSave = await _repo.getAutoSave();
    // Storage disabled — ignore any previously saved 'true' value
    _cloudSync = false;
    _defaultAspectRatio = await _repo.getDefaultAspectRatio();
    _defaultQuality = await _repo.getDefaultQuality();
    _cacheSizeBytes = await FileUtils.getCacheSizeBytes();
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    _theme = theme;
    await _repo.setTheme(theme);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    await _repo.setLanguage(lang);
    notifyListeners();
  }

  Future<void> setAutoSave(bool value) async {
    _autoSave = value;
    await _repo.setAutoSave(value);
    notifyListeners();
  }

  /// Cloud Sync is blocked — always stays false until Blaze plan is active.
  /// Callers that attempt to set true should show an explanation dialog first.
  Future<void> setCloudSync(bool value) async {
    if (value) return; // silently block; the Settings screen handles the UX
    _cloudSync = false;
    await _repo.setCloudSync(false);
    notifyListeners();
  }

  Future<void> setDefaultAspectRatio(String value) async {
    _defaultAspectRatio = value;
    await _repo.setDefaultAspectRatio(value);
    notifyListeners();
  }

  Future<void> setDefaultQuality(String value) async {
    _defaultQuality = value;
    await _repo.setDefaultQuality(value);
    notifyListeners();
  }

  Future<void> refreshCacheSize() async {
    _cacheSizeBytes = await FileUtils.getCacheSizeBytes();
    notifyListeners();
  }

  Future<void> clearCache() async {
    _isLoading = true;
    notifyListeners();
    try {
      await FileUtils.clearAllCache();
      _cacheSizeBytes = await FileUtils.getCacheSizeBytes();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('SettingsViewModel.clearCache: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
