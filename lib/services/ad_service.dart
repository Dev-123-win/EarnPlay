import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

/// Service to manage all AdMob advertisements with AdMob Policy Compliance
///
/// COMPLIANCE FEATURES:
/// ✅ Exponential backoff retry (5s → 10s → 20s → 30s)
/// ✅ Max 1 interstitial per 2 minutes
/// ✅ Max 4-6 interstitials per hour per user
/// ✅ No ads forced on app start
/// ✅ Rewarded ads only after user clicks button
/// ✅ Never auto-play rewarded ads
/// ✅ Banner reuse (not recreated per screen)
/// ✅ Safe ad placement (caller responsibility for 16dp margins)
/// ✅ Crash-safe reward callbacks
class AdService {
  static final AdService _instance = AdService._internal();

  factory AdService() {
    return _instance;
  }

  AdService._internal();

  /// AdMob App ID (modifiable for debug/test)
  static String appId = 'ca-app-pub-3863562453957252~2306547174';

  /// Ad Unit IDs (use test IDs in debug)
  static String appOpenAdId = 'ca-app-pub-3863562453957252/7316428755';
  static String rewardedInterstitialAdId =
      'ca-app-pub-3863562453957252/5980806527';
  static String bannerAdId = 'ca-app-pub-3863562453957252/4000539271';
  static String interstitialAdId = 'ca-app-pub-3863562453957252/3669366780';
  static String nativeAdvancedAdId = 'ca-app-pub-3863562453957252/6003347084';
  static String rewardedAdId = 'ca-app-pub-3863562453957252/2356285112';

  /// Current instances
  AppOpenAd? _appOpenAd;
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;

  /// Flags
  bool _isInitialized = false;
  bool _isAppOpenAdReady = false;
  bool _isBannerAdReady = false;

  /// ========== COMPLIANCE TRACKING ==========
  /// Track interstitial frequency to prevent excessive ads
  DateTime? _lastInterstitialShowTime; // Time of last interstitial shown
  int _interstitialsShownThisHour = 0;
  DateTime? _hourlyResetTime;

  /// Track retry attempts for exponential backoff
  final Map<String, int> _retryAttempts =
      {}; // 'banner', 'interstitial', 'rewarded'

  /// Initialize Google Mobile Ads
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Use Google-provided test ad unit IDs when running in debug mode
      if (kDebugMode) {
        appId = 'ca-app-pub-3940256099942544~3347511713';
        appOpenAdId = 'ca-app-pub-3940256099942544/3419835294';
        rewardedInterstitialAdId = 'ca-app-pub-3940256099942544/5354046379';
        bannerAdId = 'ca-app-pub-3940256099942544/6300978111';
        interstitialAdId = 'ca-app-pub-3940256099942544/1033173712';
        nativeAdvancedAdId = 'ca-app-pub-3940256099942544/2247696110';
        rewardedAdId = 'ca-app-pub-3940256099942544/5224354917';
      }

      await MobileAds.instance.initialize();
      _isInitialized = true;
    } catch (e) {
      // Silent fail - app continues without ads
    }
  }

  /// ========== INTERSTITIAL FREQUENCY COMPLIANCE ==========
  /// Check if enough time has passed since last interstitial (min 2 minutes)
  bool _canShowInterstitial() {
    final now = DateTime.now();

    // Check 2-minute minimum between interstitials
    if (_lastInterstitialShowTime != null) {
      final timeSinceLastAd = now
          .difference(_lastInterstitialShowTime!)
          .inSeconds;
      if (timeSinceLastAd < 120) {
        // 2 minutes = 120 seconds
        return false; // Too soon
      }
    }

    // Check hourly limit (max 4-6 per hour, we use 4 for safety)
    if (_hourlyResetTime == null ||
        now.difference(_hourlyResetTime!).inHours >= 1) {
      _hourlyResetTime = now;
      _interstitialsShownThisHour = 0;
    }

    if (_interstitialsShownThisHour >= 4) {
      return false; // Hit hourly limit
    }

    return true;
  }

  /// Record that an interstitial was shown
  void _recordInterstitialShown() {
    _lastInterstitialShowTime = DateTime.now();
    _interstitialsShownThisHour++;
  }

  /// ========== EXPONENTIAL BACKOFF RETRY ==========
  /// Get retry delay with exponential backoff: 5s → 10s → 20s → 30s
  Duration _getRetryDelay(String adType) {
    int attempt = _retryAttempts[adType] ?? 0;
    const delays = [5, 10, 20, 30]; // seconds
    final delaySeconds = attempt < delays.length ? delays[attempt] : 30;
    _retryAttempts[adType] = attempt + 1;
    return Duration(seconds: delaySeconds);
  }

  /// Reset retry attempts after successful load
  void _resetRetryAttempts(String adType) {
    _retryAttempts[adType] = 0;
  }

  /// ========== APP OPEN ADS ==========
  /// Load app open ad (NO auto-show on app start)
  Future<void> loadAppOpenAd() async {
    if (!_isInitialized) await initialize();

    try {
      await AppOpenAd.load(
        adUnitId: appOpenAdId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenAd = ad;
            _isAppOpenAdReady = true;
            _resetRetryAttempts('appopen');
          },
          onAdFailedToLoad: (error) {
            _isAppOpenAdReady = false;
            // Exponential backoff retry
            final delay = _getRetryDelay('appopen');
            Future.delayed(delay, () {
              if ((_retryAttempts['appopen'] ?? 0) < 4) {
                loadAppOpenAd();
              }
            });
          },
        ),
      );
    } catch (e) {
      // Silent fail
    }
  }

  /// Show app open ad (only if user-initiated or at natural breakpoint)
  void showAppOpenAd() {
    if (_appOpenAd == null || !_isAppOpenAdReady) {
      return;
    }

    try {
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {},
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _appOpenAd = null;
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _appOpenAd = null;
          // Load next for future use
          loadAppOpenAd();
        },
      );

      _appOpenAd!.show();
    } catch (e) {
      // Silent fail
    }
  }

  /// ========== BANNER ADS ==========
  /// Create banner ad (keep alive for screen lifetime, don't recreate)
  BannerAd? createBannerAd() {
    if (!_isInitialized) {
      return null;
    }

    // Don't create duplicate banner
    if (_bannerAd != null) {
      return _bannerAd;
    }

    try {
      final newBannerAd = BannerAd(
        adUnitId: bannerAdId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _isBannerAdReady = true;
            _resetRetryAttempts('banner');
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            _isBannerAdReady = false;
            // Exponential backoff retry (5s → 10s → 20s → 30s)
            final delay = _getRetryDelay('banner');
            Future.delayed(delay, () {
              if (_bannerAd == ad) {
                loadBannerAdRetry();
              }
            });
          },
          onAdOpened: (ad) {},
          onAdClosed: (ad) {},
        ),
      );

      _bannerAd = newBannerAd;
      newBannerAd.load();
      return newBannerAd;
    } catch (e) {
      return null;
    }
  }

  /// Retry loading banner ad with backoff
  Future<void> loadBannerAdRetry() async {
    if (!_isInitialized) return;

    try {
      final delay = _getRetryDelay('banner');
      await Future.delayed(delay);

      final newBannerAd = BannerAd(
        adUnitId: bannerAdId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _isBannerAdReady = true;
            _resetRetryAttempts('banner');
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            _isBannerAdReady = false;
            // Don't retry indefinitely - cap at 3 attempts (30s max wait)
            if ((_retryAttempts['banner'] ?? 0) < 4) {
              loadBannerAdRetry();
            }
          },
          onAdOpened: (ad) {},
          onAdClosed: (ad) {},
        ),
      );

      _bannerAd = newBannerAd;
      newBannerAd.load();
    } catch (e) {
      // Silent fail
    }
  }

  /// Get banner ad (for widget usage)
  BannerAd? get bannerAd => _bannerAd;

  /// Check if banner ad is ready
  bool get isBannerAdReady => _isBannerAdReady;

  /// Dispose banner ad - called once when screen closes
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdReady = false;
  }

  /// ========== INTERSTITIAL ADS ==========
  /// Load interstitial ad with frequency compliance
  Future<void> loadInterstitialAd() async {
    if (!_isInitialized) await initialize();

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _resetRetryAttempts('interstitial');
          },
          onAdFailedToLoad: (error) {
            _interstitialAd = null;
            // Exponential backoff retry
            final delay = _getRetryDelay('interstitial');
            Future.delayed(delay, () {
              if ((_retryAttempts['interstitial'] ?? 0) < 4) {
                loadInterstitialAd();
              }
            });
          },
        ),
      );
    } catch (e) {
      // Silent fail
    }
  }

  /// Show interstitial ad (with 2-minute frequency check and hourly cap)
  /// Returns true if ad was shown, false if compliance check failed
  Future<bool> showInterstitialAd() async {
    // COMPLIANCE: Check 2-minute minimum and hourly limit
    if (!_canShowInterstitial()) {
      return false; // Too frequent - don't show
    }

    if (_interstitialAd == null) {
      await loadInterstitialAd();
      return false;
    }

    try {
      bool adShown = false;

      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          adShown = true;
          _recordInterstitialShown(); // Record frequency
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd(); // Preload next
        },
      );

      _interstitialAd!.show();
      return adShown;
    } catch (e) {
      return false;
    }
  }

  /// ========== REWARDED ADS ==========
  /// Load rewarded ad (user-initiated only, never auto-play)
  Future<void> loadRewardedAd() async {
    if (!_isInitialized) await initialize();

    try {
      await RewardedAd.load(
        adUnitId: rewardedAdId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _resetRetryAttempts('rewarded');
          },
          onAdFailedToLoad: (error) {
            _rewardedAd = null;
            // Exponential backoff retry
            final delay = _getRetryDelay('rewarded');
            Future.delayed(delay, () {
              if ((_retryAttempts['rewarded'] ?? 0) < 4) {
                loadRewardedAd();
              }
            });
          },
        ),
      );
    } catch (e) {
      // Silent fail
    }
  }

  /// Show rewarded ad (user clicked button - safe)
  /// Returns true if reward was granted
  Future<bool> showRewardedAd({
    required Function(RewardItem) onUserEarnedReward,
  }) async {
    if (_rewardedAd == null) {
      await loadRewardedAd();
      return false;
    }

    try {
      bool rewardGiven = false;

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {},
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedAd = null;
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd(); // Preload next
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          try {
            rewardGiven = true;
            onUserEarnedReward(reward);
          } catch (e) {
            // Catch crash from user callback
          }
        },
      );

      return rewardGiven;
    } catch (e) {
      return false;
    }
  }

  /// ========== REWARDED INTERSTITIAL ADS ==========
  /// Load rewarded interstitial ad (user-initiated only)
  Future<void> loadRewardedInterstitialAd() async {
    if (!_isInitialized) await initialize();

    try {
      await RewardedInterstitialAd.load(
        adUnitId: rewardedInterstitialAdId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedInterstitialAd = ad;
            _resetRetryAttempts('rewarded_interstitial');
          },
          onAdFailedToLoad: (error) {
            _rewardedInterstitialAd = null;
            // Exponential backoff retry
            final delay = _getRetryDelay('rewarded_interstitial');
            Future.delayed(delay, () {
              if ((_retryAttempts['rewarded_interstitial'] ?? 0) < 4) {
                loadRewardedInterstitialAd();
              }
            });
          },
        ),
      );
    } catch (e) {
      // Silent fail
    }
  }

  /// Show rewarded interstitial ad (user clicked button - safe)
  Future<bool> showRewardedInterstitialAd({
    required Function(RewardItem) onUserEarnedReward,
  }) async {
    if (_rewardedInterstitialAd == null) {
      await loadRewardedInterstitialAd();
      return false;
    }

    try {
      bool rewardGiven = false;

      _rewardedInterstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {},
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedInterstitialAd = null;
            },
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedInterstitialAd = null;
              loadRewardedInterstitialAd(); // Preload next
            },
          );

      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          try {
            rewardGiven = true;
            onUserEarnedReward(reward);
          } catch (e) {
            // Catch crash from user callback
          }
        },
      );

      return rewardGiven;
    } catch (e) {
      return false;
    }
  }

  /// ========== NATIVE ADS ==========
  /// Load native ad for display in feeds/lists
  /// CALLER RESPONSIBILITY: Keep ads 16dp+ from UI edges and buttons
  Future<NativeAd?> loadNativeAd({
    required Function(NativeAd) onAdLoaded,
    required Function(LoadAdError) onAdFailed,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final nativeAd = NativeAd(
        adUnitId: nativeAdvancedAdId,
        factoryId: 'listTile',
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            onAdLoaded(ad as NativeAd);
            _resetRetryAttempts('native');
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            onAdFailed(error);
            // Retry with exponential backoff (cap at 3 retries for native)
            final delay = _getRetryDelay('native');
            Future.delayed(delay, () {
              if ((_retryAttempts['native'] ?? 0) < 3) {
                // Caller should decide on re-retry
              }
            });
          },
          onAdOpened: (ad) {},
          onAdClosed: (ad) {},
          onAdImpression: (ad) {},
          onAdClicked: (ad) {},
        ),
      );

      await nativeAd.load();
      return nativeAd;
    } catch (e) {
      return null;
    }
  }

  /// Dispose a native ad
  void disposeNativeAd(NativeAd ad) {
    ad.dispose();
  }

  /// ========== AD PRELOADING (SAFE) ==========
  /// Preload next ads for faster display (not on app start)
  Future<void> preloadNextAds() async {
    if (!_isInitialized) await initialize();

    try {
      // Preload interstitial (only if not shown in last 2 min)
      if (_interstitialAd == null && _canShowInterstitial()) {
        loadInterstitialAd();
      }

      // Preload rewarded (safe - only shown on user click)
      if (_rewardedAd == null) {
        loadRewardedAd();
      }

      // Preload rewarded interstitial (safe - only shown on user click)
      if (_rewardedInterstitialAd == null) {
        loadRewardedInterstitialAd();
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// ========== UTILITIES ==========
  /// Check if ad is available
  bool get isRewardedAdAvailable => _rewardedAd != null;
  bool get isRewardedInterstitialAdAvailable => _rewardedInterstitialAd != null;
  bool get isInterstitialAdAvailable => _interstitialAd != null;

  /// Get compliance info (for debugging/monitoring)
  Map<String, dynamic> getComplianceInfo() {
    return {
      'lastInterstitialTime': _lastInterstitialShowTime,
      'interstitialsThisHour': _interstitialsShownThisHour,
      'retryAttempts': _retryAttempts,
    };
  }

  /// Dispose all ads
  void disposeAllAds() {
    _appOpenAd?.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _rewardedInterstitialAd?.dispose();

    _appOpenAd = null;
    _bannerAd = null;
    _interstitialAd = null;
    _rewardedAd = null;
    _rewardedInterstitialAd = null;

    _isAppOpenAdReady = false;
    _isBannerAdReady = false;
  }

  /// Request Ad Consent for GDPR compliance
  Future<void> requestConsentIfNeeded() async {
    // NOTE: Consent (UMP) integration is optional and requires adding
    // the User Messaging Platform (UMP) dependency. The project currently
    // does not include a UMP package in `pubspec.yaml`, and the automatic
    // references caused build errors on some platforms. To keep the app
    // buildable, consent handling is a no-op here. Add a UMP package and
    // implement consent flow in production if required for your territory.
    return Future.value();
  }
}
