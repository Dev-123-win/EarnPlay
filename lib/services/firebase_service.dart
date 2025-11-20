import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:convert';

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

      // Generate device hash for device binding (prevents multi-accounting)
      final deviceHash = await generateDeviceHash();

      await _createUserDocument(
        uid: credential.user!.uid,
        email: email,
        referralCode: referralCode,
        deviceHash: deviceHash,
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

      // Generate device hash for device binding (prevents multi-accounting)
      final deviceHash = await generateDeviceHash();

      // Create user document if new user (using SetOptions merge to avoid overwriting)
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': userCredential.user!.email,
        'displayName': userCredential.user!.displayName ?? '',
        'coins': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'referralCode': _generateReferralCode(),
        'referredBy': null,
        'deviceHash': deviceHash,
        'dailyStreak': {
          'currentStreak': 0,
          'lastCheckIn': null,
          'checkInDates': [],
        },
        'totalSpins': 3,
        'lastSpinResetDate': FieldValue.serverTimestamp(),
        'watchedAdsToday': 0,
        'lastAdResetDate': FieldValue.serverTimestamp(),
        'totalReferrals': 0,
        'totalGamesWon': 0,
        'totalAdsWatched': 0,
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
  /// Create user document on signup
  /// Initializes all required fields for security rules validation
  Future<void> _createUserDocument({
    required String uid,
    required String email,
    String? referralCode,
    String? deviceHash,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': '',
      'coins': 0, // Must start at 0 per security rules
      'referralCode': _generateReferralCode(),
      'referredBy': referralCode, // Can be null initially
      'deviceHash': deviceHash ?? 'unknown', // Device binding for anti-fraud
      'createdAt': FieldValue.serverTimestamp(),
      'dailyStreak': {
        'currentStreak': 0,
        'lastCheckIn': null,
        'checkInDates': [],
      },
      'totalSpins': 3, // Start with 3 spins per day
      'lastSpinResetDate': FieldValue.serverTimestamp(),
      'watchedAdsToday': 0, // Track daily ads watched
      'lastAdResetDate': FieldValue.serverTimestamp(),
      'totalReferrals': 0,
      'totalGamesWon': 0,
      'totalAdsWatched': 0,
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
    // IMPORTANT: Treat `coins` as a delta (positive or negative) and
    // perform an atomic increment to avoid race conditions.
    // Previous implementation wrote absolute values which caused
    // lost updates when concurrent writes occurred.
    await _firestore.collection('users').doc(uid).update({
      'coins': FieldValue.increment(coins),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
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
    final user = _auth.currentUser;
    if (user != null) {
      // Use user UID + timestamp to guarantee uniqueness
      final uid = user.uid.substring(0, 4).toUpperCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch
          .toString()
          .substring(7, 13);
      return 'REF$uid$timestamp';
    }
    return 'REF${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';
  }

  /// Generate secure device hash for device binding
  /// Prevents one device = multiple accounts (referral farming)
  /// Uses SHA256 hash of device ID for privacy
  Future<String> generateDeviceHash() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      late String deviceId;

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id; // Android Device ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown'; // iOS vendor ID
      } else {
        deviceId = 'web_user'; // Web platform fallback
      }

      // Hash for privacy (SHA256)
      final bytes = utf8.encode(deviceId);
      final hash = sha256.convert(bytes).toString();

      return hash;
    } catch (e) {
      return 'error_hash';
    }
  }

  /// Store device hash on signup
  /// Linked to user document for device binding
  Future<void> storeDeviceHash(String uid, String deviceHash) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'deviceHash': deviceHash,
        'lastRecordedDeviceHash': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to store device hash: $e');
    }
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
