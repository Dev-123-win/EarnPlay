import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameProvider extends ChangeNotifier {
  int _tictactoeWins = 0;
  int _tictactoeLosses = 0;
  int _whackMoleHighScore = 0;
  int _whackMoleCurrentScore = 0;
  bool _isGameActive = false;
  String? _error;
  bool _statsLoaded = false;

  int get tictactoeWins => _tictactoeWins;
  int get tictactoeLosses => _tictactoeLosses;
  int get whackMoleHighScore => _whackMoleHighScore;
  int get whackMoleCurrentScore => _whackMoleCurrentScore;
  bool get isGameActive => _isGameActive;
  String? get error => _error;
  bool get statsLoaded => _statsLoaded;

  /// Load game stats from Firestore subcollections
  Future<void> loadGameStats(String uid) async {
    try {
      final tictactoeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('game_stats')
          .doc('tictactoe');
      final whackMoleRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('game_stats')
          .doc('whack_mole');

      final tictactoeSnap = await tictactoeRef.get();
      final whackMoleSnap = await whackMoleRef.get();

      if (tictactoeSnap.exists) {
        _tictactoeWins = tictactoeSnap['wins'] ?? 0;
        _tictactoeLosses = tictactoeSnap['losses'] ?? 0;
      }

      if (whackMoleSnap.exists) {
        _whackMoleHighScore = whackMoleSnap['highScore'] ?? 0;
      }

      _statsLoaded = true;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load game stats: $e';
      _statsLoaded = true;
      notifyListeners();
    }
  }

  /// Record Tic-Tac-Toe win and update Firestore directly (secure via Firestore rules)
  Future<int> recordTictactoeWin({int reward = 50}) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not logged in');

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final gameStatsRef = userRef.collection('game_stats').doc('tictactoe');

      // Update game stats and coins in a batch
      final batch = FirebaseFirestore.instance.batch();

      // Update user coins
      batch.update(userRef, {
        'coins': FieldValue.increment(reward),
        'lastUpdated': Timestamp.now(),
      });

      // Update game stats
      batch.update(gameStatsRef, {
        'wins': FieldValue.increment(1),
        'totalScore': FieldValue.increment(100),
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();

      _tictactoeWins++;
      _error = null;
      notifyListeners();

      return reward; // Return the reward added
    } catch (e) {
      _error = 'Failed to record game win: $e';
      notifyListeners();
      rethrow;
    }
  }

  void recordTicTactoeLoss() {
    _tictactoeLosses++;
    _error = null;
    notifyListeners();
  }

  /// Record Whack-a-Mole win and update Firestore directly
  Future<int> recordWhackMoleWin({required int score}) async {
    final reward = (score / 2).toInt().clamp(5, 100);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not logged in');

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final gameStatsRef = userRef.collection('game_stats').doc('whack_mole');

      // Update game stats and coins in a batch
      final batch = FirebaseFirestore.instance.batch();

      // Update user coins
      batch.update(userRef, {
        'coins': FieldValue.increment(reward),
        'lastUpdated': Timestamp.now(),
      });

      // Update game stats
      batch.update(gameStatsRef, {
        'plays': FieldValue.increment(1),
        'highScore': FieldValue.increment(
          score > _whackMoleHighScore ? score - _whackMoleHighScore : 0,
        ),
        'totalScore': FieldValue.increment(score),
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();

      updateWhackMoleScore(score);
      _error = null;

      return reward;
    } catch (e) {
      _error = 'Failed to record game win: $e';
      notifyListeners();
      rethrow;
    }
  }

  void updateWhackMoleScore(int score) {
    _whackMoleCurrentScore = score;
    if (score > _whackMoleHighScore) {
      _whackMoleHighScore = score;
    }
    _error = null;
    notifyListeners();
  }

  void startGame() {
    _isGameActive = true;
    _whackMoleCurrentScore = 0;
    _error = null;
    notifyListeners();
  }

  void endGame() {
    _isGameActive = false;
    _error = null;
    notifyListeners();
  }

  void reset() {
    _tictactoeWins = 0;
    _tictactoeLosses = 0;
    _whackMoleHighScore = 0;
    _whackMoleCurrentScore = 0;
    _isGameActive = false;
    _error = null;
    notifyListeners();
  }
}
