import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

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
    final coins = (score / 2).toInt().clamp(5, 100);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over 🎮'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Moles Whacked'),
            const SizedBox(height: 16),
            Text(
              'You earned $coins coins!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Whack a Mole'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Score Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScoreCard(
                  label: 'Score',
                  value: '$score',
                  icon: Icons.sports,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                _buildScoreCard(
                  label: 'Time',
                  value: '${timeRemaining}s',
                  icon: Icons.schedule,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Game Grid
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: gridSize,
                itemBuilder: (context, index) => _buildMoleHole(index),
              ),
            ),
            const SizedBox(height: 24),

            // Control Button
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
                  backgroundColor: colorScheme.tertiary,
                ),
              )
            else
              FilledButton.icon(
                onPressed: _endGame,
                icon: const Icon(Icons.stop),
                label: const Text('End Game'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  backgroundColor: colorScheme.error,
                ),
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
                      '• Tap the moles before they hide\n• 30 seconds gameplay\n• Each mole = 1 point\n• More points = More coins',
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

  Widget _buildScoreCard({
    required String label,
    required String value,
    required IconData icon,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoleHole(int index) {
    final isActive = activeMoleIndex == index && isGameActive;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _whackMole(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.brown.shade400
              : colorScheme.surfaceContainer,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? Colors.brown.shade700 : colorScheme.outline,
            width: 3,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.brown.withValues(alpha: 128),
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
              : Icon(
                  Icons.circle,
                  size: 24,
                  color: colorScheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }
}
