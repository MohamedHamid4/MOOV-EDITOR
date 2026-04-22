import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/file_utils.dart';
import '../../data/repositories/project_repository.dart';

const _kAvatarKey = 'profile_avatar_path';
const _kExportsKey = 'exports_count';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({ProjectRepository? repo})
      : _repo = repo ?? ProjectRepository();

  final ProjectRepository _repo;

  String? _avatarPath;
  int _projectsCount = 0;
  int _minutesEdited = 0;
  int _exportsCount = 0;
  int _localStorageBytes = 0;
  bool _isLoading = false;
  List<({String name, DateTime updatedAt})> _recentActivity = [];

  String? get avatarPath => _avatarPath;
  int get projectsCount => _projectsCount;
  int get minutesEdited => _minutesEdited;
  int get exportsCount => _exportsCount;
  int get localStorageBytes => _localStorageBytes;
  bool get isLoading => _isLoading;
  List<({String name, DateTime updatedAt})> get recentActivity => _recentActivity;

  Future<void> load(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _avatarPath = prefs.getString(_kAvatarKey);
      _exportsCount = prefs.getInt(_kExportsKey) ?? 0;

      final projects = await _repo.loadAll(uid);
      _projectsCount = projects.length;
      _minutesEdited = projects.fold<int>(0, (sum, p) => sum + p.duration.inMinutes);
      _recentActivity = projects
          .take(5)
          .map((p) => (name: p.name, updatedAt: p.updatedAt))
          .toList();

      _localStorageBytes = await FileUtils.getDocumentsDirSizeBytes();
    } catch (e) {
      debugPrint('ProfileViewModel.load: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveAvatar(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAvatarKey, path);
      _avatarPath = path;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ProfileViewModel.saveAvatar: $e');
      return false;
    }
  }
}
