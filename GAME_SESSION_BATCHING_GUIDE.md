# 🎮 GAME SCREENS - SESSION BATCHING IMPLEMENTATION GUIDE

## How to Update Your Game Screens to Use Session Batching

### Key Concept
When a user opens a game screen, ALL game results accumulate in memory. Only when they leave the screen (or after 10 games), the batch is written to Firestore.

**This reduces 100 writes to 2 writes for 50 games.**

---

## Implementation Pattern for TicTacToe Screen

### Step 1: Start Session When Screen Opens
```dart
@override
void initState() {
  super.initState();
  final gameProvider = context.read<GameProvider>();
  final uid = context.read<UserProvider>().userData?.uid;
  
  // START SESSION: accumulate all games in memory
  gameProvider.startGameSession('tictactoe');
}
```

### Step 2: Record Game Result (No Firestore Write)
```dart
// When user wins or loses a game
void _recordGameEnd({required bool isWin, required int coinsEarned}) {
  final gameProvider = context.read<GameProvider>();
  
  // This ONLY updates in-memory counters
  // NO FIRESTORE WRITE happens here
  gameProvider.recordGameResultInSession(
    isWin: isWin,
    coinsEarned: coinsEarned,
  );
  
  // Display coins gained to user
  _showCoinAnimation(coinsEarned);
  
  // Check if should flush session (every 10 games or 5 minutes)
  if (gameProvider.shouldFlushSession()) {
    _flushSessionAndContinue();
  }
}

void _flushSessionAndContinue() async {
  final gameProvider = context.read<GameProvider>();
  final uid = context.read<UserProvider>().userData?.uid;
  
  if (uid != null) {
    try {
      // Flush accumulated games to Firestore
      await gameProvider.flushGameSession(uid);
      
      // Show user: "Progress saved!"
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress saved!'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
```

### Step 3: End Session When Screen Closes
```dart
@override
void dispose() {
  final gameProvider = context.read<GameProvider>();
  final uid = context.read<UserProvider>().userData?.uid;
  
  // FLUSH any pending games before leaving screen
  if (uid != null && gameProvider.sessionGamesPlayed > 0) {
    // This will flush remaining games synchronously or with await
    gameProvider.flushGameSession(uid);
  }
  
  // End the game session
  gameProvider.endGameSession(uid ?? '');
  
  super.dispose();
}
```

---

## Full TicTacToe Example

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  static const int rewardPerWin = 50;
  late TicTacToeGame _game;

  @override
  void initState() {
    super.initState();
    _game = TicTacToeGame();
    
    // START SESSION: Memory accumulation begins
    context.read<GameProvider>().startGameSession('tictactoe');
  }

  @override
  void dispose() {
    // FLUSH SESSION: Save any pending games
    final gameProvider = context.read<GameProvider>();
    final uid = context.read<UserProvider>().userData?.uid;
    
    if (uid != null && gameProvider.sessionGamesPlayed > 0) {
      gameProvider.flushGameSession(uid);
    }
    
    gameProvider.endGameSession(uid ?? '');
    super.dispose();
  }

  void _playGame() {
    // Play the game logic
    final isWin = _game.play(); // Your game logic
    
    final gameProvider = context.read<GameProvider>();
    
    if (isWin) {
      // Record in memory only
      gameProvider.recordGameResultInSession(
        isWin: true,
        coinsEarned: rewardPerWin,
      );
      
      _showWinAnimation();
      
      // Auto-flush if reached 10 games
      if (gameProvider.shouldFlushSession()) {
        _flushAndContinue();
      }
    } else {
      // Loss doesn't earn coins, but still tracked
      gameProvider.recordGameResultInSession(
        isWin: false,
        coinsEarned: 0,
      );
    }
    
    setState(() {}); // Update UI with new session stats
  }

  void _flushAndContinue() async {
    final uid = context.read<UserProvider>().userData?.uid;
    if (uid == null) return;
    
    try {
      await context.read<GameProvider>().flushGameSession(uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Progress saved!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showWinAnimation() {
    // Your coin animation logic
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tic-Tac-Toe'),
        subtitle: Text('Games: ${gameProvider.sessionGamesPlayed} | Wins: ${gameProvider.sessionCoinsEarned ~/ rewardPerWin}'),
      ),
      body: Center(
        child: Column(
          children: [
            // Your game UI
            ElevatedButton(
              onPressed: _playGame,
              child: const Text('Play Game'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Whack-A-Mole Screen Pattern (Similar)

```dart
class WhackMoleScreen extends StatefulWidget {
  @override
  State<WhackMoleScreen> createState() => _WhackMoleScreenState();
}

class _WhackMoleScreenState extends State<WhackMoleScreen> {
  @override
  void initState() {
    super.initState();
    // START: Whack-mole session
    context.read<GameProvider>().startGameSession('whack_mole');
  }

  @override
  void dispose() {
    // FLUSH: Save game before leaving
    final gameProvider = context.read<GameProvider>();
    final uid = context.read<UserProvider>().userData?.uid;
    
    if (uid != null && gameProvider.sessionGamesPlayed > 0) {
      gameProvider.flushGameSession(uid);
    }
    
    gameProvider.endGameSession(uid ?? '');
    super.dispose();
  }

  void _onGameOver(int score) {
    final reward = (score / 2).toInt().clamp(5, 100);
    final gameProvider = context.read<GameProvider>();
    
    // Record in memory
    gameProvider.recordGameResultInSession(
      isWin: true, // Whack-mole always "wins" (no lose state)
      coinsEarned: reward,
    );
    
    // Auto-flush check
    if (gameProvider.shouldFlushSession()) {
      _flushAndPlayAgain();
    }
  }

  void _flushAndPlayAgain() async {
    final uid = context.read<UserProvider>().userData?.uid;
    if (uid == null) return;
    
    await context.read<GameProvider>().flushGameSession(uid);
    
    // Continue playing or show menu
    _resetForNextGame();
  }

  void _resetForNextGame() {
    setState(() {
      // Reset game state, continue session
    });
  }
}
```

---

## User-Facing Messages to Display

### When Playing:
```
"Games: 5 | Coins Pending: 250"
```

### When Session Flushes (Auto every 10 games):
```
"✅ Progress Saved! 10 games, 500 coins"
```

### If App Crashes Mid-Session:
```
"⚠️ Note: Progress is saved every 10 games. 
   You lost progress since the last save."
```

---

## Important Notes

1. **No Coins Displayed During Gaming**
   - User won't see their new coin balance until session flushes
   - This is acceptable - they see it in-session as "Pending"

2. **Auto-Flush Guarantees**
   - Every 10 games ✓
   - Every 5 minutes of inactivity ✓
   - When leaving screen ✓

3. **Crash Recovery**
   - Lost progress: Only from current session (max 10 games or 5 minutes worth)
   - Previous sessions: Already saved and safe

4. **Data Consistency**
   - All coin increments use `FieldValue.increment()` - atomic
   - Even if app crashes after write, coins are correctly applied

---

## Testing Checklist

- [ ] Play 10 games straight - verify only 2 writes to Firestore
- [ ] Play 50 games over 10 minutes - verify 5 flushes only
- [ ] Leave screen mid-game - verify pending games flush to Firestore
- [ ] Force-close app mid-session - verify last auto-save is preserved
- [ ] Check monthly_stats document - verify game counts aggregated
- [ ] Check actions collection - verify audit trail created

