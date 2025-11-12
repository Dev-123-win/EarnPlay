import '../models/user_data_model.dart';

class LocalStorageService {
  static UserData? _cachedUserData;

  static Future<void> initialize() async {
    // Initialize local storage (can be extended with SharedPreferences later)
  }

  static Future<UserData?> getUserData() async {
    return _cachedUserData;
  }

  static Future<void> saveUserData(UserData data) async {
    _cachedUserData = data;
  }

  static Future<void> clearUserData() async {
    _cachedUserData = null;
  }
}
