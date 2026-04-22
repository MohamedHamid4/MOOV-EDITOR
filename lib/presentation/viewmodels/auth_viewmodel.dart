import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/app_user.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({AuthRepository? repo}) : _repo = repo ?? AuthRepository();

  final AuthRepository _repo;

  AppUser? _user;
  bool _isLoading = false;
  String? _error;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<void> loadCurrentUser() async {
    try {
      _user = await _repo.getCurrentUser();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> signIn(String email, String password) async {
    _error = null;
    _setLoading(true);
    try {
      _user = await _repo.signInWithEmail(email, password);
      _error = null;
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _error = null;
    _setLoading(true);
    try {
      _user = await _repo.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _error = null;
    _setLoading(true);
    try {
      _user = await _repo.signInWithGoogle();
      _error = null;
      return _user != null;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    try {
      await _repo.sendPasswordReset(email);
      _error = null;
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateDisplayName(String name) async {
    try {
      await _repo.updateDisplayName(name);
      _user = _user?.copyWith(displayName: name);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  /// Maps a [FirebaseAuthException] to an AppLocalizations key.
  /// Call `l.t(vm.error!)` in the UI to display the translated message.
  static String handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'error_user_not_found';
      case 'wrong-password':
        return 'error_wrong_password';
      case 'invalid-email':
        return 'error_invalid_email';
      case 'user-disabled':
        return 'error_user_disabled';
      case 'too-many-requests':
        return 'error_too_many_requests';
      case 'email-already-in-use':
        return 'error_email_already_in_use';
      case 'weak-password':
        return 'error_weak_password';
      default:
        return 'error_generic';
    }
  }

  String _friendlyError(Object e) {
    if (e is FirebaseAuthException) return handleFirebaseAuthError(e);
    final msg = e.toString();
    if (msg.contains('network-request-failed')) return 'error_generic';
    return 'error_generic';
  }
}
