import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Authentication Methods
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    String? referralCode,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _createUserDocument(
        uid: credential.user!.uid,
        email: email,
        referralCode: referralCode,
      );

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Create user document if new user
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': userCredential.user!.email,
        'displayName': userCredential.user!.displayName,
        'coins': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'referralCode': _generateReferralCode(),
      }, SetOptions(merge: true));

      return userCredential.user;
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  // User Document Methods
  Future<void> _createUserDocument({
    required String uid,
    required String email,
    String? referralCode,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': '',
      'coins': 0,
      'referralCode': _generateReferralCode(),
      'referredBy': referralCode,
      'createdAt': FieldValue.serverTimestamp(),
      'dailyStreak': {
        'currentStreak': 0,
        'lastCheckIn': null,
        'checkInDates': [],
      },
      'spinsRemaining': 3,
      'lastSpinReset': FieldValue.serverTimestamp(),
      'watchedAdsToday': 0,
      'lastAdReset': FieldValue.serverTimestamp(),
      'totalReferrals': 0,
      'withdrawalHistory': [],
    });
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      throw Exception('Failed to fetch user data: $e');
    }
  }

  Future<void> updateUserCoins(String uid, int coins) async {
    await _firestore.collection('users').doc(uid).update({'coins': coins});
  }

  Future<void> updateDailyStreak(
    String uid,
    Map<String, dynamic> streak,
  ) async {
    await _firestore.collection('users').doc(uid).update({
      'dailyStreak': streak,
    });
  }

  /// Update arbitrary fields on the user document
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    try {
      await _firestore.collection('users').doc(uid).update(fields);
    } catch (e) {
      throw Exception('Failed to update user fields: $e');
    }
  }

  // Helper Methods
  String _generateReferralCode() {
    return 'REF${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Wrong password provided for this user.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // Getters
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
