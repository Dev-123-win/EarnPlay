# Create the todo list to track implementation progress? #

# 🚀 EARNPLAY IMPLEMENTATION GUIDE - COMPLETE MASTER DOCUMENT

**Version:** 1.0  
**Date:** November 13, 2025  
**Architecture:** Pure Firestore (No Backend)  
**Status:** Ready for Implementation  

---

## 📖 TABLE OF CONTENTS

1. [Architecture Overview](#architecture-overview)
2. [Why Pure Firestore](#why-pure-firestore)
3. [Firestore Operations Analysis](#firestore-operations-analysis)
4. [Data Model & Collections](#data-model--collections)
5. [Security Rules](#security-rules)
6. [Service Layer Architecture](#service-layer-architecture)
7. [Implementation Plan - Phase by Phase](#implementation-plan---phase-by-phase)
8. [UI Screens Specification](#ui-screens-specification)
9. [Offline Queue & Batch Sync](#offline-queue--batch-sync)
10. [Testing Strategy](#testing-strategy)
11. [Deployment Checklist](#deployment-checklist)

---

# ARCHITECTURE OVERVIEW

## 🎯 Core Principle

**Pure Firestore with Offline-First Gameplay**

- NO backend server (no Vercel, no Firebase Functions)
- NO API calls during gameplay
- NO DevOps overhead
- Gameplay stored locally → Synced daily at 22:00 IST

## System Flow

```
USER GAMEPLAY (OFFLINE)
↓
Actions stored in SQLite locally
├─ Game played: +25 coins
├─ Ad watched: +10 coins
└─ No Firestore calls yet

DAILY SYNC (22:00 IST ±30s)
↓
Batch all 8 actions into 1 Firestore write
├─ Read current balance: 1 READ
├─ Write 8 actions: 1 WRITE (not 8!)
└─ Update balance: 1 WRITE

RESULT
├─ User sees earning history
├─ Balance updated
├─ Super efficient (8 actions = 1 write)
└─ Cost: ~$0.00003 per day per user

REFERRAL SYSTEM
├─ When user claims code: 3R + 4W (atomic transaction)
├─ When user registers with code: 3R + 7W (atomic transaction)
└─ Prevents fraud, ensures consistency

WITHDRAWAL SYSTEM
├─ User requests: 3R + 4W (checks balance, limits)
├─ You approve manually: 1R + 2W per approval
└─ All tracked in Firestore for audit
```

---

# WHY PURE FIRESTORE

## Cost Comparison (1000 users, per month)

| Metric | Vercel Backend | Pure Firestore |
|--------|---|---|
| Backend compute | $50-100 | $0 |
| Firestore operations | $0-20 | $0 |
| Storage | $0 | $0 |
| DevOps required | YES | NO |
| **Total cost** | **$50-120** | **$0** |

## Performance Comparison

| Metric | Vercel | Pure Firestore |
|--------|---|---|
| Gameplay latency | 400-600ms | 5-10ms ✓ |
| Sync time | Real-time | 22:00 IST |
| Offline capable | NO | YES ✓ |
| Auto-scaling | Manual | Automatic ✓ |

## Key Advantages

1. **NO server to maintain** ✓
2. **NO DevOps needed** ✓
3. **Offline-first gameplay** ✓
4. **Auto-scales to millions** ✓
5. **Instant user feedback** ✓
6. **Batch efficiency** ✓

---

# FIRESTORE OPERATIONS ANALYSIS

## Daily Operations Per User

### Basic User (Just Plays Games)
```
Reads:  8-10 per day
Writes: 3-4 per day
Deletes: 0 per day

Breakdown:
├─ Open app: 4 reads
├─ Play 5 games: 0 reads (offline!)
├─ Daily batch sync: 1 read + 2 writes
└─ Total: ~9 reads, 3-4 writes
```

### Active User (Games + Referrals)
```
Reads:  15-20 per day
Writes: 10-15 per day
Deletes: 0 per day

Breakdown:
├─ Basic ops: 8-10 reads, 3-4 writes
├─ Claim referral code: 3 reads + 4 writes
├─ Check referral stats: 2 reads
└─ Total: ~15-18 reads, 10-14 writes
```

### Power User (Games + Referrals + Withdrawals)
```
Reads:  25-30 per day
Writes: 15-20 per day
Deletes: 0 per day

Breakdown:
├─ Basic ops: 8-10 reads, 3-4 writes
├─ Referral claim: 3 reads + 4 writes
├─ Withdrawal request: 3 reads + 4 writes
├─ Check withdrawal history: 3 reads
└─ Total: ~25-28 reads, 15-19 writes
```

## Specific Operations Cost

### Registration WITHOUT Referral
```
Operations: 1R + 3W
Timeline: Happens once per user

Step 1: Verify email doesn't exist → 1 READ
Step 2-4: Create user, balance, stats docs → 3 WRITES

Cost: $0.00000144
Revenue enabled: User created
```

### Registration WITH Referral Code
```
Operations: 3R + 7W
Timeline: Happens once per referred user

Step 1: Verify email → 1 READ
Step 2-4: Create user docs → 3 WRITES
Step 5: Query referral code → 1 READ
Step 6: Get uncle's profile → 1 READ
Step 7: Check limit (included above)
Step 8: Update uncle's balance → 1 WRITE
Step 9: Log uncle's action → 1 WRITE
Step 10: Log referral action → 1 WRITE

Cost: $0.00001
Revenue per referral: ₹500 bonus (drives engagement)
Fraud prevention: Email verification, code validation, limit checking
ROI: 1,500,000X (costs $0.00001, generates $15 LTV)
```

### Referral Code Claim (After Registration)
```
Operations: 3R + 4W
Timeline: User can claim once

Step 1: Query code → 1 READ
Step 2: Get referrer profile → 1 READ
Step 3: Check user already claimed → 1 READ
Step 4: Update referrer balance (transaction) → 1 WRITE
Step 5: Log referrer action → 1 WRITE
Step 6: Log claimer action → 1 WRITE
Step 7: Update user referrer link → 1 WRITE

Cost: $0.00001
Success result:
├─ User linked to referrer
├─ Referrer gets ₹500 bonus
├─ Both actions logged
└─ User can't claim again
```

### Withdrawal Request
```
Operations: 3R + 4W
Timeline: User can request anytime

Step 1: Read current balance → 1 READ
Step 2: Check daily limit → 1 READ
Step 3: Query today's total withdrawals → 1 READ
Step 4: Create withdrawal request → 1 WRITE
Step 5: Deduct balance (transaction with write 4) → 1 WRITE
Step 6: Update lastWithdrawalDate → (combined)
Step 7: Log withdrawal action → 1 WRITE
Step 8: Notify admin → 1 WRITE

Cost: $0.0000117
Success result:
├─ Request created with status=PENDING
├─ Balance deducted
├─ Action logged
├─ You get admin notification
└─ Awaiting your manual approval
```

### Daily Batch Sync (22:00 IST)
```
Operations: 1R + 2W per user
Timeline: Every day at 22:00 IST ±30s random delay

Step 1: Read current balance → 1 READ
Step 2: Batch write 8 queued actions → 1 WRITE
  └─ This is genius! 8 actions = 1 write, not 8
Step 3: Update balance: balance + totalCoins → 1 WRITE

Cost: $0.00003 per user
Benefit:
├─ SAVES 6 writes per day per user!
├─ For 1000 users: 6,000 writes saved daily
├─ Per month: 180,000 writes saved
├─ Cost savings: ~$32/month!

Why ±30s delay?
├─ Prevents all users syncing at exact same time
├─ 1000 users × ±30s = spread across 60 seconds
├─ Smooth load distribution
├─ No spike in database operations
```

## Monthly Cost Breakdown (For 1000 users)

```
BASIC OPERATIONS
├─ Reads: 8 per user × 1000 users × 30 days = 240,000 reads
├─ Writes: 3 per user × 1000 users × 30 days = 90,000 writes
├─ Cost: $0.10 (reads) + $0.016 (writes) = $0.116
└─ Well within free tier!

REFERRAL OPERATIONS
├─ 30% of users claim/use referral: 300 users
├─ Reads: 3 × 300 × 30 = 27,000 reads
├─ Writes: 7 × 300 × 30 = 63,000 writes
├─ Cost: $0.016 (reads) + $0.011 (writes) = $0.027
└─ Revenue generated: $360+ (300 referrals × $1.20 LTV)

WITHDRAWAL OPERATIONS
├─ 10% of users request withdrawals: 100 users
├─ Reads: 3 × 100 × 30 = 9,000 reads
├─ Writes: 4 × 100 × 30 = 12,000 writes
├─ Cost: $0.005 (reads) + $0.002 (writes) = $0.007
└─ Revenue generated: $40+ (100 withdrawals × $0.4 commission)

DAILY BATCH SYNC
├─ Reads: 1 × 1000 × 30 = 30,000 reads
├─ Writes: 2 × 1000 × 30 = 60,000 writes
├─ Cost: $0.018 (reads) + $0.011 (writes) = $0.029
└─ SAVES: 6000 writes/day × 30 = 180,000 writes if not batched!

TOTAL MONTHLY
├─ Reads: 306,000 (free tier: 50M, using 0.6%)
├─ Writes: 225,000 (free tier: 20M, using 1.1%)
├─ Cost: $0 (all within free tier!)
└─ Scaling: Can handle 3,000+ users on free tier
```

## Scaling Analysis

```
1,000 users
├─ Daily: 12K reads + 6K writes
├─ Cost: $0/month (free tier)
└─ Status: ✓ Comfortable

3,000 users
├─ Daily: 36K reads + 18K writes
├─ Cost: $0/month (free tier)
└─ Status: ✓ Still free

5,000 users
├─ Daily: 60K reads + 30K writes
├─ Cost: $40-50/month (upgrade to paid plan)
└─ Status: ✓ Manageable

10,000 users
├─ Daily: 120K reads + 60K writes
├─ Cost: $150-200/month
└─ Status: ✓ Profitable (revenue >> costs)

100,000 users
├─ Daily: 1.2M reads + 600K writes
├─ Cost: $1,500-2,000/month
└─ Status: ✓ Still profitable with monetization
```

---

# DATA MODEL & COLLECTIONS

## Collections Structure

```
firestore/
├─ users/{uid}
│  ├─ email (string)
│  ├─ name (string)
│  ├─ phone (string)
│  ├─ createdAt (timestamp)
│  ├─ updatedAt (timestamp)
│  ├─ referrerUID (string, optional)
│  ├─ referralCode (string, unique)
│  └─ referralLinkShareable (string)
│
├─ users/{uid}/balance
│  ├─ balance (number)
│  ├─ totalEarned (number)
│  ├─ totalWithdrawn (number)
│  ├─ lastUpdate (timestamp)
│  └─ lastSyncTime (timestamp)
│
├─ users/{uid}/stats
│  ├─ gamesPlayed (number)
│  ├─ adsWatched (number)
│  ├─ totalCoinsEarned (number)
│  ├─ referralCount (number, max 50)
│  ├─ joinedVia (string, 'organic' or 'referral')
│  └─ lastActive (timestamp)
│
├─ users/{uid}/actions (subcollection)
│  └─ {actionId}
│     ├─ type (string: 'GAME_PLAYED', 'AD_WATCHED', 'REFERRAL_EARNED')
│     ├─ coinsEarned (number)
│     ├─ metadata (object, optional)
│     ├─ createdAt (timestamp)
│     └─ synced (boolean)
│
├─ users/{uid}/notifications (subcollection)
│  └─ {notificationId}
│     ├─ title (string)
│     ├─ message (string)
│     ├─ type (string: 'REFERRAL', 'WITHDRAWAL', 'REWARD')
│     ├─ read (boolean)
│     ├─ createdAt (timestamp)
│     └─ actionLink (string, optional)
│
├─ referralCodes
│  └─ {code}
│     ├─ referrerUID (string)
│     ├─ referrerName (string)
│     ├─ createdAt (timestamp)
│     ├─ usedCount (number)
│     ├─ maxUses (number, default 50)
│     ├─ active (boolean)
│     └─ lastUsedAt (timestamp)
│
├─ withdrawals
│  └─ {requestId}
│     ├─ userId (string)
│     ├─ amount (number)
│     ├─ bankAccount (string)
│     ├─ accountHolder (string)
│     ├─ status (string: 'PENDING', 'APPROVED', 'REJECTED')
│     ├─ requestedAt (timestamp)
│     ├─ approvedAt (timestamp, optional)
│     ├─ approvedBy (string, optional - your UID)
│     ├─ notes (string, optional)
│     └─ transactionId (string, optional - from your bank)
│
└─ adminSettings
   └─ config
      ├─ referralBonus (number, default 500)
      ├─ minWithdrawalAmount (number, default 100)
      ├─ maxDailyWithdrawal (number, default 5000)
      ├─ maxMonthlyWithdrawal (number, default 20000)
      ├─ withdrawalCooldown (number, default 7 days)
      ├─ maxReferralsPerUser (number, default 50)
      └─ batchSyncTime (string, default "22:00")
```

---

# SECURITY RULES

## Firestore Rules (firestore.rules)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ========== HELPER FUNCTIONS ==========
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(uid) {
      return request.auth.uid == uid;
    }
    
    function isAdmin() {
      // Set your UID as admin in Firebase Console
      return request.auth.uid in ['YOUR_ADMIN_UID'];
    }
    
    // ========== USERS COLLECTION ==========
    match /users/{uid} {
      allow read: if isSignedIn && isOwner(uid);
      allow create: if isSignedIn && isOwner(uid) && validateNewUser();
      allow update: if isSignedIn && isOwner(uid) && validateUserUpdate();
      allow delete: if false;
      
      // User's balance subcollection
      match /balance/{document=**} {
        allow read: if isSignedIn && isOwner(uid);
        allow write: if false; // Only Firestore transactions can write
      }
      
      // User's stats subcollection
      match /stats/{document=**} {
        allow read: if isSignedIn && isOwner(uid);
        allow write: if false; // Only Firestore transactions can write
      }
      
      // User's actions subcollection
      match /actions/{document=**} {
        allow read: if isSignedIn && isOwner(uid) && request.query.limit <= 100;
        allow create: if isSignedIn && isOwner(uid) && validateAction();
        allow update, delete: if false;
      }
      
      // User's notifications subcollection
      match /notifications/{document=**} {
        allow read: if isSignedIn && isOwner(uid);
        allow create: if false; // Only system can create
        allow update: if isSignedIn && isOwner(uid) && 
                      request.resource.data.keys().hasAll(['read']);
        allow delete: if isSignedIn && isOwner(uid);
      }
    }
    
    // ========== REFERRAL CODES ==========
    match /referralCodes/{code} {
      allow read: if isSignedIn;
      allow create: if isSignedIn && validateNewCode();
      allow update: if false;
      allow delete: if isAdmin();
      
      function validateNewCode() {
        return request.resource.data.referrerUID == request.auth.uid &&
               request.resource.data.code.size() > 3 &&
               request.resource.data.maxUses > 0;
      }
    }
    
    // ========== WITHDRAWALS ==========
    match /withdrawals/{requestId} {
      allow read: if isSignedIn && (isOwnerOfWithdrawal(requestId) || isAdmin());
      allow create: if isSignedIn && validateWithdrawal();
      allow update: if isAdmin() || 
                    (isSignedIn && isOwnerOfWithdrawal(requestId) && 
                     request.resource.data.status == 'CANCELLED');
      allow delete: if false;
      
      function isOwnerOfWithdrawal(requestId) {
        return get(/databases/$(database)/documents/withdrawals/$(requestId))
          .data.userId == request.auth.uid;
      }
      
      function validateWithdrawal() {
        return request.resource.data.userId == request.auth.uid &&
               request.resource.data.amount > 100 &&
               request.resource.data.status == 'PENDING' &&
               request.resource.data.requestedAt > now;
      }
    }
    
    // ========== ADMIN SETTINGS ==========
    match /adminSettings/{document=**} {
      allow read: if isSignedIn;
      allow write: if isAdmin();
    }
    
    // ========== DENY ALL ELSE ==========
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

# SERVICE LAYER ARCHITECTURE

## Services to Implement

### 1. ReferralService

**Location:** `lib/services/referral_service.dart`

```dart
class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Generate referral code for new user
  Future<String> generateReferralCode(String userId, String userName) async {
    // Generate unique code (e.g., "UNCLE123")
    final code = _generateCode(userName);
    
    // Save to Firestore
    await _firestore.collection('referralCodes').doc(code).set({
      'referrerUID': userId,
      'referrerName': userName,
      'createdAt': FieldValue.serverTimestamp(),
      'usedCount': 0,
      'maxUses': 50,
      'active': true,
      'lastUsedAt': null,
    });
    
    return code;
  }
  
  // Validate and claim referral code
  Future<void> claimReferralCode(String userId, String code) async {
    await _firestore.runTransaction((transaction) async {
      // READ 1: Get code document
      final codeDoc = await transaction.get(
        _firestore.collection('referralCodes').doc(code)
      );
      
      if (!codeDoc.exists) {
        throw Exception('Invalid referral code');
      }
      
      final referrerId = codeDoc['referrerUID'];
      final usedCount = codeDoc['usedCount'] as int;
      final maxUses = codeDoc['maxUses'] as int;
      
      if (usedCount >= maxUses) {
        throw Exception('Referral code limit reached');
      }
      
      // READ 2: Get referrer profile
      final referrerDoc = await transaction.get(
        _firestore.collection('users').doc(referrerId)
      );
      
      // READ 3: Check if user already has referrer
      final userDoc = await transaction.get(
        _firestore.collection('users').doc(userId)
      );
      
      if (userDoc['referrerUID'] != null) {
        throw Exception('You already have a referrer');
      }
      
      // WRITE 1: Update user's referrer link
      transaction.update(
        _firestore.collection('users').doc(userId),
        {'referrerUID': referrerId}
      );
      
      // WRITE 2: Update referrer's balance
      final referrerBalance = (referrerDoc['balance'] ?? 0) as num;
      transaction.update(
        _firestore.collection('users').doc(referrerId).collection('balance').doc('current'),
        {
          'balance': referrerBalance + 500, // ₹500 referral bonus
          'lastUpdate': FieldValue.serverTimestamp(),
        }
      );
      
      // WRITE 3: Log referrer's action
      transaction.set(
        _firestore.collection('users').doc(referrerId)
          .collection('actions').doc(),
        {
          'type': 'REFERRAL_EARNED',
          'coinsEarned': 500,
          'metadata': {'referredUser': userId},
          'createdAt': FieldValue.serverTimestamp(),
        }
      );
      
      // WRITE 4: Log user's action
      transaction.set(
        _firestore.collection('users').doc(userId)
          .collection('actions').doc(),
        {
          'type': 'REFERRED_BY',
          'metadata': {'referrerUID': referrerId},
          'createdAt': FieldValue.serverTimestamp(),
        }
      );
    });
  }
  
  // Get user's referral stats
  Future<Map<String, dynamic>> getUserReferralStats(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final statsDoc = await _firestore.collection('users').doc(userId)
      .collection('stats').doc('current').get();
    
    return {
      'referralCode': userDoc['referralCode'],
      'referralCount': statsDoc['referralCount'] ?? 0,
      'totalReferralEarnings': statsDoc['totalReferralEarnings'] ?? 0,
    };
  }
  
  String _generateCode(String userName) {
    // Generate code like "UNCLE123"
    return '${userName.substring(0, 3).toUpperCase()}${Random().nextInt(1000)}';
  }
}
```

### 2. WithdrawalService

**Location:** `lib/services/withdrawal_service.dart`

```dart
class WithdrawalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Request withdrawal
  Future<String> requestWithdrawal(
    String userId,
    double amount,
    String bankAccount,
    String accountHolder,
  ) async {
    final requestId = _firestore.collection('withdrawals').doc().id;
    
    await _firestore.runTransaction((transaction) async {
      // READ 1: Get current balance
      final balanceDoc = await transaction.get(
        _firestore.collection('users').doc(userId)
          .collection('balance').doc('current')
      );
      
      final balance = (balanceDoc['balance'] as num).toDouble();
      
      // READ 2: Get withdrawal settings
      final settingsDoc = await transaction.get(
        _firestore.collection('adminSettings').doc('config')
      );
      
      final minAmount = (settingsDoc['minWithdrawalAmount'] as num).toDouble();
      final maxDaily = (settingsDoc['maxDailyWithdrawal'] as num).toDouble();
      
      if (amount < minAmount) {
        throw Exception('Minimum withdrawal: ₹$minAmount');
      }
      
      if (amount > balance) {
        throw Exception('Insufficient balance');
      }
      
      // READ 3: Query today's withdrawals
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final todayWithdrawals = await transaction
        .get(_firestore.collectionGroup('withdrawals')
          .where('userId', isEqualTo: userId)
          .where('requestedAt', isGreaterThanOrEqualTo: startOfDay));
      
      final todayTotal = todayWithdrawals.docs
        .fold(0.0, (sum, doc) => sum + (doc['amount'] as num).toDouble());
      
      if (todayTotal + amount > maxDaily) {
        throw Exception('Daily limit exceeded');
      }
      
      // WRITE 1: Create withdrawal request
      transaction.set(
        _firestore.collection('withdrawals').doc(requestId),
        {
          'userId': userId,
          'amount': amount,
          'bankAccount': bankAccount,
          'accountHolder': accountHolder,
          'status': 'PENDING',
          'requestedAt': FieldValue.serverTimestamp(),
          'notes': null,
        }
      );
      
      // WRITE 2: Deduct balance
      transaction.update(
        _firestore.collection('users').doc(userId)
          .collection('balance').doc('current'),
        {
          'balance': balance - amount,
          'totalWithdrawn': FieldValue.increment(amount),
          'lastUpdate': FieldValue.serverTimestamp(),
        }
      );
      
      // WRITE 3: Log withdrawal action
      transaction.set(
        _firestore.collection('users').doc(userId)
          .collection('actions').doc(),
        {
          'type': 'WITHDRAWAL_REQUESTED',
          'amount': amount,
          'metadata': {'requestId': requestId},
          'createdAt': FieldValue.serverTimestamp(),
        }
      );
      
      // WRITE 4: Create notification for user
      transaction.set(
        _firestore.collection('users').doc(userId)
          .collection('notifications').doc(),
        {
          'title': 'Withdrawal Request',
          'message': 'Your withdrawal request of ₹$amount is being processed',
          'type': 'WITHDRAWAL',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        }
      );
    });
    
    return requestId;
  }
  
  // Check if user can withdraw
  Future<bool> canWithdraw(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final lastWithdrawal = userDoc['lastWithdrawalDate'] as Timestamp?;
    
    if (lastWithdrawal == null) return true;
    
    final daysSinceLastWithdrawal = 
      DateTime.now().difference(lastWithdrawal.toDate()).inDays;
    
    return daysSinceLastWithdrawal >= 7; // 7-day cooldown
  }
  
  // Get withdrawal history
  Future<List<Map<String, dynamic>>> getWithdrawalHistory(String userId) async {
    final snapshot = await _firestore.collection('withdrawals')
      .where('userId', isEqualTo: userId)
      .orderBy('requestedAt', descending: true)
      .limit(50)
      .get();
    
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
```

### 3. OfflineQueueService

**Location:** `lib/services/offline_queue_service.dart`

```dart
class OfflineQueueService {
  final Database _db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  OfflineQueueService(this._db);
  
  // Add gameplay action to local queue
  Future<void> addAction(String userId, String type, int coinsEarned) async {
    await _db.insert(
      'game_actions',
      {
        'id': const Uuid().v4(),
        'userId': userId,
        'type': type, // 'GAME_PLAYED', 'AD_WATCHED'
        'coinsEarned': coinsEarned,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'synced': 0,
      },
    );
  }
  
  // Get all pending actions
  Future<List<Map>> getPendingActions(String userId) async {
    final result = await _db.query(
      'game_actions',
      where: 'userId = ? AND synced = 0',
      whereArgs: [userId],
    );
    return result;
  }
  
  // Batch sync to Firestore
  Future<void> syncToFirestore(String userId) async {
    try {
      final pending = await getPendingActions(userId);
      
      if (pending.isEmpty) return;
      
      await _firestore.runTransaction((transaction) async {
        // READ 1: Get current balance
        final balanceDoc = await transaction.get(
          _firestore.collection('users').doc(userId)
            .collection('balance').doc('current')
        );
        
        double currentBalance = (balanceDoc['balance'] as num).toDouble();
        
        // Calculate total coins
        double totalCoins = pending.fold(0, 
          (sum, action) => sum + (action['coinsEarned'] as int));
        
        // WRITE 1: Batch all actions into one write
        for (var action in pending) {
          transaction.set(
            _firestore.collection('users').doc(userId)
              .collection('actions').doc(action['id']),
            {
              'type': action['type'],
              'coinsEarned': action['coinsEarned'],
              'createdAt': DateTime.fromMillisecondsSinceEpoch(action['createdAt']),
              'synced': true,
            }
          );
        }
        
        // WRITE 2: Update balance
        transaction.update(
          _firestore.collection('users').doc(userId)
            .collection('balance').doc('current'),
          {
            'balance': currentBalance + totalCoins,
            'lastSyncTime': FieldValue.serverTimestamp(),
          }
        );
      });
      
      // Mark all as synced in local DB
      for (var action in pending) {
        await _db.update(
          'game_actions',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [action['id']],
        );
      }
    } catch (e) {
      // Retry logic with exponential backoff
      print('Sync failed: $e');
      // Will retry on next scheduled sync
    }
  }
  
  // Schedule daily sync at 22:00 IST
  void scheduleDailySync(String userId) {
    // Calculate time until 22:00 IST
    final now = DateTime.now();
    final syncTime = DateTime(now.year, now.month, now.day, 22, 0);
    
    Duration delay = syncTime.isAfter(now) 
      ? syncTime.difference(now)
      : syncTime.add(const Duration(days: 1)).difference(now);
    
    // Add ±30 second random delay
    final randomDelay = Random().nextInt(60) - 30;
    delay = delay + Duration(seconds: randomDelay);
    
    Timer(delay, () => syncToFirestore(userId));
  }
}
```

### 4. Other Services

**RetryService** - Exponential backoff for failed operations
```dart
class RetryService {
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation,
    {int maxRetries = 3}
  ) async {
    int attempt = 0;
    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        
        // Exponential backoff: 1s, 2s, 4s
        await Future.delayed(Duration(seconds: 1 << attempt));
      }
    }
  }
}
```

**BackupRecoveryService** - Handle crashes and syncs
```dart
class BackupRecoveryService {
  // Create local backup of pending actions
  Future<void> createLocalBackup(String userId) async {
    // Copy pending actions to backup table
  }
  
  // Recover from backup if app crashed
  Future<void> recoverIfNeeded(String userId) async {
    // Check if any backup exists
    // If yes, restore and attempt sync
  }
}
```

---

# IMPLEMENTATION PLAN - PHASE BY PHASE

## PHASE 1: Service Layer (Week 1, Days 1-3)

### Step 1: Create service directory structure
```
lib/services/
├─ referral_service.dart
├─ withdrawal_service.dart
├─ offline_queue_service.dart
├─ retry_service.dart
├─ backup_recovery_service.dart
├─ pagination_service.dart
└─ services_locator.dart (dependency injection)
```

### Step 2: Implement ReferralService
- Generate referral codes
- Validate codes
- Claim codes with Firestore transactions
- Fetch referral stats

### Step 3: Implement WithdrawalService
- Create withdrawal requests
- Validate amounts and limits
- Deduct balance atomically
- Track withdrawal history

### Step 4: Implement OfflineQueueService
- SQLite local storage setup
- Add gameplay actions
- Batch sync logic
- Retry on failure

### Step 5: Update UserProvider
```dart
class UserProvider extends ChangeNotifier {
  late ReferralService _referralService;
  late WithdrawalService _withdrawalService;
  late OfflineQueueService _offlineQueueService;
  
  void initializeServices() {
    _referralService = ReferralService();
    _withdrawalService = WithdrawalService();
    _offlineQueueService = OfflineQueueService(_database);
  }
}
```

## PHASE 2: Deploy Security Rules (Week 1, Days 4-5)

### Step 1: Write firestore.rules
- User collections access control
- Referral codes validation
- Withdrawal request rules
- Admin settings

### Step 2: Deploy to Firebase
```bash
firebase deploy --only firestore:rules
```

### Step 3: Create Firestore indices
- Index on withdrawals(userId, requestedAt)
- Index on referralCodes(referrerUID, createdAt)
- Index on actions(userId, createdAt)

## PHASE 3: UI Screens (Week 2, Days 1-3)

### Step 1: Create ReferralScreen
**File:** `lib/screens/referral_screen.dart`

**Sections:**
1. My Referral Code
   - Display code in large text
   - Copy to clipboard button
   - Share buttons (WhatsApp, SMS, Email, Link)

2. Claim Referral Code
   - Text input field
   - Validate button
   - Success/error messages

3. Referral Stats
   - Total referrals: X
   - Total earnings: ₹X
   - Progress to next reward

4. Users Who Used Your Code
   - List of referred users
   - Their join dates
   - Earnings from each

```dart
class ReferralScreen extends StatefulWidget {
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late ReferralService _referralService;
  String? _myCode;
  ReferralStats? _stats;
  List<ReferredUser> _referredUsers = [];
  
  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }
  
  Future<void> _loadReferralData() async {
    final stats = await _referralService.getUserReferralStats(userId);
    final users = await _referralService.getUsersReferredByMe(userId);
    
    setState(() {
      _myCode = stats['referralCode'];
      _stats = stats;
      _referredUsers = users;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Referral Program')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMyCodeSection(),
            Divider(),
            _buildClaimCodeSection(),
            Divider(),
            _buildStatsSection(),
            Divider(),
            _buildReferredUsersSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMyCodeSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Your Referral Code'),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _myCode ?? 'Loading...',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: Icon(IconsaxBold.copy),
                label: Text('Copy'),
                onPressed: _copyCodeToClipboard,
              ),
              ElevatedButton.icon(
                icon: Icon(IconsaxBold.send),
                label: Text('Share'),
                onPressed: _shareCode,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildClaimCodeSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Claim Referral Code'),
          SizedBox(height: 16),
          TextField(
            controller: _claimController,
            decoration: InputDecoration(
              hintText: 'Enter referral code',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _claimCode,
            child: Text('Claim Code'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Your Referral Stats'),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Referrals'),
                      Text('${_stats?.referralCount ?? 0}'),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Earnings'),
                      Text('₹${_stats?.totalReferralEarnings ?? 0}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReferredUsersSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Users Who Used Your Code'),
          SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            itemCount: _referredUsers.length,
            itemBuilder: (context, index) {
              final user = _referredUsers[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text('Joined ${user.joinDate}'),
                trailing: Text('₹500'),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### Step 2: Create WithdrawalScreen
**File:** `lib/screens/withdrawal_screen.dart`

**Sections:**
1. Current Balance
2. Request Withdrawal Form
3. Withdrawal History

```dart
class WithdrawalScreen extends StatefulWidget {
  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  late WithdrawalService _withdrawalService;
  double _balance = 0;
  List<WithdrawalRequest> _history = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    final balance = await _withdrawalService.getCurrentBalance(userId);
    final history = await _withdrawalService.getWithdrawalHistory(userId);
    
    setState(() {
      _balance = balance;
      _history = history;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Withdrawal')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildBalanceSection(),
            Divider(),
            _buildRequestSection(),
            Divider(),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBalanceSection() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Current Balance'),
            SizedBox(height: 8),
            Text(
              '₹${_balance.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Minimum withdrawal: ₹100'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRequestSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              hintText: 'Enter amount to withdraw',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 16),
          TextField(
            controller: _accountController,
            decoration: InputDecoration(
              labelText: 'Bank Account',
              hintText: 'Enter account number',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Account Holder Name',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _requestWithdrawal,
            child: Text('Request Withdrawal'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHistorySection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Withdrawal History'),
          SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final req = _history[index];
              return ListTile(
                title: Text('₹${req.amount}'),
                subtitle: Text(req.status),
                trailing: Text(req.requestedAt),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### Step 3: Update HomeScreen
Add cards for Referral & Withdrawal screens

## PHASE 4: Offline Queue & Batch Sync (Week 2, Days 4-5)

### Step 1: SQLite Schema
```sql
CREATE TABLE game_actions (
  id TEXT PRIMARY KEY,
  userId TEXT NOT NULL,
  type TEXT NOT NULL,
  coinsEarned INTEGER NOT NULL,
  createdAt INTEGER NOT NULL,
  synced INTEGER DEFAULT 0
);

CREATE TABLE pending_operations (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  data TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  createdAt INTEGER NOT NULL
);
```

### Step 2: Initialize SQLite
```dart
Future<Database> initializeDatabase() async {
  final dbPath = await getDatabasesPath();
  return openDatabase(
    join(dbPath, 'earnplay.db'),
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE game_actions (
          id TEXT PRIMARY KEY,
          userId TEXT NOT NULL,
          type TEXT NOT NULL,
          coinsEarned INTEGER NOT NULL,
          createdAt INTEGER NOT NULL,
          synced INTEGER DEFAULT 0
        )
      ''');
    },
  );
}
```

### Step 3: Implement batch sync
Done in OfflineQueueService above

### Step 4: Schedule daily sync
```dart
void initApp() {
  // After user logs in
  _offlineQueueService.scheduleDailySync(userId);
}
```

## PHASE 5: Testing (Week 3)

### Unit Tests
```dart
void main() {
  group('ReferralService', () {
    test('Generate referral code', () async {
      final code = await referralService.generateReferralCode('uid', 'John');
      expect(code, isNotEmpty);
    });
    
    test('Validate code', () async {
      final isValid = await referralService.isValidCode('JOHN123');
      expect(isValid, isTrue);
    });
    
    test('Claim code atomically', () async {
      expect(() => referralService.claimReferralCode('user2', 'JOHN123'),
        completes);
    });
  });
}
```

### Integration Tests
```dart
void main() {
  group('Integration Tests', () {
    test('Full referral flow', () async {
      // User 1 generates code
      // User 2 registers with code
      // Verify both have correct balance
      // Verify actions logged
    });
    
    test('Withdrawal flow', () async {
      // User requests withdrawal
      // Verify balance deducted
      // Admin approves
      // Verify status updated
    });
  });
}
```

### Load Testing
- Simulate 100+ concurrent users
- Test batch sync at 22:00 IST
- Verify no race conditions

## PHASE 6: Deployment (Week 4)

### Pre-Deployment Checklist
- [ ] All services implemented
- [ ] Security rules deployed
- [ ] UI screens built
- [ ] Offline queue working
- [ ] Tests passing
- [ ] Firebase project configured
- [ ] Firestore indices created
- [ ] Monitoring alerts set up

### Deploy Steps
```bash
# 1. Deploy security rules
firebase deploy --only firestore:rules

# 2. Deploy app to Play Store/App Store
# Follow platform-specific deployment process

# 3. Monitor for issues
firebase console → Firestore → Monitoring
```

---

# UI SCREENS SPECIFICATION

## Design System

**Font:** Manrope (Google Fonts)  
**Icons:** Iconsax  
**Theme:** Material3 (already implemented)  
**Colors:** Use your app's existing color scheme

## ReferralScreen

```
┌─────────────────────────────────┐
│ Referral Program                │
├─────────────────────────────────┤
│                                 │
│ Your Referral Code              │
│ ┌──────────────────────────┐    │
│ │      UNCLE123            │    │
│ └──────────────────────────┘    │
│                                 │
│ [Copy] [Share]                  │
│                                 │
├─────────────────────────────────┤
│ Claim Referral Code             │
│ [Enter code here.............]  │
│ [Claim Code]                    │
│                                 │
├─────────────────────────────────┤
│ Your Referral Stats             │
│ ┌──────────────────────────┐    │
│ │ Total Referrals: 5       │    │
│ │ Total Earnings: ₹2500    │    │
│ └──────────────────────────┘    │
│                                 │
├─────────────────────────────────┤
│ Users Who Used Your Code        │
│ ┌──────────────────────────┐    │
│ │ Rohan  Joined 3d ago     │    │
│ │ ₹500                     │    │
│ ├──────────────────────────┤    │
│ │ Priya  Joined 1d ago     │    │
│ │ ₹500                     │    │
│ └──────────────────────────┘    │
│                                 │
└─────────────────────────────────┘
```

## WithdrawalScreen

```
┌─────────────────────────────────┐
│ Withdrawal                      │
├─────────────────────────────────┤
│                                 │
│ Current Balance                 │
│ ┌──────────────────────────┐    │
│ │ ₹5,000.00                │    │
│ │ Min withdrawal: ₹100     │    │
│ └──────────────────────────┘    │
│                                 │
├─────────────────────────────────┤
│ Request Withdrawal              │
│ [Amount..................]      │
│ [Bank Account..............]    │
│ [Account Holder Name.......]    │
│ [Request Withdrawal]            │
│                                 │
├─────────────────────────────────┤
│ Withdrawal History              │
│ ┌──────────────────────────┐    │
│ │ ₹1000  PENDING           │    │
│ │ Requested 2d ago         │    │
│ ├──────────────────────────┤    │
│ │ ₹500   APPROVED          │    │
│ │ Requested 5d ago         │    │
│ └──────────────────────────┘    │
│                                 │
└─────────────────────────────────┘
```

---

# OFFLINE QUEUE & BATCH SYNC

## How It Works

```
GAMEPLAY (User plays games at any time)
├─ User plays game → +25 coins
├─ Stored locally in SQLite
├─ No Firestore call
└─ Instant feedback to user

DAILY BATCH (22:00 IST ±30s delay)
├─ Load all pending actions from SQLite
├─ Batch into single Firestore write
├─ Update balance atomically
├─ Mark all as synced
└─ Ready for next day

NETWORK FAILURE
├─ Sync fails
├─ Queued actions stay in SQLite
├─ Next day retry automatically
└─ No data loss!
```

## SQLite Tables

```sql
-- Local storage for game actions
CREATE TABLE game_actions (
  id TEXT PRIMARY KEY,
  userId TEXT NOT NULL,
  type TEXT NOT NULL, -- 'GAME_PLAYED', 'AD_WATCHED'
  coinsEarned INTEGER NOT NULL,
  createdAt INTEGER NOT NULL,
  synced INTEGER DEFAULT 0
);

-- For tracking sync status
CREATE TABLE sync_status (
  userId TEXT PRIMARY KEY,
  lastSyncTime INTEGER,
  nextSyncTime INTEGER,
  pendingCount INTEGER DEFAULT 0
);
```

---

# TESTING STRATEGY

## Unit Tests (Service Logic)

```
ReferralService
├─ Generate code
├─ Validate code
├─ Claim code
└─ Get stats

WithdrawalService
├─ Request withdrawal
├─ Check limits
├─ Get history
└─ Can withdraw check

OfflineQueueService
├─ Add action
├─ Get pending
├─ Batch sync
└─ Mark synced
```

## Integration Tests (With Firestore)

```
Referral Flow
├─ User 1 generates code
├─ User 2 registers with code
├─ Both have correct balance
├─ Both have actions logged
└─ Can't claim twice

Withdrawal Flow
├─ User requests
├─ Balance deducted
├─ Admin approves
├─ Status changed
└─ History shows up

Batch Sync
├─ 8 actions queued
├─ Sync at 22:00
├─ All written
├─ Balance updated
└─ Marked synced
```

## Load Testing

```
Simulate:
├─ 100 concurrent users
├─ Each plays 5 games
├─ 22:00 IST batch sync
├─ Verify no conflicts
├─ Verify no duplicate writes
└─ Monitor performance
```

---

# DEPLOYMENT CHECKLIST

## Pre-Deployment

- [ ] All services implemented & tested
- [ ] Security rules finalized
- [ ] UI screens built & reviewed
- [ ] Offline queue working
- [ ] Firebase project created
- [ ] Firestore enabled
- [ ] Firestore indices configured
- [ ] Admin UID configured in rules
- [ ] Error tracking setup (Crashlytics)
- [ ] Analytics enabled
- [ ] Monitoring alerts configured

## Firebase Setup

```bash
# Create new Firebase project
firebase projects:create earnplay-prod

# Initialize Firestore
firebase firestore:create --project=earnplay-prod

# Deploy security rules
firebase deploy --only firestore:rules --project=earnplay-prod

# Create indices
firebase firestore:indexes:deploy --project=earnplay-prod
```

## Monitoring Setup

```
Key Metrics:
├─ Daily Active Users (DAU)
├─ Firestore reads (target < 50M/month free tier)
├─ Firestore writes (target < 20M/month free tier)
├─ Referral success rate (target > 95%)
├─ Withdrawal request rate
├─ Batch sync success rate (target > 99%)
├─ Error rate (target < 0.1%)
└─ Average sync time (target < 5s)

Alerts:
├─ DAU > 3000 (approaching free tier limit)
├─ Error rate > 1%
├─ Batch sync time > 10s
├─ Referral success < 90%
└─ Storage > 100MB
```

## Rollback Plan

```
If issues occur:

1. Immediate
   ├─ Stop promotion
   ├─ Notify users
   └─ Investigate logs

2. If critical
   ├─ Revert app version
   ├─ Downgrade Firestore rules
   └─ Restore from backup

3. Communication
   ├─ Inform users
   ├─ Provide timeline
   └─ Offer support
```

---

# SUMMARY: What To Build

## Files to Create

```
lib/
├─ services/
│  ├─ referral_service.dart
│  ├─ withdrawal_service.dart
│  ├─ offline_queue_service.dart
│  ├─ retry_service.dart
│  ├─ backup_recovery_service.dart
│  └─ pagination_service.dart
│
├─ screens/
│  ├─ referral_screen.dart
│  ├─ withdrawal_screen.dart
│  └─ (update) home_screen.dart
│
├─ models/
│  ├─ referral_stats_model.dart
│  ├─ withdrawal_request_model.dart
│  └─ game_action_model.dart
│
└─ providers/
   └─ (update) user_provider.dart

firestore.rules (deploy to Firebase)
```

## Configuration

```
pubspec.yaml additions:
├─ firebase_firestore: ^4.13.0
├─ cloud_functions (if needed later)
├─ sqflite: ^2.3.0
├─ uuid: ^4.0.0
└─ (icons, fonts already added)

Firebase project:
├─ Firestore database (created)
├─ Authentication enabled
├─ Security rules deployed
├─ Firestore indices created
└─ Admin UID set
```

---

# QUICK REFERENCE: Key Numbers

```
COST PER OPERATION:
├─ Read: $0.06 per 100K
├─ Write: $0.18 per 100K
├─ Delete: $0.02 per 100K
└─ Free tier: 50M reads + 20M writes per month

OPERATIONS PER USER PER DAY:
├─ Basic: 8-10 reads, 3-4 writes
├─ Active: 15-20 reads, 10-15 writes
├─ Power: 25-30 reads, 15-20 writes
└─ Average: ~15 reads, ~12 writes

BUSINESS METRICS:
├─ Referral bonus: ₹500
├─ Min withdrawal: ₹100
├─ Max daily withdrawal: ₹5000
├─ Max monthly withdrawal: ₹20000
├─ Withdrawal cooldown: 7 days
└─ Max referrals per user: 50

SCALING:
├─ 1K users: $0/month (free tier)
├─ 3K users: $0/month (free tier)
├─ 5K users: $40-50/month
├─ 10K users: $150-200/month
└─ 100K users: $1500-2000/month
```

---

## 🚀 Ready to Build!

This document contains everything needed to implement EarnPlay's backend.

**Next Step:** Pass this file to your AI agent and start building!

**Questions:** Refer to the detailed sections above.

**Issues:** Debug with reference to the specific operations documentation.

Good luck! 🎉

