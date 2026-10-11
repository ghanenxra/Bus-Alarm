import 'package:flutter/material.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/tokens.dart';

class AlarmScreen extends StatefulWidget {
  final String? alertId;
  final String stopName;
  final double distanceMeters;
  final String eventType;

  const AlarmScreen({
    super.key,
    this.alertId,
    required this.stopName,
    required this.distanceMeters,
    this.eventType = 'crossing',
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final _apiClient = ApiClient();
  bool _isAcknowledging = false;

  Future<void> _handleDismiss() async {
    setState(() => _isAcknowledging = true);
    if (widget.alertId != null) {
      try {
        await _apiClient.acknowledgeAlert(widget.alertId!, 'dismiss');
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleSnooze() async {
    setState(() => _isAcknowledging = true);
    if (widget.alertId != null) {
      try {
        await _apiClient.acknowledgeAlert(widget.alertId!, 'snooze', snoozeSeconds: 60);
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Maximum contrast black for OLED & alarms
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24, vertical: AppTokens.space32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Status Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTokens.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                      border: Border.all(color: AppTokens.error),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.alarm_on, color: AppTokens.error, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          widget.eventType.toUpperCase(),
                          style: const TextStyle(
                            color: AppTokens.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),
                  const Text('BUS ARRIVING AT', style: AppTokens.bodySmall),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    widget.stopName,
                    style: AppTokens.displayLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              // Central Metric Display
              Column(
                children: [
                  Text(
                    '${widget.distanceMeters.toStringAsFixed(0)}m',
                    style: const TextStyle(
                      fontSize: 64.0,
                      fontWeight: FontWeight.w800,
                      color: AppTokens.onBackground,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const Text(
                    'Distance to stop',
                    style: TextStyle(color: AppTokens.onBackgroundSubtle, fontSize: 16),
                  ),
                ],
              ),

              // Action Buttons
              Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTokens.error,
                      foregroundColor: AppTokens.onError,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                      ),
                    ),
                    onPressed: _isAcknowledging ? null : _handleDismiss,
                    child: const Text(
                      'Dismiss Alarm',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTokens.onBackground,
                      side: const BorderSide(color: AppTokens.surfaceBorder, width: 1.5),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                      ),
                    ),
                    onPressed: _isAcknowledging ? null : _handleSnooze,
                    child: const Text(
                      'Snooze 1 Minute',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

