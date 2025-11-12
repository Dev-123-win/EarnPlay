import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class GameProvider extends ChangeNotifier {
  int _tictactoeWins = 0;
  int _tictactoeLosses = 0;
  int _whackMoleHighScore = 0;
  int _whackMoleCurrentScore = 0;
  bool _isGameActive = false;
  String? _error;

  int get tictactoeWins => _tictactoeWins;
  int get tictactoeLosses => _tictactoeLosses;
  int get whackMoleHighScore => _whackMoleHighScore;
  int get whackMoleCurrentScore => _whackMoleCurrentScore;
  bool get isGameActive => _isGameActive;
  String? get error => _error;

  /// Record Tic-Tac-Toe win using Cloud Function (secure reward)
  Future<int> recordTictactoeWin({int reward = 50}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'recordGameWin',
      );
      final result = await callable.call({
        'gameType': 'tictactoe',
        'score': 100,
        'reward': reward,
      });

      _tictactoeWins++;
      _error = null;
      notifyListeners();

      return result.data['newBalance'] as int;
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

  /// Record Whack-a-Mole win using Cloud Function (secure reward)
  Future<int> recordWhackMoleWin({required int score}) async {
    final reward = (score / 2).toInt().clamp(5, 100);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'recordGameWin',
      );
      final result = await callable.call({
        'gameType': 'whack_mole',
        'score': score,
        'reward': reward,
      });

      updateWhackMoleScore(score);
      _error = null;

      return result.data['newBalance'] as int;
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
