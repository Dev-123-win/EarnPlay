import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/game_provider.dart';

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  late List<String> board;
  late String currentPlayer;
  late bool gameOver;
  late String? gameResult;
  String difficulty = 'Easy';

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    board = List.filled(9, '');
    currentPlayer = 'X'; // Player
    gameOver = false;
    gameResult = null;
  }

  bool _checkWinner(List<String> currentBoard, String player) {
    const List<List<int>> winningCombos = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

    for (final combo in winningCombos) {
      if (currentBoard[combo[0]] == player &&
          currentBoard[combo[1]] == player &&
          currentBoard[combo[2]] == player) {
        return true;
      }
    }
    return false;
  }

  int _getAIMove(List<String> currentBoard) {
    // Check if AI can win
    for (int i = 0; i < 9; i++) {
      if (currentBoard[i].isEmpty) {
        currentBoard[i] = 'O';
        if (_checkWinner(currentBoard, 'O')) {
          currentBoard[i] = '';
          return i;
        }
        currentBoard[i] = '';
      }
    }

    // Check if player can win and block
    for (int i = 0; i < 9; i++) {
      if (currentBoard[i].isEmpty) {
        currentBoard[i] = 'X';
        if (_checkWinner(currentBoard, 'X')) {
          currentBoard[i] = '';
          return i;
        }
        currentBoard[i] = '';
      }
    }

    // Take center if available
    if (currentBoard[4].isEmpty) return 4;

    // Take corners
    final corners = [0, 2, 6, 8];
    corners.shuffle();
    for (final corner in corners) {
      if (currentBoard[corner].isEmpty) return corner;
    }

    // Take any available
    for (int i = 0; i < 9; i++) {
      if (currentBoard[i].isEmpty) return i;
    }

    return -1;
  }

  Future<void> _playerMove(int index) async {
    if (gameOver || board[index].isNotEmpty) return;

    setState(() {
      board[index] = 'X';
      currentPlayer = 'O';
    });

    if (_checkWinner(board, 'X')) {
      setState(() {
        gameOver = true;
        gameResult = 'You Win! 🎉';
      });
      _showGameResult('You Win!', 50, true);
      return;
    }

    if (!board.contains('')) {
      setState(() {
        gameOver = true;
        gameResult = "It's a Draw!";
      });
      _showGameResult("It's a Draw!", 10, false);
      return;
    }

    // AI move
    await Future.delayed(const Duration(milliseconds: 500));

    final aiMove = _getAIMove(board);
    if (aiMove != -1) {
      setState(() {
        board[aiMove] = 'O';
        currentPlayer = 'X';
      });

      if (_checkWinner(board, 'O')) {
        setState(() {
          gameOver = true;
          gameResult = 'You Lost!';
        });
        _showGameResult('You Lost!', 0, false);
        return;
      }

      if (!board.contains('')) {
        setState(() {
          gameOver = true;
          gameResult = "It's a Draw!";
        });
        _showGameResult("It's a Draw!", 10, false);
      }
    }
  }

  void _showGameResult(String result, int coins, bool isWin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result),
        content: coins > 0
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'You earned $coins coins!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleGameEnd(isWin, coins);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGameEnd(bool isWin, int coins) async {
    final gameProvider = context.read<GameProvider>();
    final userProvider = context.read<UserProvider>();

    if (isWin) {
      gameProvider.recordTictactoeWin();
      if (coins > 0) {
        try {
          await userProvider.updateCoins(coins);
          if (mounted && userProvider.userData?.uid != null) {
            await userProvider.loadUserData(userProvider.userData!.uid);
          }
        } catch (e) {
          debugPrint('Error updating coins: $e');
        }
      }
    } else {
      gameProvider.recordTicTactoeLoss();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isWin ? '✅ Victory! +$coins coins' : '❌ Better luck next time',
          ),
          backgroundColor: isWin ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tic Tac Toe'),
        elevation: 0,
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${userProvider.userData?.coins ?? 0}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: DropdownButton<String>(
                  value: difficulty,
                  isExpanded: true,
                  items: ['Easy', 'Medium', 'Hard']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: gameOver
                      ? (val) {
                          if (val != null) {
                            setState(() => difficulty = val);
                          }
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.purple, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => _playerMove(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          board[index],
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: board[index] == 'X'
                                ? Colors.blue
                                : Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (gameResult != null)
              Text(
                gameResult!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: gameResult!.contains('Win')
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => setState(_initializeGame),
              icon: const Icon(Icons.refresh),
              label: const Text('New Game'),
            ),
          ],
        ),
      ),
    );
  }
}
