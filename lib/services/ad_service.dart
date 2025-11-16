import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service to manage all AdMob advertisements
///
/// Handles:
/// - App Open Ads (on app launch)
/// - Banner Ads (in screens)
/// - Interstitial Ads (between screens)
/// - Rewarded Ads (coin watching)
/// - Rewarded Interstitial Ads (bonus spins)
/// - Native Advanced Ads (future)
class AdService {
  static final AdService _instance = AdService._internal();

  factory AdService() {
    return _instance;
  }

  AdService._internal();

  /// AdMob App ID
  static const String appId = 'ca-app-pub-3863562453957252~2306547174';

  /// Ad Unit IDs
  static const String appOpenAdId = 'ca-app-pub-3863562453957252/7316428755';
  static const String rewardedInterstitialAdId =
      'ca-app-pub-3863562453957252/5980806527';
  static const String bannerAdId = 'ca-app-pub-3863562453957252/4000539271';
  static const String interstitialAdId =
      'ca-app-pub-3863562453957252/3669366780';
  static const String nativeAdvancedAdId =
      'ca-app-pub-3863562453957252/6003347084';
  static const String rewardedAdId = 'ca-app-pub-3863562453957252/2356285112';

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

  /// Initialize Google Mobile Ads
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      // print('📱 AdMob initialized successfully'); // Removed print
    } catch (e) {
      // print('❌ Error initializing AdMob: $e'); // Removed print
    }
  }

  /// ========== APP OPEN ADS ==========
  /// Called when app opens
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
            // print('✅ App Open Ad loaded'); // Removed print
          },
          onAdFailedToLoad: (error) {
            // print('❌ App Open Ad failed to load: $error'); // Removed print
            _isAppOpenAdReady = false;
          },
        ),
      );
    } catch (e) {
      // print('❌ Error loading App Open Ad: $e'); // Removed print
    }
  }

  /// Show app open ad
  void showAppOpenAd() {
    if (_appOpenAd == null || !_isAppOpenAdReady) {
      // print('⚠️ App Open Ad not ready'); // Removed print
      return;
    }

    try {
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          // print('📺 App Open Ad showed full screen'); // Removed print
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          // print('❌ App Open Ad failed to show: $error'); // Removed print
          ad.dispose();
          _appOpenAd = null;
        },
        onAdDismissedFullScreenContent: (ad) {
          // print('👋 App Open Ad dismissed'); // Removed print
          ad.dispose();
          _appOpenAd = null;
          loadAppOpenAd(); // Load next ad
        },
      );

      _appOpenAd!.show();
    } catch (e) {
      // print('❌ Error showing App Open Ad: $e'); // Removed print
    }
  }

  /// ========== BANNER ADS ==========
  /// Create banner ad for home screen and other screens
  BannerAd? createBannerAd() {
    if (!_isInitialized) {
      // print('❌ AdMob not initialized'); // Removed print
      return null;
    }

    try {
      final newBannerAd = BannerAd(
        adUnitId: bannerAdId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _isBannerAdReady = true;
            // print('✅ Banner Ad loaded'); // Removed print
          },
          onAdFailedToLoad: (ad, error) {
            // print('❌ Banner Ad failed to load: $error'); // Removed print
            ad.dispose();
            _isBannerAdReady = false;
            // Retry loading after delay
            Future.delayed(const Duration(seconds: 2), () {
              if (_bannerAd == ad) {
                loadBannerAdRetry();
              }
            });
          },
          onAdOpened: (ad) {
            // print('📖 Banner Ad opened'); // Removed print
          },
          onAdClosed: (ad) {
            // print('❌ Banner Ad closed'); // Removed print
          },
        ),
      );

      _bannerAd = newBannerAd;
      newBannerAd.load();
      return newBannerAd;
    } catch (e) {
      // print('❌ Error creating Banner Ad: $e'); // Removed print
      return null;
    }
  }

  /// Retry loading banner ad after failure
  Future<void> loadBannerAdRetry() async {
    if (!_isInitialized) return;

    try {
      await Future.delayed(const Duration(seconds: 2));
      final newBannerAd = BannerAd(
        adUnitId: bannerAdId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _isBannerAdReady = true;
            // print('✅ Banner Ad loaded on retry'); // Removed print
          },
          onAdFailedToLoad: (ad, error) {
            // print('❌ Banner Ad failed to load on retry: $error'); // Removed print
            ad.dispose();
            _isBannerAdReady = false;
          },
          onAdOpened: (ad) {},
          onAdClosed: (ad) {},
        ),
      );

      _bannerAd = newBannerAd;
      newBannerAd.load();
    } catch (e) {
      // print('❌ Error retrying Banner Ad: $e'); // Removed print
    }
  }

  /// Get banner ad (for widget usage)
  BannerAd? get bannerAd => _bannerAd;

  /// Check if banner ad is ready
  bool get isBannerAdReady => _isBannerAdReady;

  /// Dispose banner ad
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdReady = false;
  }

  /// ========== INTERSTITIAL ADS ==========
  /// Load interstitial ad (full-screen ads between screens)
  Future<void> loadInterstitialAd() async {
    if (!_isInitialized) await initialize();

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            // print('✅ Interstitial Ad loaded'); // Removed print
          },
          onAdFailedToLoad: (error) {
            // print('❌ Interstitial Ad failed to load: $error'); // Removed print
            _interstitialAd = null;
            // Retry on failure
            Future.delayed(const Duration(seconds: 2), () {
              loadInterstitialAd();
            });
          },
        ),
      );
    } catch (e) {
      // print('❌ Error loading Interstitial Ad: $e'); // Removed print
    }
  }

  /// Show interstitial ad
  Future<void> showInterstitialAd() async {
    if (_interstitialAd == null) {
      // print('⚠️ Interstitial Ad not ready'); // Removed print
      await loadInterstitialAd();
      return;
    }

    try {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          // print('📺 Interstitial Ad showed'); // Removed print
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          // print('❌ Interstitial Ad failed to show: $error'); // Removed print
          ad.dispose();
          _interstitialAd = null;
        },
        onAdDismissedFullScreenContent: (ad) {
          // print('👋 Interstitial Ad dismissed'); // Removed print
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd(); // Load next
        },
      );

      _interstitialAd!.show();
    } catch (e) {
      // print('❌ Error showing Interstitial Ad: $e'); // Removed print
    }
  }

  /// ========== REWARDED ADS ==========
  /// Load rewarded ad (for coin watching)
  Future<void> loadRewardedAd() async {
    if (!_isInitialized) await initialize();

    try {
      await RewardedAd.load(
        adUnitId: rewardedAdId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            // print('✅ Rewarded Ad loaded'); // Removed print
          },
          onAdFailedToLoad: (error) {
            // print('❌ Rewarded Ad failed to load: $error'); // Removed print
            _rewardedAd = null;
            // Retry on failure
            Future.delayed(const Duration(seconds: 2), () {
              loadRewardedAd();
            });
          },
        ),
      );
    } catch (e) {
      // print('❌ Error loading Rewarded Ad: $e'); // Removed print
    }
  }

  /// Show rewarded ad and handle reward
  /// Returns true if reward was granted
  Future<bool> showRewardedAd({
    required Function(RewardItem) onUserEarnedReward,
  }) async {
    if (_rewardedAd == null) {
      // print('⚠️ Rewarded Ad not ready'); // Removed print
      await loadRewardedAd();
      return false;
    }

    try {
      bool rewardGiven = false;

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          // print('📺 Rewarded Ad showed'); // Removed print
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          // print('❌ Rewarded Ad failed to show: $error'); // Removed print
          ad.dispose();
          _rewardedAd = null;
        },
        onAdDismissedFullScreenContent: (ad) {
          // print('👋 Rewarded Ad dismissed'); // Removed print
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd(); // Load next
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          // print('🎁 Reward earned: ${reward.amount} ${reward.type}'); // Removed print
          rewardGiven = true;
          onUserEarnedReward(reward);
        },
      );

      return rewardGiven;
    } catch (e) {
      // print('❌ Error showing Rewarded Ad: $e'); // Removed print
      return false;
    }
  }

  /// ========== REWARDED INTERSTITIAL ADS ==========
  /// Load rewarded interstitial ad (for bonus spins)
  Future<void> loadRewardedInterstitialAd() async {
    if (!_isInitialized) await initialize();

    try {
      await RewardedInterstitialAd.load(
        adUnitId: rewardedInterstitialAdId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedInterstitialAd = ad;
            // print('✅ Rewarded Interstitial Ad loaded'); // Removed print
          },
          onAdFailedToLoad: (error) {
            // print('❌ Rewarded Interstitial Ad failed to load: $error'); // Removed print
            _rewardedInterstitialAd = null;
            // Retry on failure
            Future.delayed(const Duration(seconds: 2), () {
              loadRewardedInterstitialAd();
            });
          },
        ),
      );
    } catch (e) {
      // print('❌ Error loading Rewarded Interstitial Ad: $e'); // Removed print
    }
  }

  /// Show rewarded interstitial ad
  Future<bool> showRewardedInterstitialAd({
    required Function(RewardItem) onUserEarnedReward,
  }) async {
    if (_rewardedInterstitialAd == null) {
      // print('⚠️ Rewarded Interstitial Ad not ready'); // Removed print
      await loadRewardedInterstitialAd();
      return false;
    }

    try {
      bool rewardGiven = false;

      _rewardedInterstitialAd!
          .fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          // print('📺 Rewarded Interstitial Ad showed'); // Removed print
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          // print('❌ Rewarded Interstitial Ad failed to show: $error'); // Removed print
          ad.dispose();
          _rewardedInterstitialAd = null;
        },
        onAdDismissedFullScreenContent: (ad) {
          // print('👋 Rewarded Interstitial Ad dismissed'); // Removed print
          ad.dispose();
          _rewardedInterstitialAd = null;
          loadRewardedInterstitialAd(); // Load next
        },
      );

      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          // print('🎁 Bonus Spin earned: +1 spin'); // Removed print
          rewardGiven = true;
          onUserEarnedReward(reward);
        },
      );

      return rewardGiven;
    } catch (e) {
      // print('❌ Error showing Rewarded Interstitial Ad: $e'); // Removed print
      return false;
    }
  }

  /// ========== NATIVE ADS ==========
  /// Load native ad for display in feeds/lists
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
            // print('✅ Native Ad loaded'); // Removed print
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            onAdFailed(error);
            // print('❌ Native Ad failed to load: $error'); // Removed print
          },
          onAdOpened: (ad) {
            // print('📖 Native Ad opened'); // Removed print
          },
          onAdClosed: (ad) {
            // print('❌ Native Ad closed'); // Removed print
          },
          onAdImpression: (ad) {
            // print('👁️ Native Ad impression'); // Removed print
          },
          onAdClicked: (ad) {
            // print('👆 Native Ad clicked'); // Removed print
          },
        ),
      );

      await nativeAd.load();
      return nativeAd;
    } catch (e) {
      // print('❌ Error loading Native Ad: $e'); // Removed print
      return null;
    }
  }

  /// Dispose a native ad
  void disposeNativeAd(NativeAd ad) {
    ad.dispose();
  }

  /// ========== AD PRELOADING ==========
  /// Preload next ads for faster display
  Future<void> preloadNextAds() async {
    if (!_isInitialized) await initialize();

    try {
      // Preload interstitial
      if (_interstitialAd == null) {
        loadInterstitialAd();
      }

      // Preload rewarded
      if (_rewardedAd == null) {
        loadRewardedAd();
      }

      // Preload rewarded interstitial
      if (_rewardedInterstitialAd == null) {
        loadRewardedInterstitialAd();
      }

      // print('📦 Ads preloaded'); // Removed print
    } catch (e) {
      // print('❌ Error preloading ads: $e'); // Removed print
    }
  }

  /// ========== UTILITIES ==========
  /// Check if ad is available (non-null and ready)
  bool get isRewardedAdAvailable => _rewardedAd != null;
  bool get isRewardedInterstitialAdAvailable => _rewardedInterstitialAd != null;
  bool get isInterstitialAdAvailable => _interstitialAd != null;

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

    // print('🧹 All ads disposed'); // Removed print
  }

  /// Request Ad Consent for GDPR compliance (optional)
  /// Call this before initializing ads for users in EU
  Future<void> requestConsentIfNeeded() async {
    try {
      // Request consent information with success and failure callbacks
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        _onConsentInfoUpdateSuccess,
        _onConsentInfoUpdateFailure,
      );
    } catch (e) {
      // print('❌ Error checking consent: $e'); // Removed print
    }
  }

  void _onConsentInfoUpdateSuccess() {
    _loadAndShowConsentForm();
  }

  void _onConsentInfoUpdateFailure(FormError formError) {
    // Handle failure
    // print('❌ Error requesting consent: ${formError.message}'); // Removed print
  }

  Future<void> _loadAndShowConsentForm() async {
    try {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        await ConsentForm.loadAndShowConsentFormIfRequired((
          FormError? formError,
        ) {
          if (formError != null) {
            // Handle the error.
            // print('❌ Error loading or showing consent form: ${formError.message}'); // Removed print
          }
        });
      }
    } catch (e) {
      // print('❌ Error loading consent form: $e'); // Removed print
    }
  }
}
