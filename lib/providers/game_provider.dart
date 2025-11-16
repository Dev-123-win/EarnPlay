import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameProvider extends ChangeNotifier {
  // ============================================
  // GAME STATS (displayed to user)
  // ============================================
  int _tictactoeWins = 0;
  int _tictactoeLosses = 0;
  int _whackMoleHighScore = 0;
  int _whackMoleCurrentScore = 0;
  bool _isGameActive = false;
  String? _error;
  bool _statsLoaded = false;

  // ============================================
  // SESSION BATCHING (in-memory accumulation)
  // Reduces writes from 2 per game to 2 per session
  // ============================================
  String? _activeGameSession; // Game type: "tictactoe" or "whack_mole"
  int _sessionGamesPlayed = 0;
  int _sessionGamesWon = 0;
  int _sessionCoinsEarned = 0;
  DateTime? _lastSessionFlushTime;

  int get tictactoeWins => _tictactoeWins;
  int get tictactoeLosses => _tictactoeLosses;
  int get whackMoleHighScore => _whackMoleHighScore;
  int get whackMoleCurrentScore => _whackMoleCurrentScore;
  bool get isGameActive => _isGameActive;
  String? get error => _error;
  bool get statsLoaded => _statsLoaded;
  int get sessionGamesPlayed => _sessionGamesPlayed;
  int get sessionCoinsEarned => _sessionCoinsEarned;

  /// Load game stats from Firestore (monthly aggregates)
  Future<void> loadGameStats(String uid) async {
    try {
      final currentMonth = _getCurrentMonthKey();
      final monthlyStatsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('monthly_stats')
          .doc(currentMonth);

      final monthlySnap = await monthlyStatsRef.get();

      if (monthlySnap.exists) {
        final data = monthlySnap.data() as Map<String, dynamic>;
        _tictactoeWins = data['tictactoeWins'] ?? 0;
        _whackMoleHighScore = data['whackMoleHighScore'] ?? 0;
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

  /// Start a new game session - called when user opens a game
  /// Accumulates all game results in memory instead of writing each one
  void startGameSession(String gameType) {
    _activeGameSession = gameType;
    _sessionGamesPlayed = 0;
    _sessionGamesWon = 0;
    _sessionCoinsEarned = 0;
    _lastSessionFlushTime = DateTime.now();
    _isGameActive = true;
    _error = null;
    notifyListeners();
  }

  /// Record a single game result (accumulates in memory only)
  /// Does NOT write to Firestore - batches until flush
  /// Call this immediately after each game completes
  void recordGameResultInSession({
    required bool isWin,
    required int coinsEarned,
  }) {
    if (_activeGameSession == null) return;

    _sessionGamesPlayed++;
    if (isWin) {
      _sessionGamesWon++;
    }
    _sessionCoinsEarned += coinsEarned;

    notifyListeners();
  }

  /// Flush session data to Firestore (batched write)
  /// Called every 10 games OR when user leaves the game screen
  /// OR every 5 minutes (auto-save)
  /// Reduces 20 writes to 2 writes for 10 games
  /// CRITICAL: Initializes all monthly stats fields to prevent Firestore rule rejection
  Future<void> flushGameSession(String uid) async {
    if (_activeGameSession == null || _sessionGamesPlayed == 0) {
      return; // Nothing to flush
    }

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final currentMonth = _getCurrentMonthKey();
      final monthlyStatsRef = userRef
          .collection('monthly_stats')
          .doc(currentMonth);
      final auditRef = userRef.collection('actions').doc();

      // Batch both writes together for atomicity
      final batch = FirebaseFirestore.instance.batch();

      // Write 1: Update user coins and game stats
      batch.update(userRef, {
        'coins': FieldValue.increment(_sessionCoinsEarned),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Write 2: Update monthly stats
      // CRITICAL: Initialize ALL fields (not just incremented ones) to avoid Firestore rule rejection
      // This prevents "document missing required fields" errors on first write
      batch.set(monthlyStatsRef, {
        'month': currentMonth,
        'gamesPlayed': FieldValue.increment(_sessionGamesPlayed),
        'gameWins': FieldValue.increment(_sessionGamesWon),
        'coinsEarned': FieldValue.increment(_sessionCoinsEarned),
        'adsWatched': 0, // ← Initialize missing fields
        'spinsUsed': 0, // ← Initialize missing fields
        'withdrawalRequests': 0, // ← Initialize missing fields
        'whackMoleHighScore': 0, // ← Initialize missing fields
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Write 3: Create audit trail for fraud detection
      batch.set(auditRef, {
        'type': 'GAME_SESSION_FLUSH',
        'gameType': _activeGameSession,
        'gamesPlayed': _sessionGamesPlayed,
        'gamesWon': _sessionGamesWon,
        'coinsEarned': _sessionCoinsEarned,
        'amount': _sessionCoinsEarned,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': uid,
      });

      await batch.commit();

      // Update local stats
      _tictactoeWins += _sessionGamesWon;
      _sessionCoinsEarned = 0;
      _sessionGamesPlayed = 0;
      _sessionGamesWon = 0;
      _lastSessionFlushTime = DateTime.now();

      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to flush game session: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Check if session should auto-flush (every 10 games or 5 minutes)
  bool shouldFlushSession() {
    if (_sessionGamesPlayed == 0) return false;

    // Flush if 10+ games played
    if (_sessionGamesPlayed >= 10) return true;

    // Flush if 5+ minutes since last flush
    final timeSinceLastFlush = DateTime.now().difference(
      _lastSessionFlushTime ?? DateTime.now(),
    );
    if (timeSinceLastFlush.inMinutes >= 5) return true;

    return false;
  }

  /// Helper: Get current month in format "2025-11"
  String _getCurrentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
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

  /// End game session and flush accumulated data to Firestore
  Future<void> endGameSession(String uid) async {
    if (shouldFlushSession()) {
      await flushGameSession(uid);
    }
    _activeGameSession = null;
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
    _activeGameSession = null;
    _sessionGamesPlayed = 0;
    _sessionGamesWon = 0;
    _sessionCoinsEarned = 0;
    notifyListeners();
  }
}
