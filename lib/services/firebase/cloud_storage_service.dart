import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/project.dart';

class CloudStorageService {
  CloudStorageService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  // ── User ──────────────────────────────────────────────────────────────────

  Future<void> saveUser(AppUser user) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(user.toJson(), SetOptions(merge: true));
  }

  Future<AppUser?> loadUser(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromJson(doc.data()!);
  }

  // ── Projects ─────────────────────────────────────────────────────────────

  Future<void> syncProject(Project project) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(project.ownerUid)
        .collection(AppConstants.projectsCollection)
        .doc(project.id)
        .set(project.toJson(), SetOptions(merge: true));
  }

  Future<List<Project>> fetchProjects(String uid) async {
    final snap = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.projectsCollection)
        .orderBy('updatedAt', descending: true)
        .get();
    return snap.docs.map((d) => Project.fromJson(d.data())).toList();
  }

  Future<void> deleteProject(String uid, String projectId) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.projectsCollection)
        .doc(projectId)
        .delete();
  }

  // ── Storage ───────────────────────────────────────────────────────────────

  /// Uploads an exported video file and returns the download URL.
  Future<String> uploadExport({
    required String uid,
    required String projectId,
    required File file,
    void Function(double)? onProgress,
  }) async {
    final ref = _storage.ref(
      '${AppConstants.storageProjectsPath}/$uid/$projectId/${file.uri.pathSegments.last}',
    );
    final task = ref.putFile(file);
    task.snapshotEvents.listen((s) {
      final p = s.bytesTransferred / (s.totalBytes == 0 ? 1 : s.totalBytes);
      onProgress?.call(p);
    });
    await task;
    return ref.getDownloadURL();
  }

  /// Returns total bytes used under `projects/{uid}/`.
  Future<int> getStorageUsedBytes(String uid) async {
    try {
      final ref = _storage.ref('${AppConstants.storageProjectsPath}/$uid');
      final list = await ref.listAll();
      int total = 0;
      for (final item in list.items) {
        final meta = await item.getMetadata();
        total += meta.size ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
