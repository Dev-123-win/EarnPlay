import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../providers/user_provider.dart';
import '../../providers/game_provider.dart';
import '../../services/ad_service.dart';

class WhackMoleScreen extends StatefulWidget {
  const WhackMoleScreen({super.key});

  @override
  State<WhackMoleScreen> createState() => _WhackMoleScreenState();
}

/// CRITICAL: Add WidgetsBindingObserver to flush game session on app background
class _WhackMoleScreenState extends State<WhackMoleScreen>
    with WidgetsBindingObserver {
  static const int gameDuration = 30;
  static const int gridSize = 9;

  late int score;
  late int timeRemaining;
  late bool isGameActive;
  late int activeMoleIndex;
  late Timer gameTimer;
  late Timer moleTimer;
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
      // Also cancel timers to prevent errors
      gameTimer.cancel();
      moleTimer.cancel();
    }
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
      Duration(milliseconds: 600 + math.Random().nextInt(600)),
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
    final baseCoins = (score / 2).toInt().clamp(5, 100);
    final doubledCoins = baseCoins * 2;

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
              'Base Coins: $baseCoins 🎁',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
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
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleGameEnd(baseCoins);
            },
            child: Text('Claim $baseCoins'),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                bool rewardGiven = await _adService.showRewardedAd(
                  onUserEarnedReward: (RewardItem reward) async {
                    try {
                      Navigator.pop(context);
                      await _handleGameEnd(doubledCoins);
                      if (mounted) {
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
                                  '🎉 Earned $doubledCoins coins (doubled)!',
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 3),
                          ),
                        );
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
            label: Text('Watch Ad (2x = $doubledCoins)'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGameEnd(int coins) async {
    final userProvider = context.read<UserProvider>();
    try {
      await userProvider.updateCoins(coins);
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
    // CRITICAL: Flush game session before leaving screen to avoid data loss
    final uid = context.read<UserProvider>().userData?.uid;
    if (uid != null) {
      context.read<GameProvider>().flushGameSession(uid);
    }
    // CRITICAL: Remove lifecycle observer to prevent memory leak
    WidgetsBinding.instance.removeObserver(this);
    if (isGameActive) {
      gameTimer.cancel();
      moleTimer.cancel();
    }
    _adService.disposeBannerAd();
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
