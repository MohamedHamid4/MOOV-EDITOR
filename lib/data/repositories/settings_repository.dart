import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _keyTheme = 'theme';
  static const _keyLanguage = 'language';
  static const _keyAutoSave = 'auto_save';
  static const _keyCloudSync = 'cloud_sync';
  static const _keyDefaultAspectRatio = 'default_aspect_ratio';
  static const _keyDefaultQuality = 'default_quality';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String> getTheme() async {
    final p = await _prefs;
    return p.getString(_keyTheme) ?? 'system';
  }

  Future<void> setTheme(String theme) async {
    final p = await _prefs;
    await p.setString(_keyTheme, theme);
  }

  Future<String> getLanguage() async {
    final p = await _prefs;
    return p.getString(_keyLanguage) ?? 'en';
  }

  Future<void> setLanguage(String lang) async {
    final p = await _prefs;
    await p.setString(_keyLanguage, lang);
  }

  Future<bool> getAutoSave() async {
    final p = await _prefs;
    return p.getBool(_keyAutoSave) ?? true;
  }

  Future<void> setAutoSave(bool value) async {
    final p = await _prefs;
    await p.setBool(_keyAutoSave, value);
  }

  Future<bool> getCloudSync() async {
    final p = await _prefs;
    return p.getBool(_keyCloudSync) ?? false;
  }

  Future<void> setCloudSync(bool value) async {
    final p = await _prefs;
    await p.setBool(_keyCloudSync, value);
  }

  Future<String> getDefaultAspectRatio() async {
    final p = await _prefs;
    return p.getString(_keyDefaultAspectRatio) ?? '16:9';
  }

  Future<void> setDefaultAspectRatio(String value) async {
    final p = await _prefs;
    await p.setString(_keyDefaultAspectRatio, value);
  }

  Future<String> getDefaultQuality() async {
    final p = await _prefs;
    return p.getString(_keyDefaultQuality) ?? 'Medium';
  }

  Future<void> setDefaultQuality(String value) async {
    final p = await _prefs;
    await p.setString(_keyDefaultQuality, value);
  }
}
