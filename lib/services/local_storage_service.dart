import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_data_model.dart';

class LocalStorageService {
  static UserData? _cachedUserData;
  static late SharedPreferences _prefs;
  static const String _userDataKey = 'user_data_cache';
  static const String _lastSyncKey = 'last_sync_timestamp';

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCachedUserData();
  }

  static Future<void> _loadCachedUserData() async {
    try {
      final jsonString = _prefs.getString(_userDataKey);
      if (jsonString != null) {
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        _cachedUserData = UserData.fromMap(jsonData);
      }
    } catch (e) {
      // Silently handle corrupted cache
    }
  }

  static Future<UserData?> getUserData() async {
    return _cachedUserData;
  }

  static Future<void> saveUserData(UserData data) async {
    _cachedUserData = data;
    try {
      final jsonString = jsonEncode(data.toMap());
      await _prefs.setString(_userDataKey, jsonString);
      await _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      // Silently handle save errors
    }
  }

  static Future<void> clearUserData() async {
    _cachedUserData = null;
    try {
      await _prefs.remove(_userDataKey);
      await _prefs.remove(_lastSyncKey);
    } catch (e) {
      // Silently handle clear errors
    }
  }

  static DateTime? getLastSyncTime() {
    try {
      final timeString = _prefs.getString(_lastSyncKey);
      return timeString != null ? DateTime.parse(timeString) : null;
    } catch (e) {
      return null;
    }
  }
}
