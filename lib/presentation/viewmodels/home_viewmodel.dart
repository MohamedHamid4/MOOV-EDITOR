import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/project_repository.dart';
import '../../domain/entities/project.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({ProjectRepository? repo}) : _repo = repo ?? ProjectRepository();

  final ProjectRepository _repo;

  List<Project> _projects = [];
  bool _isLoading = false;
  String? _error;

  List<Project> get projects => List.unmodifiable(_projects);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Loads projects from local storage only.
  Future<void> loadProjects(String ownerUid) async {
    _setLoading(true);
    try {
      _projects = await _repo.loadAll(ownerUid);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<Project> createProject({
    required String name,
    required String ownerUid,
    String aspectRatio = '16:9',
  }) async {
    final project = Project(
      id: const Uuid().v4(),
      name: name,
      ownerUid: ownerUid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      aspectRatio: aspectRatio,
    );
    await _repo.save(project);
    _projects.insert(0, project);
    notifyListeners();
    return project;
  }

  Future<void> renameProject(String id, String newName) async {
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final updated = _projects[idx].copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );
    await _repo.save(updated);
    _projects[idx] = updated;
    notifyListeners();
  }

  Future<void> duplicateProject(String id) async {
    final src = _projects.firstWhere((p) => p.id == id);
    final copy = src.copyWith(
      id: const Uuid().v4(),
      name: '${src.name} Copy',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      cloudSynced: false,
    );
    await _repo.save(copy);
    _projects.insert(0, copy);
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    await _repo.delete(id);
    _projects.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  /// Attempts Firestore metadata sync. Fails silently if unavailable.
  Future<void> syncToCloud(String id) async {
    final project = _projects.firstWhere((p) => p.id == id);
    await _repo.syncToCloud(project);
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _projects[idx] = project.copyWith(cloudSynced: true);
      notifyListeners();
    }
  }

  /// Pull-to-refresh: only reloads from local storage.
  /// Cloud merge is skipped while Storage is on Spark plan.
  Future<void> refreshFromCloud(String uid) async {
    _setLoading(true);
    try {
      // Local reload only — cloud merge disabled until Blaze plan
      _projects = await _repo.loadAll(uid);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
