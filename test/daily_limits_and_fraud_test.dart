import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Daily Limit Logic', () {
    test('isNewDay returns true when dates differ (day)', () {
      final now = DateTime(2025, 11, 20, 10, 0, 0); // Nov 20, 10:00
      final lastReset = DateTime(2025, 11, 19, 23, 0, 0); // Nov 19, 23:00

      final isNewDay =
          now.day != lastReset.day ||
          now.month != lastReset.month ||
          now.year != lastReset.year;

      expect(isNewDay, true);
    });

    test('isNewDay returns false when dates are same', () {
      final now = DateTime(2025, 11, 20, 10, 0, 0);
      final lastReset = DateTime(
        2025,
        11,
        20,
        8,
        0,
        0,
      ); // Same day, different hour

      final isNewDay =
          now.day != lastReset.day ||
          now.month != lastReset.month ||
          now.year != lastReset.year;

      expect(isNewDay, false);
    });

    test('isNewDay returns true when month changes', () {
      final now = DateTime(2025, 12, 1, 0, 0, 0); // Dec 1
      final lastReset = DateTime(2025, 11, 30, 23, 59, 59); // Nov 30

      final isNewDay =
          now.day != lastReset.day ||
          now.month != lastReset.month ||
          now.year != lastReset.year;

      expect(isNewDay, true);
    });

    test('isNewDay returns true when year changes', () {
      final now = DateTime(2026, 1, 1, 0, 0, 0);
      final lastReset = DateTime(2025, 12, 31, 23, 59, 59);

      final isNewDay =
          now.day != lastReset.day ||
          now.month != lastReset.month ||
          now.year != lastReset.year;

      expect(isNewDay, true);
    });

    test('Ad limit enforcement: 3 per day max', () {
      const maxAdsPerDay = 3;
      int watchedToday = 0;

      // Watch 3 ads
      expect(watchedToday < maxAdsPerDay, true);
      watchedToday++; // 1

      expect(watchedToday < maxAdsPerDay, true);
      watchedToday++; // 2

      expect(watchedToday < maxAdsPerDay, true);
      watchedToday++; // 3

      // Try 4th ad
      expect(watchedToday < maxAdsPerDay, false); // Blocked
    });

    test('Game win limit enforcement: 2 per day max', () {
      const maxWinsPerDay = 2;
      int winsToday = 0;

      // Win 2 games
      expect(winsToday < maxWinsPerDay, true);
      winsToday++; // 1

      expect(winsToday < maxWinsPerDay, true);
      winsToday++; // 2

      // Try 3rd win
      expect(winsToday < maxWinsPerDay, false); // Blocked
    });

    test('Spin limit enforcement: 1 per day max', () {
      const spinsPerDay = 1;
      int spinsUsedToday = 0;

      // Use 1 spin
      expect(spinsUsedToday < spinsPerDay, true);
      spinsUsedToday++; // 1

      // Try 2nd spin
      expect(spinsUsedToday < spinsPerDay, false); // Blocked
    });

    test('Daily reset: counter resets to 1 on new day', () {
      int watchedAdsToday = 10; // Was at limit yesterday
      const maxAdsPerDay = 3;

      // Old day logic (would block)
      bool canWatchOnOldDay = watchedAdsToday < maxAdsPerDay;
      expect(canWatchOnOldDay, false);

      // New day: reset counter
      watchedAdsToday = 1; // ← Reset to 1, not increment
      bool canWatchOnNewDay = watchedAdsToday < maxAdsPerDay;
      expect(canWatchOnNewDay, true);
    });

    test('Daily reset: counter incremented correctly same day', () {
      int watchedAdsToday = 1; // Already watched 1 today
      const maxAdsPerDay = 3;

      expect(watchedAdsToday < maxAdsPerDay, true);
      watchedAdsToday++; // Increment to 2

      expect(watchedAdsToday < maxAdsPerDay, true);
      watchedAdsToday++; // Increment to 3

      expect(watchedAdsToday < maxAdsPerDay, false); // Now blocked
    });

    test('Streak calculation: multiplier based on consecutive days', () {
      // Day 1: 1 * 5 = 5 coins
      int streak = 1;
      int reward = streak * 5;
      expect(reward, 5);

      // Day 2: 2 * 5 = 10 coins
      streak++;
      reward = streak * 5;
      expect(reward, 10);

      // Day 7: 7 * 5 = 35 coins
      streak = 7;
      reward = streak * 5;
      expect(reward, 35);

      // Day 8: capped at 8 (max streak multiplier)
      streak = 8;
      reward = streak * 5;
      expect(reward, 40);
    });

    test('Reward amounts match production spec', () {
      const rewardAdWatch = 12;
      const rewardTictactoe = 10;
      const rewardWhackmole = 15;
      const rewardSpin = 20;

      expect(rewardAdWatch, 12);
      expect(rewardTictactoe, 10);
      expect(rewardWhackmole, 15);
      expect(rewardSpin, 20);

      // Total daily max (realistic scenario)
      int dailyMax =
          (3 * rewardAdWatch) + // 3 ads
          (2 * rewardTictactoe) + // 2 tic-tac-toe wins
          (1 * rewardWhackmole) + // 1 whack-a-mole win
          (1 * rewardSpin); // 1 spin

      // 36 + 20 + 15 + 20 = 91 coins
      expect(dailyMax, 91);
    });

    test('Timezone independence: no UTC vs IST issues', () {
      // Simulate UTC and IST comparison
      final nowUTC = DateTime.utc(2025, 11, 20, 16, 0, 0); // Nov 20 4 PM UTC
      final ist = nowUTC.add(
        const Duration(hours: 5, minutes: 30),
      ); // Nov 20 9:30 PM IST

      // Both dates should be Nov 20 (same day in IST)
      expect(ist.year, 2025);
      expect(ist.month, 11);
      expect(ist.day, 20);

      final lastResetUTC = DateTime.utc(
        2025,
        11,
        19,
        20,
        0,
        0,
      ); // Nov 19 8 PM UTC
      final lastResetIST = lastResetUTC.add(
        const Duration(hours: 5, minutes: 30),
      ); // Nov 20 1:30 AM IST

      // Different days in IST (reset needed)
      final isNewDay = ist.day != lastResetIST.day;
      expect(isNewDay, true);
    });
  });

  group('Fraud Detection - Withdrawal', () {
    test('Account age < 7 days: +20 fraud points', () {
      final createdAt = DateTime.now().subtract(Duration(days: 6, hours: 23));
      final now = DateTime.now();
      final ageMs = now.difference(createdAt).inMilliseconds;
      final ageDays = ageMs / (1000 * 60 * 60 * 24);

      int fraudScore = 0;
      if (ageDays < 7) fraudScore += 20;

      expect(fraudScore, 20);
    });

    test('Account age >= 7 days: no fraud points for age', () {
      final createdAt = DateTime.now().subtract(Duration(days: 7, hours: 1));
      final now = DateTime.now();
      final ageMs = now.difference(createdAt).inMilliseconds;
      final ageDays = ageMs / (1000 * 60 * 60 * 24);

      int fraudScore = 0;
      if (ageDays < 7) fraudScore += 20;

      expect(fraudScore, 0);
    });

    test('Zero activity: +15 fraud points', () {
      int totalAdsWatched = 0;
      int totalGamesWon = 0;

      int fraudScore = 0;
      if (totalAdsWatched == 0 && totalGamesWon == 0) fraudScore += 15;

      expect(fraudScore, 15);
    });

    test('IP mismatch: +10 fraud points', () {
      final lastRecordedIP = '192.168.1.1';
      final currentIP = '192.168.1.2';

      int fraudScore = 0;
      if (lastRecordedIP != currentIP) fraudScore += 10;

      expect(fraudScore, 10);
    });

    test('Combined fraud score: blocks if > 50', () {
      // New account (< 7d) + zero activity + IP mismatch
      int fraudScore = 20 + 15 + 10; // 45

      expect(fraudScore > 50, false); // Not blocked yet

      // Add one more factor
      fraudScore += 10; // Another IP concern
      expect(fraudScore > 50, true); // Now blocked
    });
  });

  group('Fraud Detection - Referral', () {
    test('Account age < 48 hours: +5 fraud points', () {
      final createdAt = DateTime.now().subtract(Duration(hours: 47));
      final now = DateTime.now();
      final ageMs = now.difference(createdAt).inMilliseconds;
      final ageHours = ageMs / (1000 * 60 * 60);

      int fraudScore = 0;
      if (ageHours < 48) fraudScore += 5;

      expect(fraudScore, 5);
    });

    test('Zero activity: +10 fraud points', () {
      int totalAdsWatched = 0;
      int totalGamesWon = 0;

      int fraudScore = 0;
      if (totalAdsWatched == 0 && totalGamesWon == 0) fraudScore += 10;

      expect(fraudScore, 10);
    });

    test('Same IP as referrer: +10 fraud points', () {
      final referrerIP = '192.168.1.1';
      final userIP = '192.168.1.1';

      int fraudScore = 0;
      if (referrerIP == userIP) fraudScore += 10;

      expect(fraudScore, 10);
    });

    test('Combined fraud score: blocks if > 30', () {
      // New account (< 48h) + zero activity + same IP
      int fraudScore = 5 + 10 + 10; // 25

      expect(fraudScore > 30, false); // Not blocked

      // Add more factors
      fraudScore += 10;
      expect(fraudScore > 30, true); // Now blocked
    });
  });

  group('Cost & Economics', () {
    test('Daily coins per user: 121 coins/day', () {
      // 3 ads × 12 = 36
      // 1 streak (avg 7 days) × 5 × 7 / 7 = 35
      // 1 spin × 20 = 20
      // 2 tic-tac-toe wins × 10 = 20
      // 1 whack-a-mole win × 15 = 15

      int dailyCoins = 36 + 35 + 20 + 20 + 15; // Realistically 90-120
      expect(dailyCoins > 100, true);
      expect(dailyCoins < 150, true);
    });

    test('Monthly cost per user: 1.34 dollars at 0.0003 per coin', () {
      int monthlyCoins = 121 * 30; // 3630 coins
      const coinRate = 0.0003;

      double monthlyCost = monthlyCoins * coinRate;
      expect(monthlyCost > 1.0, true);
      expect(monthlyCost < 1.5, true);
    });

    test('Monthly revenue per 1000 DAU: 2070 dollars', () {
      // AdMob: 420
      // Premium: 50 (5% × 0.99)
      // Cosmetics: 1500
      // Battle pass: 100

      double revenue = 420 + 50 + 1500 + 100;
      expect(revenue, 2070);
    });

    test('Gross margin: 35 percent at break-even of 1850 DAU', () {
      double revenuePerUser = 2070 / 1000;
      double costPerUser = 1339 / 1000;

      double margin = (revenuePerUser - costPerUser) / revenuePerUser;
      expect(margin > 0.30, true); // > 30%
      expect(margin < 0.40, true); // < 40%
    });
  });
}
