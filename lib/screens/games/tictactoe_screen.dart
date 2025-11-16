import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../providers/user_provider.dart';
import '../../providers/game_provider.dart';
import '../../utils/animation_helper.dart';
import '../../services/ad_service.dart';

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

enum GameResult { playerWon, aiWon, draw, playing }

/// CRITICAL: Add WidgetsBindingObserver to flush game session on app background
class _TicTacToeScreenState extends State<TicTacToeScreen>
    with WidgetsBindingObserver {
  static const int boardSize = 9;
  static const int coinsWon = 10;
  static const int doubledCoinsWon = coinsWon * 2; // 20 coins for ad watch

  late List<String> board;
  late String playerSymbol;
  late String aiSymbol;
  bool isPlayerTurn = true;
  GameResult gameResult = GameResult.playing;
  int playerScore = 0;
  int aiScore = 0;
  bool isThinking = false;
  late AdService _adService;

  @override
  void initState() {
    super.initState();
    // CRITICAL: Register lifecycle observer to catch app background/close
    WidgetsBinding.instance.addObserver(this);
    _adService = AdService();
    _adService.loadRewardedAd();
    _initializeGame();
  }

  /// CRITICAL: Handle app lifecycle changes
  /// Flushes game session when app goes to background
  /// Prevents data loss if user force-closes app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background - flush immediately
      final uid = context.read<UserProvider>().userData?.uid;
      if (uid != null) {
        context.read<GameProvider>().flushGameSession(uid);
      }
    }
  }

  void _initializeGame() {
    board = List<String>.filled(boardSize, '');
    playerSymbol = 'X';
    aiSymbol = 'O';
    isPlayerTurn = true;
    gameResult = GameResult.playing;
    isThinking = false;
  }

  Future<void> _onPlayerMove(int index) async {
    if (board[index].isNotEmpty ||
        !isPlayerTurn ||
        gameResult != GameResult.playing) {
      return;
    }

    setState(() {
      board[index] = playerSymbol;
      isPlayerTurn = false;
    });

    GameResult result = _checkGameResult();
    if (result != GameResult.playing) {
      setState(() => gameResult = result);
      _showGameResultDialog(result);
      return;
    }

    // AI's turn
    setState(() => isThinking = true);
    await Future.delayed(const Duration(milliseconds: 500));

    int aiMove = _findBestMove();
    setState(() {
      board[aiMove] = aiSymbol;
      isThinking = false;
      isPlayerTurn = true;
    });

    result = _checkGameResult();
    if (result != GameResult.playing) {
      setState(() => gameResult = result);
      _showGameResultDialog(result);
      return;
    }
  }

  int _findBestMove() {
    // Reduced difficulty: 50% chance of random move, 50% chance of using Minimax
    if (DateTime.now().millisecond % 2 == 0) {
      return _findRandomMove();
    }

    // Minimax algorithm
    int bestScore = -1000;
    int bestMove = -1;

    for (int i = 0; i < boardSize; i++) {
      if (board[i].isEmpty) {
        board[i] = aiSymbol;
        int score = _minimax(0, false);
        board[i] = '';

        if (score > bestScore) {
          bestScore = score;
          bestMove = i;
        }
      }
    }

    return bestMove == -1 ? _findRandomMove() : bestMove;
  }

  int _minimax(int depth, bool isMaximizing) {
    GameResult result = _checkGameResult();

    if (result == GameResult.aiWon) return 10 - depth;
    if (result == GameResult.playerWon) return depth - 10;
    if (result == GameResult.draw) return 0;

    if (isMaximizing) {
      int bestScore = -1000;
      for (int i = 0; i < boardSize; i++) {
        if (board[i].isEmpty) {
          board[i] = aiSymbol;
          int score = _minimax(depth + 1, false);
          board[i] = '';
          bestScore = bestScore > score ? bestScore : score;
        }
      }
      return bestScore;
    } else {
      int bestScore = 1000;
      for (int i = 0; i < boardSize; i++) {
        if (board[i].isEmpty) {
          board[i] = playerSymbol;
          int score = _minimax(depth + 1, true);
          board[i] = '';
          bestScore = bestScore < score ? bestScore : score;
        }
      }
      return bestScore;
    }
  }

  int _findRandomMove() {
    final emptySpots = <int>[];
    for (int i = 0; i < boardSize; i++) {
      if (board[i].isEmpty) emptySpots.add(i);
    }
    return emptySpots.isEmpty
        ? -1
        : emptySpots[DateTime.now().millisecond % emptySpots.length];
  }

  GameResult _checkGameResult() {
    // Check rows
    for (int row = 0; row < 3; row++) {
      int start = row * 3;
      if (board[start].isNotEmpty &&
          board[start] == board[start + 1] &&
          board[start] == board[start + 2]) {
        return board[start] == playerSymbol
            ? GameResult.playerWon
            : GameResult.aiWon;
      }
    }

    // Check columns
    for (int col = 0; col < 3; col++) {
      if (board[col].isNotEmpty &&
          board[col] == board[col + 3] &&
          board[col] == board[col + 6]) {
        return board[col] == playerSymbol
            ? GameResult.playerWon
            : GameResult.aiWon;
      }
    }

    // Check diagonals
    if (board[0].isNotEmpty && board[0] == board[4] && board[0] == board[8]) {
      return board[0] == playerSymbol ? GameResult.playerWon : GameResult.aiWon;
    }
    if (board[2].isNotEmpty && board[2] == board[4] && board[2] == board[6]) {
      return board[2] == playerSymbol ? GameResult.playerWon : GameResult.aiWon;
    }

    // Check for draw
    if (!board.contains('')) {
      return GameResult.draw;
    }

    return GameResult.playing;
  }

  void _showGameResultDialog(GameResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    String title, message;
    Color accentColor;
    bool showAdOption = false;

    if (result == GameResult.playerWon) {
      title = '🎉 You Won!';
      message = 'Congratulations! You earned $coinsWon coins.';
      accentColor = colorScheme.tertiary;
      showAdOption = true; // Show ad option only on win
      _updateScore(playerWon: true);
    } else if (result == GameResult.draw) {
      title = '🤝 Draw!';
      message = 'It\'s a tie! Well played.';
      accentColor = colorScheme.secondary;
    } else {
      title = '🤖 AI Won';
      message = 'Nice try! The AI played well.';
      accentColor = colorScheme.error;
      _updateScore(playerWon: false);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            if (showAdOption) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.play_circle,
                      color: Colors.amber.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Watch an ad to double your reward!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (showAdOption) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _initializeGame());
              },
              child: Text('Claim $coinsWon'),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  bool rewardGiven = await _adService.showRewardedAd(
                    onUserEarnedReward: (RewardItem reward) async {
                      try {
                        final userProvider = context.read<UserProvider>();
                        await userProvider.updateCoins(doubledCoinsWon);
                        if (mounted && userProvider.userData?.uid != null) {
                          await userProvider.loadUserData(
                            userProvider.userData!.uid,
                          );
                        }
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '🎁 Earned $doubledCoinsWon coins (doubled)!',
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          setState(() => _initializeGame());
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating coins: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  );
                  if (!rewardGiven && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ad not ready. Try again later.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    setState(() => _initializeGame());
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error showing ad: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.play_circle),
              label: Text('Watch Ad (2x = $doubledCoinsWon)'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
              ),
            ),
          ] else ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _initializeGame());
              },
              child: const Text('Play Again'),
            ),
          ],
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void _updateScore({required bool playerWon}) async {
    if (playerWon) {
      setState(() => playerScore++);
      // Don't update coins here - will be updated in dialog with optional ad reward
    } else {
      setState(() => aiScore++);
    }
  }

  @override
  void dispose() {
    // CRITICAL: Flush game session before leaving screen to avoid data loss
    final uid = context.read<UserProvider>().userData?.uid;
    if (uid != null) {
      context.read<GameProvider>().flushGameSession(uid);
    }
    // CRITICAL: Remove lifecycle observer to prevent memory leak
    WidgetsBinding.instance.removeObserver(this);
    _adService.disposeBannerAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tic Tac Toe'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Score Card
            ScaleFadeAnimation(
              child: Card(
                elevation: 0,
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildScoreDisplay(
                        label: 'You',
                        score: playerScore,
                        color: colorScheme.tertiary,
                        textTheme: textTheme,
                      ),
                      Divider(
                        thickness: 2,
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 51,
                        ),
                      ),
                      _buildScoreDisplay(
                        label: 'AI',
                        score: aiScore,
                        color: colorScheme.error,
                        textTheme: textTheme,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Game Status
            if (gameResult == GameResult.playing)
              Text(
                isPlayerTurn
                    ? "Your Turn (X)"
                    : isThinking
                    ? "AI is thinking..."
                    : "AI's Turn (O)",
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const SizedBox.shrink(),

            const SizedBox(height: 24),

            // Board
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(2),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: boardSize,
                itemBuilder: (context, index) =>
                    _buildBoardCell(index, colorScheme, textTheme),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _initializeGame());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Game'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Exit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Game Rules
            Card(
              elevation: 0,
              color: colorScheme.secondaryContainer.withValues(alpha: 76),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Game Rules',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Get 3 in a row (horizontal, vertical, or diagonal) to win\n• You are X, AI is O\n• Win = $coinsWon coins\n• The AI uses Minimax algorithm',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreDisplay({
    required String label,
    required int score,
    required Color color,
    required TextTheme textTheme,
  }) {
    return Column(
      children: [
        Text(label, style: textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: textTheme.displaySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBoardCell(
    int index,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final isWinningCell = _isWinningPosition(index);
    final symbol = board[index];

    return GestureDetector(
      onTap: isPlayerTurn ? () => _onPlayerMove(index) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isWinningCell
              ? colorScheme.tertiary.withValues(alpha: 51)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: symbol == 'X'
                  ? colorScheme.primary
                  : symbol == 'O'
                  ? colorScheme.error
                  : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  bool _isWinningPosition(int index) {
    // Check if this position is part of a winning line
    final winningLines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

    for (var line in winningLines) {
      if (line.contains(index) &&
          board[line[0]].isNotEmpty &&
          board[line[0]] == board[line[1]] &&
          board[line[0]] == board[line[2]]) {
        return true;
      }
    }
    return false;
  }
}
