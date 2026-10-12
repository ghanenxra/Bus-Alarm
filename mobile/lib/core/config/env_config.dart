import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class EnvConfig {
  static const String defaultBaseUrl = 'https://bus-alarm.onrender.com';
  
  static SharedPreferences? _prefs;
  static String installationId = 'default-device-install-id';
  static String deviceSecret = 'default-device-secret-key';
  static String? deviceId;
  static String? fcmToken;
  static String baseUrl = defaultBaseUrl;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Installation ID
    var storedInstallId = _prefs?.getString('installation_id');
    if (storedInstallId == null) {
      storedInstallId = const Uuid().v4();
      await _prefs?.setString('installation_id', storedInstallId);
    }
    installationId = storedInstallId;

    // Device secret
    var storedSecret = _prefs?.getString('device_secret');
    if (storedSecret == null) {
      storedSecret = const Uuid().v4();
      await _prefs?.setString('device_secret', storedSecret);
    }
    deviceSecret = storedSecret;

    deviceId = _prefs?.getString('device_id');
    fcmToken = _prefs?.getString('fcm_token');

    final storedUrl = _prefs?.getString('backend_url');
    // Auto-migrate previous localhost or emulator dev URLs to permanent production Render backend
    if (storedUrl == null ||
        storedUrl.isEmpty ||
        storedUrl.contains('localhost') ||
        storedUrl.contains('10.0.2.2')) {
      baseUrl = defaultBaseUrl;
      await _prefs?.setString('backend_url', defaultBaseUrl);
    } else {
      baseUrl = storedUrl;
    }
  }

  static Future<void> setDeviceId(String id) async {
    deviceId = id;
    await _prefs?.setString('device_id', id);
  }

  static Future<void> setFcmToken(String token) async {
    fcmToken = token;
    await _prefs?.setString('fcm_token', token);
  }

  static Future<void> setBaseUrl(String url) async {
    baseUrl = url;
    await _prefs?.setString('backend_url', url);
  }
}

