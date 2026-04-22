import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/utils/file_utils.dart';
import '../../domain/entities/project.dart';
import '../../services/firebase/cloud_storage_service.dart';

class ProjectRepository {
  ProjectRepository({CloudStorageService? cloudStorage})
      : _cloudStorage = cloudStorage ?? CloudStorageService();

  final CloudStorageService _cloudStorage;

  Future<File> _projectFile(String id) async {
    final dir = await FileUtils.getProjectsDir();
    return File('${dir.path}/$id.json');
  }

  Future<void> save(Project project) async {
    final file = await _projectFile(project.id);
    await file.writeAsString(jsonEncode(project.toJson()));
  }

  Future<Project?> load(String id) async {
    final file = await _projectFile(id);
    if (!file.existsSync()) return null;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return Project.fromJson(data);
  }

  Future<List<Project>> loadAll(String ownerUid) async {
    final dir = await FileUtils.getProjectsDir();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final projects = <Project>[];
    for (final f in files) {
      try {
        final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final p = Project.fromJson(data);
        if (p.ownerUid == ownerUid) projects.add(p);
      } catch (_) {}
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<void> delete(String id) async {
    final file = await _projectFile(id);
    if (file.existsSync()) await file.delete();
  }

  /// Syncs project metadata to Firestore. Gracefully no-ops if unavailable.
  Future<void> syncToCloud(Project project) async {
    try {
      await _cloudStorage.syncProject(project);
    } catch (e) {
      debugPrint('ProjectRepository.syncToCloud: Firestore unavailable — $e');
    }
  }

  /// Fetches project list from Firestore. Returns empty list on failure.
  Future<List<Project>> fetchFromCloud(String uid) async {
    try {
      return await _cloudStorage.fetchProjects(uid);
    } catch (e) {
      debugPrint('ProjectRepository.fetchFromCloud: Firestore unavailable — $e');
      return [];
    }
  }

  /// Merges cloud projects into local storage. Silently skips on failure.
  Future<void> mergeFromCloud(String uid) async {
    try {
      final cloudProjects = await fetchFromCloud(uid);
      for (final p in cloudProjects) {
        final local = await load(p.id);
        if (local == null || p.updatedAt.isAfter(local.updatedAt)) {
          await save(p);
        }
      }
    } catch (e) {
      debugPrint('ProjectRepository.mergeFromCloud: merge skipped — $e');
    }
  }
}
