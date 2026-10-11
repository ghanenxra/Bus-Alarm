import 'package:flutter/material.dart';
import '../../core/config/env_config.dart';
import '../../core/networking/api_client.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  final _apiClient = ApiClient();
  bool _isTestingBackend = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _urlController.text = EnvConfig.baseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testBackend() async {
    setState(() {
      _isTestingBackend = true;
      _testResult = null;
    });

    final currentUrl = _urlController.text.trim();
    await EnvConfig.setBaseUrl(currentUrl);

    final online = await _apiClient.checkHealth();
    setState(() {
      _isTestingBackend = false;
      _testResult = online ? 'Connected successfully (200 OK)' : 'Failed to connect to backend';
    });
  }

  Future<void> _triggerTestAlarm() async {
    await NotificationService.instance.showAlarmNotification(
      id: 999,
      stopName: 'Test Stop',
      distanceMeters: 145.0,
      alertId: 'test-local-alarm',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test alarm notification dispatched')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings and Permissions'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.space16),
        children: [
          // Backend Server Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Backend Service URL', style: AppTokens.titleMedium),
                  const SizedBox(height: AppTokens.space8),
                  const Text(
                    'Set the FastAPI server URL (e.g. Render hosted domain or emulator local address).',
                    style: AppTokens.bodySmall,
                  ),
                  const SizedBox(height: AppTokens.space12),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'API Base URL',
                      hintText: 'https://bus-alarm-api.onrender.com',
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _isTestingBackend ? null : _testBackend,
                        child: _isTestingBackend
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTokens.onPrimary),
                              )
                            : const Text('Test Connection'),
                      ),
                    ],
                  ),
                  if (_testResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTokens.space8),
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testResult!.contains('success') ? AppTokens.success : AppTokens.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space16),

          // Android Permissions Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Android System Permissions', style: AppTokens.titleMedium),
                  const SizedBox(height: AppTokens.space12),
                  _buildPermissionRow('Post Notifications', 'Allowed for background delivery', true),
                  _buildPermissionRow('Full-screen Intents', 'Displays alarm over lock screen', true),
                  _buildPermissionRow('Battery Optimization Exemption', 'Recommended for Xiaomi / Samsung / OnePlus', false),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space16),

          // Alarm Sound & Vibration Test
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Test Alarm Channel', style: AppTokens.titleMedium),
                  const SizedBox(height: AppTokens.space8),
                  const Text(
                    'Trigger a sample high-importance alarm notification to confirm ring and vibration.',
                    style: AppTokens.bodySmall,
                  ),
                  const SizedBox(height: AppTokens.space16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Fire Test Alarm Notification'),
                    onPressed: _triggerTestAlarm,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String title, String subtitle, bool isGranted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space12),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle_outline : Icons.info_outline,
            color: isGranted ? AppTokens.success : AppTokens.warning,
            size: 20,
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTokens.bodyMedium),
                Text(subtitle, style: AppTokens.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

