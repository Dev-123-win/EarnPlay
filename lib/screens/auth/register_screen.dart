import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../services/firebase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _referralCodeController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _referralCodeController = TextEditingController();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showErrorDialog('Please fill in all required fields');
      return false;
    }

    if (!_emailController.text.contains('@')) {
      _showErrorDialog('Please enter a valid email address');
      return false;
    }

    if (_passwordController.text.length < 6) {
      _showErrorDialog('Password must be at least 6 characters long');
      return false;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog('Passwords do not match');
      return false;
    }

    if (!_agreeToTerms) {
      _showErrorDialog('Please agree to the Terms & Conditions');
      return false;
    }

    return true;
  }

  Future<void> _handleRegister() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseService().signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        referralCode: _referralCodeController.text.isEmpty
            ? null
            : _referralCodeController.text,
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.primary,
        centerTitle: true,
        title: Text(
          'Create Account',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.surface.withOpacity(0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email Field
                    Text(
                      'Email Address',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.transparent,
                      child: TextField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.outline.withOpacity(0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Iconsax.sms,
                            color: colorScheme.primary,
                          ),
                          hintText: 'your@email.com',
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Password Field
                    Text(
                      'Password',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.transparent,
                      child: TextField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.outline.withOpacity(0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Iconsax.lock,
                            color: colorScheme.primary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Iconsax.eye_slash
                                  : Iconsax.eye,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                          hintText: 'Minimum 6 characters',
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Confirm Password Field
                    Text(
                      'Confirm Password',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.transparent,
                      child: TextField(
                        controller: _confirmPasswordController,
                        enabled: !_isLoading,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.outline.withOpacity(0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Iconsax.lock,
                            color: colorScheme.primary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Iconsax.eye_slash
                                  : Iconsax.eye,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              );
                            },
                          ),
                          hintText: 'Re-enter password',
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Referral Code Field
                    Text(
                      'Referral Code (Optional)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.transparent,
                      child: TextField(
                        controller: _referralCodeController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.outline.withOpacity(0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Iconsax.gift,
                            color: colorScheme.primary,
                          ),
                          hintText: 'Enter referral code if you have one',
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Terms & Conditions Checkbox
                    CheckboxListTile(
                      enabled: !_isLoading,
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() => _agreeToTerms = value ?? false);
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'I agree to the ',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : Text(
                                'Create Account',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(
                                    context,
                                  ).pushReplacementNamed('/login');
                                },
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
