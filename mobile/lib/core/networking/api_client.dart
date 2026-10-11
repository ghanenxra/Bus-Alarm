import 'package:dio/dio.dart';
import '../config/env_config.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Secret': EnvConfig.deviceSecret,
        },
      ),
    );
  }

  // Health & Status
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> checkReadiness() async {
    try {
      final response = await _dio.get('/health/ready');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSystemStatus() async {
    try {
      final response = await _dio.get('/api/v1/status');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  // Device Registration
  Future<String?> registerDevice() async {
    try {
      final response = await _dio.post(
        '/api/v1/devices/register',
        data: {
          'installation_id': EnvConfig.installationId,
          'fcm_token': EnvConfig.fcmToken,
          'platform': 'android',
          'app_version': '1.0.0',
        },
      );
      if (response.statusCode == 201) {
        final deviceId = response.data['device_id'];
        await EnvConfig.setDeviceId(deviceId);
        return deviceId;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> updateFcmToken(String fcmToken) async {
    if (EnvConfig.deviceId == null) return false;
    try {
      final response = await _dio.put(
        '/api/v1/devices/${EnvConfig.deviceId}/fcm-token',
        data: {'fcm_token': fcmToken},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Sessions
  Future<Map<String, dynamic>?> createTrackingSession({
    required String nickname,
    required String shareUrl,
    int pollInterval = 10,
  }) async {
    if (EnvConfig.deviceId == null) {
      await registerDevice();
    }
    try {
      final response = await _dio.post(
        '/api/v1/tracking-sessions',
        data: {
          'device_id': EnvConfig.deviceId,
          'nickname': nickname,
          'share_url': shareUrl,
          'poll_interval_seconds': pollInterval,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> listTrackingSessions() async {
    if (EnvConfig.deviceId == null) return [];
    try {
      final response = await _dio.get(
        '/api/v1/tracking-sessions',
        queryParameters: {'device_id': EnvConfig.deviceId},
      );
      return response.data as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLatestPosition(String sessionId) async {
    if (EnvConfig.deviceId == null) return null;
    try {
      final response = await _dio.get(
        '/api/v1/tracking-sessions/$sessionId/position',
        queryParameters: {'device_id': EnvConfig.deviceId},
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<bool> activateSession(String sessionId) async {
    if (EnvConfig.deviceId == null) return false;
    try {
      final response = await _dio.post(
        '/api/v1/tracking-sessions/$sessionId/activate',
        queryParameters: {'device_id': EnvConfig.deviceId},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pauseSession(String sessionId) async {
    if (EnvConfig.deviceId == null) return false;
    try {
      final response = await _dio.post(
        '/api/v1/tracking-sessions/$sessionId/pause',
        queryParameters: {'device_id': EnvConfig.deviceId},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Geofences
  Future<Map<String, dynamic>?> createGeofence({
    required String sessionId,
    required String name,
    required double latitude,
    required double longitude,
    int radiusMeters = 200,
    int cooldownSeconds = 900,
  }) async {
    if (EnvConfig.deviceId == null) await registerDevice();
    try {
      final response = await _dio.post(
        '/api/v1/geofences',
        data: {
          'device_id': EnvConfig.deviceId,
          'session_id': sessionId,
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'radius_meters': radiusMeters,
          'cooldown_seconds': cooldownSeconds,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Alerts
  Future<bool> acknowledgeAlert(String alertId, String action, {int snoozeSeconds = 0}) async {
    if (EnvConfig.deviceId == null) return false;
    try {
      final response = await _dio.post(
        '/api/v1/alerts/$alertId/acknowledge',
        queryParameters: {'device_id': EnvConfig.deviceId},
        data: {'action': action, 'snooze_seconds': snoozeSeconds},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendTestNotification() async {
    if (EnvConfig.deviceId == null) return false;
    try {
      final response = await _dio.post('/api/v1/devices/${EnvConfig.deviceId}/test-notification');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
