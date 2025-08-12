import 'package:shared_preferences/shared_preferences.dart';

class PushService {
  // Push notifications deferred. Keep minimal stubs so we can re-enable later.
  static Future<void> registerSavedTokenWithBackend() async {}
  static Future<void> saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }
}
