import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/game_provider.dart';

class WhackMoleScreen extends StatefulWidget {
  const WhackMoleScreen({super.key});

  @override
  State<WhackMoleScreen> createState() => _WhackMoleScreenState();
}

class _WhackMoleScreenState extends State<WhackMoleScreen> {
  static const int gameDuration = 30;
  static const int gridSize = 9;

  late int score;
  late int timeRemaining;
  late bool isGameActive;
  late int activeMoleIndex;
  late Timer gameTimer;
  late Timer moleTimer;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    score = 0;
    timeRemaining = gameDuration;
    isGameActive = false;
    activeMoleIndex = -1;
  }

  void _startGame() {
    setState(() {
      isGameActive = true;
      score = 0;
      timeRemaining = gameDuration;
      activeMoleIndex = -1;
    });

    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        timeRemaining--;
      });

      if (timeRemaining <= 0) {
        _endGame();
      }
    });

    _showNextMole();
  }

  void _showNextMole() {
    if (!isGameActive) return;

    setState(() {
      activeMoleIndex = math.Random().nextInt(gridSize);
    });

    moleTimer = Timer(
      Duration(milliseconds: 800 + math.Random().nextInt(700)),
      () {
        if (isGameActive) {
          setState(() {
            activeMoleIndex = -1;
          });
          _showNextMole();
        }
      },
    );
  }

  void _whackMole(int index) {
    if (!isGameActive) return;

    if (index == activeMoleIndex) {
      moleTimer.cancel();
      setState(() {
        score++;
        activeMoleIndex = -1;
      });
      _showNextMole();
    }
  }

  void _endGame() {
    gameTimer.cancel();
    moleTimer.cancel();
    setState(() {
      isGameActive = false;
    });
    _showGameResult();
  }

  void _showGameResult() {
    final gameProvider = context.read<GameProvider>();
    gameProvider.updateWhackMoleScore(score);

    final highScore = gameProvider.whackMoleHighScore;
    final isNewHighScore = score > highScore;
    final coins = (score / 2).toInt().clamp(5, 100);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: isNewHighScore
            ? const Text('🏆 New High Score!')
            : const Text('Game Over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (isNewHighScore)
              const Text('You set a new high score!')
            else
              Text('High Score: $highScore'),
            const SizedBox(height: 16),
            Text(
              'You earned $coins coins!',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleGameEnd(coins);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGameEnd(int coins) async {
    final userProvider = context.read<UserProvider>();
    try {
      await userProvider.updateCoins(coins);
      if (mounted && userProvider.userData?.uid != null) {
        await userProvider.loadUserData(userProvider.userData!.uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    if (isGameActive) {
      gameTimer.cancel();
      moleTimer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Whack a Mole'),
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
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            const Text('Score'),
                            Text(
                              '$score',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            const Text('Time'),
                            Text(
                              '$timeRemaining"',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            const Text('High Score'),
                            Text(
                              '${gameProvider.whackMoleHighScore}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: gridSize,
                    itemBuilder: (context, index) => _buildMoleHole(index),
                  ),
                ),
                const SizedBox(height: 24),
                if (!isGameActive)
                  FilledButton.icon(
                    onPressed: _startGame,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Game'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: _endGame,
                    icon: const Icon(Icons.stop),
                    label: const Text('End Game'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoleHole(int index) {
    final isActive = activeMoleIndex == index && isGameActive;

    return GestureDetector(
      onTap: () => _whackMole(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isActive ? Colors.brown : Colors.grey.shade300,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.brown.shade700, width: 3),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.brown.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: isActive
              ? const Icon(
                  Icons.sentiment_very_satisfied,
                  size: 48,
                  color: Colors.amber,
                )
              : const Icon(Icons.circle, size: 24, color: Colors.brown),
        ),
      ),
    );
  }
}
