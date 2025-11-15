import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/animation_helper.dart';

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

enum GameResult { playerWon, aiWon, draw, playing }

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  static const int boardSize = 9;
  static const int coinsWon = 10;

  late List<String> board;
  late String playerSymbol;
  late String aiSymbol;
  bool isPlayerTurn = true;
  GameResult gameResult = GameResult.playing;
  int playerScore = 0;
  int aiScore = 0;
  bool isThinking = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
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

    if (result == GameResult.playerWon) {
      title = '🎉 You Won!';
      message = 'Congratulations! You earned $coinsWon coins.';
      accentColor = colorScheme.tertiary;
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
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _initializeGame());
            },
            child: const Text('Play Again'),
          ),
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
      final userProvider = context.read<UserProvider>();
      try {
        await userProvider.updateCoins(coinsWon);
        if (mounted && userProvider.userData?.uid != null) {
          await userProvider.loadUserData(userProvider.userData!.uid);
        }
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: const Text('Failed to update coins'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } else {
      setState(() => aiScore++);
    }
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
