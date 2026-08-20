import 'package:firebase_auth/firebase_auth.dart';

/// The surveyor ID typed into the app is just a data field (matches the
/// original spreadsheet-driven workflow, not a login). To let Firestore/
/// Storage security rules require "signed in", we sign in anonymously and
/// silently — the surveyor never sees or interacts with this.
class AuthService {
  Future<User?> ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser;
    try {
      final result = await auth.signInAnonymously();
      return result.user;
    } catch (_) {
      return null;
    }
  }
}
