# 🎨 EARNPLAY COMPLETE UI/UX DESIGN SYSTEM

**Version:** 1.0  
**Date:** November 13, 2025  
**Design System:** Material 3 Expressive  
**Primary Font:** Manrope (Google Fonts)  
**Status:** Ready for Implementation  

---

## 📖 TABLE OF CONTENTS

1. [Design System Foundation](#design-system-foundation)
2. [Typography & Font Hierarchy](#typography--font-hierarchy)
3. [Color Palette & Theming](#color-palette--theming)
4. [Material 3 Expressive Components](#material-3-expressive-components)
5. [Responsive Design System](#responsive-design-system)
6. [Ad Placement Strategy](#ad-placement-strategy)
7. [Screen-by-Screen Specifications](#screen-by-screen-specifications)
8. [Animation Library](#animation-library)
9. [Dialog & Modal System](#dialog--modal-system)
10. [Error & Empty States](#error--empty-states)
11. [Accessibility Guidelines](#accessibility-guidelines)

---

# DESIGN SYSTEM FOUNDATION

## 🎯 Core Design Philosophy

**EARNPLAY Design Principles:**
- Material 3 Expressive (rounded, bold, playful)
- Offline-first with instant feedback
- Game-first mentality (fun, engagement, rewards)
- Accessibility-first (all users matter)
- Responsive (mobile-first, tablet-friendly, large screens)

## 📐 Key Design Values

```
EARNPLAY Design = Material 3 Expressive + Playfulness + Monetization

Expression:
├─ Bold colors & shapes
├─ Large, rounded components
├─ Generous spacing
└─ Rich animations

Playfulness:
├─ Game mechanics in UI
├─ Celebratory animations on wins
├─ Progress visualizations
└─ Reward highlights

Monetization:
├─ Ad placement (non-intrusive but visible)
├─ Referral highlights (encourage sharing)
├─ Withdrawal easy (encourage spending)
└─ Earn progress tracking
```

---

# TYPOGRAPHY & FONT HIERARCHY

## Font Family System

```
PRIMARY FONT: Manrope (Google Fonts)
├─ Super Light: 200 (Not used)
├─ Light: 300 (Subtitles, hints)
├─ Regular: 400 (Body text)
├─ Medium: 500 (Emphasis, labels)
├─ Semi-Bold: 600 (Headings, buttons)
├─ Bold: 700 (Primary headings)
└─ Extra-Bold: 800 (Large titles)

SECONDARY FONTS:
├─ Headlines: Manrope Bold (800)
├─ Subtitles: Inter (Google Fonts, 400)
├─ Metadata: JetBrains Mono (monospace, for codes)
└─ System: Roboto (fallback)
```

## Typography Scale

```
SIZE HIERARCHY:

Display Large
├─ Font: Manrope Bold 800
├─ Size: 57sp
├─ Line Height: 64sp
├─ Letter Spacing: 0sp
├─ Usage: Main app title, huge headlines
└─ Example: "EARNPLAY" on splash screen

Display Medium
├─ Font: Manrope Bold 700
├─ Size: 45sp
├─ Line Height: 52sp
├─ Usage: Screen titles, major sections
└─ Example: "Watch & Earn" title

Display Small
├─ Font: Manrope Semi-Bold 600
├─ Size: 36sp
├─ Line Height: 44sp
├─ Usage: Section headers, game names
└─ Example: "Tic Tac Toe" game name

Headline Large
├─ Font: Manrope Semi-Bold 600
├─ Size: 32sp
├─ Line Height: 40sp
├─ Usage: Card titles, major content
└─ Example: "Your Earnings" card

Headline Medium
├─ Font: Manrope Semi-Bold 600
├─ Size: 28sp
├─ Line Height: 36sp
├─ Usage: Secondary titles
└─ Example: "Complete Tasks"

Headline Small
├─ Font: Manrope Semi-Bold 600
├─ Size: 24sp
├─ Line Height: 32sp
├─ Usage: List item headers
└─ Example: "Claim Bonus"

Title Large
├─ Font: Manrope Medium 500
├─ Size: 22sp
├─ Line Height: 28sp
├─ Usage: Buttons, cards, sections
└─ Example: Button text

Title Medium
├─ Font: Manrope Medium 500
├─ Size: 16sp
├─ Line Height: 24sp
├─ Usage: Secondary button text
└─ Example: "Skip" button

Title Small
├─ Font: Manrope Regular 400
├─ Size: 14sp
├─ Line Height: 20sp
├─ Usage: Tab labels, small headings
└─ Example: Tab text

Body Large
├─ Font: Manrope Regular 400
├─ Size: 16sp
├─ Line Height: 24sp
├─ Usage: Main body text
└─ Example: Screen content

Body Medium
├─ Font: Manrope Regular 400
├─ Size: 14sp
├─ Line Height: 20sp
├─ Usage: Secondary text
└─ Example: List items

Body Small
├─ Font: Manrope Light 300
├─ Size: 12sp
├─ Line Height: 16sp
├─ Usage: Captions, metadata
└─ Example: Timestamps

Label Large
├─ Font: Manrope Semi-Bold 600
├─ Size: 14sp
├─ Line Height: 20sp
├─ Usage: Form labels, tags
└─ Example: Input label

Label Medium
├─ Font: Manrope Medium 500
├─ Size: 12sp
├─ Line Height: 16sp
├─ Usage: Small labels, hints
└─ Example: Helper text

Label Small
├─ Font: Manrope Medium 500
├─ Size: 11sp
├─ Line Height: 16sp
├─ Usage: Badges, small metadata
└─ Example: Badge text
```

---

# COLOR PALETTE & THEMING

## Material 3 Expressive Color System

```
PRIMARY COLORS:
├─ Primary: #6B5BFF (Purple - Main CTA, highlights)
├─ On Primary: #FFFFFF (Text on primary)
├─ Primary Container: #E8E0FF (Soft purple background)
├─ On Primary Container: #21005D (Dark purple text)
└─ Inverse Primary: #D0BCFF

SECONDARY COLORS:
├─ Secondary: #FF6B9D (Pink - Accents, warnings)
├─ On Secondary: #FFFFFF (White text)
├─ Secondary Container: #FFD8E8 (Soft pink)
├─ On Secondary Container: #78003A
└─ Inverse Secondary: #FFB1D9

TERTIARY COLORS:
├─ Tertiary: #1DD1A1 (Green - Success, gains)
├─ On Tertiary: #FFFFFF
├─ Tertiary Container: #B8F0D1 (Soft green)
├─ On Tertiary Container: #002D1B
└─ Inverse Tertiary: #8CDD00

ERROR COLORS:
├─ Error: #FF5252 (Red - Errors, losses)
├─ On Error: #FFFFFF
├─ Error Container: #FFCDD2 (Soft red)
└─ On Error Container: #8B0000

NEUTRAL COLORS:
├─ Background: #FAFAFA (Off-white)
├─ On Background: #1A1A1A (Dark text)
├─ Surface: #FFFFFF (Card background)
├─ On Surface: #1A1A1A
├─ Surface Dim: #F0F0F0
├─ Surface Bright: #FFFFFF
├─ Outline: #B0B0B0 (Borders)
├─ Outline Variant: #D0D0D0 (Subtle borders)
└─ Scrim: #000000 (Overlay black)

GAME-SPECIFIC COLORS:
├─ Win: #1DD1A1 (Green - Celebratory)
├─ Lose: #FF5252 (Red - Warning)
├─ Draw: #FFA500 (Orange - Neutral)
├─ Coin: #FFD700 (Gold - Rewards)
├─ Energy: #FF6B9D (Pink - Power)
└─ Streak: #FF9500 (Orange - Multiplier)
```

## Dark Mode Support

```
DARK MODE PALETTE:
├─ Primary: #D0BCFF (Lighter purple)
├─ Background: #121212 (Black)
├─ Surface: #1E1E1E (Dark gray)
├─ On Surface: #FFFFFF (Light text)
├─ Error: #FFB1B1 (Lighter red)
├─ Tertiary: #66D699 (Brighter green)
└─ (Apply inversions for contrast)
```

## Semantic Color Usage

```
COLORS BY MEANING:

Success = Tertiary (#1DD1A1)
├─ Win dialogs
├─ Task completion
├─ Referral rewards
└─ Withdrawal approval

Error = Error (#FF5252)
├─ Validation errors
├─ Insufficient balance
├─ Connection issues
└─ Game losses

Warning = Secondary (#FF6B9D)
├─ Limited time offers
├─ Energy depletion
├─ Ad recommendations
└─ Draw results

Info = Primary (#6B5BFF)
├─ App information
├─ Navigation highlights
├─ Selection indicators
└─ Focus states

Neutral = Outline (#B0B0B0)
├─ Disabled states
├─ Inactive tabs
├─ Secondary text
└─ Dividers

Reward = Coin (#FFD700)
├─ Coin displays
├─ Earning indicators
├─ Reward amounts
└─ Balance highlights
```

---

# MATERIAL 3 EXPRESSIVE COMPONENTS

## Button System

### Primary Button
```dart
Material 3 Filled Button
├─ Shape: 16dp rounded (M3 Expressive)
├─ Height: 56dp (touch-friendly)
├─ Padding: 24dp horizontal
├─ Background: Primary (#6B5BFF)
├─ Text: On Primary (#FFFFFF)
├─ Font: Manrope Semi-Bold 600, 16sp
├─ Elevation: 3dp (shadow)
├─ State:
│  ├─ Enabled: Full color, shadow
│  ├─ Hovered: +8% overlay
│  ├─ Pressed: +12% overlay
│  ├─ Disabled: 38% opacity, no shadow
│  └─ Loaded: 100% opacity
├─ Animation: Scale (0.98x on tap), 200ms ease-out
└─ Usage: Primary CTAs (Login, Submit, Play)

Example:
┌────────────────────────────────┐
│  🎮 PLAY GAME                  │
└────────────────────────────────┘
(Purple background, white text, rounded corners)
```

### Secondary Button
```dart
Material 3 Outlined Button
├─ Shape: 16dp rounded
├─ Height: 48dp
├─ Border: 2dp primary color
├─ Background: Transparent
├─ Text: Primary (#6B5BFF)
├─ Font: Manrope Medium 500, 16sp
├─ State:
│  ├─ Enabled: Outline visible
│  ├─ Pressed: 12% color overlay
│  └─ Disabled: 38% opacity
├─ Animation: Border expand on hover
└─ Usage: Secondary actions (Cancel, Skip, Learn More)

Example:
┌────────────────────────────────┐
│  ◻️  SKIP                       │
└────────────────────────────────┘
(Purple border, transparent background)
```

### Tertiary Button
```dart
Material 3 Tonal Button
├─ Shape: 16dp rounded
├─ Height: 48dp
├─ Background: Primary Container (#E8E0FF)
├─ Text: On Primary Container (#21005D)
├─ Font: Manrope Medium 500, 16sp
├─ State:
│  ├─ Enabled: Light purple background
│  ├─ Pressed: +8% darker
│  └─ Disabled: 38% opacity
├─ Animation: Color shift on interaction
└─ Usage: Tertiary actions (Learn More, Details)

Example:
┌────────────────────────────────┐
│  📖 LEARN MORE                  │
└────────────────────────────────┘
(Light purple background)
```

### Text Button
```dart
Material 3 Text Button
├─ Shape: 8dp rounded
├─ Background: Transparent
├─ Text: Primary (#6B5BFF)
├─ Font: Manrope Medium 500, 14sp
├─ Padding: 12dp horizontal
├─ State:
│  ├─ Enabled: Text only
│  ├─ Pressed: 10% color overlay
│  └─ Disabled: 38% opacity
├─ Animation: Text color fade
└─ Usage: Lightweight actions (Back, More, Details)

Example: [ Skip ]  [ Learn More ]  [ Details ]
```

## Card System

### Elevated Card
```dart
Material 3 Elevated Card
├─ Shape: 12dp rounded corners
├─ Background: Surface (#FFFFFF)
├─ Elevation: 1dp
├─ Padding: 16dp
├─ Border: None
├─ Shadow: 1dp soft shadow
├─ State:
│  ├─ Default: Light shadow
│  ├─ Hovered: 6dp elevation
│  └─ Pressed: 12dp elevation
├─ Animation: Elevation slide on interaction, 200ms
└─ Usage: Content containers (stats, tasks)

Example:
╔════════════════════════╗
║  Your Balance          ║
║  ₹5,000.00            ║
║  Updated 2m ago        ║
╚════════════════════════╝
```

### Filled Card
```dart
Material 3 Filled Card
├─ Shape: 12dp rounded
├─ Background: Surface Dim (#F0F0F0)
├─ Elevation: 0dp
├─ Padding: 16dp
├─ Border: 1dp outline
├─ State:
│  ├─ Default: Subtle background
│  ├─ Selected: Primary color border
│  └─ Disabled: 38% opacity
├─ Animation: Border color change
└─ Usage: Interactive selection cards

Example:
┌─────────────────────┐
│ Task 1              │
│ Play 3 games        │
│ ✓ Completed         │
└─────────────────────┘
```

### Outlined Card
```dart
Material 3 Outlined Card
├─ Shape: 12dp rounded
├─ Background: Surface
├─ Border: 1dp Outline (#B0B0B0)
├─ Elevation: 0dp
├─ Padding: 16dp
├─ State:
│  ├─ Default: Subtle border
│  ├─ Hovered: 2dp border, shadow
│  └─ Selected: Primary color border
├─ Animation: Border color on interaction
└─ Usage: Less prominent cards

Example:
┌─────────────────────┐
│ Optional Task       │
│ Watch 5 ads         │
└─────────────────────┘
```

## Input Field System

### Filled Text Field
```dart
Material 3 Filled TextField
├─ Shape: 12dp rounded top
├─ Height: 56dp
├─ Background: Surface Dim (#F0F0F0)
├─ Border Bottom: 1dp on focus
├─ Label: Float above on focus
├─ Font: Manrope Regular 400, 16sp
├─ Padding: 16dp horizontal, 8dp vertical
├─ State:
│  ├─ Enabled: Gray background
│  ├─ Focused: 2dp primary border
│  ├─ Error: 2dp error border, red text
│  └─ Filled: Indicates value present
├─ Animation: Label float up, 200ms
├─ Cursor: Primary color (#6B5BFF)
└─ Usage: Form inputs (email, password, amount)

Example:
━━━━━━━━━━━━━━━━━━━━━━━
 Email Address
 [user@example.com....]
━━━━━━━━━━━━━━━━━━━━━━━
```

### Outlined Text Field
```dart
Material 3 Outlined TextField
├─ Shape: 8dp rounded
├─ Height: 56dp
├─ Background: Surface (transparent)
├─ Border: 1dp Outline
├─ State:
│  ├─ Focused: 2dp primary border
│  ├─ Error: Red border
│  └─ Disabled: 38% opacity
├─ Animation: Border color change
└─ Usage: Search fields, optional inputs

Example:
┌─────────────────────────┐
│ Search... 🔍            │
└─────────────────────────┘
```

## Chip System

### Input Chip
```dart
Material 3 Input Chip
├─ Shape: 24dp rounded (pill-shaped)
├─ Height: 32dp
├─ Padding: 12dp
├─ Background: Surface Dim
├─ Border: 1dp outline
├─ Font: Manrope Regular 400, 14sp
├─ State:
│  ├─ Selected: Primary background
│  ├─ Disabled: 38% opacity
│  └─ Hovered: 8% overlay
├─ Animation: Scale on selection, 150ms
└─ Usage: Tags, filter options, selected items

Example: [✓ Purple] [Hobby] [Games]
```

### Filter Chip
```dart
Material 3 Filter Chip
├─ Similar to Input Chip
├─ With checkmark icon when selected
├─ Usage: Filter options in lists

Example: [✓ Completed] [Pending] [All]
```

### Suggestion Chip
```dart
Material 3 Suggestion Chip
├─ Shape: 16dp rounded
├─ Background: Outlined
├─ No deletion option
├─ Usage: Suggested actions, tags

Example: [📺 Watch Ad] [🎮 Play Game] [💰 Withdraw]
```

## Dialog System

### Alert Dialog
```dart
Material 3 AlertDialog
├─ Shape: 16dp rounded
├─ Background: Surface (#FFFFFF)
├─ Elevation: 6dp
├─ Max Width: 320dp (mobile), 560dp (tablet)
├─ Padding: 24dp
├─ Structure:
│  ├─ Icon (top): 48dp, primary color
│  ├─ Title: Display Small, Manrope Bold 700
│  ├─ Body: Body Large, Manrope Regular 400
│  └─ Actions: Primary + Secondary button
├─ Button Layout:
│  ├─ Mobile: Stacked vertical
│  ├─ Tablet: Horizontal, right-aligned
│  └─ Padding: 8dp between buttons
├─ Animation: Fade in (200ms) + scale (300ms)
├─ Scrim: 32% black overlay (#000000 with 32% opacity)
└─ Usage: Important confirmations, alerts

Example (Win Dialog):
┏━━━━━━━━━━━━━━━━━━━━┓
┃        🎉           ┃
┃    YOU WIN!        ┃
┃                    ┃
┃  You earned +25 💰 ┃
┃                    ┃
┃ [CONTINUE] [SHARE] ┃
┗━━━━━━━━━━━━━━━━━━━━┛
```

## Sheet System

### Bottom Sheet
```dart
Material 3 ModalBottomSheet
├─ Shape: 16dp rounded top corners
├─ Background: Surface
├─ Width: Full screen width
├─ Height: Content-based, max 90% screen
├─ Handle: 4dp bar at top (Outline color)
├─ Padding: 24dp
├─ Animation:
│  ├─ Slide up from bottom, 300ms
│  ├─ Scrim fade in, 200ms
│  └─ Decelerate easing
├─ Scrim: 32% black overlay
├─ Gesture: Swipe down to dismiss
└─ Usage: Action sheets, filters, content

Example (Withdrawal Options):
────────────────────────────────
         ━━━━━━━━━━
  Withdraw Balance
────────────────────────────────
  Amount: [_________]
  Account: [_________]
  Name: [_________]
  
  [REQUEST] [CANCEL]
────────────────────────────────
```

## Progress Indicators

### Linear Progress Indicator
```dart
Material 3 LinearProgressIndicator
├─ Height: 4dp
├─ Shape: 2dp rounded
├─ Background: Outline Variant (#D0D0D0)
├─ Foreground: Primary (#6B5BFF)
├─ Animation: Smooth color change, 300ms
├─ Animation: Indeterminate: Sliding, 2s
├─ Usage: Loading states, progress tracking

Example:
████████░░░░░░░░░░░░░░░░░  75%
(Purple bar on gray background)
```

### Circular Progress Indicator
```dart
Material 3 CircularProgressIndicator
├─ Size: 40dp / 48dp / 56dp (variant)
├─ Stroke Width: 4dp
├─ Color: Primary (#6B5BFF)
├─ Background: Outline Variant
├─ Animation:
│  ├─ Determinate: Smooth arc to target
│  ├─ Indeterminate: Spinning, 1.5s
│  └─ Easing: FastOutSlowIn
├─ Usage: Loading, buffering

Example:
    ╭─────╮
    │  ⟲  │ (Spinning)
    ╰─────╯
```

## Snackbar System

### Material 3 Snackbar
```dart
Material 3 Snackbar
├─ Shape: 12dp rounded
├─ Height: 48dp
├─ Background: On Surface (#1A1A1A)
├─ Text Color: Surface (#FFFFFF)
├─ Padding: 16dp horizontal
├─ Action: Secondary button
├─ Position: Bottom of screen
├─ Margin: 8dp from bottom/sides
├─ Animation:
│  ├─ Slide up from bottom, 300ms
│  ├─ Fade out, 200ms
│  └─ Auto-dismiss: 4s
├─ Usage: Non-critical messages

Example (Success):
████████████████████ ✓ Coins added!  [UNDO]
(Dark background, white text, 4s duration)

Example (Error):
████████████████████ ✗ Insufficient balance [RETRY]
```

---

# RESPONSIVE DESIGN SYSTEM

## Screen Size Breakpoints

```
DEVICE CATEGORIES:

Small Phone (320-480dp)
├─ Examples: iPhone SE, Galaxy A12
├─ Portrait: Full width content
├─ Landscape: 2-column layouts
├─ Padding: 12-16dp
└─ Font Scale: Default

Medium Phone (480-600dp)
├─ Examples: iPhone 12, Galaxy A51
├─ Portrait: Full width optimized
├─ Landscape: 3-column layouts
├─ Padding: 16-20dp
└─ Font Scale: Default

Large Phone (600-720dp)
├─ Examples: iPhone 14 Pro, Galaxy S22
├─ Portrait: Full width with margins
├─ Landscape: 4-column layouts
├─ Padding: 20-24dp
└─ Font Scale: Default

Tablet (720-1280dp)
├─ Examples: iPad Mini, Galaxy Tab A
├─ Portrait: 2-column layouts
├─ Landscape: 3-4 column layouts
├─ Padding: 24-32dp
├─ Content Max Width: 840dp
└─ Font Scale: 110%

Large Tablet (1280+dp)
├─ Examples: iPad Pro, Galaxy Tab S
├─ All Layouts: Centered content
├─ Content Max Width: 1080dp
├─ Padding: 32-48dp
└─ Font Scale: 120%
```

## Layout Grid System

```
COLUMN SYSTEM:

Mobile (320-720dp):
├─ 4-column grid
├─ Gutter: 8dp
├─ Margin: 16dp
└─ Card Width: (Device - 32) / 2

Tablet (720-1280dp):
├─ 8-column grid
├─ Gutter: 16dp
├─ Margin: 24dp
└─ Card Width: (Device - 48) / 3 or 4

Desktop (1280+dp):
├─ 12-column grid
├─ Gutter: 24dp
├─ Margin: 32dp
└─ Max Content Width: 1080dp
```

## Responsive Components

### Floating Action Button (FAB)
```
Mobile:
├─ Size: 56dp (standard)
├─ Position: Bottom-right, 16dp from edge
└─ Behavior: Scroll-aware (hide/show)

Tablet:
├─ Size: 56dp (standard) or 96dp (extended)
├─ Position: Bottom-right or floating sidebar
└─ Extended FAB: Icon + label visible

Desktop:
├─ Size: 56dp or 96dp
├─ Position: Floating corner or app bar
└─ Extended label always visible
```

### Navigation
```
Mobile:
├─ Bottom Navigation Bar (3-5 items)
├─ Height: 56-80dp
├─ Label: Below icon
└─ Active: Color + label

Tablet:
├─ Navigation Rail (left side)
├─ Width: 56-80dp
├─ Orientation: Vertical
├─ Label: Tooltip or compact

Desktop:
├─ Left Navigation Drawer
├─ Width: 256-360dp
├─ Orientation: Vertical
└─ Label: Always visible
```

### Text Scaling
```
Small Phone: 95% of base size
Medium Phone: 100% (base)
Large Phone: 105% of base size
Tablet: 110-120% of base size
Desktop: 120-130% of base size
```

---

# AD PLACEMENT STRATEGY

## Ad Format Specifications

### 1. Banner Ad
```
Specifications:
├─ Size: 320x50dp (mobile), 728x90dp (tablet)
├─ Position: Bottom of screen (persistent)
├─ Refresh Rate: Every 30 seconds
├─ Animation: Fade in/out on refresh
├─ Background: Surface color (match app)
├─ Border: 1dp Outline Variant above
└─ Safe Area: 8dp padding from edges

Placement Strategy:
├─ Home Screen: Bottom, above nav bar
├─ Watch & Earn: Sticky below video section
├─ Spin & Win: Bottom above spin button
├─ Game Screens (Tic Tac Toe, Whack-a-Mole): Below game area
├─ Referral Screen: Bottom
├─ Withdrawal Screen: Bottom
├─ Profile Screen: Bottom
└─ NOT on: Onboarding, Loading, Game during active play

Implementation:
import 'package:google_mobile_ads/google_mobile_ads.dart';

BannerAd(
  adUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy',
  size: AdSize.banner,
  request: const AdRequest(),
  listener: const BannerAdListener(),
)
```

### 2. Interstitial Ad
```
Specifications:
├─ Size: Full screen (animated or static)
├─ Duration: 2-30 seconds (user can skip after 5s)
├─ Animation: Fade in from black
├─ Dismiss: Close button after countdown
└─ Callback: Optional, on close action

Trigger Points:
├─ After 3rd game completion in a session
├─ Before accessing Withdrawal screen first time
├─ After 5 tasks completed
├─ Between game rounds (optional)
└─ NOT: More than 1 per 5 minutes

Implementation:
InterstitialAd.load(
  adUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz',
  request: const AdRequest(),
  adLoadCallback: InterstitialAdLoadCallback(
    onAdLoaded: (ad) {
      ad.show();
    },
  ),
);

User Experience:
┏━━━━━━━━━━━━━━━━━┓
┃  Advertisement  ┃
┃                 ┃
┃   [AD CONTENT]  ┃
┃                 ┃
┃ Skip in 5s... ✕ ┃
┗━━━━━━━━━━━━━━━━━┛
```

### 3. Rewarded Ad
```
Specifications:
├─ Size: Full screen video or interactive
├─ Duration: 15-30 seconds
├─ Reward: 10-25 coins
├─ Skip: Not allowed (must watch fully)
├─ Animation: Fade in, video plays, success screen
└─ Sound: Enabled by default (user can mute)

Trigger Points:
├─ "Watch to Earn" button on Watch & Earn screen
├─ Optional ad bonus on spin result
├─ Daily bonus pool
├─ Task completion optional boost
└─ Max 10-15 per day (configurable)

Reward Calculation:
├─ Base: 10 coins
├─ Multiplier: Time of day (1x-2x)
├─ Streak bonus: +5 coins (if watching consecutively)
└─ Total: 10-25 coins per ad

Implementation:
RewardedAd.load(
  adUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/aaaaaaaaa',
  request: const AdRequest(),
  rewardedAdLoadCallback: RewardedAdLoadCallback(
    onAdLoaded: (ad) {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          // Grant coins
          // Update balance
          // Show success dialog
        },
      );
      ad.show(
        onUserEarnedReward: (ad, reward) {
          print('Earned ${reward.amount} ${reward.type}');
        },
      );
    },
  ),
);

UI Flow:
┌────────────────────────────────┐
│ Watch & Earn                   │
├────────────────────────────────┤
│                                │
│ [Watch Rewarded Ad - +15 💰]   │ ← Click to watch
│                                │
├────────────────────────────────┤
│ Advertisement                  │
│ [VIDEO PLAYS 30s]              │
│ ✓ Watched! +15 coins           │
│ [CLAIM]                        │
└────────────────────────────────┘
```

### 4. Native Banner Ad
```
Specifications:
├─ Size: Full width, 120-150dp height
├─ Format: Image + headline + body + CTA button
├─ Background: Filled Card (#F0F0F0)
├─ Border: 1dp Outline
├─ Corner Radius: 12dp
├─ Padding: 16dp

Native Ad Structure:
┌─────────────────────────────────────┐
│ 🎮 [AD] Play Epic Quest             │
│ [IMAGE]  Adventure awaits you!      │
│          [DOWNLOAD]                 │
└─────────────────────────────────────┘

Placement Strategy:
├─ Watch & Earn Screen: Between video cards
│  └─ Position: Every 3rd video card
├─ Game History Screens: Between entries
│  └─ Position: Every 4th entry
├─ Referral Screen: Below stats section
│  └─ Position: Sticky, between referrals
├─ Profile Screen: Above logout button
│  └─ Position: Single card at bottom
└─ Tasks Screen: Between task cards
   └─ Position: Every 5th task

Implementation:
NativeAd(
  factoryId: 'listTile',
  customOptions: {'clickable': 'true'},
  listener: NativeAdListener(
    onAdLoaded: (ad) {
      setState(() => nativeAd = ad);
    },
  ),
)
```

### 5. Rewarded Interstitial Ad
```
Specifications:
├─ Size: Full screen
├─ Reward: 5-10 coins
├─ Skip: Allowed after 5s (but user loses reward)
├─ Duration: 15-20 seconds
├─ Message: "Skip = No reward" warning
└─ Animation: Fade in/out

Trigger Points:
├─ After withdrawal request
│  └─ "Earn coins towards next withdrawal"
├─ On insufficient balance check
│  └─ "Watch ad for instant +10 coins?"
├─ Daily streak reset warning
│  └─ "Watch ad to extend streak?"
└─ Max 5 per day

Implementation:
RewardedInterstitialAd.load(
  adUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/bbbbbbbb',
  request: const AdRequest(),
  rewardedInterstitialAdLoadCallback: 
    RewardedInterstitialAdLoadCallback(
    onAdLoaded: (ad) {
      ad.show(
        onUserEarnedReward: (ad, reward) {
          // Grant coins
        },
      );
    },
  ),
);

User Experience:
┏━━━━━━━━━━━━━━━━━┓
┃  Advertisement  ┃
┃                 ┃
┃ ⚠️ Skip = No 💰 ┃
┃ [AD VIDEO]      ┃
┃ Skip in 5s... ✕ ┃
┗━━━━━━━━━━━━━━━━━┛
```

## Ad Placement Heat Map

```
SCREEN: Home Screen
┌─────────────────────────────┐
│ Balance Card                │
├─────────────────────────────┤
│ 🏃 Quick Stats              │
│ ────────────────────────────┤
│ [Referral Card] [WithdrawCard]
├─────────────────────────────┤
│ 🎮 Featured Games           │
│ [Game 1] [Game 2]           │
│ [Game 3] [Game 4]           │
├─────────────────────────────┤
│ ▓▓▓ BANNER AD ▓▓▓            │ ← Banner Ad (sticky)
├─────────────────────────────┤
│ 📊 Bottom Navigation        │
└─────────────────────────────┘

SCREEN: Watch & Earn
┌─────────────────────────────┐
│ Watch Videos                │
├─────────────────────────────┤
│ [Video 1] - Watch for +10   │
│ [Video 2] - Watch for +10   │
│ ┌─────────────────────────┐ │
│ │ 🎬 [NATIVE AD] Play Game│ │ ← Native Ad
│ │ [Image] [CTA]           │ │
│ └─────────────────────────┘ │
│ [Video 3] - Watch for +10   │
│ [Video 4] - Watch for +10   │
│ ┌─────────────────────────┐ │
│ │ 🎬 [NATIVE AD] Quiz App │ │ ← Native Ad
│ │ [Image] [CTA]           │ │
│ └─────────────────────────┘ │
│ [Video 5] - Watch for +10   │
├─────────────────────────────┤
│ ▓▓▓ BANNER AD ▓▓▓            │ ← Banner Ad
└─────────────────────────────┘

SCREEN: Games (Tic Tac Toe, Whack-a-Mole)
┌─────────────────────────────┐
│ 🎮 TIC TAC TOE              │
├─────────────────────────────┤
│                             │
│  X │ O │                    │
│ ───┼───┼───                 │
│  O │   │                    │
│ ───┼───┼───                 │
│    │   │ X                  │
│                             │
│ [RESTART] [HINT]            │
│                             │
├─────────────────────────────┤
│ ▓▓▓ BANNER AD ▓▓▓            │ ← Banner Ad
│ [50% Play Again Button]     │ ← Placement below ad
└─────────────────────────────┘
```

## Ad Loading & Failure Handling

```
LOADING SEQUENCE:

1. Screen Loads
   ├─ Preload banner (low priority)
   ├─ Preload interstitial (medium priority)
   └─ Preload rewarded ad (high priority)

2. Ad Ready
   ├─ Display banner
   ├─ Enable ad-triggered buttons
   └─ Show in native slots

3. Ad Fails
   ├─ Continue without ad
   ├─ Retry after 10s
   ├─ Log error to analytics
   └─ Don't block user experience

FALLBACK STRATEGY:

If Banner Fails:
├─ Show 2dp Outline Variant border (placeholder)
├─ Retry loading after 30s
└─ User can still see content

If Rewarded Ad Fails:
├─ Show error snackbar
├─ Give 50% coins (5 instead of 10)
├─ Offer retry button
└─ Or skip and continue

If Interstitial Fails:
├─ Silently skip showing
├─ Continue to next screen
├─ Retry next eligible trigger
└─ Don't disrupt UX

CODE EXAMPLE:

class AdManager {
  static Future<void> loadBannerAd() async {
    try {
      _bannerAd = BannerAd(
        adUnitId: _bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdFailedToLoad: (ad, error) {
            print('Banner ad failed: ${error.message}');
            ad.dispose();
            // Retry after 30s
            Future.delayed(Duration(seconds: 30), loadBannerAd);
          },
        ),
      );
      await _bannerAd?.load();
    } on Exception catch (e) {
      print('Banner load error: $e');
    }
  }
  
  static Future<void> showRewardedAd() async {
    try {
      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            ad.show(
              onUserEarnedReward: (ad, reward) {
                // Grant coins
                grantCoins(reward.amount.toInt());
              },
            );
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('Rewarded ad failed: ${error.message}');
            // Give partial coins
            grantCoins(5);
            // Show snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ad unavailable. Got 5 coins instead!')),
            );
          },
        ),
      );
    } on Exception catch (e) {
      print('Rewarded ad error: $e');
      grantCoins(5);
    }
  }
}
```

---

# SCREEN-BY-SCREEN SPECIFICATIONS

## 1️⃣ SPLASH SCREEN

**Duration:** 2-3 seconds  
**Navigation:** Auto-navigate to Onboarding (first time) or Home (logged in)

### Layout Structure

```
┌─────────────────────────────┐
│                             │
│  ╭───────────────────────╮  │
│  │                       │  │ ← Logo (animated scale up)
│  │     🎮 EARNPLAY       │  │
│  │                       │  │
│  ╰───────────────────────╯  │
│                             │
│       Loading Animation     │
│   ◐ ◓ ◑ ◒ (rotating)       │ ← Circular progress
│                             │
│  "Loading your rewards..." │ ← Subtitle
│                             │
│  [Progress Bar ████░░░░░░░] │ ← Linear progress 40%
│                             │
└─────────────────────────────┘
```

### Components Used

```
1. Logo
   ├─ Asset: Logo.png (512x512)
   ├─ Size: 120dp
   ├─ Color: Primary (#6B5BFF)
   ├─ Animation: Scale (0.5x → 1x) + Fade (0 → 1)
   ├─ Duration: 800ms (Decelerate curve)
   └─ Code:
      ScaleTransition(
        scale: Tween<double>(begin: 0.5, end: 1.0)
          .animate(CurvedAnimation(parent: _controller, 
            curve: Curves.decelerate)),
        child: Image.asset('assets/logo.png', width: 120),
      )

2. Circular Progress
   ├─ Size: 56dp
   ├─ Stroke Width: 4dp
   ├─ Color: Primary (#6B5BFF)
   ├─ Animation: Spinning, 1.5s per rotation
   ├─ Duration: Infinite loop
   └─ Code:
      SizedBox(
        width: 56,
        height: 56,
        child: CircularProgressIndicator(
          strokeWidth: 4,
          valueColor: AlwaysStoppedAnimation(Colors.purple),
        ),
      )

3. Subtitle Text
   ├─ Font: Manrope Regular 400, 14sp
   ├─ Color: On Surface (#1A1A1A)
   ├─ Text: "Loading your rewards..."
   ├─ Opacity: Animated fade (0.5 → 1.0)
   └─ Duration: 1s

4. Linear Progress Bar
   ├─ Height: 4dp
   ├─ Width: 120dp
   ├─ Background: Outline Variant (#D0D0D0)
   ├─ Foreground: Primary (#6B5BFF)
   ├─ Animation: Smooth 40% fill, 1.5s
   └─ Code:
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: 0.4,
          minHeight: 4,
          backgroundColor: Color(0xFFD0D0D0),
          valueColor: AlwaysStoppedAnimation(Color(0xFF6B5BFF)),
        ),
      )
```

### Animation Sequence

```
Timeline:
├─ 0ms: Logo fade in (0 → 1), scale (0.5x → 1x)
├─ 800ms: Hold logo
├─ 800ms: Progress spinner start
├─ 1000ms: Subtitle fade in
├─ 1000ms: Progress bar fill
├─ 2000ms: Check auth status
├─ 2500ms: Navigate
└─ 3000ms: Screen transition complete

Easing Functions:
├─ Logo: Curves.decelerate (bouncy feel)
├─ Progress: Curves.linear (steady)
├─ Text: Curves.easeInOut (smooth)
└─ Navigation: Curves.easeInOutCubic
```

### Code Skeleton

```dart
class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logofadeOpacity;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _logoScale = Tween<double>(begin: 0.5, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));
    
    _logofadeOpacity = Tween<double>(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    
    _controller.forward();
    _checkAuthAndNavigate();
  }
  
  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(Duration(seconds: 3));
    // Check if user is logged in
    // Navigate accordingly
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _logoScale,
              child: FadeTransition(
                opacity: _logofadeOpacity,
                child: Image.asset('assets/logo.png', width: 120),
              ),
            ),
            SizedBox(height: 48),
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            SizedBox(height: 24),
            Text('Loading your rewards...'),
            SizedBox(height: 16),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## 2️⃣ ONBOARDING SCREENS (3 Screens)

**Navigation:** Next/Skip buttons, Dot indicators, Auto-scroll on last screen

### Screen 1: Welcome

```
┌─────────────────────────────┐
│                             │
│  ╭───────────────────────╮  │
│  │  🎮                   │  │ ← Icon (120dp, Primary)
│  │  EARN & PLAY          │  │ ← Title
│  ╰───────────────────────╯  │
│                             │
│  Play fun games and earn    │ ← Description
│  real money rewards!        │
│                             │
│  [NEXT] [Skip →]            │ ← Buttons
│                             │
│  ● ○ ○                      │ ← Dot indicators
│                             │
└─────────────────────────────┘
```

### Screen 2: Features

```
┌─────────────────────────────┐
│  🎯 Multiple Ways to Earn   │
│                             │
│  ✓ Play addictive games    │ ← Feature 1
│  ✓ Watch rewarded videos   │ ← Feature 2
│  ✓ Spin the wheel daily    │ ← Feature 3
│  ✓ Refer friends, earn 💰  │ ← Feature 4
│  ✓ Withdraw instantly      │ ← Feature 5
│                             │
│  [NEXT] [← Back]            │
│  ○ ● ○                      │
│                             │
└─────────────────────────────┘
```

### Screen 3: Ready to Start

```
┌─────────────────────────────┐
│                             │
│  ╭───────────────────────╮  │
│  │  🚀                   │  │ ← Icon
│  │  YOU'RE READY!        │  │ ← Title
│  ╰───────────────────────╯  │
│                             │
│  Start earning today and    │
│  watch your balance grow!   │
│                             │
│  [GET STARTED]              │ ← Primary CTA
│                             │
│  ○ ○ ●                      │
│                             │
└─────────────────────────────┘
```

### Components for Onboarding

```
1. PageView Container
   ├─ Height: Full screen
   ├─ Background: Gradient (Primary → Tertiary)
   ├─ Gestures: Swipe left/right
   └─ Code:
      PageView(
        controller: _pageController,
        children: [
          OnboardingPage1(),
          OnboardingPage2(),
          OnboardingPage3(),
        ],
      )

2. Dot Indicators (Smooth PageIndicator)
   ├─ Size: 8dp
   ├─ Active: 24dp width (pill-shaped)
   ├─ Color: Primary
   ├─ Animation: Smooth expansion
   └─ Code:
      SmoothPageIndicator(
        controller: _pageController,
        count: 3,
        effect: ExpandingDotsEffect(
          activeDotColor: Colors.purple,
          dotHeight: 8,
          expansionFactor: 3,
        ),
      )

3. Icon Display
   ├─ Size: 120dp
   ├─ Color: White
   ├─ Shadows: 8dp blur (Primary shadow)
   ├─ Animation: Bounce on screen (scale 0.8x → 1x)
   └─ Duration: 600ms

4. Title Text
   ├─ Font: Manrope Bold 700, 32sp
   ├─ Color: White
   ├─ Alignment: Center
   ├─ Max Lines: 2
   └─ Animation: Fade in (0 → 1)

5. Description Text
   ├─ Font: Manrope Regular 400, 16sp
   ├─ Color: White 80%
   ├─ Max Lines: 3
   ├─ Center alignment
   └─ Animation: Fade in (0 → 1) with 100ms delay

6. Feature List (Screen 2)
   ├─ Layout: Column of rows
   ├─ Item:
   │  ├─ Icon: ✓ (checkmark)
   │  ├─ Text: Feature description
   │  ├─ Height: 48dp
   │  └─ Padding: 16dp
   ├─ Separator: 1dp Outline Variant (20% opacity)
   ├─ Animation: Slide in (left) + fade (0 → 1)
   ├─ Stagger: 50ms between items
   └─ Code:
      ListView.separated(
        shrinkWrap: true,
        itemCount: features.length,
        separatorBuilder: (_, __) => Divider(),
        itemBuilder: (_, index) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(-1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(...)),
            child: ListTile(
              leading: Icon(Icons.check_circle),
              title: Text(features[index]),
            ),
          );
        },
      )
```

### Animation Sequence

```
Page Entry:
├─ Icon: Scale (0.8x → 1.0x) + Fade (0 → 1) in 600ms
├─ Title: Fade (0 → 1) + SlideUp (16dp) in 400ms
├─ Subtitle: Fade (0 → 1) in 500ms (200ms delay)
├─ Features: Staggered slide in (100ms each)
└─ Buttons: Fade (0 → 1) in 300ms (600ms delay)

Page Transition:
├─ Swipe detected
├─ Dot indicator animates to next (300ms)
├─ PageView slides (300ms, Curves.easeInOutCubic)
├─ New page elements animate in (sequence above)
└─ Total: 600ms smooth transition

Button Interactions:
├─ Pressed: Scale (0.98x) in 100ms
├─ Released: Scale (1.0x) in 100ms
├─ Next: Page advances + fade transition
└─ Skip: Direct to login (fade out, fade in)
```

### Dart Code

```dart
class OnboardingScreen extends StatefulWidget {
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  
  final List<OnboardingPageData> pages = [
    OnboardingPageData(
      icon: Icons.videogame_asset,
      title: 'EARN & PLAY',
      description: 'Play fun games and earn real money rewards!',
    ),
    OnboardingPageData(
      icon: Icons.featured_play_list,
      title: '🎯 Multiple Ways to Earn',
      description: '',
      features: [
        '✓ Play addictive games',
        '✓ Watch rewarded videos',
        '✓ Spin the wheel daily',
        '✓ Refer friends, earn 💰',
        '✓ Withdraw instantly',
      ],
    ),
    OnboardingPageData(
      icon: Icons.rocket_launch,
      title: 'YOU\'RE READY!',
      description: 'Start earning today and watch your balance grow!',
    ),
  ];
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) => setState(() => _currentPage = page),
        itemCount: pages.length,
        itemBuilder: (_, index) => _buildPage(pages[index], index),
      ),
    );
  }
  
  Widget _buildPage(OnboardingPageData data, int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6B5BFF), Color(0xFF1DD1A1)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Icon with animation
            _buildAnimatedIcon(data.icon),
            
            // Title
            Text(
              data.title,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Description or Features
            if (data.features.isEmpty)
              Text(
                data.description,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              )
            else
              _buildFeaturesList(data.features),
            
            // Buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pageController.previousPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                        ),
                        child: Text('← Back'),
                      ),
                    ),
                  SizedBox(width: index > 0 ? 8 : 0),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (index < pages.length - 1) {
                          _pageController.nextPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                          );
                        } else {
                          // Navigate to login
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                      child: Text(index < pages.length - 1 ? 'NEXT' : 'GET STARTED'),
                    ),
                  ),
                  if (index < pages.length - 1) ...[
                    SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: Text('Skip →'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Dot indicators
            SmoothPageIndicator(
              controller: _pageController,
              count: pages.length,
              effect: ExpandingDotsEffect(
                activeDotColor: Colors.white,
                dotHeight: 8,
                expansionFactor: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnimatedIcon(IconData icon) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: ..., curve: Curves.elasticOut)),
      child: Icon(icon, size: 120, color: Colors.white),
    );
  }
  
  Widget _buildFeaturesList(List<String> features) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: features.map((feature) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    feature,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final List<String> features;
  
  OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    this.features = const [],
  });
}
```

---

[CONTINUING IN NEXT SECTION - CHARACTER LIMIT REACHED]

Due to character limits, I'll continue with the remaining screens. Let me create the rest of the UI documentation:
