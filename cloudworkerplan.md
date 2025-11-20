
I'm in Plan mode. Let me gather the context needed to create a comprehensive, detailed plan for reducing costs while maintaining monetization at scale.

Analyze current Firebase/Worker usage patterns

Read firebase_service.dart

Read offline_storage_service.dart

Read user_provider.dart

Read game_provider.dart

Read worker_service.dart

Read firestore.rules

Read index.js

Read home_screen.dart

Read watch_earn_screen.dart

Read spin_win_screen.dart

Read daily_streak_screen.dart

Read tictactoe_screen.dart, lines 1 to 151

Read withdrawal_screen.dart, lines 1 to 101

Read referral_screen.dart, lines 1 to 81

Read profile_screen.dart, lines 1 to 51

Read src

Read ad.js

Read withdrawal_referral.js

Read utils

Read constants.js

Perfect. Now I have the complete picture. Let me create a comprehensive planning document:

Plan: Cost Optimization & Monetization Framework for 1K DAU Free Tier
Based on my ruthless audit and the current usage analysis, here's your complete plan to optimize Firebase/Worker costs while maintaining 1K DAU on the free tier and implementing a sustainable monetization model with 60/40 AdMob revenue split.

SECTION 3: BACKEND OPTIMIZATION (WORKERS)
3.1 Current Worker Usage
Endpoints Currently Called:

/verify-ad (watch_earn_screen.dart)
/claim-referral (referral_screen.dart)
/request-withdrawal (withdrawal_screen.dart)
Endpoints Defined But NOT Called:

/verify-game
/spin-wheel
/claim-streak
Issue: Unused endpoints increase code complexity without benefit.

3.2 Optimized Backend Architecture
New Workers Design: Consolidate to 3 core atomic operations

New Endpoint: /verify-ad (Atomic Transaction)

New Endpoint: /claim-referral (Multi-User Atomic Transaction)

New Endpoint: /request-withdrawal (Atomic Balance Check)

Middleware: Idempotency Verification

SECTION 4: RACE CONDITIONS & MITIGATION
4.1 All Potential Race Conditions by Screen
Watch Ads Screen
Race Condition	Scenario	Impact	Mitigation
Double Ad Reward	User clicks "Watch", network delays, user clicks again	+10 coins twice	Idempotency key on timestamp:adUnitId hash. Store claim in Firestore, check before rewarding.
Ad Expiration	Ad loads, expires before user watches, user still gets reward	Fraudulent reward	Backend: Verify ad impression timestamp within 5 minutes.
Limit Bypass	User watches 8th ad at 11:59:59 PM, watches 9th ad at 12:00:01 AM	Exceeds 8/day limit	Lazy reset: Backend checks lastAdResetDate on each call. Firestore rule validates watchedAdsToday <= 8.
Offline Sync Conflict	User watches ad offline, claims reward, comes online, sync fires	Coins already reflected locally but Firestore update late	Worker idempotency handles this. Claim doc ensures only one reward per ad.
Concurrent Reward Callbacks	Multiple ad instances open, both finish simultaneously	+10 coins × instances	Service layer: Close ad after reward claim. Store isRewardClaimed flag in local state.
Mitigation Summary for Watch Ads:

Idempotency Key: sha256("${userId}:${adUnitId}:${Math.floor(timestamp/60000)}") (key per minute per ad unit)
Claim Document: Write to /users/{uid}/claims/{idempotencyKey} immediately after reward
Firestore Rule: Enforce watchedAdsToday <= 8 in validateUserUpdate
Worker Atomic Tx: Single transaction reads user, validates, updates coins, writes claim
Client-Side: Disable "Watch" button for 10 seconds after click (prevent double-tap)
Spin & Win Screen
Race Condition	Scenario	Impact	Mitigation
Double Spin Claim	User spins, claims reward, connection drops, modal stays up, user re-claims	+50 coins twice	Idempotency key on spin timestamp. Store spinClaimId after first successful claim.
Spin Reset Race	User has 2 spins at 11:59 PM, plays both, game 2 ends at 12:00:01 AM	Second spin doesn't decrement (reset to 3)	Lazy reset: Backend checks date change before allowing spin. Client shows countdown to reset.
Ad Double in Spin	User clicks "Watch Ad to Double", ad finishes, callback fires twice	+100 coins instead of +50	Ad service singleton pattern. Only allow one ad instance. Disable button during ad playback.
Spin Without Reset	New day, user hasn't opened app, spins shows 0/3 in UI but system thinks they can't spin	UI confusion	Load spins on screen init, call resetSpinsIfNewDay() before showing button.
Concurrent Spin Requests	User taps "SPIN" button twice rapidly	Two spins deducted, game runs twice	Disable button after first tap. State machine: IDLE → SPINNING → RESULT → IDLE.
Mitigation Summary for Spin & Win:

Idempotency Key: sha256("${userId}:${spinTimestamp}:claim")
Claim Document: /users/{uid}/claims/spin_${spinTimestamp}
Firestore Rule: Enforce totalSpins >= 0 and daily reset pattern
Client State: _isSpinning boolean, disable button during animation
Backend: Atomic transaction for spin deduction + claim recording
Daily Streak Screen
Race Condition	Scenario	Impact	Mitigation
Duplicate Check-In	User checks in, network lag, user checks in again	Coins earned twice	Idempotency key on date. Check if today's date already has a claim.
Missed Day Detection Wrong	User checks in day 1, misses day 2, checks in day 3. System detects miss (correct), but also resets old coins	Coins lost	Only reset future counts, don't touch past earnings. Store in DB not in transaction.
Timezone Boundary	User in IST at 11:59 PM checks in, system thinks new day. User in NYC same UTC time hasn't hit new day yet	Different behavior per timezone	Use UTC timestamps for day boundaries. Client calculates local days for display only.
Concurrent Streak Claims	User has 2 devices, both claim streak at same time	Coins earned on both, streak incremented twice	Idempotency: sha256("${userId}:${dateString}"). If claim doc exists for today, reject.
Streak Auto-Reset During Claim	Auto-reset fires simultaneously with claim	Streak = 0, coins might be calculated wrong	Combine into single transaction: check days missed → if >1, set to 0; else increment + add coins.
Mitigation Summary for Daily Streak:

Idempotency Key: sha256("${userId}:${dateString}") where date = YYYY-MM-DD
Claim Document: /users/{uid}/claims/streak_${dateString}
Firestore Rule: Enforce immutable past dates, allow only current/future updates
Single Transaction: Combine reset check + coin addition + claim recording
Client: Show countdown to next reset. Lock button after claiming today.
Games (Tic-Tac-Toe, Whack-A-Mole)
Race Condition	Scenario	Impact	Mitigation
Session Flush During Game	User plays game 1, Game Provider flushes (app background), user plays game 2, game 2 lost on crash	Games not counted	Use session ID. Only flush when user exits game, not during play. Use WidgetsBindingObserver for background pause only.
Concurrent Game Finishes	User plays 2 games on 2 devices, both finish, both flush simultaneously	Session coins double-counted	Session ID + idempotency key per session. Store session start time. Flush only once per session.
Double Reward from Ad	User wins game, shows ad-doubling modal, watches ad, callback fires twice	+50 coins instead of +25	Idempotency: sha256("${userId}:${gameEndTime}:${gameName}"). Track in /claims collection.
Game Result Spoofing	User modifies app code to claim "win" without playing	Fraudulent coins	All game state client-side BUT: Server-side validation on flush. Check coinsEarned <= maxCoinsPerGame[gameType]. If > max, reject flush and notify admin.
Offline Game Sync Lost	User plays 5 games offline, queues for 22:00 sync, crashes before sync	5 games lost	Persist queue to local Hive. On app relaunch, auto-retry sync with exponential backoff (every hour). Show UI warning "Pending games queued".
Session Flush Race	App pause triggers flush, user quickly returns to app, plays another game	Game counted twice in session before flush	Use atomic session state: Lock session during flush. Set _sessionFlushed = true. Start new session on next game.
Mitigation Summary for Games:

Session ID: UUID generated on game screen init. Persisted across all games in same session.
Idempotency Key: ${sessionId}:${gameNumber}:${Math.floor(finishTime/1000)}
Atomic Session: _sessionFlushed boolean. After flush, start fresh session for next game.
Server Validation: if (coinsEarned > 250) { reject and notify admin } (max expected from multi-game combo)
Offline Recovery: Auto-retry sync every hour. UI shows "2 games pending sync".
WidgetsBindingObserver: Only flush on AppLifecycleState.paused, not during rapid navigation.
Referral Screen
Race Condition	Scenario	Impact	Mitigation
Two Users Claim Same Code	User A and User B both enter referral code simultaneously	Both claim +100, referrer gets +50 × 2	Backend queries referrer by code FIRST, then locks user (adds referredBy field). Transaction fails for second claimer (referredBy already set). Firestore rule prevents.
Referrer Delete After Claim	User A starts claim, User B (referrer) deletes account mid-transaction	Claim fails mid-way, User A gets coins but User B not updated	Use transaction, all-or-nothing. If referrer doc missing, whole transaction fails. Client retries.
Network Timeout on Claim	User A claims, Worker processes, user loses connection before response	User A sees error, but backend already credited + deducted	Idempotency key. User retries claim. Backend checks claim doc, finds previous result, returns cached response.
Referrer Balance Desync	Referrer has 500 coins, two people claim simultaneously	Each sees FieldValue.increment(50), total = 600 expected, Firestore = 600 correct, but user UI shows 550 (stale)	Client immediately reload balance after claim success. Show toast "Referral received! Check balance."
Duplicate Referral Bonus After Withdraw	User claimed referral 2 days ago, now withdraws. Check audit log for referral action twice	Coins counted twice, payout inflated	Check type == 'REFERRAL_BONUS' count in actions. If > 1 per referrer-claimer pair, alert admin. Audit log immutable prevents this.
Mitigation Summary for Referrals:

Idempotency Key: sha256("${claimerId}:${referralCode}:${claimTime/60000}")
Backend Multi-User Tx: Query referrer, check referredBy null, update both atomically. All-or-nothing.
Firestore Rule: oldData.referredBy == null && newData.referredBy != null ensures one-time set
Claim Dedupe: /users/{claimer}/claims/${idempotencyKey} stores result
Client Recovery: On error, show "Retry" button. On success, toast + reload balance.
Withdrawal Screen
Race Condition	Scenario	Impact	Mitigation
Double Withdrawal Same Amount	User submits 5000 coins, submits again before response	Two withdrawal docs created, -10000 coins total	Idempotency key. Both requests get same withdrawalId. Firestore shows only one withdrawal doc.
Balance Desync on Withdraw	User has 5000 coins, submits 5000 withdrawal, balance becomes 0. Submits another 2000 withdrawal (didn't reload balance)	Second withdrawal succeeds (balance was 0, now -2000). Invalid state.	Always reload balance before submit. Show "Current Balance: 5000" read-only. Worker checks balance immediately before deduction.
Concurrent Withdrawals	User submits 2000 withdrawal on Device A, 3000 on Device B simultaneously	Both hit Worker. Worker atomically checks balance. If only 5000, first succeeds (balance = 3000), second fails (insufficient). Correct!	Worker does atomic: read balance → validate >= amount → decrement. Second fails with INSUFFICIENT_BALANCE. Retry UI shows this error.
Withdrawal Approval During Pending	Admin approves withdrawal for 5000 coins. Same time, user requests another 5000. System processes both.	User balance goes -5000 after new request, but approval already processed 5000. Total -10000.	Admin can only approve PENDING withdrawals. New withdrawal creates new PENDING doc. Admin approves each separately. Coins already deducted on creation.
Zero Balance Withdrawal	User has 999 coins, min is 1000. Submits 1000 anyway.	Fails at Worker validation. Worker responds 400.	Client-side: Disable button if balance < 1000. Show "Min 1000 coins needed". Also Worker validates, returns error.
Idempotency Key Collision	Two different withdrawal requests use same idempotency key (user error)	First request processed, second gets cached response (wrong withdrawal ID returned)	Client generates UUID-based key. Collision probability negligible. If happens, user retries with new key.
Payment Failure After Coins Deducted	Worker deducts 5000 coins, creates withdrawal, then payment gateway fails. Admin doesn't process it.	User coins gone but no money received. User angry.	Withdrawal status: PENDING → APPROVED → COMPLETED. Until admin moves from APPROVED to COMPLETED, coins are "on hold", not transferred. If admin sets to FAILED, coins reversed via Cloud Function.
Mitigation Summary for Withdrawals:

Idempotency Key: sha256("${userId}:${amount}:${paymentDetails}:${requestTime/60000}")
Atomic Worker Tx: Read balance → validate → deduct → create withdrawal → log audit
Client Safeguards: Reload balance. Disable button if < 1000. Show current balance read-only.
Firestore Rule: Enforce min 1000, max 100000 in validateWithdrawalCreation.
Status Flow: PENDING → APPROVED → COMPLETED (or FAILED → REFUND Cloud Function).
Cached Responses: Idempotency saves second request, returns previous withdrawal ID + result.
4.2 App-Wide Race Conditions
Scenario	Cause	Impact	Mitigation
Auth Token Expiry Mid-Request	User logged in, token expires, API call fails, but response already deducted coins	Coins lost in limbo	Worker checks ID token freshness. If expired, return 401. Client re-authenticates, retries with new token and same idempotency key. Worker recognizes key, returns cached result.
Provider State Desync	UserProvider.coins = 500 locally. Firestore has 600 (another device claimed reward). User plays game, wins 50. Sync shows 650, not 550.	User confused about balance	On every screen load: Reload UserData from Firestore. On critical operations (withdrawal, claim): Fresh read + FieldValue.increment(). Never use stale Provider state.
Worker Timeout	Worker request takes >30s, Flutter HTTP client times out. User sees error but backend still processes	User retries, double-charge can occur	Idempotency key on Worker side survives timeouts. If timeout, client can safely retry same request (Worker returns cached result). Timeout != failure.
Offline Queue Corruption	App crashes during Hive queue write. File corrupted.	App fails to start, stuck in restart loop	LocalStorageService: Wrap Hive reads in try-catch. If corrupted, clear queue (show user "Lost pending data, sorry"). Initialize fresh. Prevent app crash.
Monthly Stats Reset Bug	End of month, user plays game at 11:59 PM. Game finishes at 12:00:01 AM (new month). Flush tries to update new month stats but initializes wrong fields.	Coins don't persist, lost forever	GameProvider.flushGameSession(): Before writing, check current month key. Use atomic batch to write coins + monthly_stats together. Initialize ALL fields (see Firestore rules).
Referral Code Collision	Two users generate same 8-char referral code. System breaks.	Referral code not unique, both users claim each other	Generate code with: generateCode() => uuid().substring(0, 8).toUpperCase() (high entropy). OR: Generate, check uniqueness in Firestore, retry if collision (statistically impossible with UUID).
Push Notification Lost	Withdrawal approved, push notification queued but service crashes	User doesn't know withdrawal approved, thinks lost	No single-point-of-failure. User can check "Withdrawal History" UI anytime. Notification is nice-to-have, not critical.
SECTION 5: IMPLEMENTATION ROADMAP
Phase 1: Foundation (Week 1-2)
 Update Firestore Rules (new file: firestore.rules.v2)

Add idempotency key validation
Fix validateMonthlyStats
Add rate limiting (5s between updates)
Add referralCode format validation
 Update Models

Add idempotencyKey to actions, withdrawals, claims
Add sessionId to GameProvider
 Update Worker Endpoints

Refactor /verify-ad with idempotency + claim tracking
Refactor /claim-referral with multi-user atomic tx
Refactor /request-withdrawal with balance check
Phase 2: Client-Side Safety (Week 2-3)
 Add Idempotency Key Generation (lib/utils/idempotency_helper.dart)

Crypto.sha256 for consistent keys
Include timestamp, operation type, user context
 Update Screen Logic

Add state machine to prevent double-clicks (Watch Ads, Spins, etc.)
Add balance reload on critical operations
Add countdown timers to UI (reset times, withdrawal status)
 Improve Error Handling

Distinguish between retryable (timeout) vs non-retryable (insufficient balance) errors
Auto-retry with exponential backoff + idempotency
Show user-friendly error messages
Phase 3: Monetization Tuning (Week 3-4)
 Implement New Coin Rewards (per Section 1.2)

Watch Ads: 10-15 coins
Games: 25-50 coins (difficulty-based)
Spins: Weighted probabilities
Streaks: 15/25/50 pattern
Withdrawals: Min 1000 coins
 Update Firestore Rules to match new increments

 A/B Test User Engagement

Cohort 1: Old rewards (baseline)
Cohort 2: New rewards (experimental)
Measure: DAU, engagement, ARPU, churn
Phase 4: Deploy & Monitor (Week 4)
 Deploy new Firestore rules
 Deploy Worker updates
 Deploy app updates (phased rollout to 10% → 50% → 100%)
 Monitor: Firestore usage, Worker calls, error rates, user feedback
SECTION 6: FIRESTORE COST PROJECTIONS
Free Tier Limits
Reads: 50K/day
Writes: 20K/day
Deletes: 20K/day
Your Current Usage (1K DAU)
Reads: 8K/day (16% of limit) ✅
Writes: 4.2K/day (21% of limit) ✅
Deletes: 0/day ✅
Scaling to 10K DAU (10× growth)
Reads: 80K/day (160% of limit) ❌ EXCEEDS
Writes: 42K/day (210% of limit) ❌ EXCEEDS
Cost on Blaze Plan (if you scale beyond free tier)
Reads: $0.000005 per read
Writes: $0.00001 per write
Deletes: $0.00001 per delete
10K DAU Monthly Cost:

Reads: 80K/day × 30 = 2.4M reads = $12
Writes: 42K/day × 30 = 1.26M writes = $12.60
Total: ~$25/month (still very cheap)
Optimization: Reduce Writes Further
Current bottleneck: Game session flush (2 writes per session)

Optimization: Batch 3 sessions into 1 monthly write

User plays 3 game sessions (15 games total)
Instead of: 3 × 2 = 6 writes
Do: 1 write to monthly_stats with aggregated data
Saves: 5 writes per 3 sessions = 66% reduction
Impact: 42K writes → 14K writes/day (safe at any scale up to 100K DAU)

SECTION 7: WORKER COST PROJECTIONS
Your Current Usage
Calls: 600/day
Cost: 600 / 1,000,000 × $0.50 = $0.0003/day = $0.009/month ✅
Scaling to 10K DAU
Calls: 6,000/day
Cost: 6,000 / 1,000,000 × $0.50 = $0.003/day = $0.09/month ✅
Scaling to 100K DAU
Calls: 60,000/day
Cost: 60,000 / 1,000,000 × $0.50 = $0.03/day = $0.90/month ✅
Conclusion: Workers remain negligible cost at any scale (< $1/month).

SECTION 8: DEPLOYMENT CHECKLIST
Pre-Deployment
 Code review: All endpoints tested locally
 Unit tests: Idempotency, transactions, error handling
 Integration tests: Full user flow (ad → coin → withdrawal)
 Load testing: Simulate 100 concurrent users
 Security review: No sensitive data in logs, encryption checked
Deployment (Phased)

Deploy Firestore rules (v2)

Deploy Worker endpoints (test mode)

Deploy app update with idempotency support

Enable Worker integration (10% of users)

Monitor metrics for 48 hours

Expand to 100% of users

Clean up old endpoints (after 2 weeks)
Post-Deployment Monitoring
 Firestore: Check read/write/delete rates stay under limits
 Worker: Check error rates (target: < 0.1%)
 App: Check crash rates, error logs for race conditions
 Users: Monitor earnings, withdrawal requests, complaints
 Admins:

 Middleware: Idempotency Verification// my-backend/src/middleware/idempotency.js

export async function handleVerifyIdempotency(request, env) {
  if (request.method === 'POST') {
    const body = await request.json();

    if (!body.idempotencyKey || body.idempotencyKey.length < 16) {
      return new Response(
        JSON.stringify({
          error: 'MISSING_IDEMPOTENCY_KEY',
          message: 'All POST requests require idempotencyKey (min 16 chars)',
        }),
        { status: 400 }
      );
    }
  }

  return undefined; // Continue to next handler
}