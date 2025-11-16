# EarnPlay - Complete Ads Placement & Trigger Conditions

## Overview
The EarnPlay app uses **Google AdMob** to display various types of advertisements across different screens. All ad management is centralized in the **AdService** singleton class.

---

## 📊 Ad Types Implemented

| Ad Type | Unit ID | Purpose | Format |
|---------|---------|---------|--------|
| **App Open Ad** | `ca-app-pub-3863562453957252/7316428755` | Displays when app opens/resumes | Full Screen |
| **Banner Ad** | `ca-app-pub-3863562453957252/4000539271` | Persistent ad bar at bottom of screen | 320x50 Banner |
| **Interstitial Ad** | `ca-app-pub-3863562453957252/3669366780` | Full-screen ads between screen transitions | Full Screen |
| **Rewarded Ad** | `ca-app-pub-3863562453957252/2356285112` | Users watch to earn coins | Full Screen + Reward |
| **Rewarded Interstitial Ad** | `ca-app-pub-3863562453957252/5980806527` | Users watch to earn bonus spins | Full Screen + Reward |
| **Native Advanced Ad** | `ca-app-pub-3863562453957252/6003347084` | Custom native ad format (Future use) | Native |

---

## 🎯 Ad Placements & Trigger Conditions

### 1. **HOME SCREEN** (`lib/screens/home_screen.dart`)

#### 📍 Location: Home Screen
- **Ad Type**: Banner Ad (320x50)
- **Where Displayed**: Bottom of the screen (persistent)
- **Trigger Condition**: 
  - Loads when screen initializes (`initState`)
  - Displayed only when banner is ready (`isBannerAdReady == true`)
- **Load Method**: `_adService.createBannerAd()`
- **UI Display**: 
  ```dart
  if (_bannerAd != null && _adService.isBannerAdReady)
    AdWidget(ad: _bannerAd!)
  ```
- **Lifecycle**: 
  - Created on init
  - Disposed when leaving screen
  - Auto-retry if loading fails after 2 seconds

**Code Flow:**
```
initState → _loadBannerAd() → AdService.createBannerAd()
```

---

### 2. **WATCH & EARN SCREEN** (`lib/screens/watch_earn_screen.dart`)

#### 📍 Location: Watch Earn Screen
- **Ad Type**: Rewarded Ad (Full Screen)
- **Purpose**: User watches ad to earn coins
- **Coins Per Ad**: 5 coins
- **Maximum Ads Per Day**: 10 ads (max daily limit)
- **Trigger Condition**:
  - User clicks "Watch Ad" button
  - Check if watched ads < 10 for the day
  - Ad must be loaded and ready
- **Load Method**: `_adService.loadRewardedAd()` (called in initState)
- **Show Method**: `_adService.showRewardedAd(onUserEarnedReward: callback)`

**Trigger Logic:**
```dart
Future<void> _watchAd(int adIndex) async {
  final watched = userProvider.userData?.watchedAdsToday ?? 0;
  
  if (watched >= maxAdsPerDay) {  // ❌ Limit reached
    // Show "Daily limit reached" message
    return;
  }
  
  if (!adService.isRewardedAdAvailable) {  // ❌ Ad not ready
    // Show "Ad not ready yet" message
    return;
  }
  
  // ✅ Show rewarded ad
  bool rewardGiven = await _adService.showRewardedAd(
    onUserEarnedReward: (reward) {
      // Add 5 coins to user
      // Increment watched ads counter
      // Reload UI
    }
  );
}
```

**Reward on Completion:**
- 5 coins added to user balance
- Watched ads counter incremented
- UI refreshed with new balance

---

### 3. **SPIN & WIN SCREEN** (`lib/screens/spin_win_screen.dart`)

#### 📍 Location A: Reward Dialog - "Watch Ad to Double Reward"
- **Ad Type**: Rewarded Ad (Full Screen)
- **Purpose**: User watches ad to DOUBLE their spin reward
- **Trigger Condition**:
  - User completes a spin (spins remaining > 0)
  - Reward dialog appears
  - User clicks "Watch Ad" button
  - Ad must be loaded and ready
- **Load Method**: `_adService.loadRewardedAd()` (called in initState)
- **Show Method**: `_adService.showRewardedAd(onUserEarnedReward: callback)`

**Reward Dialog Flow:**
```dart
Future<void> _showRewardDialogWithAd() async {
  // Dialog shows spin result with options:
  // Button 1: "Claim" - Get normal reward (no ad)
  // Button 2: "Watch Ad" - Watch ad to get 2x reward
  
  showDialog(..., actions: [
    TextButton(onPressed: () {
      // Claim normal reward
      await userProvider.claimSpinReward(rewardAmount, watchedAd: false);
    }, child: Text('Claim')),
    
    FilledButton(onPressed: () async {
      bool rewardGiven = await _adService.showRewardedAd(
        onUserEarnedReward: (reward) async {
          // Claim DOUBLED reward
          final doubledReward = rewardAmount * 2;
          await userProvider.claimSpinReward(doubledReward, watchedAd: true);
        }
      );
    }, child: Text('Watch Ad')),
  ])
}
```

**Reward Examples:**
| Spin Result | Normal Reward | With Ad (2x) |
|------------|---------------|-------------|
| 10 coins | 10 | 20 |
| 25 coins | 25 | 50 |
| 50 coins | 50 | 100 |
| 15 coins | 15 | 30 |
| 30 coins | 30 | 60 |
| 20 coins | 20 | 40 |

---

## 🔄 Ad Lifecycle & Management

### Initialization Flow (`lib/admob_init.dart`)

```
main() 
  → initializeAdMob()
    → MobileAds.instance.initialize()
    → AdService.initialize()
    → AdService.preloadNextAds()
      → loadInterstitialAd()
      → loadRewardedAd()
      → loadRewardedInterstitialAd()
```

**Preloading Strategy:**
- Ads are preloaded on app startup for faster display
- When an ad is shown, next ad is preloaded
- Failed ad loads are retried after 2 seconds

### Banner Ad Retry Logic
```
createBannerAd()
  → newBannerAd.load()
  → onAdFailedToLoad (if failure)
    → Schedule loadBannerAdRetry() after 2 seconds
    → loadBannerAdRetry() creates new banner and tries again
```

### Rewarded Ad Preloading
```
showRewardedAd() called
  → If _rewardedAd == null
    → await loadRewardedAd() (load if not ready)
  → If still null
    → return false (ad not available)
  → Show ad and handle reward
  → After dismissal → preload next ad
```

---

## 📍 Screen-by-Screen Ad Summary

| Screen | Ad Type | Placement | Trigger | Reward |
|--------|---------|-----------|---------|--------|
| **Home Screen** | Banner | Bottom persistent | On load | None (Display only) |
| **Watch & Earn** | Rewarded | Full Screen | User tap "Watch Ad" | 5 coins (max 10/day) |
| **Spin & Win** | Rewarded | Full Screen | User tap "Watch Ad" in reward dialog | 2x spin reward |
| **Other Screens** | None Currently | - | - | - |

---

## ⚙️ AdService Configuration

### Key Settings in `lib/services/ad_service.dart`

```dart
static const String appId = 'ca-app-pub-3863562453957252~2306547174';
static const String bannerAdId = 'ca-app-pub-3863562453957252/4000539271';
static const String interstitialAdId = 'ca-app-pub-3863562453957252/3669366780';
static const String rewardedAdId = 'ca-app-pub-3863562453957252/2356285112';
static const String rewardedInterstitialAdId = 'ca-app-pub-3863562453957252/5980806527';
static const String nativeAdvancedAdId = 'ca-app-pub-3863562453957252/6003347084';
```

### AdService Methods Available

| Method | Purpose | Returns |
|--------|---------|---------|
| `initialize()` | Init Google Mobile Ads SDK | void |
| `createBannerAd()` | Create banner ad instance | BannerAd? |
| `loadAppOpenAd()` | Load app open ad | void |
| `showAppOpenAd()` | Display app open ad | void |
| `loadInterstitialAd()` | Load interstitial ad | void |
| `showInterstitialAd()` | Display interstitial ad | Future<void> |
| `loadRewardedAd()` | Load rewarded ad | void |
| `showRewardedAd(callback)` | Display rewarded ad & handle reward | Future<bool> |
| `loadRewardedInterstitialAd()` | Load rewarded interstitial | void |
| `showRewardedInterstitialAd(callback)` | Display rewarded interstitial | Future<bool> |
| `preloadNextAds()` | Preload all ads for faster display | void |
| `disposeAllAds()` | Clean up all ad resources | void |
| `requestConsentIfNeeded()` | GDPR consent handling | void |

---

## 🔍 Ad Availability Checks

### Before Displaying Ads:
```dart
// Check if rewarded ad is available
bool isRewardedAvailable = adService.isRewardedAdAvailable;

// Check if banner is ready
bool isBannerReady = adService.isBannerAdReady;

// Check if interstitial is available
bool isInterstitialAvailable = adService.isInterstitialAdAvailable;

// Check if rewarded interstitial is available
bool isRewardedInterstitialAvailable = adService.isRewardedInterstitialAdAvailable;
```

---

## 📋 Ad Status Flags & States

| Flag | Type | Purpose |
|------|------|---------|
| `_isInitialized` | bool | Track if AdMob SDK initialized |
| `_isAppOpenAdReady` | bool | Track if app open ad ready |
| `_isBannerAdReady` | bool | Track if banner ad ready |
| `_appOpenAd` | AppOpenAd? | Store current app open ad instance |
| `_bannerAd` | BannerAd? | Store current banner ad instance |
| `_interstitialAd` | InterstitialAd? | Store current interstitial ad |
| `_rewardedAd` | RewardedAd? | Store current rewarded ad |
| `_rewardedInterstitialAd` | RewardedInterstitialAd? | Store current rewarded interstitial |

---

## 🎯 Future Ad Implementation Opportunities

### Currently NOT Implemented:
1. **App Open Ads** - Prepared but not triggered (could show on app launch)
2. **Interstitial Ads** - Prepared but not used (could show between screen transitions)
3. **Rewarded Interstitial Ads** - Prepared but not used (could offer bonus spins)
4. **Native Advanced Ads** - Prepared for future implementation

---

## 📱 Ad Test Unit IDs

The app uses production AdMob IDs. For testing with test ads, these are Google's test unit IDs:

```dart
// Test Unit IDs (for development)
static const String testBannerAdId = 'ca-app-pub-3940256099942544/6300978111';
static const String testInterstitialAdId = 'ca-app-pub-3940256099942544/1033173712';
static const String testRewardedAdId = 'ca-app-pub-3940256099942544/5224354917';
static const String testRewardedInterstitialAdId = 'ca-app-pub-3940256099942544/5354046494';
static const String testAppOpenAdId = 'ca-app-pub-3940256099942544/5575463023';
```

---

## 🛡️ GDPR Compliance

### Consent Handling:
```dart
// Request GDPR consent if needed (for EU users)
Future<void> requestConsentIfNeeded() {
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    _onConsentInfoUpdateSuccess,
    _onConsentInfoUpdateFailure,
  );
}
```

---

## 📊 Ad Display Configuration

### Banner Ad Size
- **Size**: 320x50 (standard mobile banner)
- **Ad Size Constant**: `AdSize.banner`
- **Responsive**: No (fixed size)

### Full Screen Ads
- **App Open**: Full screen, shown on app resume
- **Interstitial**: Full screen, shown between actions
- **Rewarded**: Full screen with close button, requires user interaction for reward
- **Rewarded Interstitial**: Full screen with close button, requires view completion for reward

---

## 🚨 Error Handling

### Ad Load Failures:
- Automatic retry after 2 seconds
- Maximum retries: Infinite (retry every 2 seconds on failure)
- User sees snackbar message if ad not ready when clicked

### Ad Display Failures:
- Ad disposed and instance set to null
- Next ad preloaded automatically
- User notified with error message

### Network/Connectivity Issues:
- AdMob SDK handles connection errors internally
- App continues to function without ads
- Ads resume loading when connection restored

---

## 📈 Analytics & Tracking

Currently, all ad interactions are logged with commented-out print statements:
- Ad loaded ✅
- Ad failed to load ❌
- Ad showed 📺
- Ad dismissed 👋
- Reward earned 🎁

For production logging, integrate with Firebase Analytics or preferred logging service.

---

## 🔗 Related Files

| File | Purpose |
|------|---------|
| `lib/services/ad_service.dart` | Main ad management singleton |
| `lib/admob_init.dart` | AdMob initialization on app startup |
| `lib/screens/home_screen.dart` | Banner ad display |
| `lib/screens/watch_earn_screen.dart` | Rewarded ads for coin earning |
| `lib/screens/spin_win_screen.dart` | Rewarded ads for spin doubling |

---

## 📝 Summary

**Total Ad Types:** 6 (App Open, Banner, Interstitial, Rewarded, Rewarded Interstitial, Native)

**Currently Active:** 2 types
- ✅ Banner Ads (Home Screen)
- ✅ Rewarded Ads (Watch Earn & Spin Win Screens)

**Currently Prepared but Inactive:** 4 types
- ⏸️ App Open Ads
- ⏸️ Interstitial Ads
- ⏸️ Rewarded Interstitial Ads
- ⏸️ Native Ads

**Daily Earning Limits:**
- Watch & Earn: Max 10 ads/day = 50 coins max
- Spin & Win: Unlimited (tied to daily spin limit)

**Reward Mechanics:**
- Watch Ads = Additional rewards (coins or doubled spin rewards)
- No forced ads (all ads are opt-in by user)
- User can always claim reward without watching ad

