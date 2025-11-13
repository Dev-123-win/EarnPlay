# 🎨 EARNPLAY COMPLETE UI/UX DESIGN - PART 2

**Continuing from Part 1...**

---

## 3️⃣ LOGIN SCREEN

**Purpose:** User authentication with email/password  
**Navigation:** From splash or signup screen

### Layout Structure

```
┌─────────────────────────────┐
│                             │
│  ╭───────────────────────╮  │
│  │  🎮 EARNPLAY          │  │ ← Logo (80dp)
│  ╰───────────────────────╯  │
│                             │
│  Welcome Back!              │ ← Subtitle
│                             │
│  [Email...............]     │ ← Email field
│                             │
│  [Password............]     │ ← Password field
│                             │
│  [ ] Remember me            │ ← Checkbox
│  [← Forgot Password?]       │ ← Text button
│                             │
│  [LOGIN]                    │ ← Primary button
│                             │
│  Don't have account?        │ ← Text
│  [Sign Up Here]             │ ← Link button
│                             │
└─────────────────────────────┘
```

### Components

```
1. Logo Header
   ├─ Size: 80dp
   ├─ Animation: Fade in (0 → 1) in 400ms
   ├─ Position: Top center (48dp from top)
   └─ Color: Primary

2. Form Title
   ├─ Font: Manrope Bold 700, 28sp
   ├─ Text: "Welcome Back!"
   ├─ Color: On Surface
   ├─ Animation: Slide up (16dp) + fade
   └─ Delay: 200ms

3. Email TextField
   ├─ Type: Filled TextInputField
   ├─ Label: "Email Address"
   ├─ Hint: "your@email.com"
   ├─ Icon: Iconsax mail icon (left)
   ├─ KeyboardType: .emailAddress
   ├─ Error Validation: Real-time
   ├─ Animation: Scale (0.95x → 1.0x) on focus
   ├─ Height: 56dp
   └─ Code:
      TextField(
        decoration: InputDecoration(
          filled: true,
          fillColor: Color(0xFFF0F0F0),
          hintText: 'your@email.com',
          labelText: 'Email Address',
          prefixIcon: Icon(Iconsax.sms),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          errorText: _emailError,
        ),
        onChanged: (value) => _validateEmail(value),
      )

4. Password TextField
   ├─ Type: Filled TextField
   ├─ Label: "Password"
   ├─ Icon: Iconsax lock icon (left)
   ├─ KeyboardType: .visiblePassword
   ├─ Obscure: True (toggleable)
   ├─ Toggle Icon: Iconsax eye icon (right)
   ├─ Animation: Eye icon rotate (0° → 180°)
   ├─ Height: 56dp
   └─ Code:
      TextField(
        decoration: InputDecoration(
          filled: true,
          fillColor: Color(0xFFF0F0F0),
          labelText: 'Password',
          prefixIcon: Icon(Iconsax.lock),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Iconsax.eye_slash : Iconsax.eye),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        obscureText: _obscurePassword,
      )

5. Remember Me Checkbox
   ├─ Type: M3 Checkbox
   ├─ Label: "Remember me"
   ├─ Size: 24dp
   ├─ Color: Primary (checked)
   ├─ Animation: Check mark draw
   └─ Code:
      CheckboxListTile(
        title: Text('Remember me'),
        value: _rememberMe,
        onChanged: (value) => setState(() => _rememberMe = value),
        controlAffinity: ListTileControlAffinity.leading,
      )

6. Forgot Password Link
   ├─ Font: Manrope Regular 400, 14sp
   ├─ Color: Primary
   ├─ Text: "← Forgot Password?"
   ├─ Alignment: Right
   ├─ Animation: Text color on hover
   └─ Gesture: Navigate to forgot password screen

7. Login Button
   ├─ Type: Filled button
   ├─ Text: "LOGIN"
   ├─ Height: 56dp
   ├─ Color: Primary
   ├─ Loading: Show spinner
   ├─ Disabled: During API call
   ├─ Animation: Scale (0.98x) on tap
   └─ Code:
      ElevatedButton(
        onPressed: _isLoading ? null : _loginUser,
        child: _isLoading
          ? SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
          : Text('LOGIN'),
      )

8. Sign Up Link
   ├─ Text: "Don't have account? Sign Up Here"
   ├─ Color: On Surface
   ├─ Link Color: Primary
   ├─ Animation: Link color on hover
   └─ Gesture: Navigate to signup
```

### Validation & Error Handling

```
VALIDATION RULES:

Email:
├─ Pattern: Valid email format (regex check)
├─ Error: "Invalid email address"
├─ Real-time: Check on each keystroke
├─ Animation: Red border + error text fade in
└─ Icon: ✗ on error, ✓ on valid

Password:
├─ Min length: 8 characters
├─ Error: "Password must be at least 8 characters"
├─ Real-time: Show strength indicator
├─ Strength:
│  ├─ Weak (0-33%): Red
│  ├─ Medium (34-66%): Orange
│  └─ Strong (67-100%): Green
└─ Animation: Strength bar fill

Login Errors:
├─ Invalid credentials:
│  └─ Snackbar: "Incorrect email or password"
├─ Network error:
│  └─ Snackbar: "Network error. Please try again."
├─ Server error:
│  └─ Dialog: "Server error. Please try again later."
└─ Animation: Shake effect (±4dp, 200ms) on error

Success:
├─ Button: Show success checkmark
├─ Animation: Checkmark scale (0 → 1)
├─ Duration: 500ms
├─ Navigation: Fade out + fade in to home
```

### Dart Code

```dart
class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset('assets/logo.png', width: 80, height: 80),
            SizedBox(height: 32),
            
            // Title
            Text(
              'Welcome Back!',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
            ),
            SizedBox(height: 32),
            
            // Email field
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                filled: true,
                fillColor: Color(0xFFF0F0F0),
                labelText: 'Email Address',
                hintText: 'your@email.com',
                prefixIcon: Icon(Icons.mail_outline),
                errorText: _emailError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => _validateEmail(value),
            ),
            SizedBox(height: 16),
            
            // Password field
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                filled: true,
                fillColor: Color(0xFFF0F0F0),
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                errorText: _passwordError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => _validatePassword(value),
            ),
            SizedBox(height: 12),
            
            // Remember & Forgot
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (value) => setState(() => _rememberMe = value ?? false),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                  child: Text('← Forgot Password?'),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // Login button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _loginUser,
                child: _isLoading
                  ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text('LOGIN'),
              ),
            ),
            SizedBox(height: 24),
            
            // Sign up link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Don't have account? "),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                  child: Text('Sign Up Here'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _validateEmail(String value) {
    setState(() {
      _emailError = value.isEmpty
        ? 'Email required'
        : !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)
          ? 'Invalid email'
          : null;
    });
  }
  
  void _validatePassword(String value) {
    setState(() {
      _passwordError = value.isEmpty
        ? 'Password required'
        : value.length < 8
          ? 'Min 8 characters'
          : null;
    });
  }
  
  Future<void> _loginUser() async {
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);
    
    if (_emailError != null || _passwordError != null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Call login service
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

---

## 4️⃣ REGISTER SCREEN

**Similar structure to login but with additional fields**

### Layout Structure

```
┌─────────────────────────────┐
│  🎮 EARNPLAY (50dp)         │
│                             │
│  Create Account             │ ← Title
│                             │
│  [Name....................]  │ ← New field
│  [Email...............]     │
│  [Password............]     │
│  [Confirm Password...]      │ ← New field
│                             │
│  □ Referral Code (Optional) │ ← Referral field
│  [Code if available...]     │
│                             │
│  [CREATE ACCOUNT]           │
│  [← Already have account?]  │
│                             │
└─────────────────────────────┘
```

### Key Differences from Login

```
1. Name TextField
   ├─ Type: Filled TextField
   ├─ Label: "Full Name"
   ├─ Icon: Iconsax profile icon
   ├─ Validation: Min 2 chars
   └─ Error: "Name must be at least 2 characters"

2. Confirm Password Field
   ├─ Type: Filled TextField
   ├─ Label: "Confirm Password"
   ├─ Icon: Iconsax lock icon
   ├─ Validation: Must match password
   └─ Error: "Passwords don't match"

3. Referral Code Section
   ├─ Type: Optional ExpansionTile
   ├─ Label: "Have a referral code? (Optional)"
   ├─ TextField: Code input
   ├─ Validation: Real-time check (exists or not)
   ├─ Success: Green checkmark
   ├─ Error: Red X
   └─ Benefit Display: "Join with code UNCLE123 and get ₹500!"

4. Terms Checkbox
   ├─ Text: "I agree to Terms & Conditions"
   ├─ Link: Terms color in blue
   ├─ Validation: Must be checked
   └─ Error: "Please agree to terms"

5. Create Account Button
   ├─ Same as login button
   ├─ Text: "CREATE ACCOUNT"
   ├─ Loading state
   └─ Disabled: If validation fails

6. Success Flow
   ├─ Account created
   ├─ Show success dialog: "Account created successfully!"
   ├─ Auto-login
   ├─ Navigate to home or onboarding
   └─ Animation: Confetti (optional)
```

### Referral Code Integration

```dart
class RegisterScreen extends StatefulWidget {
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _referralController = TextEditingController();
  String? _referralError;
  bool _referralValid = false;
  String? _referrerInfo;
  
  Future<void> _validateReferralCode(String code) async {
    if (code.isEmpty) {
      setState(() {
        _referralError = null;
        _referralValid = false;
        _referrerInfo = null;
      });
      return;
    }
    
    try {
      // Query Firestore for referral code
      final doc = await FirebaseFirestore.instance
        .collection('referralCodes')
        .doc(code.toUpperCase())
        .get();
      
      if (doc.exists) {
        setState(() {
          _referralError = null;
          _referralValid = true;
          _referrerInfo = 'Join with code and get ₹500!';
        });
      } else {
        setState(() {
          _referralError = 'Invalid referral code';
          _referralValid = false;
        });
      }
    } catch (e) {
      setState(() {
        _referralError = 'Error validating code';
        _referralValid = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            // Logo
            Image.asset('assets/logo.png', width: 60, height: 60),
            SizedBox(height: 24),
            
            Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            SizedBox(height: 24),
            
            // Name field
            TextField(
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 16),
            
            // Email field (same as login)
            // Password field (same as login)
            // Confirm password field
            
            SizedBox(height: 16),
            
            // Referral Code Section
            ExpansionTile(
              title: Text('Have a referral code? (Optional)'),
              leading: Icon(Icons.card_giftcard),
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _referralController,
                        decoration: InputDecoration(
                          labelText: 'Referral Code',
                          hintText: 'e.g., UNCLE123',
                          suffixIcon: _referralValid 
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : _referralError != null
                              ? Icon(Icons.cancel, color: Colors.red)
                              : null,
                          errorText: _referralError,
                        ),
                        onChanged: _validateReferralCode,
                      ),
                      if (_referrerInfo != null) ...[
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFB8F0D1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _referrerInfo!,
                            style: TextStyle(
                              color: Color(0xFF002D1B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            // Create button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _createAccount,
                child: Text('CREATE ACCOUNT'),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Login link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have account? '),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Login Here'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _createAccount() async {
    // Validation
    // Create account
    // Handle referral if code exists
    // Navigate
  }
  
  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
  }
}
```

---

## 5️⃣ HOME SCREEN

**Main dashboard showing balance, quick stats, game cards, ads**

### Layout Structure

```
┌─────────────────────────────┐
│ EARNPLAY                    │ ← App bar
├─────────────────────────────┤
│                             │
│ ┌─────────────────────────┐ │
│ │ 💰 Your Balance         │ │ ← Balance card
│ │ ₹5,000.00              │ │
│ │ ✓ Daily Bonus Claimed  │ │
│ └─────────────────────────┘ │
│                             │
│ ✨ Quick Stats              │ ← Section header
│ [Plays: 42] [Ads: 15]      │ ← Stats chips
│                             │
│ 🎮 Featured Games           │ ← Section header
│ [Game Card 1]              │ ← 2-column grid
│ [Game Card 2]              │
│ [Game Card 3]              │
│ [Game Card 4]              │
│                             │
│ ▓▓▓ BANNER AD ▓▓▓            │ ← Banner ad
│                             │
│ 🎁 Referral Card            │ ← Info cards
│ 💳 Withdrawal Card          │
│                             │
└─────────────────────────────┘
```

### Components

```
1. App Bar
   ├─ Height: 56dp
   ├─ Background: Surface
   ├─ Title: "EARNPLAY"
   ├─ Font: Manrope Bold 700, 20sp
   ├─ Leading: None (or hamburger if drawer)
   ├─ Actions: Notification icon (8dp badge)
   └─ Elevation: 2dp shadow

2. Balance Card (Elevated Card)
   ├─ Padding: 24dp
   ├─ Background: Gradient (Primary → Tertiary)
   ├─ Height: 140dp
   ├─ Border Radius: 16dp
   ├─ Elements:
   │  ├─ "Your Balance" (Label Small, 12sp)
   │  ├─ "₹5,000.00" (Display Small, 36sp, bold)
   │  ├─ "✓ Daily Bonus Claimed" (Body Small, 12sp)
   │  └─ "Next bonus in 18 hours" (Caption)
   ├─ Shadows: 8dp blur
   ├─ Animation: Slide up on scroll, maintain position
   └─ Gesture: Tap to refresh balance

3. Stats Section
   ├─ Title: "✨ Quick Stats" (Headline Small, 24sp)
   ├─ Chips: Input chips (horizontal scroll)
   ├─ Items:
   │  ├─ "Games Played: 42"
   │  ├─ "Videos Watched: 15"
   │  ├─ "Coins Earned: 2,450"
   │  └─ "Streak: 7 days 🔥"
   ├─ Chip Design:
   │  ├─ Background: Primary Container (#E8E0FF)
   │  ├─ Text: On Primary Container (#21005D)
   │  ├─ Height: 32dp
   │  ├─ Padding: 12dp horizontal
   │  └─ Border Radius: 24dp
   └─ Scroll: Horizontal, smooth

4. Featured Games Section
   ├─ Title: "🎮 Featured Games" (Headline Small)
   ├─ Layout: 2-column grid
   ├─ Item Height: 200dp
   ├─ Spacing: 12dp
   ├─ Padding: 12dp sides
   └─ Grid Code:
      GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
        children: games.map((game) => GameCard(game)).toList(),
      )

5. Game Card (Filled Card)
   ├─ Size: 160x200dp (in 2-column layout)
   ├─ Background: Surface Dim (#F0F0F0)
   ├─ Border Radius: 12dp
   ├─ Elements:
   │  ├─ Image (120dp square, top)
   │  ├─ Game name (Title Small, 14sp)
   │  ├─ Earn amount (Label Large, 12sp, Tertiary)
   │  └─ "Play" button or "Tap to play"
   ├─ State:
   │  ├─ Default: 0dp elevation
   │  ├─ Hovered: 4dp elevation
   │  └─ Pressed: 8dp elevation
   ├─ Animation: 
   │  ├─ Elevation smooth change
   │  ├─ Scale (0.98x) on press
   │  └─ Image zoom (1.05x) on hover
   └─ Gesture: Tap to navigate to game

Example Game Card:
┌──────────────────┐
│ [GAME IMAGE]     │
│ 120x120          │
├──────────────────┤
│ Tic Tac Toe      │ ← Title
│ +25 💰           │ ← Earn amount
│ [Tap to Play]    │ ← Action
└──────────────────┘

6. Referral Card (Outlined Card)
   ├─ Height: 120dp
   ├─ Padding: 20dp
   ├─ Border: 2dp Primary
   ├─ Corner Radius: 16dp
   ├─ Elements:
   │  ├─ "🎁 Refer & Earn"
   │  ├─ "Invite friends, earn ₹500 each"
   │  └─ "→ Claim Code" (Link style button)
   ├─ Colors: Primary border
   ├─ Animation: Border glow on hover
   └─ Gesture: Navigate to referral screen

7. Withdrawal Card (Outlined Card)
   ├─ Same as referral but:
   ├─ Title: "💳 Withdraw Balance"
   ├─ Subtitle: "Request withdrawal anytime"
   ├─ CTA: "→ Withdraw" (Link style button)
   ├─ Border Color: Secondary (#FF6B9D)
   └─ Gesture: Navigate to withdrawal screen

8. Banner Ad
   ├─ Position: Sticky at bottom above nav
   ├─ Height: 50dp + 8dp padding
   ├─ Animation: Slide up from bottom on load
   └─ Refresh: Every 30s

9. Bottom Navigation Bar
   ├─ Type: Material 3 NavigationBar
   ├─ Height: 80dp
   ├─ Background: Surface
   ├─ Items: 5 destinations
   │  ├─ Home (house icon)
   │  ├─ Watch & Earn (play icon)
   │  ├─ Games (gamepad icon)
   │  ├─ Referral (gift icon)
   │  └─ Profile (person icon)
   ├─ Active: Purple background + label
   ├─ Inactive: Gray text
   ├─ Animation: Scale (0.8x → 1.0x) on selection
   └─ Badge: Notification count on home
```

### Animations

```
Home Screen Entrance:
├─ Logo: Fade in (0 → 1) in 400ms
├─ Balance card: Slide up (32dp) + fade in 400ms
├─ Stats: Staggered fade (100ms between items)
├─ Game cards: Slide up + fade (staggered, 50ms)
└─ Total: Sequence complete by 1.2s

Scroll Behavior:
├─ App bar: Stay fixed (Material 3 style)
├─ Balance card: Stick to top while scrolling
├─ Game cards: Scroll smoothly
├─ Banner ad: Smooth fade in/out on scroll
└─ NAV bar: Stay fixed at bottom

Refresh Animation:
├─ Pull-to-refresh gesture
├─ Circular progress (centered above content)
├─ Balance updates (number animation: old → new)
├─ Duration: 1.5-2s
└─ Completion: Refresh indicator hides
```

---

## 6️⃣ WATCH ADS & EARN SCREEN

**Watch rewarded ads for rewards (no video content)**

### Layout Structure

```
┌─────────────────────────────┐
│ Watch Ads & Earn            │
├─────────────────────────────┤
│                             │
│ Available Today: 12 more    │
│ [████████░░░░░] 75%        │
│                             │
│ Ad 1                        │ ← Ad card
│ [App Banner/Icon]           │
│ "Play Epic Quest"           │
│ Watch 30s ad for +10 💰     │
│ [WATCH AD]                  │
│                             │
│ ┌─────────────────────────┐ │
│ │ [NATIVE AD]             │ │ ← Native ad
│ │ Game App Showcase       │ │
│ │ [Install]               │ │
│ └─────────────────────────┘ │
│                             │
│ Ad 2                        │
│ [App Banner]                │
│ "Clash of Kings"            │
│ Watch 30s ad for +10 💰     │
│ [WATCH AD]                  │
│                             │
│ ▓▓▓ BANNER AD ▓▓▓            │
│                             │
└─────────────────────────────┘
```

### Components

```
1. Header Section
   ├─ Title: "Watch Ads & Earn" (Display Medium, 45sp)
   ├─ Subtitle: "Available Today: 12 more ads"
   ├─ Progress bar showing daily limit
   │  ├─ Height: 8dp
   │  ├─ Background: Outline Variant
   │  ├─ Foreground: Tertiary (green)
   │  ├─ Percentage: Animate value changes
   │  └─ Label: "75% (9/12 watched)"
   └─ Padding: 24dp

2. Ad Card (Elevated Card)
   ├─ Size: Full width - 24dp padding
   ├─ Height: Auto (160-180dp)
   ├─ Padding: 16dp
   ├─ Border Radius: 16dp
   ├─ Elevation: 2dp
   ├─ Elements:
   │  ├─ App Icon/Banner (80x80dp, left side)
   │  │  ├─ Background: White container
   │  │  ├─ Border Radius: 12dp
   │  │  └─ Shadow: 2dp
   │  ├─ App info (right side, expand)
   │  │  ├─ App name (Title Large, 16sp, bold)
   │  │  ├─ Description (Body Small, 12sp, gray)
   │  │  ├─ "Watch 30s ad for +X 💰" (Label Large, Tertiary, 14sp)
   │  │  ├─ Rating: "⭐ 4.5" (Body Small, 12sp)
   │  │  ├─ [WATCH AD] button (Filled, Tertiary, width: 100dp)
   │  │  └─ Status: "✓" checkmark if watched
   │  └─ Layout: Row with horizontal arrangement
   ├─ State:
   │  ├─ Default: Normal
   │  ├─ Hovered: 6dp elevation
   │  ├─ Watched: Opacity 0.6, checkmark overlay, button disabled
   │  └─ Loading: Button shows spinner
   ├─ Animation:
   │  ├─ Card hover: Smooth elevation increase
   │  ├─ Icon scale: (0.95x) on tap
   │  └─ Button press: Scale (0.98x)
   └─ Gesture: Tap to watch ad

3. Native Ad Card (Every 3rd position)
   ├─ Type: Custom Native Ad container
   ├─ Size: Full width - 24dp padding
   ├─ Height: 140dp
   ├─ Background: Filled Card (#F0F0F0)
   ├─ Border: 1dp Outline
   ├─ Corner Radius: 12dp
   ├─ Layout: Horizontal
   │  ├─ Image (left, 100x100)
   │  └─ Content (right, 200dp)
   ├─ Elements:
   │  ├─ "🎮 [AD]" (Label)
   │  ├─ Title ("Download Game App")
   │  ├─ Description ("5M+ downloads")
   │  └─ [INSTALL] button (Outlined)
   ├─ Animation: Subtle pulse
   └─ Gesture: Open play store

4. Banner Ad (Sticky)
   ├─ Position: Bottom above nav
   ├─ Height: 50dp
   ├─ Refresh: Every 30s
   └─ Animation: Fade in/out on refresh

5. Empty State (if no ads available)
   ├─ Icon: 📺 (120dp, gray)
   ├─ Title: "No ads available right now"
   ├─ Subtitle: "Check back later for more rewards"
   ├─ Button: [REFRESH]
   └─ Animation: Bounce icon on load

6. Watched State
   ├─ Card overlay: Semi-transparent (0.6 opacity)
   ├─ Checkmark: ✓ (32dp, green, top right)
   ├─ Status badge: "WATCHED"
   └─ Button: Disabled, grayed out with "WATCHED ✓" text
```

### Watch Ad Flow

```
User taps [WATCH AD] button:

1. Dialog appears
   ├─ Full-screen rewarded ad player
   ├─ Countdown timer: 30s
   ├─ Can't skip (or skip after 5s with penalty)
   ├─ "Close" button disabled until ad completes
   └─ Audio: On by default

2. Ad plays
   ├─ Full-screen video or interactive ad
   ├─ Duration: 15-30 seconds
   ├─ Sound: On by default
   ├─ Mute button: Available
   ├─ Fullscreen: Already fullscreen
   └─ Timer: Visible countdown in top-right

3. Ad completes
   ├─ Success animation
   ├─ Coins animation: +10 💰 floating up
   ├─ Confetti (subtle, 500ms)
   ├─ Dialog shows: "Great! You earned +10 coins"
   ├─ Button: "CLAIM" (auto-enable after ad)
   └─ Delay: 500ms before auto-reward

4. Claim rewards
   ├─ Update balance (counter animation)
   ├─ Update progress bar
   ├─ Mark ad as watched
   ├─ Refresh ad list
   ├─ Snackbar: "Added 10 coins!"
   ├─ Dialog close options: [CLOSE] [NEXT AD]
   └─ If next ad exists: Show next ad option

Dialog Code:
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => RewardedAdDialog(
    adKey: ad.id,
    onComplete: () {
      // Update balance
      // Show success
      // Close dialog
    },
  ),
);
```

### Dart Code Skeleton

```dart
class WatchAdsAndEarnScreen extends StatefulWidget {
  @override
  State<WatchAdsAndEarnScreen> createState() => _WatchAdsAndEarnScreenState();
}

class _WatchAdsAndEarnScreenState extends State<WatchAdsAndEarnScreen> {
  List<AdOffer> ads = [];
  int adsWatchedToday = 0;
  int maxAdsPerDay = 12;
  
  @override
  void initState() {
    super.initState();
    _loadAds();
  }
  
  Future<void> _loadAds() async {
    // Load ads from Firestore or AdMob
    setState(() {
      ads = [
        AdOffer(
          id: '1',
          appName: 'Play Epic Quest',
          appIcon: '...',
          description: 'Action RPG Game',
          rating: '4.5',
          reward: 10,
          watched: false,
        ),
        AdOffer(
          id: '2',
          appName: 'Clash of Kings',
          appIcon: '...',
          description: 'Strategy Game',
          rating: '4.7',
          reward: 10,
          watched: false,
        ),
        // More ads...
      ];
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Watch Ads & Earn')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Today: ${maxAdsPerDay - adsWatchedToday} more',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: adsWatchedToday / maxAdsPerDay,
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation(Color(0xFF1DD1A1)),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${(adsWatchedToday / maxAdsPerDay * 100).toStringAsFixed(0)}% (${adsWatchedToday}/$maxAdsPerDay)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            
            // Ad list
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: ads.length + (ads.length ~/ 3), // Include native ads
              separatorBuilder: (_, index) => SizedBox(height: 12),
              itemBuilder: (_, index) {
                // Every 3rd item is a native ad
                if (index % 4 == 3) {
                  return _buildNativeAd();
                }
                
                final adIndex = index - (index ~/ 4);
                if (adIndex >= ads.length) return SizedBox.shrink();
                
                return _buildAdCard(ads[adIndex]);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdCard(AdOffer ad) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // App icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(ad.appIcon, fit: BoxFit.cover),
              ),
            ),
            SizedBox(width: 16),
            
            // Ad info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ad.appName,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (ad.watched)
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    ad.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '⭐ ${ad.rating}',
                    style: TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Watch 30s ad for +${ad.reward} 💰',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1DD1A1),
                        ),
                      ),
                      SizedBox(
                        height: 36,
                        width: 90,
                        child: ElevatedButton(
                          onPressed: ad.watched ? null : () => _watchAd(ad),
                          child: Text(
                            ad.watched ? '✓' : 'WATCH',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNativeAd() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFD0D0D0)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Image.network('...', width: 100, height: 140, fit: BoxFit.cover),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🎮 [AD]', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10)),
                      Text('Download Game App', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('5M+ downloads', style: TextStyle(fontSize: 12, color: Colors.gray)),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {}, // Open play store
                    child: Text('INSTALL'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _watchAd(AdOffer ad) async {
    // Show rewarded ad dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RewardedAdDialog(
        ad: ad,
        onRewardEarned: (reward) {
          // Update balance
          // Update watched count
          // Mark ad as watched
          setState(() {
            adsWatchedToday++;
            ad.watched = true;
          });
          _loadAds(); // Refresh list
        },
      ),
    );
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}

class AdOffer {
  String id;
  String appName;
  String appIcon;
  String description;
  String rating;
  int reward;
  bool watched;
  
  AdOffer({
    required this.id,
    required this.appName,
    required this.appIcon,
    required this.description,
    required this.rating,
    required this.reward,
    this.watched = false,
  });
}

// Rewarded Ad Dialog
class RewardedAdDialog extends StatefulWidget {
  final AdOffer ad;
  final Function(int) onRewardEarned;
  
  const RewardedAdDialog({
    required this.ad,
    required this.onRewardEarned,
  });
  
  @override
  State<RewardedAdDialog> createState() => _RewardedAdDialogState();
}

class _RewardedAdDialogState extends State<RewardedAdDialog>
    with TickerProviderStateMixin {
  late AnimationController _countdownController;
  int _remainingSeconds = 30;
  bool _adCompleted = false;
  
  @override
  void initState() {
    super.initState();
    _countdownController = AnimationController(
      duration: Duration(seconds: 30),
      vsync: this,
    );
    _startCountdown();
  }
  
  void _startCountdown() {
    _countdownController.forward();
    _countdownController.addListener(() {
      setState(() => _remainingSeconds = (30 - (_countdownController.value * 30)).ceil());
      if (_remainingSeconds <= 0) {
        _adCompleted = true;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // Ad container (simulated)
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(widget.ad.appIcon, fit: BoxFit.cover),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    widget.ad.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.ad.description,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          
          // Countdown timer (top right)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                '${_remainingSeconds}s',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          
          // Close button (only after ad completes)
          if (_adCompleted)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onRewardEarned(widget.ad.reward);
                      Navigator.pop(context);
                    },
                    child: Text('CLAIM +${widget.ad.reward} 💰'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _countdownController.dispose();
    super.dispose();
  }
}
```

---

[CONTINUING WITH REMAINING SCREENS IN PART 3...]

Due to length, I'm breaking into multiple parts. Let me continue with critical screens in Part 3:
