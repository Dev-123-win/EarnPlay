# 🚀 Complete EarnPlay Deployment & Setup Guide

## Full Checklist for Production Deployment

This guide provides step-by-step instructions for deploying EarnPlay with all backend components.

---

## Table of Contents

1. [Environment Setup](#environment-setup)
2. [Firebase Project Setup](#firebase-project-setup)
3. [Clone & Configuration](#clone--configuration)
4. [Dependency Installation](#dependency-installation)
5. [Cloud Functions Deployment](#cloud-functions-deployment)
6. [Firestore Setup](#firestore-setup)
7. [Flutter App Configuration](#flutter-app-configuration)
8. [Testing](#testing)
9. [Production Deployment](#production-deployment)
10. [Monitoring & Maintenance](#monitoring--maintenance)

---

## Environment Setup

### Prerequisites

```bash
# Check Node.js version (18+ required)
node --version

# Check Flutter version
flutter --version

# Check Dart version
dart --version
```

### Install Global Tools

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Verify installation
firebase --version

# Login to Google account
firebase login
```

---

## Firebase Project Setup

### 1. Create Firebase Project

```bash
# In Firebase Console:
# 1. Go to https://console.firebase.google.com
# 2. Click "Add Project"
# 3. Name: "earnplay"
# 4. Select region
# 5. Create project
```

### 2. Upgrade to Blaze Plan

```bash
# Cloud Functions require Blaze (paid) plan
# In Firebase Console:
# 1. Go to Project Settings
# 2. Click "Upgrade to Blaze"
# 3. Add billing information
```

### 3. Enable Required Services

```bash
# In Firebase Console, enable:
# - Authentication
# - Cloud Firestore
# - Cloud Functions
# - Cloud Storage
```

### 4. Set Up Authentication

```bash
# In Firebase Console → Authentication:
# 1. Go to Sign-in method
# 2. Enable: Email/Password
# 3. Enable: Google (add OAuth credentials)
```

### 5. Create Firestore Database

```bash
# In Firebase Console → Firestore:
# 1. Create Database
# 2. Start in test mode (we'll add security rules)
# 3. Select region (same as Functions)
# 4. Click Create
```

---

## Clone & Configuration

### 1. Download Files

```bash
# Navigate to your projects folder
cd ~/projects

# Clone or extract earnplay folder
cd earnplay

# Verify structure
ls -la
```

### 2. Check File Structure

```
earnplay/
├── lib/                          # Flutter app code
├── functions/                    # Cloud Functions
├── android/                      # Android configuration
├── ios/                          # iOS configuration
├── pubspec.yaml                  # Flutter dependencies
├── firestore.rules               # Firestore security rules
├── firebase.json                 # Firebase configuration
└── ... (documentation files)
```

---

## Dependency Installation

### 1. Flutter Dependencies

```bash
cd earnplay

# Get Flutter packages
flutter pub get

# Analyze for issues
flutter analyze

# Format code
dart format lib/
```

### 2. Cloud Functions Dependencies

```bash
cd functions

# Install Node dependencies
npm install

# Verify
npm list
```

---

## Cloud Functions Deployment

### 1. Initialize Firebase in Project

```bash
# From project root
firebase init

# Select: Functions, Firestore
# Follow prompts
```

### 2. Deploy Cloud Functions

```bash
# From project root
firebase deploy --only functions

# Monitor deployment
firebase functions:log --limit 50 --follow
```

### 3. Verify Functions

```bash
# List all deployed functions
firebase functions:list

# Expected output:
# updateUserCoins
# claimDailyStreak
# processReferralBonus
# requestWithdrawal
# recordGameWin
# resetDailyLimits (scheduled)
# resetInactiveStreaks (scheduled)
# createUserDocument (on-call)
# deleteUserData (on-call)
```

### 4. Test Functions Locally

```bash
# Start emulator
firebase emulators:start

# In another terminal:
firebase functions:shell

# Test function in shell:
updateUserCoins({uid: "test-user", amount: 50, reason: "test"})
```

---

## Firestore Setup

### 1. Deploy Security Rules

```bash
# From project root
firebase deploy --only firestore:rules

# Verify deployment
firebase firestore:indexes
```

### 2. Create Initial Collections

```bash
# Firestore will create collections automatically
# But you can pre-create them:

# In Firebase Console → Firestore:
# 1. Create collections:
#    - users
#    - coinTransactions
#    - withdrawals
#    - games
#    - leaderboards
#    - referrals
#    - errors
#    - auditLogs
#    - config
```

### 3. Add Configuration Document

```bash
# In Firebase Console → Firestore:
# Create doc: config/apiVersion
# Add: version: "1.0.0"
```

---

## Flutter App Configuration

### 1. Update Firebase Options

```bash
# Generate firebase_options.dart
flutterfire configure

# Select iOS and Android when prompted
```

### 2. Update Android Configuration

```bash
# Copy google-services.json to:
# android/app/google-services.json

# Verify in android/build.gradle:
# classpath 'com.google.gms:google-services:4.3.15'

# Verify in android/app/build.gradle:
# apply plugin: 'com.google.gms.google-services'
```

### 3. Update iOS Configuration

```bash
# Copy GoogleService-Info.plist to:
# ios/Runner/GoogleService-Info.plist

# In Xcode:
# 1. Open ios/Runner.xcworkspace
# 2. Add GoogleService-Info.plist to Runner group
# 3. Ensure it's in Build Phases → Copy Bundle Resources
```

### 4. Test App Locally

```bash
# Android
flutter run -d emulator-5554

# iOS
flutter run -d <device-name>

# Check console for errors
# Verify Firebase initialization message
```

---

## Testing

### 1. Unit Tests

```bash
# Run all tests
flutter test

# Test specific file
flutter test test/models/user_data_model_test.dart

# With coverage
flutter test --coverage
```

### 2. Integration Tests

```bash
# Run integration tests
flutter test integration_test/

# On specific device
flutter test -d emulator-5554 integration_test/
```

### 3. Firebase Emulator Testing

```bash
# Start emulators
firebase emulators:start

# In another terminal, run tests
flutter test --dart-define FIREBASE_EMULATOR=true

# Or set environment
export FIREBASE_DATABASE_EMULATOR_HOST=localhost:9000
export FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
flutter run
```

### 4. Manual Feature Testing

```
Checklist:
□ Authentication (email/password, Google Sign-In)
□ Daily streak claiming
□ Ad watching (10 limit)
□ Spinning wheel (3 spins)
□ Tic-Tac-Toe game
□ Whack-a-Mole game
□ Profile viewing
□ Referral code sharing
□ Withdrawal request
□ Coin balance updates
□ Error messages
□ Network timeout handling
```

---

## Production Deployment

### 1. Build Android Release

```bash
# Clean build
flutter clean
flutter pub get

# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Output location:
# build/app/outputs/flutter-apk/app-release.apk
# build/app/outputs/bundle/release/app-release.aab
```

### 2. Build iOS Release

```bash
# Clean build
flutter clean
flutter pub get

# Build iOS
flutter build ios --release

# Archive in Xcode
# open ios/Runner.xcworkspace
# Product → Archive
# Upload to App Store Connect
```

### 3. Prepare Play Store Listing

```
Required information:
□ App name: EarnPlay
□ Short description (80 chars)
□ Full description
□ Screenshots (min 2, max 8)
□ Feature graphic (1024x500)
□ Promo graphic (optional)
□ Icon (512x512)
□ Privacy policy URL
□ Terms & Conditions URL
□ Contact email
```

### 4. Prepare App Store Listing

```
Required information (same as Play Store + iOS specific):
□ Keywords
□ Promotional text
□ Support URL
□ Privacy policy URL
□ App category
□ Rating information
```

### 5. Submit Apps

```bash
# Android
# 1. Go to Google Play Console
# 2. Create new app
# 3. Upload bundle/APK
# 4. Fill app details
# 5. Add content rating
# 6. Set pricing
# 7. Submit for review

# iOS
# 1. Go to App Store Connect
# 2. Create new app
# 3. Upload with Transporter
# 4. Fill app information
# 5. Add app preview videos
# 6. Submit for review
```

---

## Monitoring & Maintenance

### 1. Set Up Monitoring

```bash
# View Cloud Functions logs
firebase functions:log

# View real-time logs
firebase functions:log --limit 50 --follow

# Filter by function
firebase functions:log updateUserCoins
```

### 2. Monitor Firestore

```bash
# In Firebase Console:
# 1. Go to Firestore → Stats
# 2. Monitor reads/writes/deletes
# 3. Check costs
# 4. View largest documents
```

### 3. Set Up Alerts

```bash
# In Firebase Console:
# 1. Go to Project Settings → Alerts
# 2. Set up billing alerts
# 3. Receive notifications for quota increases
```

### 4. Regular Maintenance

```bash
# Daily checks:
□ Review error logs in errors collection
□ Monitor Cloud Functions execution
□ Check transaction logs
□ Review withdrawal requests

# Weekly checks:
□ Check database size
□ Review user growth
□ Monitor API usage
□ Backup critical data

# Monthly checks:
□ Review costs and optimize
□ Update dependencies
□ Security audit
□ Performance optimization
```

### 5. Backup Strategy

```bash
# Export data regularly
firebase firestore:export gs://earnplay-backups/backup-$(date +%Y-%m-%d)

# Test restore process
firebase firestore:import gs://earnplay-backups/backup-2024-01-01

# Store backups in multiple regions
gsutil mb gs://earnplay-backups
gsutil mb gs://earnplay-backups-europe
```

---

## Troubleshooting

### Common Issues

**Issue**: Cloud Functions timeout
```bash
# Solution: Increase timeout in firebase.json
# Set timeoutSeconds to 540 (max)
```

**Issue**: Firestore rules rejection
```bash
# Solution: Test rules locally
firebase emulators:start

# Check rule syntax
firebase deploy --only firestore:rules --dry-run
```

**Issue**: Authentication errors
```bash
# Solution: Verify credentials
flutterfire configure

# Check firebase_options.dart
cat lib/firebase_options.dart
```

**Issue**: Performance degradation
```bash
# Solution: Optimize queries
# 1. Add indexes
# 2. Batch operations
# 3. Use caching
# 4. Archive old data
```

---

## Performance Optimization

### 1. Database Optimization

```bash
# Create indexes for common queries
# In firestore.rules, indexes are defined

firebase firestore:indexes
```

### 2. Function Optimization

```bash
# Monitor execution time
firebase functions:log --limit 100 | grep duration

# Optimize slow functions:
# - Reduce database calls
# - Use batch operations
# - Implement caching
```

### 3. Frontend Optimization

```bash
# In Flutter:
flutter analyze
flutter build apk --split-per-abi

# Check performance
flutter run --profile
```

---

## Security Checklist

```
Security Verification:
□ HTTPS enabled
□ Firebase rules deployed
□ API keys restricted
□ Sensitive data encrypted
□ User authentication required
□ Admin access controlled
□ Audit logs enabled
□ Regular backups configured
□ Error handling implemented
□ Input validation enabled
□ SQL injection prevention
□ XSS protection (web)
□ CORS configured correctly
```

---

## Post-Launch

### Week 1
```
□ Monitor error logs closely
□ Watch for spike in usage
□ Respond to user feedback
□ Monitor costs
□ Check system health
```

### Week 2-4
```
□ Implement user feedback
□ Optimize performance
□ Add monitoring dashboards
□ Plan feature updates
□ Document common issues
```

### Monthly
```
□ Analytics review
□ Performance optimization
□ Security audit
□ User satisfaction review
□ Plan next features
```

---

## Contact & Support

**Firebase Support**: https://firebase.google.com/support  
**Flutter Docs**: https://flutter.dev/docs  
**Cloud Functions Docs**: https://firebase.google.com/docs/functions  

---

## Conclusion

Your EarnPlay backend is now fully deployed and ready for production. Follow the monitoring and maintenance checklist for optimal performance.

**Congratulations on launching EarnPlay! 🎉**

---

*Last Updated: 2024*  
*Version: 1.0.0*
