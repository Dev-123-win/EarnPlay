import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/animation_helper.dart';
import '../providers/game_provider.dart';
import '../models/game_models.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  late ScrollController _scrollController;
  String _selectedGameType = 'All';
  String _selectedResult = 'All';
  final List<String> _gameTypes = [
    'All',
    'TicTacToe',
    'WhackAMole',
    'Spin',
    'Ads',
  ];
  final List<String> _resultTypes = ['All', 'Won', 'Lost', 'Draw'];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      // Load more when reaching end
      _loadMore();
    }
  }

  void _loadMore() {
    // Pagination logic would go here
  }

  List<GameRecord> _getFilteredHistory(List<GameResult> gameResults) {
    // Convert GameResult from provider to GameRecord for display
    final records = gameResults.map((result) {
      final resultStatus = result.isWon ? 'Won' : 'Lost';

      return GameRecord(
        gameType: _formatGameName(result.gameName),
        result: resultStatus,
        coinsEarned: result.coinsEarned,
        playedAt: result.playedAt,
        duration: Duration(seconds: result.duration),
      );
    }).toList();

    // Apply filters
    return records.where((record) {
      final typeMatch =
          _selectedGameType == 'All' || record.gameType == _selectedGameType;
      final resultMatch =
          _selectedResult == 'All' || record.result == _selectedResult;
      return typeMatch && resultMatch;
    }).toList();
  }

  /// Convert game name to display format
  String _formatGameName(String gameName) {
    switch (gameName.toLowerCase()) {
      case 'tictactoe':
        return 'TicTacToe';
      case 'whackmole':
        return 'WhackAMole';
      case 'spin':
        return 'Spin';
      case 'ads':
        return 'Ads';
      default:
        return gameName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game History'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        centerTitle: true,
      ),
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, _) {
          final filteredHistory = _getFilteredHistory(
            gameProvider.localGameHistory,
          );

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Game Type Filter
                Text(
                  'Filter by Game',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _gameTypes.map((type) {
                      final isSelected = _selectedGameType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedGameType = type);
                          },
                          backgroundColor: colorScheme.surfaceContainer,
                          selectedColor: colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Result Filter
                Text(
                  'Filter by Result',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _resultTypes.map((type) {
                      final isSelected = _selectedResult == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedResult = type);
                          },
                          backgroundColor: colorScheme.surfaceContainer,
                          selectedColor: colorScheme.secondary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? colorScheme.onSecondary
                                : colorScheme.onSurface,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        label: 'Total Games',
                        value: '${filteredHistory.length}',
                        icon: Icons.sports_esports,
                        color: colorScheme.primary,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: 'Total Coins',
                        value:
                            '${filteredHistory.fold<int>(0, (sum, record) => sum + record.coinsEarned)}',
                        icon: Icons.monetization_on,
                        color: colorScheme.tertiary,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // History List
                Text(
                  'Recent Games',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (filteredHistory.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: colorScheme.primary.withAlpha(128),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No games found',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(filteredHistory.length, (index) {
                    final record = filteredHistory[index];
                    return _buildHistoryCard(record, colorScheme, textTheme);
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return ScaleFadeAnimation(
      child: Card(
        elevation: 0,
        color: color.withAlpha(25),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    GameRecord record,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final dateFormat =
        '${record.playedAt.month}/${record.playedAt.day}/${record.playedAt.year} ${record.playedAt.hour}:${record.playedAt.minute.toString().padLeft(2, '0')}';
    final resultColor = record.result == 'Won'
        ? colorScheme.tertiary
        : record.result == 'Lost'
        ? colorScheme.error
        : colorScheme.secondary;
    final resultIcon = record.result == 'Won'
        ? Icons.check_circle
        : record.result == 'Lost'
        ? Icons.cancel
        : Icons.drag_handle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getGameIcon(record.gameType),
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          record.gameType,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: resultColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(resultIcon, color: resultColor, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                record.result,
                                style: textTheme.labelSmall?.copyWith(
                                  color: resultColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat,
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(record.duration),
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (record.coinsEarned > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${record.coinsEarned}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getGameIcon(String gameType) {
    switch (gameType) {
      case 'TicTacToe':
        return Icons.grid_3x3;
      case 'WhackAMole':
        return Icons.gamepad;
      case 'Spin':
        return Icons.layers_rounded;
      case 'Ads':
        return Icons.play_circle;
      default:
        return Icons.sports_esports;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

class GameRecord {
  final String gameType;
  final String result;
  final int coinsEarned;
  final DateTime playedAt;
  final Duration duration;

  GameRecord({
    required this.gameType,
    required this.result,
    required this.coinsEarned,
    required this.playedAt,
    required this.duration,
  });
}
