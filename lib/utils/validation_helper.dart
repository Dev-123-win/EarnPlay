/// Input validation and form helpers
class ValidationHelper {
  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate password strength
  static Map<String, bool> validatePasswordStrength(String password) {
    return {
      'length': password.length >= 8,
      'uppercase': password.contains(RegExp(r'[A-Z]')),
      'lowercase': password.contains(RegExp(r'[a-z]')),
      'digit': password.contains(RegExp(r'\d')),
      'special': password.contains(
        RegExp(r'[!@#$%^&*()_+=\-\[\]{};:<>?,.\\/~`]'),
      ),
    };
  }

  /// Get password strength message
  static String getPasswordStrengthMessage(String password) {
    final strength = validatePasswordStrength(password);
    final passedChecks = strength.values.where((v) => v).length;

    if (passedChecks <= 1) return 'Weak';
    if (passedChecks <= 3) return 'Fair';
    if (passedChecks <= 4) return 'Good';
    return 'Strong';
  }

  /// Validate UPI ID format
  static bool isValidUPI(String upi) {
    final upiRegex = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z]{3,}$');
    return upiRegex.hasMatch(upi);
  }

  /// Validate bank account number
  static bool isValidBankAccount(String account) {
    // Basic validation: 8-17 digits
    final accountRegex = RegExp(r'^\d{8,17}$');
    return accountRegex.hasMatch(account);
  }

  /// Validate IFSC code
  static bool isValidIFSC(String ifsc) {
    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    return ifscRegex.hasMatch(ifsc);
  }

  /// Validate phone number (10 digits for India)
  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\d{10}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Validate coin amount
  static bool isValidCoinAmount(int amount, {int min = 0, int max = 999999}) {
    return amount >= min && amount <= max;
  }

  /// Validate withdrawal amount (min 100 coins)
  static bool isValidWithdrawalAmount(int amount) {
    return amount >= 100 && amount <= 999999;
  }

  /// Validate referral code format (8 alphanumeric)
  static bool isValidReferralCode(String code) {
    final codeRegex = RegExp(r'^[A-Z0-9]{8}$');
    return codeRegex.hasMatch(code);
  }

  /// Validate name (2-50 characters, letters and spaces only)
  static bool isValidName(String name) {
    final nameRegex = RegExp(r'^[a-zA-Z\s]{2,50}$');
    return nameRegex.hasMatch(name);
  }

  /// Sanitize input by removing special characters
  static String sanitizeInput(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9\s@._-]'), '').trim();
  }

  /// Get validation error message
  static String getValidationError(String field, String? value) {
    if (value == null || value.isEmpty) {
      return '$field is required';
    }

    switch (field.toLowerCase()) {
      case 'email':
        if (!isValidEmail(value)) {
          return 'Please enter a valid email address';
        }
        break;
      case 'password':
        if (value.length < 8) {
          return 'Password must be at least 8 characters';
        }
        break;
      case 'phone':
        if (!isValidPhone(value)) {
          return 'Please enter a valid 10-digit phone number';
        }
        break;
      case 'upi':
        if (!isValidUPI(value)) {
          return 'Please enter a valid UPI ID (e.g., name@bank)';
        }
        break;
      case 'referral code':
        if (!isValidReferralCode(value)) {
          return 'Please enter a valid 8-character referral code';
        }
        break;
      case 'amount':
        if (!isValidCoinAmount(int.tryParse(value) ?? 0)) {
          return 'Please enter a valid amount';
        }
        break;
    }

    return '';
  }
}

/// String extensions for common validations
extension StringValidation on String {
  bool get isValidEmail => ValidationHelper.isValidEmail(this);
  bool get isValidPhone => ValidationHelper.isValidPhone(this);
  bool get isValidUPI => ValidationHelper.isValidUPI(this);
  bool get isValidReferralCode => ValidationHelper.isValidReferralCode(this);
  bool get isValidName => ValidationHelper.isValidName(this);

  String get sanitized => ValidationHelper.sanitizeInput(this);
}

/// Integer extensions for validations
extension IntValidation on int {
  bool isValidCoinAmount({int min = 0, int max = 999999}) {
    return ValidationHelper.isValidCoinAmount(this, min: min, max: max);
  }

  bool get isValidWithdrawalAmount {
    return ValidationHelper.isValidWithdrawalAmount(this);
  }
}
