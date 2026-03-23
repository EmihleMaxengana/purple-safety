import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _nameKey = 'user_name';
  static const String _emailKey = 'user_email';
  static const String _phoneKey = 'user_phone';
  static const String _passwordKey = 'user_password';

  static Future<void> saveUser(String name, String email, String phone, {String? password}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_phoneKey, phone);
    if (password != null) {
      await prefs.setString(_passwordKey, password);
    }
  }

  static Future<Map<String, String?>> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_nameKey),
      'email': prefs.getString(_emailKey),
      'phone': prefs.getString(_phoneKey),
      'password': prefs.getString(_passwordKey),
    };
  }

  static Future<bool> validatePassword(String enteredPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPassword = prefs.getString(_passwordKey);
    return storedPassword == enteredPassword;
  }

  static Future<void> updatePassword(String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passwordKey, newPassword);
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_passwordKey);
  }
}