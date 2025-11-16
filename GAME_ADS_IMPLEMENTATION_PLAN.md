# Game Ads Implementation Plan

## 🎮 Overview
Add rewarded ads to Tic Tac Toe and Whack a Mole games without interrupting gameplay.

---

## 📋 Implementation Strategy

### ✅ Core Principle: **Post-Game Rewards**
- Ads shown ONLY after game ends
- Never interrupt active gameplay
- Optional for user (can claim without watching)
- Incentivize watching for double/triple rewards

---

## 🎯 TIC TAC TOE GAME

### Current State:
- **Coins for Win**: 10 coins
- **Result Dialog**: Shows win/draw/loss after game
- **No Ads**: Currently not using ads

### Proposed Implementation:

#### **Step 1: When to Show Ads**
After game ends (player wins, loses, or draw), show reward dialog with options:

```
┌─────────────────────────────┐
│   🎉 You Won!               │
│   +10 coins earned          │
├─────────────────────────────┤
│  [Claim 10]  [Watch Ad: 20] │
└─────────────────────────────┘
```

#### **Step 2: Ad Placement Strategy**

**Option A: Two-Button Approach** (RECOMMENDED)
```
- Button 1: "Claim" → Get 10 coins immediately
- Button 2: "Watch Ad for 2x" → Show rewarded ad
  - On reward → Get 20 coins (2x)
  - On skip → Get 10 coins (normal)
```

**Option B: Ad + Banner**
```
- Claim button at top
- Rewarded ad button in middle
- Banner ad at bottom (optional)
```

#### **Step 3: Implementation Steps**
1. Add AdService import
2. Initialize AdService in initState
3. Preload rewarded ads when screen loads
4. Modify result dialog to show ad button
5. Handle ad reward callback
6. Update UI with coin multiplier

#### **Reward Structure**
| Scenario | Coins |
|----------|-------|
| Win (no ad) | 10 |
| Win (watch ad) | 20 |
| Loss (no ad) | 0 |
| Loss (watch ad) | 5 |
| Draw (no ad) | 0 |
| Draw (watch ad) | 3 |

---

## 🎮 WHACK A MOLE GAME

### Current State:
- **Coins Formula**: `(score / 2).toInt().clamp(5, 100)`
- **Result Dialog**: Shows score and coins after game
- **No Ads**: Currently not using ads

### Proposed Implementation:

#### **Step 1: When to Show Ads**
After game timer ends, show result dialog:

```
┌──────────────────────────────┐
│   Game Over! 🎮              │
│   Score: 15 Moles            │
│   Base Coins: 50              │
├──────────────────────────────┤
│  [Claim 50]  [Watch Ad: 100] │
└──────────────────────────────┘
```

#### **Step 2: Ad Placement Strategy**

**Option A: Double Reward** (RECOMMENDED)
```
- Show calculated coins (base reward)
- Option 1: "Claim" → Get base coins
- Option 2: "Watch Ad for 2x" → Show rewarded ad
  - On reward → Get 2x coins
  - On skip → Get base coins
```

**Option B: Bonus Points**
```
- Base coins: (score/2).clamp(5, 100)
- Watch ad: Get +50% bonus
- Show banner at bottom
```

#### **Step 3: Implementation Steps**
1. Add AdService import and initialization
2. Load rewarded ads in initState
3. Modify result dialog to include ad button
4. Calculate doubled reward
5. Handle ad completion
6. Update user coins with multiplier

#### **Reward Structure**
| Score | Base Coins | With Ad (2x) |
|-------|------------|-------------|
| 5 | 5 | 10 |
| 10 | 5 | 10 |
| 20 | 10 | 20 |
| 30 | 15 | 30 |
| 40 | 20 | 40 |
| 60 | 30 | 60 |

---

## 🎨 UI/UX Design for Result Dialogs

### **TIC TAC TOE - Win Result Dialog**
```
┌────────────────────────────────────┐
│  🎉 You Won!                        │
│  Congratulations! Nice play.        │
├────────────────────────────────────┤
│  You earned:                        │
│  💰 10 coins                        │
│                                    │
│  Want to earn more?                │
│  Watch a 30-second ad to earn 2x!  │
├────────────────────────────────────┤
│  [Claim 10] [Watch Ad (2x = 20)]   │
└────────────────────────────────────┘
```

### **WHACK A MOLE - Game Over Dialog**
```
┌────────────────────────────────────┐
│  Game Over! 🎮                      │
│  Your Score: 20                     │
│  Moles Whacked: 20                  │
├────────────────────────────────────┤
│  Base Coins: 50 🎁                 │
│                                    │
│  💡 Tip: Watch an ad to double it! │
├────────────────────────────────────┤
│  [Claim 50] [Watch Ad (2x = 100)]  │
└────────────────────────────────────┘
```

---

## 🛠️ Technical Implementation Details

### **Common Pattern**

```dart
// 1. Add import
import '../services/ad_service.dart';

// 2. In State class
late AdService _adService;

// 3. In initState
@override
void initState() {
  super.initState();
  _adService = AdService();
  _adService.loadRewardedAd();
}

// 4. In result dialog
FilledButton(
  onPressed: () async {
    bool rewardGiven = await _adService.showRewardedAd(
      onUserEarnedReward: (reward) async {
        // Award DOUBLED coins
        await userProvider.updateCoins(baseCoins * 2);
      }
    );
    
    if (!rewardGiven) {
      // User didn't watch or dismissed - give base coins
      await userProvider.updateCoins(baseCoins);
    }
  },
  label: Text('Watch Ad (2x = ${baseCoins * 2})'),
)

// 5. Dispose
@override
void dispose() {
  _adService.disposeBannerAd();
  super.dispose();
}
```

---

## 🎯 Benefits

### **For Users**:
✅ Optional (not forced)
✅ Instant gratification (see coins before watching)
✅ Clear incentive (2x reward)
✅ No gameplay interruption
✅ Always get base coins (even if skip ad)

### **For App**:
✅ Monetization after natural game end
✅ Higher engagement (incentives watching)
✅ Non-intrusive (post-game only)
✅ Clear CTA (double reward button)
✅ Analytics ready (track ad views vs coins earned)

---

## 📊 Optional Enhancements

### 1. **Streak Bonus**
```
First ad watch today: +10% bonus
Every 3 ads watched: +5 bonus coins
```

### 2. **Limited Offers**
```
Today's offer: 3x coins (first 2 ads)
Regular: 2x coins (after 2 ads)
```

### 3. **Banner Ad in Dialog**
```
Show small banner at bottom of result dialog
Keeps user engaged post-game
```

### 4. **Countdown Timer**
```
Next ad available in: 30s
Prevents ad spamming
```

### 5. **Analytics Events**
```
event_game_played: {game: 'tictactoe', result: 'win', coins: 10}
event_ad_viewed: {game: 'tictactoe', coins_earned: 20}
event_reward_claimed: {game: 'tictactoe', method: 'ad_watch'}
```

---

## 🚀 Implementation Priority

### **Phase 1: MVP (Quick Implementation)**
- [x] Add AdService to both games
- [x] Show ad button in result dialogs
- [x] Implement 2x reward on ad watch
- [x] Handle edge cases (no ad ready, user skip)

### **Phase 2: Enhancement**
- [ ] Add banner ads in result dialog
- [ ] Implement streak tracking
- [ ] Add analytics events
- [ ] Test on multiple devices

### **Phase 3: Optimization**
- [ ] A/B test reward multipliers
- [ ] Implement frequency capping
- [ ] Add animations on reward
- [ ] Optimize ad preloading

---

## ✅ Checklist

### **TIC TAC TOE**
- [ ] Import AdService
- [ ] Initialize AdService in initState
- [ ] Load rewarded ads on screen open
- [ ] Modify _showGameResultDialog
- [ ] Add "Watch Ad" button for wins
- [ ] Handle ad reward callback
- [ ] Update coins with 2x multiplier
- [ ] Handle skip/no-ad scenarios
- [ ] Test all game outcomes

### **WHACK A MOLE**
- [ ] Import AdService
- [ ] Initialize AdService in initState
- [ ] Load rewarded ads on screen open
- [ ] Modify _showGameResult dialog
- [ ] Add "Watch Ad" button
- [ ] Calculate 2x reward
- [ ] Handle ad reward callback
- [ ] Update coins correctly
- [ ] Test score to coins calculation

---

## 🎬 Example Flow Diagram

### **User Journey - TIC TAC TOE Win**
```
1. User wins game
   ↓
2. _showGameResultDialog() called
   ↓
3. Dialog shows "You Won! +10 coins"
   ↓
4. Two buttons:
   - "Claim 10" → Get 10 coins, close dialog
   - "Watch Ad (2x = 20)" → Show rewarded ad
   ↓
5. Ad shows
   ↓
6a. User watches → Get 20 coins, show success message
   ↓
6b. User skips → Get 10 coins (base), show message
   ↓
7. Dialog closes, play again or exit

```

### **User Journey - WHACK A MOLE End**
```
1. Game timer reaches 0
   ↓
2. _endGame() called
   ↓
3. Calculate coins: (score/2).clamp(5, 100)
   ↓
4. _showGameResult() shows dialog
   ↓
5. Dialog shows score and base coins
   ↓
6. Two buttons:
   - "Claim {baseCoins}" → Add coins, close
   - "Watch Ad (2x = {baseCoins*2})" → Show ad
   ↓
7. Ad shows
   ↓
8a. Watch complete → Add 2x coins
   ↓
8b. Skip → Add base coins
   ↓
9. Update UI, allow play again

```

