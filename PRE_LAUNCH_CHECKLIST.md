# ✅ PRE-LAUNCH CHECKLIST

## Critical Setup (MUST DO BEFORE LAUNCH)

### Firestore Rules
- [ ] Replace `'ADMIN_UID_HERE'` in firestore.rules with your actual Firebase UID
  - Get from: Firebase Console → Authentication → Your email → Copy UID
  - Replace in: `firestore.rules` line ~14
  - Even though you won't use admin features, syntax requires a valid UID

- [ ] Deploy firestore.rules to production
  - Firebase Console → Firestore → Rules → Paste new rules → Publish

### User Creation
- [ ] Test signup with email/password
  - Verify new user gets fields: coins=0, totalSpins=3, watchedAdsToday=0
  - Check Firestore: users/{uid} has all required fields

- [ ] Test signup with Google Sign-In
  - Verify same fields created
  - Check referralCode generated correctly

- [ ] Test signup with referral code
  - User A creates account (gets referralCode)
  - User B signup with User A's code
  - Verify both get +50 coins
  - User B's referredBy is locked (can't change)

---

## Game Implementation

### Session Batching
- [ ] Update TicTacToe screen:
  - [ ] Call `startGameSession('tictactoe')` in initState
  - [ ] Call `recordGameResultInSession()` after each game
  - [ ] Call `flushGameSession()` in dispose + on shouldFlushSession
  - [ ] Verify only 2 writes for 10 games (check Firestore logs)

- [ ] Update Whack-A-Mole screen:
  - [ ] Same pattern as TicTacToe
  - [ ] Verify session flushes correctly

### Monthly Stats
- [ ] Verify document created at: `users/{uid}/monthly_stats/2025-11`
- [ ] Check fields populate correctly: gamesPlayed, gameWins, coinsEarned

### Audit Trail
- [ ] After playing games, verify: `users/{uid}/actions/{id}` created
- [ ] Check action has: type='GAME_SESSION_FLUSH', amount, timestamp, userId

---

## Coins & Rewards

### Ad Watching
- [ ] Watch ad → Coins increment by +5
- [ ] Watch 10 ads → All allowed
- [ ] Try to watch 11th ad → Error "Daily limit reached"
- [ ] Next day at midnight → Try watching ad → Should reset to 1, not 11

### Daily Streak
- [ ] Claim daily streak → Get 10 coins (day 1)
- [ ] Next day claim → Get 20 coins (day 2)
- [ ] Skip a day → Streak resets
- [ ] Verify coins appear in: `users/{uid}/actions` collection

### Spin & Win
- [ ] User has 3 spins on login
- [ ] Spin once → 2 spins remain
- [ ] Wait for next day → Spins reset to 3
- [ ] Verify spin rewards: 10, 15, 20, 25, 30, or 50 coins

### Coins Updates
- [ ] Verify NO direct SET operations on coins field
- [ ] All coin changes use FieldValue.increment()
- [ ] Simultaneous game+ad: both increments apply (no lost coins)

---

## Referral System

- [ ] New user without code:
  - [ ] referredBy is null
  - [ ] Can claim code anytime before first payout

- [ ] New user with code at signup:
  - [ ] referredBy set immediately
  - [ ] Both users get +50 coins
  - [ ] Can never claim another code

- [ ] Cannot claim own code:
  - [ ] Try to claim own referralCode → Error

- [ ] Referrer tracking:
  - [ ] Referrer's totalReferrals increments
  - [ ] Referrer gets +50 coins per referral
  - [ ] Audit trail shows referral transaction

---

## Withdrawals

- [ ] Minimum amount: 500 coins (not 100)
- [ ] Valid UPI format: `name@bank` (e.g., `supreet@okhdfcbank`)
- [ ] Valid Bank: 9-18 digit account number
- [ ] Create withdrawal:
  - [ ] Coins deducted immediately
  - [ ] Status = 'PENDING'
  - [ ] Withdrawal document created in Firestore
  - [ ] Audit trail created

- [ ] Cannot withdraw more than balance:
  - [ ] Try with 5000 coins but only have 1000 → Error

---

## Data Integrity

### Audit Trail
- [ ] Every coin action creates `users/{uid}/actions/{id}`
- [ ] Actions are immutable (can't be deleted/edited)
- [ ] Timestamp is server-generated (can't fake)

### Monthly Stats
- [ ] Queries all actions sum matches current balance
- [ ] No unexplained coin sources
- [ ] No discrepancies between claimed and actual actions

### Race Conditions
- [ ] Trigger simultaneous:
  - [ ] Game win: +50 coins
  - [ ] Ad watch: +5 coins
  - [ ] Both should apply → +55 total (not overwritten)

---

## Performance Optimization

### Write Reduction
- [ ] Before: 100 writes per 50 games
- [ ] After: 10 writes per 50 games (5x reduction)
- [ ] Check Firestore logs to verify

### Read Optimization
- [ ] Login (first time): 2 reads (user doc + monthly stats)
- [ ] Login (subsequent): 0 reads (cached data)
- [ ] Ad watch: 0 reads (metadata already loaded)

---

## Security Testing

### Coin Cheating Prevention
- [ ] Attacker tries: `coins: 999999` → REJECTED ❌
- [ ] Attacker tries: `coins: 100` (not in allowed list) → REJECTED ❌
- [ ] Valid write: `coins: +50` → ALLOWED ✅

### Ad Limit Bypass
- [ ] Attacker tries: `watchedAdsToday: 100` → REJECTED ❌
- [ ] After 10 ads, 11th fails → REJECTED ❌
- [ ] Next day resets automatically → ALLOWED ✅

### Referral Double-Claim
- [ ] Claim code A → ALLOWED ✅
- [ ] Try to claim code B → REJECTED ❌
- [ ] Try to reset to null → REJECTED ❌

### Account Takeover Prevention
- [ ] Attacker tries: `uid: "different_uid"` → REJECTED ❌
- [ ] Attacker tries: `email: "hacker@email.com"` → REJECTED ❌

---

## Error Handling

- [ ] All network errors show user-friendly messages
- [ ] No raw error codes exposed to user
- [ ] Retry logic on transient failures
- [ ] Offline fallback uses cached data

---

## Monitoring

### Firebase Console Checks
- [ ] Monitor Firestore quota usage (should be ~150K writes/month at 100 users)
- [ ] Monitor error rates (should be < 1%)
- [ ] Verify no unexpected collections created

### Fraud Detection
- [ ] Set monthly reminder to check actions collection
- [ ] Look for:
  - [ ] Users earning > 1000 coins in 1 day
  - [ ] Withdrawals > lifetime earnings
  - [ ] Impossible game counts
  - [ ] Multiple referral bonuses for same account

---

## Launch Readiness

Before announcing the app publicly:

- [ ] All tests passed above
- [ ] No errors in Firebase logs
- [ ] Coins display correctly
- [ ] Ads show and reward correctly
- [ ] Withdrawals create properly (manual approval in Console for now)

- [ ] Documentation prepared:
  - [ ] Privacy policy (includes audit trails)
  - [ ] Terms of service (fraud clause)
  - [ ] How to contact support

---

## Post-Launch Monitoring (First Week)

### Daily Checks
- [ ] No spike in write costs (should be linear with users)
- [ ] No fraud detected in audit trails
- [ ] Users can complete full flow: signup → play → withdraw

### First Month
- [ ] Aggregate statistics:
  - [ ] Average coins per user
  - [ ] Average playtime
  - [ ] Conversion to withdrawal
  - [ ] Fraud rate (should be < 1%)

### Cost Check
- [ ] Expected cost: ₹50-100/month at 100 users
- [ ] If exceeding: Check for bugs (unnecessary reads/writes)

---

## If Issues Found

### Problem: Write costs too high
- [ ] Check if session batching working (should see 2-3 writes per session)
- [ ] Check if games creating extra writes (rollback to batch if needed)
- [ ] Verify ads not creating duplicate writes

### Problem: Coins disappearing
- [ ] Check if increment operations being used (not SET)
- [ ] Verify no race conditions
- [ ] Check audit trail for missing actions

### Problem: Users can't withdraw
- [ ] Check withdrawal rules pass validation
- [ ] Verify coins actually deducted
- [ ] Check minimum amount is 500 (not 100)

### Problem: Referral bonuses not working
- [ ] Verify referredBy locked after first claim
- [ ] Check both users get +50 coins
- [ ] Verify audit trail created

---

## Success Metrics

✅ App launches and is stable
✅ Firestore costs remain under ₹100/month at 100 users
✅ Zero fraud detected in first month
✅ Users complete full gameplay-to-withdrawal flow
✅ Session batching reduces writes by 80%
✅ No race conditions causing lost coins
✅ Referral system working flawlessly

---

## Quick Reference: Critical Numbers

| Metric | Target |
|--------|--------|
| Coins per game win | 10-50 |
| Coins per ad watch | 5 |
| Coins per spin | 10-50 |
| Coins per referral | 50 each user |
| Ads per day limit | 10 |
| Spins per day | 3 |
| Min withdrawal | 500 |
| Max withdrawal | 100,000 |
| Monthly write cost (100 users) | ₹50-100 |
| Session batch size | 10 games |
| Auto-flush time | 5 minutes |

