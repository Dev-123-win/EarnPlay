# TODO: UI / UX / Logic / Ads / Backend Improvements

This file lists prioritized improvements across the app split by area. Use this as a checklist for follow-ups and assign owners/PRs for each.

**How to use**
- Each item is short and actionable. Start from the top (security & fraud) and work down.
- Items that require provider credentials or design assets are marked.

---

## Critical (High Priority)
- [ ] Harden Firestore rules for withdrawal reads/writes and worker-only sensitive fields.
- [ ] Audit and fix any non-atomic client Firestore writes; enforce `FieldValue.increment()` everywhere for coin updates.
- [ ] Add telemetry & alerts for unexpected Firestore read/write spikes and suspicious activity.

## UX / UI Improvements
- [ ] Referral: Display explicit time window (e.g., "Claim within 24 hours") and show clear claim status with reason.
- [ ] Referral: Prevent multiple attempts and show cooldown + reason on failure (server rate-limits).
- [ ] Withdrawal: Show immediate balance change AND payment processing timeline (Pending → Processing → Sent/Failed).
- [ ] Withdrawal: Add a clear Withdrawal History view (or worker API if Firestore rules block client reads).
- [ ] Ads: Show loading state and retry/backoff UI when ad isn't ready; display remaining daily ad count and reset countdown.
- [ ] Onboarding: Add privacy/consent UI with links to Terms & Privacy (no UMP integration requested).
- [ ] Add manual support/contact CTA in withdrawal screens with transaction id copy action.

### Per-screen suggested UI/UX improvements
- Login Screen (`lib/screens/auth/login_screen.dart`):
	- Show inline validation errors (already present) and add a small explanatory help text under email/password inputs.
	- Make the "Create Account" link visually distinct (bold + underline) and add a short hover/tap ripple.
	- After failed login, suggest retry flows and a "Forgot password" CTA (if not present).

- Register Screen (`lib/screens/auth/register_screen.dart`):
	- Show live password-strength hint and explain what "Strong" means.
	- Add a 24-hour referral disclaimers and show claim status after registration.
	- Make Terms link tappable and show modal with short summary + full link.

- Home Screen (`lib/screens/home_screen.dart`):
	- Surface today's progress (ads/spins/games) and show prominent CTA for high-value actions.
	- Provide an always-available coin balance card with quick Withdraw, History, and Share buttons.

- Watch Ads Screen (`lib/screens/watch_earn_screen.dart`):
	- Show explicit "Ad will award X coins" CTA and a loading UI while the SDK loads the ad.
	- Display remaining daily ad count, and a countdown to reset (local time/IST as app uses).
	- If verification fails, show clear next steps: "Try again" or "Contact support" with idempotency key.

- Spin & Win (`lib/screens/spin_win_screen.dart`):
	- Show "Spins reset at 04:30 AM" with a live countdown.
	- Indicate server-authoritative outcome if using server RNG (show "Verified by server" badge).
	- After spin, show clear buttons: "Claim" (no ad) and "Double via Ad" (shows expected final coins before pressing).

- Referral Screen (`lib/screens/referral_screen.dart`):
	- Show countdown until referral entry expires (24h) and the referrer's basic safe info on success.
	- When claim fails, show a one-line reason and a disabled cooldown timer (if server rate-limits).

- Withdrawal Screen (`lib/screens/withdrawal_screen.dart`):
	- Show transactional id immediately after request with copy-to-clipboard.
	- Show a status timeline per withdrawal (Pending → Processing → Sent/Failed) and allow users to tap for details.

- Profile (`lib/screens/profile_screen.dart`):
	- Add quick links to Referral, Withdrawal History, and Privacy/Terms.
	- Show last sync time and local cache status.

- Games (tictactoe, whack_mole):
	- Show brief modal before giving reward that the result will be synced at 22:00 IST (or immediately via server if supported).
	- Flush session on app background and show an indicator if flush failed.


## Reward Logic & Client-Server Contract (Firebase-only)
- [ ] Ensure all coin writes use atomic Firestore operations (use `FieldValue.increment()` and Firestore transactions where needed).
- [ ] Replace Worker-based verification flows with Firestore-backed verification patterns or Firebase Cloud Functions if server-side verification is required.
- [ ] Document Firestore schemas and document shapes for `spin`, `ad_reward`, and `batch_events` so the client parses responses exactly.
- [ ] Implement idempotency using Firestore documents (idempotency doc per event) or use Cloud Functions to perform server-authoritative writes.

## Ads Compliance & Performance
- [ ] Ensure debug builds use Google test ad unit IDs; production builds must use your real AdMob IDs (you confirmed you set them).
- [ ] Preload next ad after show/dismiss and keep exponential backoff on load failures (already implemented, verify retries cap).
- [ ] Enforce clear placement rules (banners away from interactive controls) in component guidelines.

## Backend (Firebase-focused)
- [ ] Implement a payout processing plan that uses Firestore and Cloud Functions or an external payout system asynchronously; avoid long-running client calls.
- [ ] Implement idempotent payout integration and webhook reconciliation; store provider reference IDs in `withdrawals` documents.
- [ ] Provide a secure, server-side endpoint (Cloud Function) for `withdrawal-history` if Firestore security rules block direct client reads.
- [ ] Use Firestore documents for short-lived ad challenges/idempotency markers (with TTL field + scheduled cleanup) if you prefer not to use Workers/KV.
- [ ] Add periodic archival (export) of action documents older than 30 days to GCS/BigQuery for cost control.


## Security & Process
- [ ] Perform a security review of service account permissions and Firestore rules; follow least-privilege.
- [ ] Implement rate-limiting/behavioral throttles in Cloud Functions or Firestore rules patterns to reduce abuse.
- [ ] Add audit logging for high-risk events: withdrawals, referral claims, large coin awards.

## Low Priority / Nice-to-have
- [ ] Show user-friendly reasons for common fail cases (e.g., "Daily ad limit reached", "Referral invalid or expired").
- [ ] Add UI toggles to disable ads (for accessibility or user preference) and persist choice.
- [ ] Add optional reward summaries (monthly) in user profile and an export option for support requests.
 - [ ] Add UI toggles to disable ads (for accessibility or user preference) and persist choice.
 - [ ] Add optional reward summaries (monthly) in user profile and an export option for support requests.

---

If you want, I can:
- scaffold Cloud Functions to replace worker endpoints (e.g., `withdrawal-history`, ad verification) using Firebase-native tooling; or
- implement focused per-screen UI fixes and PR-ready patches.

Tell me which items you'd like me to implement first and I'll start (I can begin with A) Cloud Functions scaffold, B) per-screen UI fixes, or C) audit and fix non-atomic Firestore writes).
