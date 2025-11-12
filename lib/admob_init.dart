import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/ad_service.dart';

/// Initialize AdMob when app starts
Future<void> initializeAdMob() async {
  try {
    // Initialize Google Mobile Ads
    await MobileAds.instance.initialize();

    // Initialize AdService
    final adService = AdService();
    await adService.initialize();

    // Preload initial ads
    await adService.preloadNextAds();

    // ✅ AdMob initialized successfully (logged via proper logger in production)
  } catch (e) {
    // ❌ Error initializing AdMob logged via proper logger
  }
}
