import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/app_user.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/cloud_storage_service.dart';

class AuthRepository {
  AuthRepository({
    AuthService? authService,
    CloudStorageService? cloudStorage,
  })  : _auth = authService ?? AuthService(),
        _cloud = cloudStorage ?? CloudStorageService();

  final AuthService _auth;
  final CloudStorageService _cloud;

  Stream<User?> get authStateChanges => _auth.authStateChanges;

  AppUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'User',
      photoUrl: user.photoURL,
    );
  }

  Future<AppUser> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmail(email, password);
    final user = _mapFirebaseUser(cred.user)!;
    try { await _cloud.saveUser(user); } catch (_) {}
    return user;
  }

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    final user = _mapFirebaseUser(cred.user)!;
    try { await _cloud.saveUser(user); } catch (_) {}
    return user;
  }

  Future<AppUser?> signInWithGoogle() async {
    final cred = await _auth.signInWithGoogle();
    if (cred == null) return null;
    final user = _mapFirebaseUser(cred.user)!;
    try { await _cloud.saveUser(user); } catch (_) {}
    return user;
  }

  Future<void> updateDisplayName(String name) => _auth.updateDisplayName(name);

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email);

  Future<AppUser?> getCurrentUser() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;
    // Try to load from cloud for full stats
    final cloudUser = await _cloud.loadUser(fbUser.uid);
    return cloudUser ?? _mapFirebaseUser(fbUser);
  }

  Future<void> signOut() => _auth.signOut();
}
