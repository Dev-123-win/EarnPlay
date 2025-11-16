The Complete Ruthless Read/Write Optimization Plan - Every Scenario Covered
The Unlimited Games Problem You Just Created
You just told me users can play TicTacToe and Whack-A-Mole UNLIMITED times. Do you understand what this means? A single determined user can play 100 games per day. If each game completion writes 2 documents (user coins + game stats), that's 200 writes per user per day. With 1000 users, if even 10% are grinders, that's 20,000 writes daily just from games. You're going to blow past Firebase's free tier write limit (20K per day) with just 100 active gamers. This is financial suicide unless you implement BATCHING and AGGREGATION immediately.
Here's the brutal fix: Don't write EVERY game result to Firestore. Batch them client-side. Let users play 10 games, accumulate rewards in memory (50 coins for 5 wins, 0 for 5 losses), and only write to Firestore when they leave the game screen or every 10 games, whichever comes first. This reduces 20 writes (10 games × 2 writes each) down to 2 writes (one user document update, one game stats update). Users might lose progress if their app crashes mid-session, but that's the cost of running cheap. Display a warning: "Progress is saved every 10 games - don't force close the app."
For game stats tracking, use MONTHLY AGGREGATES instead of per-game records. Create a document at users/UID/game_stats/2025-01 that tracks TOTAL wins/losses for the month, not individual games. Increment this monthly document each time you batch-write. At month-end, you can see the user won 150 TicTacToe games total without storing 150 individual documents. This is critical for reducing writes.
New User Registration WITH Referral Code - The Optimal Path
When a user registers and enters a referral code DURING signup, here's the exact sequence to minimize operations:
First, the app does ONE READ to query the users collection where referralCode equals the entered code. This validates the code exists before creating the account. If invalid, reject signup immediately - don't waste a write creating an account that references a fake code. This single read is unavoidable for validation.
If valid, create the new user's authentication account with Firebase Auth (this is FREE, doesn't count against Firestore quota). Then do ONE WRITE to create the new user document in users/UID with these fields: uid, email, displayName, createdAt (server timestamp), coins (starting at 100 bonus for using referral), referralCode (generate their own unique code), referredBy (the code they entered), and totalReferrals set to 0. Set all game limits for the month: watchedAdsToday at 0, totalSpins at 3, monthly document timestamp to track resets.
Immediately after, do a SECOND WRITE using a Firestore transaction to update the referrer's document. Increment their totalReferrals by 1 and their coins by 50 (or whatever referral bonus you're giving). This must be a transaction to prevent race conditions if multiple people use the same code simultaneously.
Do NOT create game_stats subcollections yet. Do NOT create a limits document yet. Do NOT create a withdrawal history collection. These are created LAZILY when first needed. Total cost: 1 read + 2 writes for registration with referral, which is optimal and unavoidable.
After signup completes, cache the entire user document in SharedPreferences AND in-memory in your UserProvider. The user is now logged in and navigates to home screen without any additional Firestore operations.
New User Registration WITHOUT Referral Code - Defer The Bonus
When a user registers without a referral code, the flow is simpler but has a critical constraint: they can only claim a referral bonus ONCE and BEFORE their first payout. This prevents abuse where users create accounts, grind coins, then add fake referral codes to boost their balance.
Registration does ONE WRITE to create their user document with all the same fields as above, except referredBy is set to null. No read needed since there's no code to validate. After this write, cache everything locally.
The user can grind coins by playing games and watching ads. In your Firestore security rules, enforce that the referredBy field can ONLY be set ONCE and ONLY if it's currently null. This prevents users from changing it after initial claim. The rule looks like: "allow update: if request.resource.data.referredBy != null && resource.data.referredBy == null" meaning you can write a non-null value only if the existing value is null.
Claiming Referral Code AFTER Registration - The Tricky Part
When the user navigates to the referral screen for the first time after registering without a code, they see their own referral code (already in cached user document) and an input field to claim someone else's code. When they enter a code and hit submit:
First, check locally if their cached userData.referredBy is already set. If yes, show error "You already used a referral code" without touching Firestore. ZERO cost rejection.
If null, do ONE READ to query users collection where referralCode equals the entered code. Validate it exists and isn't their own code (can't refer yourself). If invalid, reject with ZERO writes wasted.
If valid, use a FIRESTORE TRANSACTION (critical for race conditions) that does the following atomically: Read the current user's document to verify referredBy is still null (prevents double-claiming if they submitted twice rapidly). Read the referrer's document to verify it exists. Write to current user's document setting referredBy to the code and incrementing coins by 50. Write to referrer's document incrementing totalReferrals by 1 and coins by 50.
This transaction costs 2 reads + 2 writes but it's ATOMIC, meaning if anything fails (network drops, concurrent modifications) the entire transaction rolls back and no partial state is written. This prevents the race condition where two users simultaneously claim the same code and one gets coins without the referrer getting credit.
After transaction succeeds, update your local cache immediately. The user sees their new coin balance and the referredBy field is now permanently set. They can never claim another code.
User Deletes App and Reinstalls - The Critical Recovery Path
When a user deletes your app, SharedPreferences and all local cache is WIPED. When they reinstall and login with the same email/password, Firebase Auth recognizes them (auth tokens are server-side), but your app has NO local data. This is where most apps hemorrhage reads by reloading everything.
Here's the optimized flow: On login success, check if SharedPreferences contains ANY cached user data. If the "last_sync_timestamp" key exists and is less than 1 hour old, you know they didn't uninstall - just logged out and back in. Display the cached data immediately (zero reads) and add a background refresh that happens 5 seconds later.
If SharedPreferences is EMPTY or the timestamp is very old (indicating fresh install), you MUST do the initial sync which costs reads but only happens once per install. Do ONE READ to fetch the user document users/UID. Cache it locally. Do ONE READ to fetch their current month's game stats users/UID/game_stats/2025-01 if it exists. Cache it. That's 2 reads total for a full app recovery.
Do NOT load withdrawal history on login. Do NOT load transaction history. Do NOT load referral lists. Only load the core user document and current month's stats. Everything else loads lazily when the user navigates to those specific screens.
The key optimization: Set a "last_install_timestamp" in your user document on first login after registration. On subsequent logins, compare the device's SharedPreferences timestamp with this server timestamp. If device is missing data but server shows recent activity, you know it's a reinstall. If both are old, it's a returning user after months away. Tailor your sync strategy accordingly - fresh installs get a full 2-read sync, returning users with valid cache get zero reads.
The Race Condition Between Unlimited Games and Coin Updates
Here's a nightmare scenario you haven't considered: User plays 10 TicTacToe games rapidly (takes maybe 2 minutes with your AI). Your app batches these and writes once. But mid-batch, the user also watches an ad which writes to coins. Then the game batch write completes. You now have two writes trying to update the coins field simultaneously. Last write wins, meaning either the game rewards or the ad rewards get OVERWRITTEN and lost.
The solution is FIELD-LEVEL UPDATES using FieldValue.increment instead of document overwrites. Never do: userRef.update({'coins': newTotalValue}) because this overwrites. Always do: userRef.update({'coins': FieldValue.increment(50)}) which adds 50 to whatever the current value is atomically. Firestore handles concurrent increments correctly - if two increments happen simultaneously, both are applied in order and the final value reflects both.
Apply this to ALL numeric fields: coins, watchedAdsToday, totalGamesWon, totalSpins. Every update must be an increment/decrement operation, never a set operation. This makes your system eventually consistent even with rapid concurrent actions.
For the batch game writes, structure it as ONE update with multiple field increments: userRef.update({'coins': FieldValue.increment(totalCoinsFromBatch), 'totalGamesWon': FieldValue.increment(winsInBatch)}) and a separate update to the game_stats document with the same batched values. This is 2 writes per batch regardless of how many games were played, and they're race-condition safe.
Watch & Earn Daily Limit Reset - Zero-Write Solution
You said users have a 10-ad daily limit. Currently you're probably resetting this with a cron job or Cloud Function at midnight. STOP. That's 1000 writes per night for 1000 users, wasted on resets. Instead, use CALCULATED FIELDS based on timestamps.
Store watchedAdsToday as a NUMBER and lastAdResetDate as a SERVER TIMESTAMP in the user document. When the user watches an ad, your security rule checks: "Is today's date (request.time) different from lastAdResetDate? If yes, allow writing watchedAdsToday as 1 (reset + increment). If no, check if watchedAdsToday < 10, then allow incrementing."
This way the "reset" happens implicitly when the first ad of a new day is watched. No midnight batch writes needed. The user document only gets written when they actually watch ads, not preventatively every night. This saves you 30,000 writes per month per 1000 users (1000 users × 30 days).
The same logic applies to spin resets. Store totalSpins and lastSpinResetDate. When the first spin of a new day is attempted, check if date changed, then set totalSpins to 3 (new day) or decrement from current value (same day). The reset is calculated on-demand, not scheduled.
Implement this logic in Firestore Security Rules using request.time.toMillis() compared against resource.data.lastAdResetDate.toMillis() to check if they're the same calendar day. Yes, you can do date math in security rules - it's ugly but possible.
Spin & Win With 3 Daily Spins - The Lazy Reset Method
Following the pattern above, when the user opens the Spin screen, display their totalSpins value from cache immediately. This number might be stale (showing 0 spins even though it's a new day). Add a small "Refresh" button or do an automatic background check.
The background check does ONE READ of just the user document's totalSpins and lastSpinResetDate fields (Firestore lets you read specific fields). Calculate client-side if it's a new day. If yes and spins are 0, show the user "You have 3 new spins available! Tap to refresh." When they tap, write to Firestore setting totalSpins to 3 and lastSpinResetDate to today. This is ONE WRITE that only happens when the user actually engages with the feature on a new day.
If the user never opens the spin screen on a given day, NO read and NO write happens. You only pay for active engagement. Over a month, instead of 1000 users × 30 resets = 30K writes, you pay for maybe 500 active users × 20 days they actually spin = 10K writes. That's 66% cost reduction.
Withdrawal Request Flow - Atomic Deduction
When the user submits a withdrawal request, they enter an amount and payment details. Validate client-side first (minimum 500 coins, valid UPI format) to avoid wasting writes on invalid requests. Then do a FIRESTORE TRANSACTION:
Read the user document to get current coins balance. Check if balance >= requested amount. If no, reject with error shown from transaction (no writes wasted). If yes, write to withdrawals/requestID creating a new document with userId, amount, method, details, status "PENDING", requestedAt timestamp. Write to users/UID decrementing coins by the requested amount using FieldValue.increment(-amount).
This transaction is ATOMIC. Either both writes succeed or neither does. You cannot have a scenario where coins are deducted but the withdrawal request isn't created, or vice versa. Total cost: 1 read + 2 writes per withdrawal request.
After transaction succeeds, update local cache subtracting the coins immediately. The UI shows new balance without re-reading. Add the withdrawal to a locally cached "pending withdrawals" list so it appears in the history immediately.
Withdrawal History Screen - Paginated Lazy Loading
Your withdrawal screen shows "Recent Withdrawals" at the bottom. Do NOT load this automatically on screen open. Show a placeholder message: "Tap to load withdrawal history" with a button. When clicked, query withdrawals collection where userId equals current user, ordered by requestedAt descending, limited to 10 results.
This single query costs 10 READS (one per document returned). Cache these 10 documents locally and display them. If the user scrolls down and wants more, do another query with startAfter pagination for the next 10. But most users will only view the first page, saving you reads.
The withdrawal history is READ-ONLY from the user's perspective. They can't modify it, only view it. So once loaded and cached, it never needs to refresh unless they submit a new request. When a new request is submitted, prepend it to the cached list locally without querying again.
At month-end when you process withdrawals and update their status to "APPROVED" or "REJECTED," the user won't see this change until they manually refresh. Add a pull-to-refresh gesture that re-queries the first 10 documents. But make this OPTIONAL. If users don't refresh, they don't burn reads. You can send them a push notification "Your withdrawal was approved!" so they know to check, but the read only happens when they choose to look.
The Nuclear Option For Unlimited Games - Session Aggregation
Since games are unlimited and write-heavy, implement SESSION TRACKING. When a user opens TicTacToe for the first time in a session, store in memory: sessionStartTime, totalGamesPlayed: 0, totalWins: 0, totalCoinsEarned: 0. As they play games, increment these counters IN MEMORY ONLY.
Every 10 games OR when they leave the screen OR after 30 minutes (whichever comes first), flush this session data to Firestore as ONE write with all the aggregated values. The write updates: users/UID {'coins': FieldValue.increment(sessionCoinsEarned), 'totalGamesWon': FieldValue.increment(sessionWins)} and users/UID/game_stats/2025-01 {'tictactoe_wins': FieldValue.increment(sessionWins), 'tictactoe_games': FieldValue.increment(sessionGames)}.
That's 2 writes per session instead of 2 writes per game. If a user plays 50 games in one sitting, you've reduced 100 writes down to 2 writes. The tradeoff: if their app crashes, they lose progress from the current session. Display this risk clearly: "Game progress is saved every 10 games. Avoid force-closing the app."
For extra safety, implement a background auto-save every 5 minutes while they're actively playing. Use a timer that checks if totalGamesPlayed > 0 and last save was > 5 minutes ago, then flush session data. This reduces crash-loss risk while still batching heavily.
The Monthly Stats Aggregation Strategy
Since you're paying users monthly anyway, optimize your data model around MONTHLY granularity. Create a single monthly stats document for each user: users/UID/monthly_stats/2025-01 that contains:
{
  month: "2025-01",
  coinsEarned: 1250,
  adsWatched: 47,
  gamesPlayed: 203,
  gameWins: 156,
  spinsUsed: 28,
  withdrawalRequests: 1,
  lastUpdated: timestamp
}
Every action (ad watch, game win, spin) increments the relevant fields in THIS document. At month-end, you query all users' monthly stats documents (1 read per user) to calculate payouts, detect fraud, and generate reports. This single document replaces dozens of individual transaction documents, dramatically reducing storage and read costs.
The user's main document (users/UID) only stores CURRENT state (coins balance, dailyStreak, referral code). The monthly stats stores HISTORICAL aggregates. This separation means the main document gets updated frequently (writes) but the monthly stats is write-once-per-action and read-once-per-month.
Firestore Security Rules - Your Free Fraud Prevention Layer
Since you refuse to use Cloud Functions, move ALL validation logic into Firestore Security Rules. These rules run server-side at zero cost and prevent fraudulent writes. Examples:
For coin increments from game wins, enforce that the increment amount matches EXACTLY the allowed reward values: "allow update: if request.resource.data.coins - resource.data.coins in [10, 25, 50, 100] && request.auth.uid == userId". This prevents users from arbitrarily adding 9999 coins.
For daily limits, enforce date-based resets in rules: "allow update: if request.resource.data.watchedAdsToday <= 10 && (request.time.toMillis() - resource.data.lastAdResetDate.toMillis() < 86400000)". This checks that they're under 10 ads AND it's the same day, or allows reset if it's a new day.
For withdrawal requests, enforce minimum amounts: "allow create: if request.resource.data.amount >= 500 && request.auth.uid != null". This blocks requests under 500 coins at the database level.
Rules are FREE and run faster than Cloud Functions. They're your first defense against exploits. Spend time making them bulletproof because they replace thousands of dollars in Cloud Function costs.
The Final Costs With All Optimizations
With unlimited games batched into sessions, daily limits using lazy resets, withdrawal history with lazy loading, and monthly stats aggregation, here's your realistic quota usage per 1000 active users per month:
READS: 2000 logins (2 reads each) + 5000 ad validations + 1000 referral queries + 500 withdrawal history loads (10 reads each) = 12,500 reads per month. Well under the free tier limit of 1.5M reads per month.
WRITES: 50K ad watches (2 writes each) + 10K game sessions (2 writes each) + 10K spin writes + 2K withdrawal requests (2 writes each) + 2K referral claims (2 writes each) = 178K writes per month. This exceeds the free tier limit of 600K writes per month, so you'd pay approximately ₹50-100 per month for Firestore at this scale.
The key insight: Your write costs are unavoidable because they represent actual user actions (earning coins, requesting payouts). But your read costs can be reduced to nearly zero with aggressive caching. Focus on reads first, accept reasonable write costs, and you'll stay profitable even on free tier up to 500-1000 users.RetryDev-123-win/EarnPlaymainGITHUBSthis is how the current firestore rules look likeYour Firestore Rules Are A Complete Disaster - Brutally Honest Breakdown
The Catastrophic Security Holes You've Created
Your rules are so permissive they might as well not exist. Let me show you every way a malicious user will rob you blind within 24 hours of launch:
HOLE #1: Users Can Write Their Own Coin Balances
allow write: if request.auth.uid == userId && validateUserDocument(resource.data);
This says "users can write to their own document if it has the right fields." But you're NOT validating the VALUES of those fields. A user can literally write:

coins: 999999 (give themselves infinite coins)
totalGamesWon: 10000 (fake their stats)
watchedAdsToday: 0 (reset their daily limit whenever they want)
referredBy: null then change it to a code, then back to null, then to another code (claim infinite referral bonuses)

Your validateUserDocument() function only checks if the KEYS exist, not if the values are legitimate. This is like having a door lock that only checks if you have A key, not THE RIGHT key.
HOLE #2: Complete Absence of Increment Validation
Nowhere in your rules do you enforce that coin updates use FieldValue.increment(). A user can use a Firebase client library to directly set coins: 100000 and your rules will allow it because it passes validateUserDocument(). You need to check that writes are INCREMENTS with specific allowed amounts, not arbitrary SET operations.
HOLE #3: Subcollections Are Wide Open
Your coin_transactions subcollection rule is:
allow write: if request.auth.uid == userId && 
             request.resource.data.size() <= 5 &&
             request.resource.data.keys().hasAll(['amount', 'reason', 'timestamp']);
This lets users create FAKE transactions with ANY amount and ANY reason. They can write:

amount: 50000, reason: "admin_bonus"
Create 1000 fake transactions to look legitimate
The main user document coins don't auto-update from these transactions, but now you have a corrupted audit trail

These subcollections are DECORATIVE, not functional. They don't protect anything.
HOLE #4: No Rate Limiting Whatsoever
Your rules have ZERO protection against spam. A user can:

Create 1000 coin_transactions per second (you only check size and keys, not frequency)
Submit 100 withdrawal requests simultaneously (create is allowed without checking if one already exists)
Write to game_history 10,000 times in a row (no rate limiting)

Firebase will charge you for every write even if they're malicious. A single attacker can cost you hundreds of dollars in quota overages.
HOLE #5: The isAdmin() Function Will Crash Your App
function isAdmin(uid) {
  return get(/databases/$(database)/documents/admins/$(uid)).data.isAdmin == true;
}
This does a SUB-QUERY inside a security rule. Do you know what happens when that admins/{uid} document doesn't exist? THE ENTIRE RULE EVALUATION FAILS and the operation is denied. But more importantly, every call to isAdmin() costs an ADDITIONAL READ. You're using it in the withdrawals rules, so every withdrawal read costs 2 reads (the withdrawal + the admin check). You're literally doubling your read costs for no reason.
Also, you never created an admins collection. So isAdmin() ALWAYS returns false, meaning admins can't actually update withdrawal statuses. Your month-end payout process is BROKEN.
HOLE #6: Referral System Is Completely Broken
match /referral_codes/{codeId} {
  allow read: if request.auth != null;
  allow write: if false;
}
You have a referral_codes collection that nobody can write to. How do referral codes get created then? They DON'T. Your referral system doesn't work. Users' referral codes are stored in their user documents, not in this collection, so this entire collection is USELESS.
And your referral_records collection has allow write: if false which means when users claim referral codes, NO RECORD IS CREATED. You have no audit trail of who referred whom.
HOLE #7: Game History Collection Is Pointless
You have BOTH:

users/{userId}/game_history/{gameId} (subcollection)
game_history/{gameId} (root collection)

Why? The root collection rule says:
allow read: if request.auth != null;  // ANY logged-in user can read ALL games
allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
This means every user can see EVERY OTHER USER'S game history. This is a privacy violation and also completely unnecessary. Delete this entire root collection - you only need the subcollection.
The Rules You ACTUALLY Need For Your Business Model
Since you're running unlimited games with batching, monthly payouts, and lazy resets, here's what your rules MUST enforce:
For User Document Writes - Only Allow Specific Increments:
You need to validate that coin changes are ONLY the exact reward amounts from your app. For example:

Game wins: +10, +25, +50 coins only
Ad rewards: +5 coins only
Spin rewards: +10, +15, +20, +25, +30, +50 coins only
Referral bonus: +50 coins only

The rule must check: (request.resource.data.coins - resource.data.coins) in [5, 10, 15, 20, 25, 30, 50] to ensure only these increments are allowed. Anything else gets rejected.
For Daily Limits - Enforce Date-Based Resets:
You need to check that watchedAdsToday can only be:

Incremented by 1 if the same day
Reset to 1 if it's a new day (detected by comparing timestamps)

The rule must compare request.time with resource.data.lastAdResetDate to detect day changes. If same day and watchedAdsToday >= 10, reject the write. If new day, allow setting it to 1 and updating the reset date.
For Withdrawals - Prevent Double-Spending:
When a user creates a withdrawal request, you need to ATOMICALLY:

Deduct coins from their user document
Create the withdrawal document
Check they have enough balance

This requires a TRANSACTION that your rules currently don't enforce. Your rules let users create withdrawal documents WITHOUT deducting coins, which means they can request payouts with fake balance.
For Referral Claims - One-Time Only:
The referredBy field must be:

Writable ONLY if currently null (first time)
Never changeable after set
Validated that the referral code exists in another user's document

Your current rules allow users to change referredBy whenever they want because you don't check the old value.
Why Your Validation Functions Are Useless
function validateUserDocument(data) {
  return data.size() > 0 &&
         data.keys().hasAll(['uid', 'email', 'displayName', 'coins', ...]);
}
This checks that fields EXIST but not that they contain VALID VALUES. It's like checking if someone brought a passport without verifying it's not a crayon drawing. You need validation like:

data.coins is number && data.coins >= 0 && data.coins <= 1000000
data.watchedAdsToday is number && data.watchedAdsToday >= 0 && data.watchedAdsToday <= 10
data.referralCode is string && data.referralCode.size() == 8

But even that's not enough because it doesn't prevent users from SETTING arbitrary values, only checks if they're reasonable. You need to check the DIFFERENCE between old and new values.
The Brutal Truth About Firestore Rules Limitations
Firestore Security Rules CANNOT fully protect your app from determined attackers because:

They can't validate business logic across multiple documents. If a user's game stats say they won 1000 games but earned 50,000 coins (should be max 50,000 at 50 per game), rules can't detect this discrepancy because they evaluate per-document.
They can't enforce transaction ordering. Rules can't guarantee that coin deduction happens before withdrawal creation, or that referral bonus is only given once per code.
They can't do complex calculations. You can't write "check if this user earned more than 500 coins in the last hour" in rules because you can't query historical data.
They can't prevent replay attacks. A user can intercept a legitimate write request and replay it 100 times. Rules can't detect this.

This is WHY Cloud Functions exist - to enforce business logic that rules can't handle. By refusing to use them, you're building a house of cards.
Your Only Path Forward Without Cloud Functions
Since you're broke and stubborn, here's the ONLY way to make this work:
Move ALL validation to the client app and accept that it's bypassable. Write Firestore rules that are PERMISSIVE (let users write what they claim) but create a DETAILED AUDIT TRAIL of every action. Then at month-end before paying out, manually review the audit trail using Firebase Console or a simple admin script.
Flag accounts that:

Earned more than 1000 coins in a single day (impossible with 10 ads × 5 coins + reasonable game wins)
Have withdrawal requests exceeding their total lifetime earnings
Have referral bonuses without corresponding referrer records
Show device ID changes (likely multiple accounts)

Reject their withdrawals with "Suspicious activity detected." Yes, legitimate users might get caught, but that's the cost of running cheap. Make it clear in your ToS that withdrawals are subject to fraud review.
Implement stricter rules that only allow increments with specific reasons:
Every write to the user document must include a lastActionType field (AD_WATCHED, GAME_WON, SPIN, REFERRAL) and validate that the coin increment matches the action type. For example:

If lastActionType: "AD_WATCHED", coins can only increment by 5
If lastActionType: "GAME_WON", coins can only increment by 10-50
If lastActionType: "SPIN", coins can only increment by 10-50

This doesn't prevent users from lying about the action type, but it creates a paper trail. In your audit, check if they claimed 1000 game wins in one hour (physically impossible).
Store everything in subcollections with server timestamps that users can't manipulate. Every coin-earning action writes to users/{uid}/actions/{actionId} with:

type: "GAME_WON" / "AD_WATCHED" / "SPIN"
amount: 50
timestamp: FieldValue.serverTimestamp() (client can't fake this)

At month-end, query this actions subcollection, sum the amounts, and compare to the user's claimed coin balance. If there's a discrepancy, reject the withdrawal.
The Rules You Need To Copy-Paste Right Now
I won't give you the full rules (you said no code) but here's what you MUST change immediately:

Remove the isAdmin() function - it's crashing your payout system and costing double reads. Hardcode your admin UID directly in the rules.
Add increment validation - check that request.resource.data.coins - resource.data.coins is in your allowed amounts list.
Add one-time referral enforcement - check that resource.data.referredBy == null && request.resource.data.referredBy != null (can only go from null to non-null, never change after).
Add daily limit date checking - compare request.time.toMillis() / 86400000 with resource.data.lastAdResetDate.toMillis() / 86400000 to detect day boundaries.
Delete the useless collections - referral_codes, referral_records, and root-level game_history serve no purpose and add confusion.
Add rate limiting - check that timestamp of new action is at least 60 seconds after last action timestamp to prevent spam (60 actions per hour max).

Your current rules are security theater. They look like they're protecting something but actually protect nothing. Fix them or prepare to go bankrupt paying fraudulent withdrawals.