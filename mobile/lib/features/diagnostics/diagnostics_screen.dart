import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/env_config.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/tokens.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _apiClient = ApiClient();
  Map<String, dynamic>? _backendStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDiagnostics();
  }

  Future<void> _fetchDiagnostics() async {
    setState(() => _isLoading = true);
    final status = await _apiClient.getSystemStatus();
    setState(() {
      _backendStatus = status;
      _isLoading = false;
    });
  }

  void _copyDiagnostics() {
    final text = '''
--- BUS ALARM DIAGNOSTIC REPORT ---
App Version: 1.0.0
Client Platform: Android
Backend URL: ${EnvConfig.baseUrl}
Installation ID: ${EnvConfig.installationId}
Device ID: ${EnvConfig.deviceId ?? 'Not Registered'}
Backend Status: ${_backendStatus?['backend_status'] ?? 'Offline'}
Active Sessions on Server: ${_backendStatus?['active_sessions_count'] ?? 0}
Timestamp: ${DateTime.now().toUtc().toIso8601String()}
[Notice: All JWT tokens, FCM tokens, and device credentials have been redacted.]
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sanitized diagnostics copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTokens.space16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('System Health & Connectivity', style: AppTokens.titleMedium),
                        const SizedBox(height: AppTokens.space12),
                        _buildRow('App Version', '1.0.0+1'),
                        _buildRow('Backend Service', EnvConfig.baseUrl),
                        _buildRow(
                          'Backend Status',
                          _backendStatus?['backend_status'] ?? 'Offline / Unreachable',
                          isSuccess: _backendStatus != null,
                        ),
                        _buildRow(
                          'Active Backend Sessions',
                          '${_backendStatus?['active_sessions_count'] ?? 0}',
                        ),
                        _buildRow(
                          'Device Registration',
                          EnvConfig.deviceId != null ? 'Registered' : 'Pending First Sync',
                          isSuccess: EnvConfig.deviceId != null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Privacy & Redaction', style: AppTokens.titleMedium),
                        const SizedBox(height: AppTokens.space8),
                        const Text(
                          'All tracking link tokens and credentials are encrypted at rest and excluded from telemetry and diagnostic reports.',
                          style: AppTokens.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space24),

                OutlinedButton.icon(
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copy Sanitized Diagnostics'),
                  onPressed: _copyDiagnostics,
                ),
              ],
            ),
    );
  }

  Widget _buildRow(String label, String value, {bool? isSuccess}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTokens.bodySmall),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSuccess == null
                  ? AppTokens.onBackground
                  : (isSuccess ? AppTokens.success : AppTokens.error),
            ),
          ),
        ],
      ),
    );
  }
}
