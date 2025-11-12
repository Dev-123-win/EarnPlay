import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/user_provider.dart';
import '../services/ad_service.dart';

class SpinWinScreen extends StatefulWidget {
  const SpinWinScreen({super.key});

  @override
  State<SpinWinScreen> createState() => _SpinWinScreenState();
}

class _SpinWinScreenState extends State<SpinWinScreen>
    with SingleTickerProviderStateMixin {
  static const List<int> rewards = [0, 3, 6, 9, 10, 30];
  static const List<String> labels = [
    'Try Again',
    '3 Coins',
    '6 Coins',
    '9 Coins',
    '10 Coins',
    '30 Coins',
  ];
  static const int spinsPerDay = 3;

  late AnimationController _animationController;
  late AdService _adService;
  bool _isSpinning = false;
  int? _lastReward;
  late math.Random _random;

  @override
  void initState() {
    super.initState();
    _random = math.Random();
    _adService = AdService();

    // Preload rewarded interstitial ads when screen opens
    _adService.loadRewardedInterstitialAd();

    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isSpinning = false);
        _showRewardDialog();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    final userProvider = context.read<UserProvider>();
    final spinsRemaining = userProvider.userData?.spinsRemaining ?? 0;

    if (spinsRemaining <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No spins remaining today. Watch an ad for +1 spin!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isSpinning = true);

    _lastReward = _random.nextInt(rewards.length);
    final rotation = (_random.nextDouble() * 2 * math.pi) + (10 * 2 * math.pi);

    _animationController.forward(from: 0.0).then((_) {
      final actualRotation = rotation % (2 * math.pi);
      final segmentAngle = 2 * math.pi / rewards.length;
      _lastReward = ((actualRotation / segmentAngle).ceil() % rewards.length);
    });
  }

  void _showRewardDialog() {
    if (_lastReward == null) return;

    final reward = rewards[_lastReward!];
    final label = labels[_lastReward!];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 You Won!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(label, style: Theme.of(context).textTheme.headlineSmall),
            if (reward > 0)
              Text(
                '+$reward coins',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        actions: [
          if (reward == 0)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Show rewarded interstitial for bonus spin
                _watchAdForBonusSpin();
              },
              child: const Text('Watch Ad for +1 Spin'),
            )
          else
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                if (reward > 0) {
                  final userProvider = context.read<UserProvider>();
                  try {
                    await userProvider.updateCoins(reward);
                    if (mounted && userProvider.userData?.uid != null) {
                      await userProvider.loadUserData(
                        userProvider.userData!.uid,
                      );
                    }
                  } catch (e) {
                    if (mounted && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Claim Reward'),
            ),
        ],
      ),
    );
  }

  Future<void> _watchAdForBonusSpin() async {
    try {
      bool rewardGiven = await _adService.showRewardedInterstitialAd(
        onUserEarnedReward: (RewardItem reward) async {
          // Add bonus spin via provider and persist
          final userProvider = context.read<UserProvider>();
          try {
            await userProvider.addBonusSpin();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('🎁 +1 Bonus Spin Earned!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving spin: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      );

      if (!rewardGiven && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad not ready. Try again in a moment.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _watchAdForSpin() async {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Watching Ad...'),
          content: const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        Navigator.pop(context);
        final userProvider = context.read<UserProvider>();
        final userData = userProvider.userData;
        if (userData != null) {
          userData.spinsRemaining = (userData.spinsRemaining + 1).clamp(0, 3);
          setState(() {});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spin & Win'),
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
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final spinsRemaining = userProvider.userData?.spinsRemaining ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Spins Remaining',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            spinsPerDay,
                            (index) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Icon(
                                Icons.favorite,
                                color: index < spinsRemaining
                                    ? Colors.red
                                    : Colors.grey.shade300,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: _animationController.value * 10 * 2 * math.pi,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.purple.shade700,
                              width: 4,
                            ),
                          ),
                          child: CustomPaint(
                            painter: WheelPainter(rewards, labels),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.deepOrange,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_downward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _isSpinning || spinsRemaining <= 0 ? null : _spin,
                  icon: const Icon(Icons.casino),
                  label: const Text('SPIN'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _watchAdForSpin,
                  icon: const Icon(Icons.video_library),
                  label: const Text('Watch Ad for +1 Spin'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<int> rewards;
  final List<String> labels;

  WheelPainter(this.rewards, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final segmentAngle = 2 * math.pi / rewards.length;

    for (int i = 0; i < rewards.length; i++) {
      final startAngle = i * segmentAngle - math.pi / 2;
      final paint = Paint()
        ..color = Colors.primaries[i % Colors.primaries.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      final textAngle = startAngle + segmentAngle / 2;
      final textX = center.dx + (radius * 0.6) * math.cos(textAngle);
      final textY = center.dy + (radius * 0.6) * math.sin(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(textX - textPainter.width / 2, textY - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) => false;
}
