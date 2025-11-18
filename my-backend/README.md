# 🎮 EarnPlay API Worker (Phase 1: Ad Verification)

A **production-ready Cloudflare Worker** handling reward claims for the EarnPlay Flutter app. Implements atomic Firestore transactions for secure, cost-optimized coin rewards.

## 🎯 What's This?

This worker validates and processes ad watches, game wins, spin wheels, referrals, and withdrawals. For Phase 1, only **ad verification** is implemented.

**Key Features**:
- ✅ Atomic Firestore transactions (66% cost savings)
- ✅ Firebase token verification
- ✅ Daily limits with lazy reset (no scheduled jobs)
- ✅ Async audit logging
- ✅ Fraud prevention (timestamp validation)
- ✅ CORS support

## 📊 Architecture

```
Flutter App (iOS/Android)
        ↓ (Firebase ID Token + Request)
Cloudflare Worker (Ad Verification, etc.)
        ↓ (Atomic Transaction)
Firestore (Update coins, audit logs)
```

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Firebase project with Firestore
- Cloudflare account (free tier OK)

### Installation

```bash
# 1. Clone/download the project
cd my-backend

# 2. Install dependencies
npm install

# 3. Add Firebase service account to wrangler.jsonc
# See PHASE1_SETUP.md for detailed instructions

# 4. Run locally
npm run dev

# 5. Test with curl (in another terminal)
# See PHASE1_SETUP.md for testing commands
```

## 📝 API Endpoints

### POST /verify-ad
**Claim reward for watching an ad**

**Request**:
```bash
curl -X POST http://localhost:8787/verify-ad \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "adUnitId": "ca-app-pub-3940256099942544/5224354917",
    "timestamp": 1731945600000
  }'
```

**Success (200)**:
```json
{
  "success": true,
  "reward": 5,
  "newBalance": 105,
  "adsWatchedToday": 1
}
```

**Errors**:
- `400`: Missing fields, invalid timestamp, stale request
- `401`: Missing/invalid token
- `404`: User not found
- `429`: Daily limit exceeded (10/day)

## 📂 Project Structure

```
my-backend/
├── src/
│   ├── index.js              # Router entry point
│   ├── auth.js               # Firebase token verification
│   ├── endpoints/
│   │   └── ad.js             # Ad reward logic (Phase 1)
│   └── utils/
│       ├── firebase.js       # Admin SDK + transactions
│       ├── validation.js     # Request validation
│       └── constants.js      # Rewards, limits, etc.
├── wrangler.jsonc            # Worker configuration
├── package.json              # Dependencies
├── PHASE1_SETUP.md           # Detailed setup guide
├── PHASE1_REFERENCE.md       # API reference
└── start.bat / start.sh      # Quick start scripts
```

## 🔄 How the Ad Endpoint Works

1. **Request arrives** with Firebase ID token + ad details
2. **Token verified** by Firebase Admin SDK
3. **Atomic transaction** reads user data:
   - ✅ Validate timestamp (< 1 min old)
   - ✅ Check daily limit (< 10 ads/day)
   - ✅ Detect day change (lazy reset)
4. **Update Firestore atomically**:
   - `coins += 5`
   - `watchedAdsToday` incremented or reset
   - Timestamps updated
5. **Return response immediately** (user sees instant UI update)
6. **Async logging** happens in background via `ctx.waitUntil()`

## 💰 Cost Optimization

### Before (Separate Updates)
```javascript
// 3 separate writes
await userRef.update({coins: increment(5)});
await userRef.update({watchedAdsToday: increment(1)});
await userRef.update({lastAdResetDate: now});
// Cost: $0.000018 per ad claim
```

### After (Atomic Transaction)
```javascript
// 1 batched write
await db.runTransaction((tx) => {
  tx.update(userRef, {
    coins: increment(5),
    watchedAdsToday: increment(1),
    lastAdResetDate: now
  });
});
// Cost: $0.000006 per ad claim (66% savings!)
```

### Monthly Projection (1,000 DAU)
| Plan | Writes/Day | Writes/Month | Cost |
|------|-----------|--------------|------|
| Old | 3,000 | 90,000 | $0.36 |
| **New** | **1,000** | **30,000** | **$0.12** |
| **Savings** | | | **67%** |

## 🧪 Testing

### Local Testing
```bash
# Terminal 1: Start server
npm run dev

# Terminal 2: Get Firebase token (see PHASE1_SETUP.md)

# Terminal 3: Test endpoint
curl -X POST http://localhost:8787/verify-ad \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"adUnitId\":\"test\",\"timestamp\":$(date +%s)000}"
```

### Test Scenarios
1. **Normal claim** → 200 OK, coins increased
2. **Stale timestamp** → 400 Bad Request
3. **Daily limit** → 429 Too Many Requests
4. **Invalid token** → 401 Unauthorized
5. **Day changed** → 200 OK, counter reset

See **PHASE1_SETUP.md** for detailed test instructions.

## 🚀 Deployment

### To Cloudflare Workers

```bash
# 1. Login to Cloudflare
wrangler login

# 2. Deploy
wrangler deploy

# 3. Your worker is live!
# URL: https://earnplay-api.your-subdomain.workers.dev
```

### Update Flutter App
```dart
const String WORKER_URL = 'https://earnplay-api.your-subdomain.workers.dev';

final response = await http.post(
  Uri.parse('$WORKER_URL/verify-ad'),
  headers: {...},
  body: jsonEncode({...})
);
```

## 🔐 Security

- ✅ Firebase ID token verification on every request
- ✅ Timestamp validation (anti-replay attacks)
- ✅ Server-side date tracking (timezone-proof)
- ✅ Atomic transactions (prevent race conditions)
- ✅ Input validation on all fields
- ✅ Error messages don't leak internals

## 🔧 Development

### Add a new endpoint

1. Create `src/endpoints/newfeature.js`:
```javascript
export async function handleNewFeature(request, db, userId, ctx) {
  // Implement logic with atomic transactions
}
```

2. Import in `src/index.js`:
```javascript
import { handleNewFeature } from './endpoints/newfeature.js';
```

3. Add route:
```javascript
case '/new-feature':
  response = await handleNewFeature(request, db, userId, ctx);
  break;
```

### Format code
```bash
npm run format
```

### Check for errors
```bash
npm run lint
```

## 📚 Documentation

- **[PHASE1_SETUP.md](./PHASE1_SETUP.md)** - Step-by-step setup guide
- **[PHASE1_REFERENCE.md](./PHASE1_REFERENCE.md)** - Complete API reference
- **[cloudworkerplan.md](../cloudworkerplan.md)** - Architecture & planning

## ⚠️ Important Notes

### Firebase Config
- Must be added to `wrangler.jsonc` as a **single line** (no breaks)
- Keep private key intact with `\n` characters
- Never commit to git (add to `.gitignore`)

### Daily Limits
- Reset happens automatically on first request of new day (lazy evaluation)
- No scheduled Cloud Functions needed
- Works across timezones (uses server timestamp)

### Audit Logs
- Fire-and-forget pattern: user gets instant response, logs added async
- If worker crashes, logs may not complete (acceptable trade-off)
- Located in `users/{uid}/actions` subcollection

## 🐛 Troubleshooting

**"Firebase initialization failed"**
→ Check FIREBASE_CONFIG JSON is on single line

**"Token verification failed"**
→ Get fresh token, ensure service account has Editor role

**"User not found"**
→ Create user document in Firestore with required fields

**"Daily limit immediately exceeded"**
→ Normal if testing same day; auto-resets tomorrow or manually reset `watchedAdsToday`

**Worker crashes locally**
→ `npm install` fresh, try `npm run dev` again

See **PHASE1_SETUP.md** for detailed troubleshooting.

## 📞 Support

- Documentation: See `PHASE1_SETUP.md`
- Issues: Check Firebase service account permissions
- Logs: `wrangler tail` for deployed worker

## 🎯 Next Phases

- **Phase 2**: Game verification (same atomic transaction pattern)
- **Phase 3**: Spin wheel & streak claims
- **Phase 4**: Withdrawal & referral (multi-document transactions)

## 📄 License

EarnPlay © 2024

---

**Ready to deploy? Follow [PHASE1_SETUP.md](./PHASE1_SETUP.md)! 🚀**
